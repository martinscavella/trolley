/// La barra principale che galleggia in basso, come nella tela: una pillola
/// d'inchiostro, la voce attiva bianca con il suo nome, le altre solo icona,
/// e in mezzo il "+" giallo, perché da lì nasce un'idea.
///
/// È una sola per tutte le sezioni (ADR-013): quando la voce attiva cambia,
/// la pillola bianca scivola dalla voce di prima alla nuova e si allunga sul
/// suo nome, mentre quella di prima torna icona (tela, 126).
library;

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

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

class _BarraPrincipaleState extends State<BarraPrincipale>
    with SingleTickerProviderStateMixin {
  /// La corsa della pillola, da dov'era a dove va.
  late final _corsa = AnimationController(
    vsync: this,
    duration: Ritmo.medio,
    value: 1,
  );

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
    _apertePrima = _aperte;
    _pillolaPrima = _pillola;
    _arrivo = nuova;
    if (movimentoRidotto(context) || _pillolaPrima == null) {
      _corsa.value = 1;
    } else {
      _corsa.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _corsa.dispose();
    super.dispose();
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
      builder: (context, vincoli) => AnimatedBuilder(
        animation: _corsa,
        builder: (context, _) => _tasti(context, vincoli.maxWidth),
      ),
    ),
  );

  Widget _tasti(BuildContext context, double larghezza) {
    final t = Ritmo.curva.transform(_corsa.value);
    final voci = [...widget.prima, null, ...widget.dopo];
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

    double aperta(VoceBarra v) => lerpDouble(
      _apertePrima[v.etichetta] ?? 0,
      v.etichetta == _arrivo ? 1 : 0,
      t,
    )!;

    final crescite = [for (final v in voci) v == null ? 0.0 : crescita(v)];
    final aperture = [for (final v in voci) v == null ? 0.0 : aperta(v)];
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

    final i = voci.indexWhere((v) => v?.etichetta == _arrivo);
    final dove = i < 0
        ? null
        : Rect.fromLTWH(sinistre[i], 0, larghezze[i], _lato);
    final pillola = dove == null
        ? null
        : _pillolaPrima == null
        ? dove
        : Rect.lerp(_pillolaPrima, dove, t);
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
            rect: pillola,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: Colori.bianco,
                borderRadius: BorderRadius.all(Radius.circular(_lato / 2)),
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
