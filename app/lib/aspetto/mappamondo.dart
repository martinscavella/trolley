/// Il mappamondo della tela (66): un globo che si gira col dito, con i paesi
/// grattati in cobalto e gli altri grigi. Un paese nuovo si gratta col dito
/// (95–97): il globo ci si avvicina, e sotto una patina d'argento c'è il
/// cobalto. I confini sono quelli veri (dati/confini.dart); la proiezione è
/// ortografica, la Terra vista da lontano. Senza rete e senza fornitori
/// (ADR-005).
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../dati/confini.dart';
import '../dominio/mappa.dart';
import 'movimento.dart';
import 'tavolozza.dart';

/// La Terra vista da lontano, con [centro] davanti: dove finisce un punto
/// della sfera di raggio uno. x verso destra, y verso l'alto, z verso chi
/// guarda: il punto è davanti se z ≥ 0.
class Ortografica {
  factory Ortografica(Coordinate centro) {
    final lon = centro.lon * pi / 180;
    final lat = centro.lat * pi / 180;
    return Ortografica._(
      -sin(lon),
      cos(lon),
      0,
      -sin(lat) * cos(lon),
      -sin(lat) * sin(lon),
      cos(lat),
      cos(lat) * cos(lon),
      cos(lat) * sin(lon),
      sin(lat),
    );
  }

  const Ortografica._(
    this._ex,
    this._ey,
    this._ez,
    this._nx,
    this._ny,
    this._nz,
    this._vx,
    this._vy,
    this._vz,
  );

  // Verso est, verso nord e verso chi guarda, dal centro.
  final double _ex, _ey, _ez, _nx, _ny, _nz, _vx, _vy, _vz;

  /// Il punto [i] di un contorno (x, y, z di seguito).
  (double, double, double) punto(Float32List punti, int i) {
    final (x, y, z) = (punti[i * 3], punti[i * 3 + 1], punti[i * 3 + 2]);
    return (
      x * _ex + y * _ey + z * _ez,
      x * _nx + y * _ny + z * _nz,
      x * _vx + y * _vy + z * _vz,
    );
  }

  double profondita(Float32List punti, int i) =>
      punti[i * 3] * _vx + punti[i * 3 + 1] * _vy + punti[i * 3 + 2] * _vz;

  (double, double, double) coordinata(Coordinate c) =>
      punto(_sullaSfera(c.lat, c.lon), 0);
}

Float32List _sullaSfera(double lat, double lon) {
  final (f, l) = (lat * pi / 180, lon * pi / 180);
  return Float32List.fromList([cos(f) * cos(l), cos(f) * sin(l), sin(f)]);
}

/// Il punto della sfera sotto un contorno: la media dei suoi punti.
Coordinate _baricentro(Float32List punti) {
  var (x, y, z) = (0.0, 0.0, 0.0);
  for (var i = 0; i < punti.length; i += 3) {
    x += punti[i];
    y += punti[i + 1];
    z += punti[i + 2];
  }
  final l = sqrt(x * x + y * y + z * z);
  return (lat: asin(z / l) * 180 / pi, lon: atan2(y, x) * 180 / pi);
}

/// Il paese da grattare, e da dove lo si gratta: il globo ci si avvicina
/// finché il paese occupa metà del disco. Un paese troppo piccolo anche da
/// vicino (il Vaticano, Malta) è un gettone.
typedef _Patina = ({
  String paese,
  Coordinate centro,
  double scala,
  bool gettone,
});

/// Il globo. Si gira trascinandolo; quando [centro] cambia ci gira da solo.
/// I paesi [grattati] compaiono in cobalto poco dopo che si apre. Con un
/// paese [daGrattare] il globo ci si avvicina, non gira più, e il dito
/// gratta la patina: scoperto per buona parte, il paese si colora tutto e si
/// chiama [onScoperto].
class Mappamondo extends StatefulWidget {
  const Mappamondo({
    super.key,
    required this.grattati,
    required this.centro,
    required this.etichetta,
    this.punti = const {},
    this.daGrattare,
    this.onScoperto,
  });

  final Set<String> grattati;

  /// Dove guarda.
  final Coordinate centro;

  /// Cosa legge VoiceOver: «Mappamondo, 7 paesi».
  final String etichetta;

  /// Dove mettere un punto per i paesi grattati troppo piccoli per il globo,
  /// o che stanno dentro un altro.
  final Map<String, Coordinate> punti;

