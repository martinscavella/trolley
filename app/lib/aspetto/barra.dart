/// La barra principale che galleggia in basso, come nella tela: una pillola
/// d'inchiostro, la voce attiva bianca con il suo nome, le altre solo icona,
/// e in mezzo il "+" giallo, perché da lì nasce un'idea.
///
/// È una sola per tutte le sezioni (ADR-013): quando la voce attiva cambia,
/// la pillola bianca scivola dalla voce di prima alla nuova e si allunga sul
/// suo nome, mentre quella di prima torna icona (tela, 126). I suoi due bordi
/// hanno ciascuno la sua molla, e quello davanti è più svelto: la pillola si
/// stira nella corsa e torna tonda all'arrivo, senza scatti (tela, 143).
///
/// Come la barra di iOS, la pillola si trascina (tela, 137 e 143): col dito
/// sulla barra diventa una lente, un poco più grande, che insegue il dito.
/// Sotto il dito la barra sta ferma — i nomi non si aprono né si chiudono —
/// e dove passa la lente icone e nomi si scuriscono; un tocco leggero del
/// telefono a ogni voce. Lasciando, la lente si posa sulla voce più vicina
/// portandosi la velocità del dito, e solo allora il nome si apre e la
/// sezione cambia; il «+» si attraversa ma non si sceglie così.
library;

import 'dart:math';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'movimento.dart';
import 'tavolozza.dart';
import 'testi.dart';

/// Una voce della barra in basso.
class VoceBarra {
  const VoceBarra({
    this.icona,
    this.simbolo,
    required this.etichetta,
    required this.onTap,
    this.attiva = false,
  }) : assert(icona != null || simbolo != null);

  final IconData? icona;

  /// Un simbolo disegnato dall'app, del colore che riceve, quando nessuna
  /// icona di sistema va bene: il passaporto.
  final Widget Function(Color colore)? simbolo;

  final String etichetta;
  final VoidCallback onTap;
  final bool attiva;
}

class BarraPrincipale extends StatefulWidget {
  const BarraPrincipale({
    super.key,
    required this.prima,
    required this.dopo,
    required this.onAggiungi,
    required this.etichettaAggiungi,
  });

  final List<VoceBarra> prima;
  final List<VoceBarra> dopo;
  final VoidCallback onAggiungi;
  final String etichettaAggiungi;

  /// Quanto spazio lasciare in fondo ai contenuti perché la barra non li copra.
  static const ingombro = 112.0;

  @override
  State<BarraPrincipale> createState() => _BarraPrincipaleState();
}

/// Un tasto della barra: le voci spente, il «+».
const _lato = 48.0;

/// Il margine della pillola bianca attorno all'icona e al nome.
const _margine = 16.0;
const _icona = 22.0;
const _fraIconaENome = 8.0;

/// Il minimo fra un tasto e l'altro, anche con un nome lungo.
const _fraTasti = 4.0;

/// I nomi che si aprono e si chiudono: senza rimbalzo, in un terzo di
/// secondo, e solo quando il dito ha lasciato (tela, 143).
const _mollaNomi = SpringDescription(mass: 1, stiffness: 300, damping: 34.6);

/// Le molle dei due bordi della pillola: quello davanti, nel verso della
/// corsa, più svelto di quello dietro, così la pillola si stira e torna tonda
/// all'arrivo. Col dito sono più rigide, perché la lente gli stia vicina.
const _davanti = 500.0;
const _dietro = 190.0;
const _davantiColDito = 1500.0;
const _dietroColDito = 900.0;

