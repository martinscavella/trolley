/// Il mappamondo della tela (66, rifatto nella 144 e nella 149): la Terra
/// disegnata, una sfera d'inchiostro con un alone cobalto, con il giorno e la
/// notte di adesso. Da lontano la terra è fatta di puntini, chiari dove è
/// giorno e spenti dove è notte, e i paesi visti sono accesi: puntini bianchi
/// su un alone cobalto. Da vicino i puntini lasciano il posto alle forme.
///
/// Il globo si muove come un oggetto vero: lanciato col dito continua a
/// girare e rallenta, a riposo gira piano da solo, e verso un paese ci vola
/// allontanandosi un poco a metà strada. Il globo piccolo si apre a tutto
/// schermo sotto le dita: cresce da dov'è, seguendole, e lasciato prosegue
/// con la loro velocità (tela, 149).
///
/// Un paese nuovo si gratta col dito (95–97): il globo ci si avvicina, e
/// sotto una patina d'argento c'è il cobalto. I confini sono quelli veri
/// (dati/confini.dart); la proiezione è ortografica, la Terra vista da
/// lontano. Senza rete e senza fornitori (ADR-005).
///
/// La grattata è viva (tela, 138): la patina luccica prima che la si tocchi,
/// dove passa il dito si stacca a pezzi d'argento che cadono, e il telefono
/// vibra piano, più fitto quanto più si scopre. Scoperto il paese, la patina
/// salta via, il paese si gonfia e torna, un anello di cobalto si allarga, e
/// il telefono dà il colpo pieno. Con «Riduci movimento» niente pezzi, luce,
/// anello né giro da solo: le cose compaiono, con lo stesso colpo.
library;

import 'dart:math';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui' show FragmentProgram, FragmentShader, PointMode, lerpDouble;

import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../dati/confini.dart';
import '../dominio/mappa.dart';
import '../dominio/sole.dart';
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

  /// Verso est, verso nord e verso chi guarda: per chi disegna la Terra
  /// punto per punto.
  List<double> get assi => [_ex, _ey, _ez, _nx, _ny, _nz, _vx, _vy, _vz];

  /// Il punto della Terra che si vede in [x], [y] del disco di raggio uno;
  /// `null` fuori dal disco.
  Coordinate? inverso(double x, double y) {
    final d = x * x + y * y;
    if (d > 1) return null;
    final z = sqrt(1 - d);
    final (wx, wy, wz) = (
      x * _ex + y * _nx + z * _vx,
      x * _ey + y * _ny + z * _vy,
      x * _ez + y * _nz + z * _vz,
    );
    return (
      lat: asin(wz.clamp(-1.0, 1.0)) * 180 / pi,
      lon: atan2(wy, wx) * 180 / pi,
    );
  }
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

/// Quanto sono lontani due punti della Terra, in gradi d'arco.
double distanzaSulGlobo(Coordinate a, Coordinate b) {
  final (pa, pb) = (_sullaSfera(a.lat, a.lon), _sullaSfera(b.lat, b.lon));
  final d = pa[0] * pb[0] + pa[1] * pb[1] + pa[2] * pb[2];
  return acos(d.clamp(-1.0, 1.0)) * 180 / pi;
}

/// Il punto a [t] della strada più corta da [a] a [b], sul cerchio massimo:
/// il globo gira come una palla, non lungo i meridiani.
Coordinate sullaStrada(Coordinate a, Coordinate b, double t) {
  final (pa, pb) = (_sullaSfera(a.lat, a.lon), _sullaSfera(b.lat, b.lon));
  final d = (pa[0] * pb[0] + pa[1] * pb[1] + pa[2] * pb[2]).clamp(-1.0, 1.0);
  final angolo = acos(d);
  if (angolo < 1e-6) return b;
  final (ka, kb) = (
    sin((1 - t) * angolo) / sin(angolo),
    sin(t * angolo) / sin(angolo),
  );
  final (x, y, z) = (
    pa[0] * ka + pb[0] * kb,
    pa[1] * ka + pb[1] * kb,
    pa[2] * ka + pb[2] * kb,
  );
  return (
    lat: asin(z.clamp(-1.0, 1.0)) * 180 / pi,
    lon: atan2(y, x) * 180 / pi,
  );
}

/// La sfera disegnata (tela, 144 e 149): il programma che colora il fondo
/// della Terra, chiaro dove è giorno e buio dove è notte. È nell'app: niente
/// rete (ADR-005). Se non si carica, la sfera è un fondo sfumato, e il giorno
/// e la notte li dicono solo i puntini.
class SferaDisegnata {
  SferaDisegnata._(this._fondo);

  final FragmentShader _fondo;

  static Future<SferaDisegnata?>? _caricata;
  static Future<SferaDisegnata?> carica() => _caricata ??= _leggi();

  static Future<SferaDisegnata?> _leggi() async {
    try {
      final programma = await FragmentProgram.fromAsset('shaders/sfera.frag');
      return SferaDisegnata._(programma.fragmentShader());
    } on Object {
      return null;
    }
  }

  /// Il fondo della sfera vista con [o], grande [raggio] attorno a
  /// [centro], con il sole a picco su [sole].
  Shader fondo(Ortografica o, Offset centro, double raggio, Coordinate sole) {
    final (f, l) = (sole.lat * pi / 180, sole.lon * pi / 180);
    const giorno = Colori.giornoSullaTerra;
    const notte = Colori.notteBuia;
    final valori = [
      centro.dx,
      centro.dy,
      raggio,
      ...o.assi,
      cos(f) * cos(l),
      cos(f) * sin(l),
      sin(f),
      giorno.r,
      giorno.g,
      giorno.b,
      notte.r,
      notte.g,
      notte.b,
    ];
    for (final (i, v) in valori.indexed) {
      _fondo.setFloat(i, v);
    }
    return _fondo;
  }
}

/// La bandiera di un paese (tela, 151): i puntini dei paesi visti ne
/// prendono i colori, ciascuno quello del punto della bandiera che gli
/// corrisponde. Viene dall'emoji del telefono, che le ha tutte e non chiede
/// la rete: si disegna una volta, se ne leggono i colori, e si tiene.
class Bandiera {
  Bandiera._(this._rgba, this._larga, this._l, this._t, this._r, this._b);

  final Uint8List _rgba;
  final int _larga;
  final int _l, _t, _r, _b;

  /// Il colore del punto [u], [v] della bandiera: da sinistra a destra e
  /// dall'alto in basso, da 0 a 1.
  Color colore(double u, double v) {
    final x = (_l + u.clamp(0.0, 1.0) * (_r - _l)).round();
    final y = (_t + v.clamp(0.0, 1.0) * (_b - _t)).round();
    final i = (y * _larga + x) * 4;
    return Color.fromARGB(255, _rgba[i], _rgba[i + 1], _rgba[i + 2]);
  }

  static final _bandiere = <String, Future<Bandiera?>>{};

  /// La bandiera di [codice]; `null` se il telefono non ce l'ha: allora i
  /// puntini restano bianchi.
  static Future<Bandiera?> di(String codice) =>
      _bandiere[codice] ??= _disegna(codice);

  /// Per le prove, che non hanno le emoji: una bandiera disegnata a mano.
  @visibleForTesting
  static void usa(String codice, Future<Bandiera?> bandiera) =>
      _bandiere[codice] = bandiera;