  final String? daGrattare;
  final ValueChanged<String>? onScoperto;

  @override
  State<Mappamondo> createState() => _MappamondoState();
}

class _MappamondoState extends State<Mappamondo> with TickerProviderStateMixin {
  Confini? _confini;
  late Coordinate _centro = widget.centro;
  double _scala = 1;
  double _lato = 300;
  double get _raggio => _lato / 2 - 1;

  /// Il giro verso un nuovo centro e una nuova distanza, da dove si era.
  late final _giro = AnimationController(vsync: this, duration: Ritmo.lungo * 2)
    ..addListener(_gira)
    ..addStatusListener((stato) {
      if (stato == AnimationStatus.completed) _arrivato();
    });
  Coordinate? _da;
  Coordinate? _a;
  double _daScala = 1;
  double _aScala = 1;

  /// Il globo che continua a girare dopo un lancio, rallentando.
  late final _lancio = AnimationController.unbounded(vsync: this)
    ..addListener(_rallenta);
  Offset _direzione = Offset.zero;
  double _lanciato = 0;

  /// Il cobalto dei paesi grattati, che compare aprendo.
  late final _entrata = AnimationController(
    vsync: this,
    duration: Ritmo.lungo * 2,
  );
  late final _comparso = CurvedAnimation(
    parent: _entrata,
    curve: const Interval(0.35, 1, curve: Ritmo.curva),
  );

  /// La patina che se ne va, quando il paese è scoperto.
  late final _scopri = AnimationController(vsync: this, duration: Ritmo.medio);

  _Patina? _patina;

  /// Dove è passato il dito, un tratto per ogni volta che si appoggia.
  final _tratti = <List<Offset>>[];

  /// I punti del paese da scoprire, e quelli già scoperti.
  List<Offset> _celle = const [];
  final _scoperte = <int>{};
  double _passo = 8;
  bool _finito = false;

  /// La larghezza del dito che gratta.
  static const _dito = 28.0;

  /// Quanto del paese va scoperto perché si scopra tutto.
  static const _basta = 0.6;