class _BarraPrincipaleState extends State<BarraPrincipale>
    with TickerProviderStateMixin {
  /// I nomi, da com'erano a come vanno: da 0 a 1.
  late final _corsa = AnimationController.unbounded(vsync: this, value: 1);

  /// La lente: quanto è cresciuta la pillola sotto il dito.
  late final _lente = AnimationController(vsync: this, duration: Ritmo.breve);

  /// I due bordi della pillola, ciascuno con la sua molla. `null` prima del
  /// primo disegno.
  Inseguitore? _sinistra;
  Inseguitore? _destra;

  /// Dove devono andare i bordi, all'ultimo disegno.
  Rect? _bersaglio;

  /// Il passo delle molle.
  late final Ticker _molle = createTicker(_avanza);
  Duration _ultimo = Duration.zero;

  /// Dove sta il dito, in punti dalla sinistra della barra; `null` se non
  /// si trascina.
  double? _dito;

  /// Com'era la barra quando il dito si è appoggiato: sotto il dito non si
  /// ridisegna, si muove solo la lente.
  List<double>? _ferme;

  /// La voce più vicina al dito, per il tocco del telefono quando cambia.
  int? _vicina;

  /// Il centro e la larghezza di ogni posto all'ultimo disegno.
  List<double> _centri = const [];
  List<double> _larghezze = const [];

  /// La voce dove va la pillola.
  late String? _arrivo = _attiva(widget);

  /// Quanto era aperta ogni voce quando i nomi sono partiti: una corsa
  /// interrotta riparte da lì, senza salti.
  Map<String, double> _apertePrima = const {};

  /// Com'era all'ultimo disegno.
  Map<String, double> _aperte = const {};

  static String? _attiva(BarraPrincipale b) =>
      [...b.prima, ...b.dopo].where((v) => v.attiva).firstOrNull?.etichetta;

  @override
  void didUpdateWidget(BarraPrincipale vecchia) {
    super.didUpdateWidget(vecchia);
    final nuova = _attiva(widget);
    if (nuova == _arrivo) return;
    _parti(nuova);
  }

  /// I nomi partono verso [arrivo], e la pillola ci va.
  void _parti(String? arrivo) {
    _apertePrima = _aperte;
    _arrivo = arrivo;
    if (movimentoRidotto(context) || _sinistra == null) {
      _corsa.value = 1;
    } else {
      _corsa.animateWith(SpringSimulation(_mollaNomi, 0, 1, 0));
      _sveglia();
    }
  }

  void _sveglia() {
    if (_molle.isActive) return;
    _ultimo = Duration.zero;
    _molle.start();
  }

  /// Un passo delle molle: i bordi inseguono il bersaglio dell'ultimo
  /// disegno, e il disegno dopo dice il bersaglio nuovo.
  void _avanza(Duration trascorso) {
    final dt = (trascorso - _ultimo).inMicroseconds / 1e6;
    _ultimo = trascorso;
    final (s, d, b) = (_sinistra, _destra, _bersaglio);
    if (s == null || d == null || b == null) return;
    final colDito = _dito != null;
    // Il bordo davanti è quello verso cui va il centro.
    final versoDestra = b.center.dx > (s.posizione + d.posizione) / 2;
    final svelto = colDito ? _davantiColDito : _davanti;
    final lento = colDito ? _dietroColDito : _dietro;
    s.avanza(
      b.left,
      dt,
      rigidita: versoDestra ? lento : svelto,
      smorzamento: 0.9,
    );
    d.avanza(
      b.right,
      dt,
      rigidita: versoDestra ? svelto : lento,
      smorzamento: 0.9,
    );
    if (!colDito &&
        !_corsa.isAnimating &&
        s.fermoSu(b.left) &&
        d.fermoSu(b.right)) {
      s.salta(b.left);
      d.salta(b.right);
      _molle.stop();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _molle.dispose();
    _corsa.dispose();
    _lente.dispose();
    super.dispose();
  }

  List<VoceBarra?> get _voci => [...widget.prima, null, ...widget.dopo];

  /// Il posto più vicino al punto [x] della barra: il «+» non si sceglie.
  int _voceVicina(double x) {
    final voci = _voci;
    var migliore = 0;
    var distanza = double.infinity;
    for (final (i, v) in voci.indexed) {
      if (v == null || i >= _centri.length) continue;
      final d = (_centri[i] - x).abs();
      if (d < distanza) (migliore, distanza) = (i, d);
    }
    return migliore;
  }

  void _appoggia(DragStartDetails d) {
    _corsa.stop();
    final x = d.localPosition.dx;
    setState(() {
      _ferme = [
        for (final v in _voci) v == null ? 0.0 : _aperte[v.etichetta] ?? 0,
      ];
      _dito = x;
      _vicina = _voceVicina(x);
    });
    if (!movimentoRidotto(context)) {
      _lente.forward();
      _sveglia();
    }
    HapticFeedback.selectionClick();
  }

  void _scorri(DragUpdateDetails d) {
    if (_dito == null) return;
    final x = d.localPosition.dx;
    final vicina = _voceVicina(x);
    if (vicina != _vicina) HapticFeedback.selectionClick();
    setState(() {
      _dito = x;
      _vicina = vicina;
    });
  }

  void _lascia([DragEndDetails? fine]) {
    final dito = _dito;
    if (dito == null) return;
    final voce = _voci[_voceVicina(dito)]!;
    // La lente si posa portandosi la velocità del dito.
    final v = fine?.velocity.pixelsPerSecond.dx ?? 0;
    _sinistra?.velocita += v * 0.6;
    _destra?.velocita += v * 0.6;
    setState(() {
      _dito = null;
      _ferme = null;
    });
    _lente.reverse();
    _parti(voce.etichetta);
    if (!voce.attiva) {
      HapticFeedback.lightImpact();
      voce.onTap();
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    height: 64,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colori.inchiostro,
      borderRadius: BorderRadius.circular(32),
      boxShadow: [
        BoxShadow(
          color: Colori.inchiostro.withValues(alpha: 0.3),
          blurRadius: 30,
          offset: const Offset(0, 12),
        ),
      ],
    ),
    child: LayoutBuilder(
      builder: (context, vincoli) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: _appoggia,
        onHorizontalDragUpdate: _scorri,
        onHorizontalDragEnd: _lascia,
        onHorizontalDragCancel: _lascia,
        child: AnimatedBuilder(
          animation: Listenable.merge([_corsa, _lente]),
          builder: (context, _) => _tasti(context, vincoli.maxWidth),
        ),
      ),
    ),
  );

  Widget _tasti(BuildContext context, double larghezza) {
    final t = _corsa.value;
    final voci = _voci;
    final ferme = _ferme;
    final scala = MediaQuery.textScalerOf(context);
    final ridotto = movimentoRidotto(context);

    // Quanto cresce ogni voce quando è aperta: il nome e il margine. La voce
    // attiva prende lo spazio che resta: con cinque voci, su un telefono
    // stretto, il suo nome si accorcia invece di uscire.
    final massimo =
        larghezza - voci.length * _lato - _fraTasti * (voci.length - 1);
    double crescita(VoceBarra v) {
      final nome = TextPainter(
        text: TextSpan(text: v.etichetta, style: Testi.voceBarra),
        textDirection: TextDirection.ltr,
        textScaler: scala,
        maxLines: 1,
      )..layout();
      final piena = 2 * _margine + _icona + _fraIconaENome + nome.width - _lato;
      nome.dispose();
      return piena.clamp(0, massimo < 0 ? 0 : massimo);
    }

    // Col dito la barra resta com'era; altrimenti i nomi vanno da com'erano
    // a dove arrivano.
    double aperta(int i, VoceBarra v) =>
        ferme?[i] ??
        lerpDouble(
          _apertePrima[v.etichetta] ?? 0,
          v.etichetta == _arrivo ? 1 : 0,
          t,
        )!.clamp(0.0, 1.0);

    final crescite = [for (final v in voci) v == null ? 0.0 : crescita(v)];
    final aperture = [
      for (final (i, v) in voci.indexed) v == null ? 0.0 : aperta(i, v),
    ];
    // Dove sta ogni posto con quelle aperture: lo spazio che resta si divide
    // fra un posto e l'altro.
    (List<double>, List<double>) disponi(List<double> aperture) {
      final larghezze = [
        for (final (i, _) in voci.indexed) _lato + crescite[i] * aperture[i],
      ];
      final spazio =
          (larghezza - larghezze.fold(0.0, (a, b) => a + b)) /
          (voci.length - 1);
      final sinistre = <double>[];
      var x = 0.0;
      for (final l in larghezze) {
        sinistre.add(x);
        x += l + spazio;
      }
      return (sinistre, larghezze);
    }

    final (sinistre, larghezze) = disponi(aperture);
    _centri = [for (final (j, l) in larghezze.indexed) sinistre[j] + l / 2];
    _larghezze = larghezze;
    // Dove deve andare la pillola: col dito, una lente larga quanto il posto
    // che ha sotto, centrata sul dito e dentro la barra; altrimenti il posto
    // della voce dove arriva, com'è a nomi già aperti: la pillola va dritta
    // lì, e la barra le si sistema sotto.
    final dito = _dito;
    final Rect? bersaglio;
    if (dito != null) {
      final larga = _larghezze[_voceVicina(dito)];
      final sinistra = (dito - larga / 2).clamp(0.0, larghezza - larga);
      bersaglio = Rect.fromLTWH(sinistra, 0, larga, _lato);
    } else {
      final i = voci.indexWhere((v) => v?.etichetta == _arrivo);
      if (i < 0) {
        bersaglio = null;
      } else {
        final (s, l) = disponi([
          for (final (j, v) in voci.indexed) v != null && j == i ? 1.0 : 0.0,
        ]);
        bersaglio = Rect.fromLTWH(s[i], 0, l[i], _lato);
      }
    }
    _bersaglio = bersaglio;
    _aperte = {
      for (final (j, v) in voci.indexed)
        if (v != null) v.etichetta: aperture[j],
    };

    // La prima volta, e con «Riduci movimento», la pillola è già dove va.
    if (bersaglio != null && (_sinistra == null || ridotto)) {
      (_sinistra ??= Inseguitore(bersaglio.left)).salta(bersaglio.left);
      (_destra ??= Inseguitore(bersaglio.right)).salta(bersaglio.right);
    } else if (bersaglio != null && !_molle.isActive) {
      final (s, d) = (_sinistra!, _destra!);
      if (!s.fermoSu(bersaglio.left) || !d.fermoSu(bersaglio.right)) {
        // Il bersaglio si è spostato senza che nessuno lo dicesse: un
        // telefono girato, il testo più grande.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _sveglia();
        });
      }
    }
    final (s, d) = (_sinistra, _destra);
    final pillola = bersaglio == null || s == null || d == null
        ? null
        : Rect.fromLTRB(
            s.posizione,
            0,
            max(d.posizione, s.posizione + _lato * 0.6),
            _lato,
          );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (pillola != null)
          Positioned.fromRect(
            // La lente: un poco più grande, sollevata sulla barra.
            rect: pillola.inflate(4 * _lente.value),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colori.bianco,
                borderRadius: BorderRadius.circular(
                  _lato / 2 + 4 * _lente.value,
                ),
                boxShadow: _lente.value == 0
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: 0.35 * _lente.value,
                          ),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        ),
                      ],
              ),
            ),
          ),
        for (final (j, v) in voci.indexed)
          Positioned(
            left: sinistre[j],
            top: 0,
            width: larghezze[j],
            height: _lato,
            child: v == null
                ? _aggiungi()
                : _voce(
                    v,
                    aperta: aperture[j],
                    crescita: crescite[j],
                    // La pillola vista da questo posto: lì icona e nome sono
                    // d'inchiostro, fuori bianchi.
                    sotto: pillola
                        ?.inflate(4 * _lente.value)
                        .shift(Offset(-sinistre[j], 0)),
                  ),
          ),
      ],
    );
  }

  Widget _voce(
    VoceBarra v, {
    required double aperta,
    required double crescita,
    required Rect? sotto,
  }) {
    final nome = crescita - (2 * _margine + _icona + _fraIconaENome - _lato);
    Widget contenuto(Color colore) => Stack(
      children: [
        Positioned(
          left: lerpDouble((_lato - _icona) / 2, _margine, aperta),
          top: (_lato - _icona) / 2,
          child:
              v.simbolo?.call(colore) ??
              Icon(v.icona, size: _icona, color: colore),
        ),
        if (aperta > 0.01 && nome > 0)
          Positioned(
            left: _margine + _icona + _fraIconaENome,
            top: 0,
            bottom: 0,
            width: nome,
            child: Opacity(
              opacity: aperta * aperta,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  v.etichetta,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: Testi.voceBarra.copyWith(color: colore),
                ),
              ),
            ),
          ),
      ],
    );
    return Semantics(
      selected: v.attiva,
      child: Premibile(
        onTap: v.onTap,
        scala: 0.94,
        etichetta: v.etichetta,
        child: ExcludeSemantics(
          child: ClipRect(
            child: sotto == null
                ? contenuto(_spenta)
                : ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (riquadro) =>
                        _sottoLaPillola(riquadro, sotto),
                    child: contenuto(Colori.bianco),
                  ),
          ),
        ),
      ),
    );
  }

  /// Le voci spente, fuori dalla pillola.
  static final _spenta = Colori.bianco.withValues(alpha: 0.75);

  /// Il colore di un posto della barra: d'inchiostro dove c'è la pillola,
  /// bianco fuori. Il taglio è dritto: icone e nomi stanno a metà altezza,
  /// dove la pillola è piena.
  static Shader _sottoLaPillola(Rect riquadro, Rect pillola) {
    final w = riquadro.width;
    final a = w == 0 ? 0.0 : (pillola.left / w).clamp(0.0, 1.0);
    final b = w == 0 ? 0.0 : (pillola.right / w).clamp(a, 1.0);
    return LinearGradient(
      colors: [
        _spenta,
        _spenta,
        Colori.inchiostro,
        Colori.inchiostro,
        _spenta,
        _spenta,
      ],
      stops: [0, a, a, b, b, 1],
    ).createShader(riquadro);
  }

  Widget _aggiungi() => Premibile(
    onTap: widget.onAggiungi,
    scala: 0.9,
    etichetta: widget.etichettaAggiungi,
    child: Container(
      width: _lato,
      height: _lato,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colori.sole,
      ),
      child: const Icon(Icons.add_rounded, size: 28, color: Colori.inchiostro),
    ),
  );
}

