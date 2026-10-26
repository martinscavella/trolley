/// La barra principale che galleggia in basso, come nella tela: una pillola
/// d'inchiostro, la voce attiva bianca con il suo nome, le altre solo icona,
/// e in mezzo il "+" giallo, perché da lì nasce un'idea.
///
/// È una sola per tutte le sezioni (ADR-013): quando la voce attiva cambia,
/// la pillola bianca scivola dalla voce di prima alla nuova e si allunga sul
/// suo nome, mentre quella di prima torna icona (tela, 126). Ci arriva con
/// una molla, con un piccolo rimbalzo.
///
/// Come la barra di iOS, la pillola si trascina (tela, 137): col dito sulla
/// barra cresce un poco, come una lente, lo segue senza scatti e si allunga
/// sul nome della voce che ha sotto, con un tocco leggero del telefono a ogni
/// voce. Lasciando, va sulla voce più vicina e la sezione cambia; il «+» si
/// attraversa ma non si sceglie così.
library;

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
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

/// La molla della pillola: arriva in un terzo di secondo, con un rimbalzo
/// appena.
const _molla = SpringDescription(mass: 1, stiffness: 520, damping: 33);

class _BarraPrincipaleState extends State<BarraPrincipale>
    with TickerProviderStateMixin {
  /// La corsa della pillola, da dov'era a dove va: da 0 a 1, con la molla
  /// che passa un poco oltre e torna.
  late final _corsa = AnimationController.unbounded(vsync: this, value: 1);

  /// La lente: quanto è cresciuta la pillola sotto il dito.
  late final _lente = AnimationController(vsync: this, duration: Ritmo.breve);

  /// Dove sta il dito, come posto fra le voci (il «+» compreso): 1,5 è a
  /// metà fra la seconda e la terza. `null` se non si trascina.
  double? _dito;

  /// La voce più vicina al dito, per il tocco del telefono quando cambia.
  int? _vicina;

  /// Il centro di ogni posto all'ultimo disegno: dal punto del dito al posto.
  List<double> _centri = const [];

  /// La voce dove va la pillola.
  late String? _arrivo = _attiva(widget);

  /// Quanto era aperta ogni voce, e dov'era la pillola, quando è partita:
  /// una corsa interrotta riparte da lì, senza salti.
  Map<String, double> _apertePrima = const {};
  Rect? _pillolaPrima;

  /// Com'era all'ultimo disegno.
  Map<String, double> _aperte = const {};
  Rect? _pillola;

  static String? _attiva(BarraPrincipale b) =>
      [...b.prima, ...b.dopo].where((v) => v.attiva).firstOrNull?.etichetta;

  @override
  void didUpdateWidget(BarraPrincipale vecchia) {
    super.didUpdateWidget(vecchia);
    final nuova = _attiva(widget);
    if (nuova == _arrivo) return;
    _parti(nuova);
  }

  /// La pillola parte da dov'è verso [arrivo].
  void _parti(String? arrivo) {
    _apertePrima = _aperte;
    _pillolaPrima = _pillola;
    _arrivo = arrivo;
    if (movimentoRidotto(context) || _pillolaPrima == null) {
      _corsa.value = 1;
    } else {
      _corsa.animateWith(SpringSimulation(_molla, 0, 1, 0));
    }
  }

  @override
  void dispose() {
    _corsa.dispose();
    _lente.dispose();
    super.dispose();
  }

  List<VoceBarra?> get _voci => [...widget.prima, null, ...widget.dopo];

  /// Il posto sotto il punto [x] della barra, fra i centri dei posti.
  double _posto(double x) {
    final c = _centri;
    if (c.isEmpty) return 0;
    if (x <= c.first) return 0;
    for (var i = 0; i < c.length - 1; i++) {
      if (x <= c[i + 1]) return i + (x - c[i]) / (c[i + 1] - c[i]);
    }
    return c.length - 1.0;
  }

  /// La voce più vicina a un posto: il «+» non si sceglie.
  int _voceVicina(double posto) {
    final voci = _voci;
    var migliore = 0;
    var distanza = double.infinity;
    for (final (i, v) in voci.indexed) {
      if (v == null) continue;
      final d = (i - posto).abs();
      if (d < distanza) (migliore, distanza) = (i, d);
    }
    return migliore;
  }

  void _appoggia(DragStartDetails d) {
    _corsa.stop();
    final posto = _posto(d.localPosition.dx);
    setState(() {
      _dito = posto;
      _vicina = _voceVicina(posto);
    });
    if (!movimentoRidotto(context)) _lente.forward();
    HapticFeedback.selectionClick();
  }

  void _scorri(DragUpdateDetails d) {
    if (_dito == null) return;
    final posto = _posto(d.localPosition.dx);
    final vicina = _voceVicina(posto);
    if (vicina != _vicina) HapticFeedback.selectionClick();
    setState(() {
      _dito = posto;
      _vicina = vicina;
    });
  }

  void _lascia() {
    final dito = _dito;
    if (dito == null) return;
    final voce = _voci[_voceVicina(dito)]!;
    setState(() => _dito = null);
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
        onHorizontalDragEnd: (_) => _lascia(),
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
    final dito = _dito;
    final scala = MediaQuery.textScalerOf(context);

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

    // Col dito, è aperta la voce che ha sotto, e a metà strada mezza l'una e
    // mezza l'altra; altrimenti si va da com'era a dove arriva.
    double aperta(int i, VoceBarra v) => dito != null
        ? (1 - (i - dito).abs()).clamp(0.0, 1.0)
        : lerpDouble(
            _apertePrima[v.etichetta] ?? 0,
            v.etichetta == _arrivo ? 1 : 0,
            t,
          )!.clamp(0.0, 1.0);

    final crescite = [for (final v in voci) v == null ? 0.0 : crescita(v)];
    final aperture = [
      for (final (i, v) in voci.indexed) v == null ? 0.0 : aperta(i, v),
    ];
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

    _centri = [
      for (final (j, l) in larghezze.indexed) sinistre[j] + l / 2,
    ];
    Rect posto(int j) => Rect.fromLTWH(sinistre[j], 0, larghezze[j], _lato);

    final Rect? pillola;
    if (dito != null) {
      // Sotto il dito, fra un posto e l'altro.
      final da = dito.floor().clamp(0, voci.length - 1);
      final a = dito.ceil().clamp(0, voci.length - 1);
      pillola = Rect.lerp(posto(da), posto(a), dito - da);
    } else {
      final i = voci.indexWhere((v) => v?.etichetta == _arrivo);
      final dove = i < 0 ? null : posto(i);
      pillola = dove == null
          ? null
          : _pillolaPrima == null
          ? dove
          : Rect.lerp(_pillolaPrima, dove, t);
    }
    _aperte = {
      for (final (j, v) in voci.indexed)
        if (v != null) v.etichetta: aperture[j],
    };
    _pillola = pillola;

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
                : _voce(v, aperta: aperture[j], crescita: crescite[j]),
          ),
      ],
    );
  }

  Widget _voce(
    VoceBarra v, {
    required double aperta,
    required double crescita,
  }) {
    final colore = Color.lerp(
      Colori.bianco.withValues(alpha: 0.75),
      Colori.inchiostro,
      aperta,
    )!;
    final nome = crescita - (2 * _margine + _icona + _fraIconaENome - _lato);
    return Semantics(
      selected: v.attiva,
      child: Premibile(
        onTap: v.onTap,
        scala: 0.94,
        etichetta: v.etichetta,
        child: ExcludeSemantics(
          child: ClipRect(
            child: Stack(
              children: [
                Positioned(
                  left: lerpDouble((_lato - _icona) / 2, _margine, aperta),
                  top: (_lato - _icona) / 2,
                  child:
                      v.simbolo?.call(colore) ??
                      Icon(v.icona, size: _icona, color: colore),
                ),
                if (aperta > 0 && nome > 0)
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
                          style: Testi.voceBarra.copyWith(
                            color: Colori.inchiostro,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
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
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(dimensione),
    painter: _Passaporto(colore),
  );
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