  static Future<Bandiera?> _disegna(String codice) async {
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(codice)) return null;
    try {
      // Le due lettere del codice, come lettere regionali: l'emoji.
      final emoji = String.fromCharCodes([
        for (final c in codice.codeUnits) 0x1F1E6 + c - 65,
      ]);
      final testo = TextPainter(
        text: TextSpan(text: emoji, style: const TextStyle(fontSize: 96)),
        textDirection: TextDirection.ltr,
      )..layout();
      final registro = ui.PictureRecorder();
      testo.paint(Canvas(registro), Offset.zero);
      final immagine = await registro.endRecording().toImage(
        testo.width.ceil(),
        testo.height.ceil(),
      );
      return await daImmagine(immagine);
    } on Object {
      return null;
    }
  }

  /// La bandiera dentro [immagine]: il rettangolo pieno, senza il margine
  /// trasparente. Se non ha almeno due colori non è una bandiera (sono le
  /// due lettere, senza le emoji), e non vale.
  static Future<Bandiera?> daImmagine(ui.Image immagine) async {
    final dati = await immagine.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    if (dati == null) return null;
    final rgba = dati.buffer.asUint8List();
    final (larga, alta) = (immagine.width, immagine.height);
    var (l, t, r, b) = (larga, alta, -1, -1);
    final colori = <int>{};
    for (var y = 0; y < alta; y++) {
      for (var x = 0; x < larga; x++) {
        final i = (y * larga + x) * 4;
        if (rgba[i + 3] < 200) continue;
        (l, t, r, b) = (min(l, x), min(t, y), max(r, x), max(b, y));
        colori.add(
          (rgba[i] >> 5) << 6 | (rgba[i + 1] >> 5) << 3 | rgba[i + 2] >> 5,
        );
      }
    }
    if (r < l || colori.length < 2) return null;
    // Un poco dentro dal bordo, che nelle emoji è sfumato.
    final (mx, my) = (((r - l) * 0.04).round(), ((b - t) * 0.04).round());
    return Bandiera._(rgba, larga, l + mx, t + my, r - mx, b - my);
  }
}

/// Dove sta un paese sulla Terra, per metterci sopra la sua bandiera: il
/// suo contorno più grande, in gradi, attorno al suo centro (anche a cavallo
/// dei 180 gradi).
class _Riquadro {
  factory _Riquadro(Float32List punti) {
    final centro = _baricentro(punti).lon;
    double attorno(double lon) => centro + (lon - centro + 540) % 360 - 180;
    var (lon0, lon1, lat0, lat1) = (360.0, -360.0, 90.0, -90.0);
    for (var i = 0; i < punti.length; i += 3) {
      final (x, y, z) = (punti[i], punti[i + 1], punti[i + 2]);
      final lon = attorno(atan2(y, x) * 180 / pi);
      final lat = asin(z.clamp(-1.0, 1.0)) * 180 / pi;
      (lon0, lon1) = (min(lon0, lon), max(lon1, lon));
      (lat0, lat1) = (min(lat0, lat), max(lat1, lat));
    }
    return _Riquadro._(centro, lon0, lon1, lat0, lat1);
  }

  const _Riquadro._(
    this._lonCentro,
    this._lon0,
    this._lon1,
    this._lat0,
    this._lat1,
  );

  final double _lonCentro, _lon0, _lon1, _lat0, _lat1;

  double _attorno(double lon) =>
      _lonCentro + (lon - _lonCentro + 540) % 360 - 180;

  /// Dove cade [lat], [lon] sulla bandiera: da sinistra a destra, dall'alto
  /// in basso.
  (double, double) uv(double lat, double lon) => (
    (_attorno(lon) - _lon0) / max(_lon1 - _lon0, 1e-6),
    (_lat1 - lat) / max(_lat1 - _lat0, 1e-6),
  );
}

/// Il colore dei puntini dei paesi accesi, uno per puntino (0 per gli
/// altri), e dove cadono sulla bandiera da sinistra a destra: per l'onda che
/// la attraversa.
class _Tinte {
  const _Tinte(this.colore, this.u);

  final Int32List colore;
  final Float32List u;

  static _Tinte di(
    Puntini puntini,
    Map<String, ({_Riquadro riquadro, Bandiera? bandiera})> paesi,
  ) {
    final colore = Int32List(puntini.length);
    final u = Float32List(puntini.length);
    final p = puntini.punti;
    for (var i = 0; i < puntini.length; i++) {
      final paese = paesi[puntini.paese(i)];
      if (paese == null) continue;
      final (x, y, z) = (p[i * 3], p[i * 3 + 1], p[i * 3 + 2]);
      final (pu, pv) = paese.riquadro.uv(
        asin(z.clamp(-1.0, 1.0)) * 180 / pi,
        atan2(y, x) * 180 / pi,
      );
      u[i] = pu;
      colore[i] = (paese.bandiera?.colore(pu, pv) ?? Colori.bianco).toARGB32();
    }
    return _Tinte(colore, u);
  }
}

/// Lo spazio attorno alla sfera per l'alone (tela, 144).
const _aria = 10.0;

/// La molla con cui il globo si apre, si chiude e torna (tela, 149): svelta,
/// e si posa senza tremare.
final _mollaApertura = SpringDescription.withDampingRatio(
  mass: 1,
  stiffness: 230,
  ratio: 0.86,
);

/// Un pezzo di patina staccato dal dito: cade, gira, e sparisce.
class _Briciola {
  _Briciola(this.dove, this.velocita, this.giro, this.colore, this.lato);

  Offset dove;
  Offset velocita;
  double giro;
  final Color colore;
  final double lato;

  /// Quanto gli resta, da 1 a 0.
  double vita = 1;
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

/// Dove sta il disco di un globo sullo schermo: il centro e il raggio.
typedef Disco = ({Offset centro, double raggio});

/// Il globo. Si gira trascinandolo; quando [centro] cambia ci vola da solo.
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
    this.onTocca,
    this.avvicinabile = false,
    this.scelto,
    this.latoMassimo = 300,
    this.onAllarga,
    this.onAllargaFine,
    this.onApri,
    this.apertura,
    this.da,
    this.onChiuso,
    this.onTieniPremuto,
    this.pienoSchermo = false,
    this.giraDaSolo = false,
  });

  /// Spento nelle prove, che aspettano che tutto si fermi: un globo che
  /// gira da solo non si ferma mai.
  static bool siGiraDaSolo = true;

  /// Che ora è, per il giorno e la notte: le prove la fissano.
  @visibleForTesting
  static DateTime Function() adesso = DateTime.now;

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

  /// Un tocco sul globo: il paese che c'è sotto, `null` sul mare. Mentre c'è
  /// un paese da grattare, il dito gratta e non tocca.
  final ValueChanged<String?>? onTocca;

  /// Si avvicina con due dita e con un doppio tocco (tela, 146).
  final bool avvicinabile;

  /// Il paese toccato, che si accende e si contorna di bianco (tela, 147).
  final String? scelto;

  /// Quanto può essere grande, al massimo.
  final double latoMassimo;

  /// Il globo piccolo allargato con due dita (tela, 149): quanto si sono
  /// allargate dall'inizio del gesto, e di quanto si è spostato il punto fra
  /// le due. Il globo piccolo non si muove: lo segue quello a tutto schermo.
  final void Function(double scala, Offset spostamento)? onAllarga;

  /// Le dita che allargavano si sono alzate, a questa velocità (in scala al
  /// secondo; più di zero se si allargavano ancora).
  final ValueChanged<double>? onAllargaFine;

  /// Con VoiceOver: «Apri a tutto schermo», fra le azioni del globo.
  final VoidCallback? onApri;

  /// Il globo a tutto schermo, quanto è aperto: 0 è al posto del globo
  /// piccolo, [da]; 1 è a tutto schermo. Lo muovono le dita e le molle.
  final AnimationController? apertura;
  final Disco? da;

  /// Chiuso del tutto: è tornato al posto del globo piccolo.
  final VoidCallback? onChiuso;

  /// Un paese tenuto premuto: il paese che c'è sotto, `null` sul mare. Più
  /// lento di un tocco, così girando e avvicinando non se ne sceglie uno per
  /// sbaglio (tela, 147).
  final ValueChanged<String?>? onTieniPremuto;

  /// Occupa tutto lo spazio che ha, e la Terra si ritaglia sulla sfera, non
  /// su un cerchio fisso: da vicino riempie lo schermo, come una mappa
  /// (tela, 147).
  final bool pienoSchermo;

  /// A riposo gira piano da solo, verso est come la Terra (tela, 149).
  final bool giraDaSolo;

  @override
  State<Mappamondo> createState() => StatoMappamondo();
}