/// Il passaporto della barra: un libretto con il mondo in copertina (tela,
/// 122). Come un'icona, del colore che riceve.
class SimboloPassaporto extends StatelessWidget {
  const SimboloPassaporto({
    super.key,
    required this.colore,
    this.dimensione = _icona,
  });

  final Color colore;
  final double dimensione;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(dimensione), painter: _Passaporto(colore));
}

class _Passaporto extends CustomPainter {
  const _Passaporto(this.colore);

  final Color colore;

  @override
  void paint(Canvas canvas, Size size) {
    // Disegnato su 24 punti, come le icone.
    final s = size.width / 24;
    final tratto = Paint()
      ..color = colore
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas
      ..drawRRect(
        RRect.fromLTRBR(5 * s, 3 * s, 19 * s, 21 * s, Radius.circular(2.5 * s)),
        tratto,
      )
      ..drawCircle(Offset(12 * s, 10.5 * s), 3.5 * s, tratto)
      ..drawLine(Offset(8.5 * s, 10.5 * s), Offset(15.5 * s, 10.5 * s), tratto)
      ..drawLine(Offset(9 * s, 17 * s), Offset(15 * s, 17 * s), tratto);
  }

  @override
  bool shouldRepaint(_Passaporto vecchio) => vecchio.colore != colore;
}