  bool _avviato = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_avviato) return;
    _avviato = true;
    final ridotto = movimentoRidotto(context);
    Confini.carica().then((confini) {
      if (!mounted) return;
      setState(() => _confini = confini);
      if (ridotto) {
        _entrata.value = 1;
      } else {
        _entrata.forward();
      }
      _preparaPatina();
    });
  }

  @override
  void didUpdateWidget(Mappamondo vecchio) {
    super.didUpdateWidget(vecchio);
    if (vecchio.daGrattare != widget.daGrattare) {
      _preparaPatina();
    } else if (vecchio.centro != widget.centro && _patina == null) {
      _vai(widget.centro, 1);
    }
  }

  @override
  void dispose() {
    _giro.dispose();
    _lancio.dispose();
    _comparso.dispose();
    _entrata.dispose();
    _scopri.dispose();
    super.dispose();
  }

  /// Il paese da grattare adesso: dove guardare, e quanto avvicinarsi.
  void _preparaPatina() {
    final confini = _confini;
    if (confini == null) return;
    _tratti.clear();
    _scoperte.clear();
    _celle = const [];
    _finito = false;
    _scopri.value = 0;
    final paese = widget.daGrattare;
    if (paese == null) {
      _patina = null;
      _vai(widget.centro, 1);
      return;
    }
    // Il contorno più grande: il Portogallo senza le Azzorre.
    Coordinate? centro;
    var lato = 0.0;
    for (final punti in confini.contorni(paese)) {
      final c = _baricentro(punti);
      final o = Ortografica(c);
      var (x0, y0, x1, y1) = (1.0, 1.0, -1.0, -1.0);
      for (var i = 0; i < punti.length ~/ 3; i++) {
        final (x, y, _) = o.punto(punti, i);
        (x0, y0, x1, y1) = (min(x0, x), min(y0, y), max(x1, x), max(y1, y));
      }
      final l = max(x1 - x0, y1 - y0);
      if (l > lato) (lato, centro) = (l, c);
    }
    final gettone = centro == null || lato * _raggio * 10 < 60;
    _patina = (
      paese: paese,
      centro: centro ?? widget.punti[paese] ?? widget.centro,
      scala: gettone ? 6 : (1 / lato).clamp(1, 10).toDouble(),
      gettone: gettone,
    );
    _vai(_patina!.centro, _patina!.scala);
  }

  void _vai(Coordinate centro, double scala) {
    _lancio.stop();
    if (movimentoRidotto(context)) {
      setState(() {
        _centro = centro;
        _scala = scala;
      });
      _arrivato();
      return;
    }
    _da = _centro;
    _a = centro;
    _daScala = _scala;
    _aScala = scala;
    _giro.forward(from: 0);
  }

  void _gira() {
    final (da, a) = (_da, _a);
    if (da == null || a == null) return;
    final t = Ritmo.curva.transform(_giro.value);
    // Per la strada più corta, anche attraverso i 180 gradi.
    final lon = (a.lon - da.lon + 540) % 360 - 180;
    setState(() {
      _centro = (
        lat: da.lat + (a.lat - da.lat) * t,
        lon: _normale(da.lon + lon * t),
      );
      _scala = _daScala + (_aScala - _daScala) * t;
    });
  }

  /// Arrivati sul paese da grattare: i punti da scoprire, una griglia dentro
  /// il suo contorno.
  void _arrivato() {
    final (confini, patina) = (_confini, _patina);
    if (confini == null || patina == null) return;
    final forma = _Globo.formaPatina(
      confini,
      patina,
      Ortografica(_centro),
      Offset(_lato / 2, _lato / 2),
      _raggio * _scala,
    );
    if (forma == null) return;
    final b = forma.getBounds();
    _passo = max(b.longestSide / 18, 5);
    final celle = [
      for (var y = b.top + _passo / 2; y < b.bottom; y += _passo)
        for (var x = b.left + _passo / 2; x < b.right; x += _passo)
          if (forma.contains(Offset(x, y))) Offset(x, y),
    ];
    setState(() => _celle = celle.isEmpty ? [b.center] : celle);
  }

  bool get _sulPaese =>
      _patina != null && !_finito && !_giro.isAnimating && _celle.isNotEmpty;

  void _appoggia(DragStartDetails d) {
    if (!_sulPaese) return;
    setState(() => _tratti.add([d.localPosition]));
    _gratta(d.localPosition, d.localPosition);
  }

  void _gratta(Offset da, Offset a) {
    final raggio = _dito / 2 + _passo * 0.3;
    for (var i = 0; i < _celle.length; i++) {
      if (!_scoperte.contains(i) && _dalTratto(_celle[i], da, a) <= raggio) {
        _scoperte.add(i);
      }
    }
    if (_scoperte.length >= _celle.length * _basta) _finisci();
  }

  static double _dalTratto(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final l = ab.distanceSquared;
    if (l == 0) return (p - a).distance;
    final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / l).clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }

  void _finisci() {
    final paese = _patina?.paese;
    if (_finito || paese == null) return;
    _finito = true;
    HapticFeedback.mediumImpact();
    if (movimentoRidotto(context)) {
      _scopri.value = 1;
      widget.onScoperto?.call(paese);
    } else {
      _scopri.forward().then((_) => widget.onScoperto?.call(paese));
    }
  }

  void _rallenta() {
    final passo = _lancio.value - _lanciato;
    _lanciato = _lancio.value;
    setState(() => _centro = _sposta(_centro, _direzione * passo));
  }

  Coordinate _sposta(Coordinate c, Offset delta) => (
    lat: (c.lat + delta.dy / _raggio * 180 / pi).clamp(-80, 80),
    lon: _normale(c.lon - delta.dx / _raggio * 180 / pi),
  );

  static double _normale(double lon) => (lon + 540) % 360 - 180;

  void _trascina(DragUpdateDetails d) {
    if (_sulPaese) {
      final tratto = _tratti.isEmpty ? null : _tratti.last;
      final prima = tratto == null || tratto.isEmpty
          ? d.localPosition
          : tratto.last;
      setState(() => (tratto ?? (_tratti..add([])).last).add(d.localPosition));
      _gratta(prima, d.localPosition);
    } else if (_patina == null) {
      setState(() => _centro = _sposta(_centro, d.delta));
    }
  }

  void _lascia(DragEndDetails d) {
    final v = d.velocity.pixelsPerSecond;
    if (_patina != null || movimentoRidotto(context) || v.distance < 50) {
      return;
    }
    _direzione = v / v.distance;
    _lanciato = 0;
    _lancio.animateWith(FrictionSimulation(0.05, 0, v.distance));
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, vincoli) {
      _lato = [vincoli.maxWidth, vincoli.maxHeight, 300.0].reduce(min);
      return Semantics(
        image: true,
        label: widget.etichetta,
        child: GestureDetector(
          onPanDown: (_) {
            if (_patina != null) return;
            _giro.stop();
            _lancio.stop();
          },
          onPanStart: _appoggia,
          onPanUpdate: _trascina,
          onPanEnd: _lascia,
          child: AnimatedBuilder(
            animation: Listenable.merge([_comparso, _scopri]),
            builder: (context, _) => CustomPaint(
              size: Size.square(_lato),
              painter: _Globo(
                confini: _confini,
                grattati: widget.grattati,
                punti: widget.punti,
                centro: _centro,
                scala: _scala,
                comparso: _comparso.value,
                patina: _patina,
                tratti: _tratti,
                scoperto: _scopri.value,
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _Globo extends CustomPainter {
  _Globo({
    required this.confini,
    required this.grattati,
    required this.punti,
    required this.centro,
    required this.scala,
    required this.comparso,
    required this.patina,
    required this.tratti,
    required this.scoperto,
  });

  final Confini? confini;
  final Set<String> grattati;
  final Map<String, Coordinate> punti;
  final Coordinate centro;

  /// Quanto è avvicinato: 1 è la Terra intera.
  final double scala;

  /// Quanto è già comparso il cobalto, da 0 a 1.
  final double comparso;

  final _Patina? patina;
  final List<List<Offset>> tratti;

  /// Quanto se n'è andata la patina, da 0 a 1.
  final double scoperto;

  /// I meridiani e i paralleli ogni 30 gradi, con un punto ogni 3.
  static final _reticolo = [
    for (var lon = -180.0; lon < 180; lon += 30)
      _linea([for (var lat = -90.0; lat <= 90; lat += 3) (lat, lon)]),
    for (var lat = -60.0; lat <= 60; lat += 30)
      _linea([for (var lon = -180.0; lon <= 180; lon += 3) (lat, lon)]),
  ];

  static Float32List _linea(List<(double, double)> punti) =>
      Float32List.fromList([
        for (final (lat, lon) in punti) ..._sullaSfera(lat, lon),
      ]);

  /// La forma da grattare: il contorno del paese, o il gettone.
  static Path? formaPatina(
    Confini confini,
    _Patina patina,
    Ortografica o,
    Offset c,
    double r,
  ) {
    if (!patina.gettone) {
      return _percorso(confini.contorni(patina.paese), o, c, r);
    }
    final (x, y, z) = o.coordinata(patina.centro);
    if (z < 0) return null;
    return Path()..addOval(
      Rect.fromCircle(center: Offset(c.dx + x * r, c.dy - y * r), radius: 44),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2 - 1;
    final grande = r * scala;
    final c = size.center(Offset.zero);
    final o = Ortografica(centro);
    canvas
      ..drawCircle(c, r, Paint()..color = Colori.cobaltoChiaro)
      ..save()
      ..clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
    _disegnaReticolo(canvas, o, c, grande);
    final confini = this.confini;
    if (confini != null) {
      final cobalto = Paint()
        ..color = Color.lerp(Colori.terra, Colori.cobalto, comparso)!;
      final pieno = Paint()..color = Colori.cobalto;
      final terra = Paint()..color = Colori.terra;
      final bordo = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = min(0.8 + 0.1 * scala, 1.5)
        ..strokeJoin = StrokeJoin.round
        ..color = Colori.bianco;
      final daGrattare = patina?.paese;
      final visibili = <String>{};
      // I grattati dopo, perché il loro bordo resti sopra.
      for (final dopo in const [false, true]) {
        for (final codice in confini.codici) {
          final colorato = grattati.contains(codice) || codice == daGrattare;
          if (colorato != dopo) continue;
          final percorso = _percorso(confini.contorni(codice), o, c, grande);
          if (percorso == null) continue;
          canvas
            ..drawPath(
              percorso,
              codice == daGrattare ? pieno : (dopo ? cobalto : terra),
            )
            ..drawPath(percorso, bordo);
          if (dopo && percorso.getBounds().longestSide >= 6) {
            visibili.add(codice);
          }
        }
      }
      final bianco = Paint()..color = Colori.bianco;
      for (final codice in grattati) {
        final punto = punti[codice];
        if (visibili.contains(codice) || punto == null) continue;
        final (x, y, z) = o.coordinata(punto);
        if (z < 0) continue;
        final dove = Offset(c.dx + x * grande, c.dy - y * grande);
        canvas
          ..drawCircle(dove, 5, bianco)
          ..drawCircle(dove, 3.5, cobalto);
      }
      final p = patina;
      final forma = p == null ? null : formaPatina(confini, p, o, c, grande);
      if (p != null && forma != null) {
        if (p.gettone) canvas.drawPath(forma, pieno);
        if (scoperto < 1) _disegnaPatina(canvas, forma);
        canvas.drawPath(forma, bordo..strokeWidth = p.gettone ? 3 : 1.5);
      }
    }
    canvas
      ..restore()
      ..drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colori.cenere,
      );
  }

  /// La patina d'argento a righe sopra il paese, tolta dove è passato il
  /// dito; quando il paese è scoperto, sfuma.
  void _disegnaPatina(Canvas canvas, Path forma) {
    final b = forma.getBounds();
    canvas
      ..saveLayer(
        b.inflate(_MappamondoState._dito),
        Paint()..color = Color.fromRGBO(0, 0, 0, 1 - scoperto),
      )
      ..clipPath(forma)
      ..drawRect(
        b,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colori.argento, Colori.foschia, Colori.argento],
          ).createShader(b),
      );
    final righe = Paint()
      ..strokeWidth = 2
      ..color = Colori.bianco.withValues(alpha: 0.45);
    for (var d = -b.height; d < b.width; d += 6) {
      canvas.drawLine(
        Offset(b.left + d, b.bottom),
        Offset(b.left + d + b.height, b.top),
        righe,
      );
    }
    final via = Paint()
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.stroke
      ..strokeWidth = _MappamondoState._dito
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final tratto in tratti) {
      if (tratto.length == 1) {
        canvas.drawCircle(
          tratto.single,
          _MappamondoState._dito / 2,
          Paint()..blendMode = BlendMode.clear,
        );
      } else {
        canvas.drawPath(Path()..addPolygon(tratto, false), via);
      }
    }
    canvas.restore();
  }

  void _disegnaReticolo(Canvas canvas, Ortografica o, Offset c, double r) {
    final percorso = Path();
    for (final linea in _reticolo) {
      var dentro = false;
      for (var i = 0; i < linea.length ~/ 3; i++) {
        final (x, y, z) = o.punto(linea, i);
        final p = Offset(c.dx + x * r, c.dy - y * r);
        if (z < 0) {
          dentro = false;
        } else if (dentro) {
          percorso.lineTo(p.dx, p.dy);
        } else {
          percorso.moveTo(p.dx, p.dy);
          dentro = true;
        }
      }
    }
    canvas.drawPath(
      percorso,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colori.bianco.withValues(alpha: 0.6),
    );
  }

  /// I contorni di un paese sul globo. I punti dietro si portano sul bordo
  /// del disco, nella loro direzione: così un paese a cavallo del bordo resta
  /// chiuso, e i contorni tutti dietro non si disegnano.
  static Path? _percorso(
    List<Float32List> contorni,
    Ortografica o,
    Offset c,
    double r,
  ) {
    Path? percorso;
    for (final punti in contorni) {
      final n = punti.length ~/ 3;
      var davanti = false;
      for (var i = 0; i < n && !davanti; i++) {
        davanti = o.profondita(punti, i) >= 0;
      }
      if (!davanti) continue;
      percorso ??= Path();
      var primo = true;
      for (var i = 0; i < n; i++) {
        var (x, y, z) = o.punto(punti, i);
        if (z < 0) {
          final l = sqrt(x * x + y * y);
          if (l == 0) continue;
          x /= l;
          y /= l;
        }
        final (px, py) = (c.dx + x * r, c.dy - y * r);
        if (primo) {
          percorso.moveTo(px, py);
          primo = false;
        } else {
          percorso.lineTo(px, py);
        }
      }
      percorso.close();
    }
    return percorso;
  }

  // Si ridisegna a ogni cambio: il dito, il giro, la patina che sfuma.
  @override
  bool shouldRepaint(_Globo vecchio) => true;
}