class StatoMappamondo extends State<Mappamondo> with TickerProviderStateMixin {
  Confini? _confini;
  SferaDisegnata? _sfera;

  /// Le bandiere dei paesi accesi, man mano che il telefono le disegna, e i
  /// colori che ne vengono, puntino per puntino.
  final _bandiere = <String, Bandiera?>{};
  final _chieste = <String>{};
  final _riquadri = <String, _Riquadro?>{};
  _Tinte? _tinte;
  String _firmaTinte = '';

  /// I secondi che passano, per la bandiera che sventola; `null` se è ferma.
  double? _tempo;

  /// Dove sta il sole: si aggiorna ogni minuto, e il giorno avanza.
  Coordinate _sole = sottoIlSole(Mappamondo.adesso());
  Timer? _orologio;

  late Coordinate _centro = widget.centro;
  double _scala = 1;
  double _lato = 300;

  /// Lo spazio dove si disegna: un quadrato, o tutto lo schermo.
  Size _spazio = const Size.square(300);
  Offset get _mezzo => _spazio.center(Offset.zero);

  /// Il raggio della Terra intera quando il globo è al suo posto.
  double get _raggioPieno => _lato / 2 - _aria;

  /// Quanto è aperto il globo a tutto schermo; 1 per gli altri.
  double get _aperto => widget.apertura?.value ?? 1;

  /// Il disco della Terra intera adesso: a metà apertura, fra il posto del
  /// globo piccolo e il mezzo dello schermo.
  Offset get _c {
    final da = widget.da;
    if (da == null || _aperto >= 1) return _mezzo;
    return Offset.lerp(da.centro, _mezzo, _aperto)!;
  }

  double get _r {
    final da = widget.da;
    if (da == null || _aperto >= 1) return _raggioPieno;
    return lerpDouble(da.raggio, _raggioPieno, _aperto)!;
  }

  /// Il volo verso un nuovo centro e una nuova distanza, da dove si era.
  late final _giro = AnimationController(vsync: this, duration: Ritmo.lungo * 2)
    ..addListener(_gira)
    ..addStatusListener((stato) {
      if (stato == AnimationStatus.completed) _arrivato();
    });
  Coordinate? _da;
  Coordinate? _a;
  double _daScala = 1;
  double _aScala = 1;

  /// Quanto si allontana a metà volo: di più per i voli lunghi.
  double _arco = 0;

  /// Il globo che continua a girare dopo un lancio, rallentando.
  late final _lancio = AnimationController.unbounded(vsync: this)
    ..addListener(_rallenta);
  Offset _direzione = Offset.zero;
  double _lanciato = 0;

  /// Il giro piano, a riposo: gradi al secondo, che salgono piano quando le
  /// dita lasciano e si fermano quando tornano.
  late final Ticker _lento = createTicker(_giraPiano);
  Duration _ultimoLento = Duration.zero;
  double _velocitaLenta = 0;
  int _dita = 0;
  static const _gradiAlSecondo = 3.5;

  /// Il cobalto dei paesi grattati, che compare aprendo.
  late final _entrata = AnimationController(
    vsync: this,
    duration: Ritmo.lungo * 2,
  );
  late final _comparso = CurvedAnimation(
    parent: _entrata,
    curve: const Interval(0.35, 1, curve: Ritmo.curva),
  );

  /// Il paese scelto che si accende, arrivati.
  late final _accendi = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  bool _accendiArrivati = false;

  /// La patina che se ne va, quando il paese è scoperto.
  late final _scopri = AnimationController(vsync: this, duration: Ritmo.medio);

  /// La luce che passa sulla patina, finché non la si tocca.
  late final _luce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  /// Il paese che si gonfia e l'anello che si allarga, scoperto.
  late final _festa = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );

  /// I pezzi di patina che cadono, mossi da un ticker solo finché ce n'è.
  final _briciole = <_Briciola>[];
  late final Ticker _caduta = createTicker(_cadono);
  Duration _ultimoPasso = Duration.zero;
  final _caso = Random();

  /// L'ultima vibrazione mentre si gratta: non più spesso di così.
  DateTime _vibrato = DateTime(0);

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

  /// Il globo piccolo sta passando le sue dita a quello grande.
  bool _apre = false;

  /// Si sta chiudendo da vicino: la distanza torna alla Terra intera
  /// insieme all'apertura.
  double? _scalaChiudendo;

  @override
  void initState() {
    super.initState();
    widget.apertura?.addListener(_seguiApertura);
    // Un paese già scelto quando il globo compare è già acceso.
    if (widget.scelto != null) _accendi.value = 1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_avviato) return;
    _avviato = true;
    final ridotto = movimentoRidotto(context);
    SferaDisegnata.carica().then((sfera) {
      if (mounted && sfera != null) setState(() => _sfera = sfera);
    });
    _orologio = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _sole = sottoIlSole(Mappamondo.adesso()));
    });
    if (widget.giraDaSolo && Mappamondo.siGiraDaSolo && !ridotto) {
      _tempo = 0;
      _lento.start();
    }
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
  void didUpdateWidget(Mappamondo oldWidget) {
    super.didUpdateWidget(oldWidget);
    final vecchio = oldWidget;
    if (vecchio.apertura != widget.apertura) {
      vecchio.apertura?.removeListener(_seguiApertura);
      widget.apertura?.addListener(_seguiApertura);
    }
    if (vecchio.daGrattare != widget.daGrattare) {
      _preparaPatina();
    } else if (vecchio.centro != widget.centro && _patina == null) {
      _vai(widget.centro, _scala);
    }
    if (vecchio.scelto != widget.scelto) {
      if (widget.scelto == null || movimentoRidotto(context)) {
        _accendi.value = widget.scelto == null ? 0 : 1;
      } else {
        _accendi.value = 0;
        // Si accende quando il globo ci è arrivato.
        if (_giro.isAnimating) {
          _accendiArrivati = true;
        } else {
          _accendi.forward(from: 0);
        }
      }
    }
  }

  @override
  void dispose() {
    widget.apertura?.removeListener(_seguiApertura);
    _orologio?.cancel();
    _giro.dispose();
    _lancio.dispose();
    _lento.dispose();
    _comparso.dispose();
    _entrata.dispose();
    _accendi.dispose();
    _scopri.dispose();
    _luce.dispose();
    _festa.dispose();
    _caduta.dispose();
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
    _festa.value = 0;
    _briciole.clear();
    final paese = widget.daGrattare;
    if (paese == null) {
      final prima = _patina;
      _patina = null;
      if (prima != null) _vai(widget.centro, 1);
      return;
    }
    final (centro, lato) = _inquadra(confini, paese);
    final gettone = centro == null || lato * _r * 10 < 60;
    _patina = (
      paese: paese,
      centro: centro ?? widget.punti[paese] ?? widget.centro,
      scala: gettone ? 6 : (1 / lato).clamp(1, 10).toDouble(),
      gettone: gettone,
    );
    _vai(_patina!.centro, _patina!.scala);
  }

  /// Dove guardare un paese, e quanto è largo visto da lì sul disco di
  /// raggio uno: il contorno più grande, il Portogallo senza le Azzorre.
  static (Coordinate?, double) _inquadra(Confini confini, String paese) {
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
    return (centro, lato);
  }

  /// Quanto ci si può avvicinare con le dita.
  static const _vicinissimo = 6.0;

  /// Quanto è avvicinato adesso: 1 è la Terra intera.
  double get scala => _scala;

  /// Dove guarda adesso, anche a metà di un giro.
  Coordinate get centroAttuale => _centro;

  /// Dove sta il disco della Terra sullo schermo: per aprire da qui il globo
  /// a tutto schermo.
  Disco? get disco {
    final scatola = context.findRenderObject();
    if (scatola is! RenderBox || !scatola.hasSize) return null;
    return (centro: scatola.localToGlobal(_c), raggio: _r);
  }

  /// Guarda subito [centro], senza volarci: il globo piccolo, quando quello
  /// grande si è richiuso su di lui.
  void guarda(Coordinate centro) {
    _giro.stop();
    _lancio.stop();
    setState(() => _centro = centro);
  }

  /// Più vicino, o più lontano (tela, 146): per chi non può usare due dita.
  void avvicina() => _vai(_centro, min(_scala * 2, _vicinissimo));
  void allontana() => _vai(_centro, max(_scala / 2, 1));

  /// Il globo vola su [paese] e lo inquadra, senza allontanarsi se si era
  /// già vicini (tela, 147).
  void vola(String paese) {
    final confini = _confini;
    if (confini == null || _patina != null) return;
    final (centro, lato) = _inquadra(confini, paese);
    final dove = centro ?? widget.punti[paese];
    if (dove == null) return;
    final scala = lato == 0 ? 4.0 : (0.9 / lato).clamp(1.0, _vicinissimo);
    _vai(dove, max(scala, min(_scala, _vicinissimo)));
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
    // Un volo lungo dura di più, e a metà si allontana per vedere dove va;
    // solo a tutto schermo, dove il globo ha spazio per farsi piccolo.
    final gradi = distanzaSulGlobo(_centro, centro);
    _arco = widget.pienoSchermo ? 0.32 * min(gradi / 70, 1) : 0;
    _giro
      ..duration = Duration(
        milliseconds: (650 + 650 * min(gradi / 120, 1)).round(),
      )
      ..forward(from: 0);
  }

  void _gira() {
    final (da, a) = (_da, _a);
    if (da == null || a == null) return;
    final t = Curves.easeInOutCubic.transform(_giro.value);
    setState(() {
      _centro = sullaStrada(da, a, t);
      _scala =
          (_daScala + (_aScala - _daScala) * t) / (1 + _arco * sin(pi * t));
    });
  }

  /// Arrivati: il paese scelto si accende; sul paese da grattare, i punti da
  /// scoprire, una griglia dentro il suo contorno.
  void _arrivato() {
    if (_accendiArrivati) {
      _accendiArrivati = false;
      _accendi.forward(from: 0);
    }
    final (confini, patina) = (_confini, _patina);
    if (confini == null || patina == null) return;
    final forma = _Globo.formaPatina(
      confini,
      patina,
      Ortografica(_centro),
      _c,
      _r * _scala,
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
    if (!movimentoRidotto(context)) _luce.repeat();
  }

  // --- L'apertura a tutto schermo (tela, 149) ---

  /// Il globo grande segue le dita che allargano quello piccolo: il raggio
  /// della Terra è quello del piccolo per quanto si sono allargate.
  void seguiDita(double scalaDita, Offset spostamento) {
    final da = widget.da;
    final apertura = widget.apertura;
    if (da == null || apertura == null) return;
    apertura.stop();
    _giro.stop();
    _lancio.stop();
    _scalaChiudendo = null;
    _raggioDalleDita(da.raggio * scalaDita);
    setState(() => _centro = _sposta(_centro, spostamento));
  }

  /// Le dita si sono alzate: se il globo era aperto abbastanza, o le dita
  /// allargavano ancora, si apre del tutto; se no torna al suo posto.
  void lasciaDita(double velocita) {
    final apertura = widget.apertura;
    if (apertura == null) return;
    final t = apertura.value;
    final apri = velocita > 0.4 || (velocita > -0.4 && t > 0.35);
    _verso(apri ? 1 : 0, velocita);
  }

  /// Si apre da sé: con VoiceOver, o da un pulsante.
  void apri() => _verso(1, 0);

  /// Si richiude sul globo piccolo, anche da vicino: la distanza torna alla
  /// Terra intera mentre il globo scende al suo posto.
  void chiudi() => _verso(0, 0);

  void _raggioDalleDita(double raggio) {
    final (da, apertura) = (widget.da, widget.apertura);
    if (da == null || apertura == null) return;
    final pieno = _raggioPieno;
    if (raggio >= pieno) {
      apertura.value = 1;
      _scala = (raggio / pieno).clamp(1.0, _vicinissimo);
    } else {
      _scala = 1;
      // Sotto il globo piccolo cede appena, come un elastico.
      final t = (raggio - da.raggio) / max(pieno - da.raggio, 1);
      apertura.value = t < 0 ? t / (1 - t * 3) : t;
    }
  }

  void _verso(double fine, double velocitaDita) {
    final (da, apertura) = (widget.da, widget.apertura);
    if (apertura == null) return;
    _giro.stop();
    _lancio.stop();
    _scalaChiudendo = fine == 0 && _scala > 1 ? _scala : null;
    void fatto() {
      if (fine == 0) widget.onChiuso?.call();
    }

    if (movimentoRidotto(context)) {
      apertura.value = fine;
      if (fine == 0) _scala = 1;
      fatto();
      return;
    }
    // La velocità delle dita, da scala al secondo ad apertura al secondo.
    final quanto = da == null
        ? 1.0
        : da.raggio / max(_raggioPieno - da.raggio, 1);
    apertura
        .animateWith(
          SpringSimulation(
            _mollaApertura,
            apertura.value,
            fine,
            velocitaDita * quanto,
          ),
        )
        .then((_) => fatto());
  }

  /// Mentre si chiude da vicino, la distanza scende insieme all'apertura.
  void _seguiApertura() {
    final s = _scalaChiudendo;
    if (s != null && mounted) {
      final t = widget.apertura!.value.clamp(0.0, 1.0);
      setState(() => _scala = 1 + (s - 1) * t);
    }
  }

  // --- I gesti ---

  bool get _sulPaese =>
      _patina != null && !_finito && !_giro.isAnimating && _celle.isNotEmpty;

  void _appoggia(Offset dove) {
    if (!_sulPaese) return;
    _luce.stop();
    setState(() => _tratti.add([dove]));
    _gratta(dove, dove);
  }

  /// Il raggio della Terra quando le dita si sono appoggiate, e dove il
  /// doppio tocco.
  double _raggioPrima = 1;
  Offset? _doppioTocco;

  /// Il punto della Terra sotto un punto del globo.
  Coordinate? _sotto(Offset p) {
    final r = _r * _scala;
    final c = _c;
    return Ortografica(_centro).inverso((p.dx - c.dx) / r, -(p.dy - c.dy) / r);
  }

  /// Il paese sotto un punto del globo; `null` sul mare.
  String? _paeseSotto(Offset p) {
    final confini = _confini;
    final dove = _sotto(p);
    return confini == null || dove == null
        ? null
        : confini.paeseIn(dove.lat, dove.lon);
  }

  void _tocca(TapUpDetails d) =>
      widget.onTocca?.call(_paeseSotto(d.localPosition));

  void _tieniPremuto(LongPressStartDetails d) =>
      widget.onTieniPremuto?.call(_paeseSotto(d.localPosition));

  /// Doppio tocco: più vicino, verso il punto toccato; al massimo, di nuovo
  /// lontano.
  void _avvicinaDove() {
    if (_scala >= _vicinissimo * 0.95) {
      _vai(_centro, 1);
      return;
    }
    final dove = _doppioTocco == null ? null : _sotto(_doppioTocco!);
    _vai(dove ?? _centro, min(_scala * 2.5, _vicinissimo));
  }

  void _gratta(Offset da, Offset a) {
    final raggio = _dito / 2 + _passo * 0.3;
    var nuove = 0;
    for (var i = 0; i < _celle.length; i++) {
      if (!_scoperte.contains(i) && _dalTratto(_celle[i], da, a) <= raggio) {
        _scoperte.add(i);
        nuove++;
      }
    }
    if (nuove > 0) {
      _staccaPezzi(a, min(2 + nuove, 6));
      _vibraGrattando();
    }
    if (_scoperte.length >= _celle.length * _basta) _finisci();
  }

  /// Più si scopre, più il telefono vibra fitto: da una volta ogni 110
  /// millesimi a una ogni 40.
  void _vibraGrattando() {
    final scoperto = _scoperte.length / max(_celle.length * _basta, 1);
    final ogni = Duration(
      milliseconds: (110 - 70 * scoperto.clamp(0, 1)).round(),
    );
    final adesso = DateTime.now();
    if (adesso.difference(_vibrato) < ogni) return;
    _vibrato = adesso;
    HapticFeedback.selectionClick();
  }

  /// [quanti] pezzi d'argento che si staccano da [dove] e cadono.
  void _staccaPezzi(Offset dove, int quanti, {double forza = 1}) {
    if (movimentoRidotto(context)) return;
    const colori = [
      Colori.argento,
      Colori.foschia,
      Colori.cenere,
      Colori.bianco,
    ];
    for (var i = 0; i < quanti; i++) {
      final angolo = -pi / 2 + (_caso.nextDouble() - 0.5) * pi * 1.4;
      final v = (60 + _caso.nextDouble() * 140) * forza;
      _briciole.add(
        _Briciola(
          dove +
              Offset(_caso.nextDouble() * 10 - 5, _caso.nextDouble() * 10 - 5),
          Offset(cos(angolo) * v, sin(angolo) * v),
          _caso.nextDouble() * pi,
          colori[_caso.nextInt(colori.length)],
          3 + _caso.nextDouble() * 4,
        ),
      );
    }
    if (!_caduta.isActive) {
      _ultimoPasso = Duration.zero;
      _caduta.start();
    }
  }

  void _cadono(Duration trascorso) {
    final dt = (trascorso - _ultimoPasso).inMicroseconds / 1e6;
    _ultimoPasso = trascorso;
    if (dt <= 0) return;
    setState(() {
      for (final b in _briciole) {
        b
          ..velocita += Offset(0, 900 * dt)
          ..dove += b.velocita * dt
          ..giro += 8 * dt
          ..vita -= dt / 0.8;
      }
      _briciole.removeWhere((b) => b.vita <= 0);
    });
    if (_briciole.isEmpty) _caduta.stop();
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
    _luce.stop();
    // Il colpo pieno, e un tocco leggero subito dopo: fatto.
    HapticFeedback.heavyImpact();
    Future<void>.delayed(
      const Duration(milliseconds: 140),
      HapticFeedback.lightImpact,
    );
    if (movimentoRidotto(context)) {
      _scopri.value = 1;
      widget.onScoperto?.call(paese);
    } else {
      // La patina salta via a pezzi, da tutto il paese.
      for (final i in [
        for (var i = 0; i < _celle.length; i++) i,
      ]..shuffle(_caso)) {
        if (_scoperte.contains(i)) continue;
        _staccaPezzi(_celle[i], 1, forza: 1.6);
        if (_briciole.length > 60) break;
      }
      _festa.forward(from: 0);
      _scopri.forward().then((_) => widget.onScoperto?.call(paese));
    }
  }

  void _rallenta() {
    final passo = _lancio.value - _lanciato;
    _lanciato = _lancio.value;
    setState(() => _centro = _sposta(_centro, _direzione * passo));
  }

  /// A riposo il globo gira piano verso est. Si ferma sotto il dito, in volo,
  /// mentre si gratta o si guarda un paese, e riparte piano, senza scatti.
  void _giraPiano(Duration trascorso) {
    final dt = (trascorso - _ultimoLento).inMicroseconds / 1e6;
    _ultimoLento = trascorso;
    if (dt <= 0 || dt > 0.1) return;
    // La bandiera sventola sempre, anche sotto il dito.
    setState(() => _tempo = (_tempo ?? 0) + dt);
    final fermo =
        _dita > 0 ||
        _giro.isAnimating ||
        _lancio.isAnimating ||
        _patina != null ||
        widget.scelto != null ||
        (widget.apertura?.isAnimating ?? false);
    if (fermo) {
      _velocitaLenta = 0;
      return;
    }
    final bersaglio = _gradiAlSecondo / _scala;
    _velocitaLenta += (bersaglio - _velocitaLenta) * min(dt * 0.9, 1);
    setState(
      () => _centro = (
        lat: _centro.lat,
        lon: _normale(_centro.lon + _velocitaLenta * dt),
      ),
    );
  }

  /// I colori delle bandiere sui puntini dei paesi accesi: si chiedono le
  /// bandiere che mancano, e si ricalcolano quando cambia qualcosa.
  void _aggiornaTinte() {
    final confini = _confini;
    if (confini == null) return;
    final accesi = {...widget.grattati, ?widget.daGrattare}..remove('--');
    for (final codice in accesi) {
      if (!_chieste.add(codice)) continue;
      Bandiera.di(codice).then((bandiera) {
        if (mounted) setState(() => _bandiere[codice] = bandiera);
      });
    }
    final firma = [...(accesi.toList()..sort()), _bandiere.length].join(',');
    if (firma == _firmaTinte) return;
    _firmaTinte = firma;
    final paesi = <String, ({_Riquadro riquadro, Bandiera? bandiera})>{};
    for (final codice in accesi) {
      final riquadro = _riquadri.putIfAbsent(codice, () {
        final contorni = confini.contorni(codice);
        if (contorni.isEmpty) return null;
        return _Riquadro(
          contorni.reduce((a, b) => a.length >= b.length ? a : b),
        );
      });
      if (riquadro != null) {
        paesi[codice] = (riquadro: riquadro, bandiera: _bandiere[codice]);
      }
    }
    _tinte = _Tinte.di(confini.puntini, paesi);
  }

  /// Il centro spostato dal dito: da vicino, lo stesso dito gira di meno.
  Coordinate _sposta(Coordinate c, Offset delta) => (
    lat: (c.lat + delta.dy / (_r * _scala) * 180 / pi).clamp(-80, 80),
    lon: _normale(c.lon - delta.dx / (_r * _scala) * 180 / pi),
  );

  static double _normale(double lon) => (lon + 540) % 360 - 180;

  void _inizia(ScaleStartDetails d) {
    if (_patina == null) {
      _giro.stop();
      _lancio.stop();
    }
    _raggioPrima = _r * _scala;
    final apertura = widget.apertura;
    if (apertura != null && apertura.isAnimating) apertura.stop();
    _scalaChiudendo = null;
    _appoggia(d.localFocalPoint);
  }

  void _trascina(ScaleUpdateDetails d) {
    if (_sulPaese) {
      final tratto = _tratti.isEmpty ? null : _tratti.last;
      final prima = tratto == null || tratto.isEmpty
          ? d.localFocalPoint
          : tratto.last;
      setState(
        () => (tratto ?? (_tratti..add([])).last).add(d.localFocalPoint),
      );
      _gratta(prima, d.localFocalPoint);
      return;
    }
    if (_patina != null) return;
    // Allargando il globo piccolo, le dita passano a quello grande, che
    // cresce da qui (tela, 149).
    if (!widget.avvicinabile &&
        widget.onAllarga != null &&
        d.pointerCount > 1 &&
        (_apre || d.scale > 1.03)) {
      _apre = true;
      widget.onAllarga!(d.scale, d.focalPointDelta);
      return;
    }
    setState(() {
      if (widget.avvicinabile && d.pointerCount > 1) {
        final raggio = _raggioPrima * d.scale;
        if (widget.apertura != null && widget.da != null) {
          // Stringendo oltre la Terra intera il globo torna verso il suo
          // posto, seguendo le dita.
          _raggioDalleDita(raggio);
        } else {
          _scala = (raggio / _r).clamp(1.0, _vicinissimo);
        }
      }
      _centro = _sposta(_centro, d.focalPointDelta);
    });
  }

  void _lascia(ScaleEndDetails d) {
    if (_apre) {
      _apre = false;
      widget.onAllargaFine?.call(d.scaleVelocity);
      return;
    }
    // Stretto a metà: si chiude o si riapre, secondo dove e come va.
    final apertura = widget.apertura;
    if (apertura != null && apertura.value < 1 && !apertura.isAnimating) {
      final chiudi =
          d.scaleVelocity < -0.4 ||
          (d.scaleVelocity < 0.4 && apertura.value < 0.75);
      _verso(chiudi ? 0 : 1, d.scaleVelocity);
      return;
    }
    final v = d.velocity.pixelsPerSecond;
    if (_patina != null ||
        movimentoRidotto(context) ||
        v.distance < 50 ||
        d.pointerCount > 0) {
      return;
    }
    _direzione = v / v.distance;
    _lanciato = 0;
    _lancio.animateWith(FrictionSimulation(0.05, 0, v.distance));
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, vincoli) {
      _aggiornaTinte();
      _lato = [
        vincoli.maxWidth,
        vincoli.maxHeight,
        widget.latoMassimo,
      ].reduce(min);
      _spazio = widget.pienoSchermo
          ? Size(vincoli.maxWidth, vincoli.maxHeight)
          : Size.square(_lato);
      return Semantics(
        // Un nodo a sé: con le sue azioni non deve tirarsi dietro le
        // etichette della schermata.
        container: true,
        image: true,
        label: widget.etichetta,
        // Con VoiceOver si avvicina scorrendo su e giù (tela, 146), e il
        // globo piccolo si apre fra le azioni.
        onIncrease: widget.avvicinabile ? avvicina : null,
        onDecrease: widget.avvicinabile ? allontana : null,
        customSemanticsActions: widget.onApri == null
            ? null
            : {
                const CustomSemanticsAction(label: 'Apri a tutto schermo'):
                    widget.onApri!,
              },
        child: Listener(
          onPointerDown: (_) => _dita++,
          onPointerUp: (_) => _dita = max(_dita - 1, 0),
          onPointerCancel: (_) => _dita = max(_dita - 1, 0),
          child: GestureDetector(
            onTapUp: widget.onTocca == null || _patina != null ? null : _tocca,
            onLongPressStart: widget.onTieniPremuto == null || _patina != null
                ? null
                : _tieniPremuto,
            onDoubleTapDown: widget.avvicinabile && _patina == null
                ? (d) => _doppioTocco = d.localPosition
                : null,
            onDoubleTap: widget.avvicinabile && _patina == null
                ? _avvicinaDove
                : null,
            onScaleStart: _inizia,
            onScaleUpdate: _trascina,
            onScaleEnd: _lascia,
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _comparso,
                _scopri,
                _luce,
                _festa,
                _accendi,
                ?widget.apertura,
              ]),
              builder: (context, _) => CustomPaint(
                size: _spazio,
                painter: _Globo(
                  confini: _confini,
                  grattati: widget.grattati,
                  punti: widget.punti,
                  centro: _centro,
                  centroDisco: _c,
                  raggioDisco: _r,
                  scala: _scala,
                  comparso: _comparso.value,
                  patina: _patina,
                  tratti: _tratti,
                  scoperto: _scopri.value,
                  luce: _luce.isAnimating ? _luce.value : null,
                  festa: _festa.value,
                  briciole: _briciole,
                  scelto: widget.scelto,
                  acceso: _accendi.value,
                  sfera: _sfera,
                  sole: _sole,
                  pienoSchermo: widget.pienoSchermo,
                  tinte: _tinte,
                  bandiere: _bandiere,
                  tempo: _tempo,
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Il puntino bianco, liscio, da tingere: quello dei paesi accesi, che si
/// gonfiano uno per uno.
final ui.Image _tondo = () {
  final registro = ui.PictureRecorder();
  Canvas(registro).drawCircle(
    const Offset(32, 32),
    31,
    Paint()
      ..color = Colori.bianco
      ..isAntiAlias = true,
  );
  return registro.endRecording().toImageSync(64, 64);
}();

/// La luce attorno a un puntino acceso: un tondo che sfuma verso il bordo.
final ui.Image _bagliore = () {
  final registro = ui.PictureRecorder();
  Canvas(registro).drawCircle(
    const Offset(32, 32),
    32,
    Paint()
      ..shader = RadialGradient(
        colors: [Colori.bianco, Colori.bianco.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: const Offset(32, 32), radius: 32)),
  );
  return registro.endRecording().toImageSync(64, 64);
}();

class _Globo extends CustomPainter {
  _Globo({
    required this.confini,
    required this.grattati,
    required this.punti,
    required this.centro,
    required this.centroDisco,
    required this.raggioDisco,
    required this.scala,
    required this.comparso,
    required this.patina,
    required this.tratti,
    required this.scoperto,
    this.luce,
    this.festa = 0,
    this.briciole = const [],
    this.scelto,
    this.acceso = 1,
    this.sfera,
    this.sole = (lat: 0, lon: 0),
    this.pienoSchermo = false,
    this.tinte,
    this.bandiere = const {},
    this.tempo,
  });

  final Confini? confini;
  final Set<String> grattati;
  final Map<String, Coordinate> punti;
  final Coordinate centro;

  /// Dove sta la Terra intera: il centro del disco e il suo raggio.
  final Offset centroDisco;
  final double raggioDisco;

  /// Quanto è avvicinato: 1 è la Terra intera.
  final double scala;

  /// Quanto sono già comparse le bandiere, da 0 a 1.
  final double comparso;

  final _Patina? patina;
  final List<List<Offset>> tratti;

  /// Quanto se n'è andata la patina, da 0 a 1.
  final double scoperto;

  /// Dove sta la luce che passa sulla patina, da 0 a 1; `null` se non passa.
  final double? luce;

  /// Il paese scoperto che si gonfia e l'anello che si allarga, da 0 a 1.
  final double festa;
  final List<_Briciola> briciole;

  /// Il paese tenuto premuto: i suoi puntini si accendono.
  final String? scelto;

  /// Quanto si è acceso il paese tenuto premuto, da 0 a 1.
  final double acceso;

  /// La sfera col giorno e la notte; senza, un fondo sfumato.
  final SferaDisegnata? sfera;

  /// Dove il sole è a picco: lì è mezzogiorno.
  final Coordinate sole;

  /// La Terra si ritaglia sulla sfera, che da vicino esce dallo schermo.
  final bool pienoSchermo;

  /// I colori delle bandiere, puntino per puntino.
  final _Tinte? tinte;

  /// Le bandiere, per i paesi troppo piccoli per avere puntini.
  final Map<String, Bandiera?> bandiere;

  /// I secondi che passano, per la bandiera che sventola; `null` se è ferma.
  final double? tempo;

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
    final r = raggioDisco;
    final grande = r * scala;
    final c = centroDisco;
    final o = Ortografica(centro);
    // Il disco della Terra: a tutto schermo la sfera intera, che da vicino
    // riempie lo schermo; altrimenti un cerchio fisso, e dentro ci si avvicina.
    final rd = pienoSchermo ? grande : r;
    final disco = Rect.fromCircle(center: c, radius: rd);
    canvas
      ..drawCircle(
        c,
        rd + _aria,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colori.cobalto.withValues(alpha: 0.45),
              Colori.cobalto.withValues(alpha: 0),
            ],
            stops: [rd / (rd + _aria) - 0.02, 1],
          ).createShader(Rect.fromCircle(center: c, radius: rd + _aria)),
      )
      ..drawCircle(
        c,
        rd,
        Paint()
          ..shader =
              sfera?.fondo(o, c, grande, sole) ??
              const RadialGradient(
                center: Alignment(-0.28, -0.4),
                radius: 0.8,
                colors: [Colori.notteChiara, Colori.notte, Colori.notteBuia],
                stops: [0, 0.6, 1],
              ).createShader(disco),
      )
      ..save()
      ..clipPath(Path()..addOval(disco));
    final confini = this.confini;
    if (confini != null) {
      final daGrattare = patina?.paese;
      final visti = {
        for (final codice in grattati)
          if (codice != daGrattare) codice,
      };
      final percorsi = <String, Path>{
        for (final codice in visti)
          codice: ?_percorso(confini.contorni(codice), o, c, grande),
      };
      // Una luce morbida sotto i paesi visti, che si spegne avvicinandosi.
      final alone = Paint()
        ..color = Colori.alone.withValues(
          alpha: 0.5 * comparso / max(1, scala / 1.4),
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 + 3 * (r / 130));
      for (final p in percorsi.values) {
        canvas.drawPath(p, alone);
      }
      // Sempre gli stessi puntini: avvicinandosi crescono con la Terra, come
      // un mosaico visto da vicino.
      _disegnaPuntini(
        canvas,
        confini.puntini,
        tinte,
        o,
        c,
        grande,
        rd,
        r / 130 * scala,
      );
      // Il paese tenuto premuto: un anello bianco si allarga una volta.
      final scelto = this.scelto;
      if (scelto != null && acceso > 0 && acceso < 1) {
        if (_percorso(confini.contorni(scelto), o, c, grande) case final p?) {
          _anello(canvas, p.getBounds(), acceso, 0.6);
        }
      }
      // I paesi visti troppo piccoli per avere puntini: un puntino solo, coi
      // colori della bandiera.
      for (final codice in visti) {
        final punto = punti[codice];
        final p = percorsi[codice];
        if (punto == null || (p != null && p.getBounds().longestSide >= 6)) {
          continue;
        }
        final (x, y, z) = o.coordinata(punto);
        if (z < 0) continue;
        final dove = Offset(c.dx + x * grande, c.dy - y * grande);
        final colore = bandiere[codice]?.colore(0.5, 0.5) ?? Colori.bianco;
        canvas.drawCircle(
          dove,
          3.5 * r / 130 * min(scala, 2.5),
          Paint()..color = Color.lerp(Colori.puntino, colore, comparso)!,
        );
      }
      final p = patina;
      final forma = p == null ? null : formaPatina(confini, p, o, c, grande);
      if (p != null && forma != null) {
        if (p.gettone) {
          // Sotto il gettone, la bandiera in un puntino grande.
          final b = forma.getBounds();
          canvas.drawCircle(
            b.center,
            b.width / 4,
            Paint()
              ..color = bandiere[p.paese]?.colore(0.5, 0.5) ?? Colori.bianco,
          );
        }
        if (festa > 0 && festa < 1) {
          _anello(canvas, forma.getBounds(), festa, 0.7);
        }
        if (scoperto < 1) {
          _disegnaPatina(canvas, forma);
          canvas.drawPath(
            forma,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeJoin = StrokeJoin.round
              ..strokeWidth = p.gettone ? 3 : 1.5
              ..color = Colori.bianco.withValues(alpha: 1 - scoperto),
          );
        }
      }
    }
    canvas
      ..restore()
      ..drawCircle(
        c,
        rd - 0.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colori.bianco.withValues(alpha: 0.1),
      );
    // I pezzi cadono anche fuori dal globo.
    for (final b in briciole) {
      canvas
        ..save()
        ..translate(b.dove.dx, b.dove.dy)
        ..rotate(b.giro)
        ..drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: b.lato,
              height: b.lato * 0.6,
            ),
            const Radius.circular(1),
          ),
          Paint()..color = b.colore.withValues(alpha: b.vita.clamp(0.0, 1.0)),
        )
        ..restore();
    }
  }

  /// Un anello bianco attorno a [b] che si allarga e sfuma, a [t] da 0 a 1:
  /// per il paese scelto e per quello appena scoperto.
  void _anello(Canvas canvas, Rect b, double t, double forza) {
    final e = Curves.easeOut.transform(t);
    canvas.drawCircle(
      b.center,
      b.longestSide / 2 * (0.9 + 0.8 * e),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5 * (1 - e)
        ..color = Colori.bianco.withValues(alpha: forza * (1 - e)),
    );
  }

  /// La patina d'argento a righe sopra il paese, tolta dove è passato il
  /// dito; quando il paese è scoperto, sfuma.
  void _disegnaPatina(Canvas canvas, Path forma) {
    final b = forma.getBounds();
    canvas
      ..saveLayer(
        b.inflate(StatoMappamondo._dito),
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
    // La luce che passa di sbieco, finché non la si tocca.
    final l = luce;
    if (l != null) {
      final x = b.left - b.width * 0.6 + l * b.width * 2.2;
      final fascia = Rect.fromLTWH(x, b.top, b.width * 0.5, b.height);
      canvas.drawRect(
        b,
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colori.bianco.withValues(alpha: 0),
              Colori.bianco.withValues(alpha: 0.75),
              Colori.bianco.withValues(alpha: 0),
            ],
            transform: const GradientRotation(-0.4),
          ).createShader(fascia),
      );
    }
    final via = Paint()
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.stroke
      ..strokeWidth = StatoMappamondo._dito
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final tratto in tratti) {
      if (tratto.length == 1) {
        canvas.drawCircle(
          tratto.single,
          StatoMappamondo._dito / 2,
          Paint()..blendMode = BlendMode.clear,
        );
      } else {
        canvas.drawPath(Path()..addPolygon(tratto, false), via);
      }
    }
    canvas.restore();
  }

  /// La terra a puntini (tela, 151), da lontano e da vicino, sempre gli
  /// stessi: più chiari
  /// verso il centro della sfera e dove è giorno, spenti dove è notte, con il
  /// crepuscolo in mezzo. Quelli dei paesi visti hanno i colori della loro
  /// bandiera, e la bandiera sventola: un'onda lenta la attraversa da
  /// sinistra a destra, e dove passa i puntini si gonfiano, si schiariscono
  /// e si alzano appena; sotto, tutto il paese respira. Il paese tenuto
  /// premuto si accende; quello da grattare ha i suoi puntini sotto la
  /// patina, e scoperto si gonfia.
  void _disegnaPuntini(
    Canvas canvas,
    Puntini puntini,
    _Tinte? tinte,
    Ortografica o,
    Offset c,
    double grande,
    double r,
    double k,
  ) {
    // Tre fasce di profondità per tre di luce: nove disegni per tutti i
    // puntini spenti, invece di un cerchio per puntino.
    const fasce = 3;
    const luci = 3;
    final spenti = List.generate(fasce * luci, (_) => <double>[]);
    final dove = <double>[];
    final aloni = <double>[];
    final ritagli = <double>[];
    final colori = <int>[];
    final dentro = r * r;
    final (fs, ls) = (sole.lat * pi / 180, sole.lon * pi / 180);
    final (sx, sy, sz) = (cos(fs) * cos(ls), cos(fs) * sin(ls), sin(fs));
    final p = puntini.punti;
    final daGrattare = patina?.paese;
    final t = tempo;
    final respiro = t == null ? 1.0 : 1 + 0.05 * sin(2 * pi * t / 3.4);
    final gonfio = 1 + 0.6 * sin(pi * festa.clamp(0.0, 1.0));
    final lato = 3.9 * k;
    for (var i = 0; i < puntini.length; i++) {
      final (x, y, z) = o.punto(p, i);
      if (z < 0.02) continue;
      final (px, py) = (c.dx + x * grande, c.dy - y * grande);
      final (dx, dy) = (px - c.dx, py - c.dy);
      if (dx * dx + dy * dy > dentro) continue;
      final sulSole = p[i * 3] * sx + p[i * 3 + 1] * sy + p[i * 3 + 2] * sz;
      final paese = puntini.paese(i);
      final tinta = tinte?.colore[i] ?? 0;
      final ilScelto = paese == scelto;
      if (tinta == 0 && !ilScelto) {
        final luce = sulSole < -0.1 ? 0 : (sulSole < 0.12 ? 1 : 2);
        final fascia = min((z * fasce).floor(), fasce - 1);
        spenti[fascia * luci + luce].addAll([px, py]);
        continue;
      }
      // Un puntino acceso: la bandiera, o il bianco del paese scelto. Si
      // vede anche di notte, appena più tenue.
      final giorno = ((sulSole + 0.1) / 0.22).clamp(0.0, 1.0);
      var chiaro = (0.8 + 0.2 * giorno) * (0.85 + 0.15 * z);
      var misura = lato * respiro;
      var su = 0.0;
      if (t != null) {
        final onda = 2 * pi * (1.4 * (tinte?.u[i] ?? 0.5) - t / 2.6);
        misura *= 1 + 0.16 * sin(onda);
        chiaro *= 0.88 + 0.14 * sin(onda + 0.9);
        su = lato * 0.3 * sin(onda);
      }
      final Color base;
      if (tinta == 0) {
        base = Colori.bianco.withValues(alpha: acceso);
        misura *= 0.85;
      } else {
        // Un poco schiariti, perché i blu scuri non spariscano nella notte.
        final bandiera = Color.lerp(Color(tinta), Colori.bianco, 0.14)!;
        base = Color.lerp(Colori.puntino, bandiera, comparso)!;
        if (ilScelto) {
          misura *= 1 + 0.25 * acceso;
          chiaro *= 1 + 0.2 * acceso;
        }
        if (paese == daGrattare) misura *= gonfio;
      }
      final a = base.a.clamp(0.0, 1.0);
      colori.add(
        Color.from(
          alpha: a,
          red: (base.r * chiaro).clamp(0.0, 1.0),
          green: (base.g * chiaro).clamp(0.0, 1.0),
          blue: (base.b * chiaro).clamp(0.0, 1.0),
        ).toARGB32(),
      );
      final s = misura / 64;
      dove.addAll([s, 0, px - 32 * s, py - su - 32 * s]);
      ritagli.addAll([0, 0, 64, 64]);
      // L'alone, più largo, pulsa con il suo puntino.
      final sa = s * 2.6;
      aloni.addAll([sa, 0, px - 32 * sa, py - su - 32 * sa]);
    }
    for (var f = 0; f < fasce; f++) {
      final z = (f + 0.5) / fasce;
      for (var l = 0; l < luci; l++) {
        // Di notte poca luce, al crepuscolo metà, di giorno tutta.
        const luceDi = [0.15, 0.55, 1.0];
        final lista = spenti[f * luci + l];
        if (lista.isEmpty) continue;
        canvas.drawRawPoints(
          PointMode.points,
          Float32List.fromList(lista),
          Paint()
            ..color = Colori.puntino.withValues(
              alpha: 0.05 + 0.08 * z + (0.14 + 0.42 * z) * luceDi[l],
            )
            ..strokeWidth = 2.9 * k
            ..strokeCap = StrokeCap.round,
        );
      }
    }
    if (colori.isEmpty) return;
    final tinteAtlante = Int32List.fromList(colori);
    final tutti = Float32List.fromList(ritagli);
    // Prima la luce attorno, a un terzo; poi i puntini.
    canvas
      ..drawRawAtlas(
        _bagliore,
        Float32List.fromList(aloni),
        tutti,
        Int32List.fromList([
          for (final c in colori)
            (c & 0x00FFFFFF) | (((c >>> 24) * 0.32).round() << 24),
        ]),
        BlendMode.modulate,
        null,
        Paint()..filterQuality = FilterQuality.medium,
      )
      ..drawRawAtlas(
        _tondo,
        Float32List.fromList(dove),
        tutti,
        tinteAtlante,
        BlendMode.modulate,
        null,
        Paint()..filterQuality = FilterQuality.medium,
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

  // Si ridisegna a ogni cambio: il dito, il giro, l'onda, la patina.
  @override
  bool shouldRepaint(_Globo vecchio) => true;
}
