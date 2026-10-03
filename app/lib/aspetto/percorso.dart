/// La giornata come un percorso, come nella tela: punti numerati collegati
/// nell'ordine della giornata, a zig-zag su una scheda con le curve di
/// livello di una carta. Il tratto già fatto è pieno e verde, quello da fare
/// è a puntini. È uno schema dell'ordine, non una mappa: la mappa vera arriva
/// con la fase 3.2, e gli stessi punti ci andranno sopra.
library;

import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import 'movimento.dart';
import 'tavolozza.dart';
import 'testi.dart';

/// Come appare un punto.
enum AspettoPunto { daFare, prossima, completata, saltata }

/// Una tappa sul percorso.
class PuntoPercorso {
  const PuntoPercorso({
    required this.titolo,
    required this.dettaglio,
    required this.aspetto,
    required this.etichetta,
    required this.onApri,
    this.capsula,
    this.dettaglioInRosso = false,
    this.inCoda = false,
    this.onTocca,
    this.suggerimentoTocca,
    this.onTieni,
    this.suggerimentoTieni,
  });

  final String titolo;

  /// La riga sotto il titolo: «Visita · 1 h · alle 10:00».
  final String dettaglio;
  final AspettoPunto aspetto;

  /// Cosa legge VoiceOver sul punto: «1, Livraria Lello, fatta».
  final String etichetta;

  /// Toccare il titolo: si apre la tappa per cambiarla.
  final VoidCallback onApri;

  /// Sopra il titolo: «Prossima · 13:00».
  final String? capsula;
  final bool dettaglioInRosso;

  /// Ha qualcosa che aspetta la rete: si vede un segno sul punto.
  final bool inCoda;

  /// Toccare il punto: lo segna, quando si può.
  final VoidCallback? onTocca;
  final String? suggerimentoTocca;

  /// Tenerlo premuto: lo salta.
  final VoidCallback? onTieni;
  final String? suggerimentoTieni;
}

class PercorsoTappe extends StatelessWidget {
  const PercorsoTappe({super.key, required this.punti});

  final List<PuntoPercorso> punti;

  static const _passo = 84.0;
  static const _bordo = 46.0;
  static const _primo = 46.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, vincoli) {
      final largo = vincoli.maxWidth;
      final centri = [
        for (var i = 0; i < punti.length; i++)
          Offset(i.isEven ? _bordo : largo - _bordo, _primo + i * _passo),
      ];
      final alto = _primo * 2 + (punti.length - 1) * _passo;
      return Container(
        height: alto,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colori.bianco,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ExcludeSemantics(
                child: CustomPaint(
                  painter: _Carta(centri, [for (final p in punti) p.aspetto]),
                ),
              ),
            ),
            for (final (i, p) in punti.indexed) ...[
              Positioned(
                left: i.isEven ? _bordo + 32 : 16,
                right: i.isEven ? 16 : _bordo + 32,
                top: centri[i].dy - 38,
                height: 76,
                child: _Etichetta(punto: p, aDestra: i.isOdd),
              ),
              Positioned(
                left: centri[i].dx - 24,
                top: centri[i].dy - 24,
                child: _Punto(numero: i + 1, punto: p),
              ),
            ],
          ],
        ),
      );
    },
  );
}

/// Il titolo e la sua riga, dalla parte opposta al punto.
class _Etichetta extends StatelessWidget {
  const _Etichetta({required this.punto, required this.aDestra});

  final PuntoPercorso punto;

  /// Il punto sta a destra: il testo si allinea a lui.
  final bool aDestra;

  @override
  Widget build(BuildContext context) {
    final allineamento = aDestra
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final testo = aDestra ? TextAlign.right : TextAlign.left;
    final capsula = punto.capsula;
    return Premibile(
      onTap: punto.onApri,
      scala: 0.98,
      etichetta: 'Apri ${punto.titolo}',
      child: ExcludeSemantics(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: allineamento,
          children: [
            if (capsula != null) ...[
              Container(
                height: 22,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colori.cobaltoChiaro,
                  borderRadius: BorderRadius.circular(11),
                ),
                // Stretta sul testo, non larga quanto la riga.
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    capsula,
                    style: Testi.pillola.copyWith(
                      color: Colori.cobaltoScuro,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 3),
            ],
            Text(
              punto.titolo,
              maxLines: capsula == null ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              textAlign: testo,
              style: Testi.evidenza.copyWith(
                color: Colori.inchiostro,
                fontSize: 15,
                height: 1.25,
                // L'alone bianco delle scritte di una carta: il percorso
                // passa sotto, non attraverso.
                backgroundColor: Colori.bianco,
              ),
            ),
            Text(
              punto.dettaglio,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: testo,
              style: Testi.didascalia.copyWith(
                color: punto.dettaglioInRosso
                    ? Colori.pericolo
                    : Colori.grafite,
                fontWeight: punto.dettaglioInRosso ? FontWeight.w600 : null,
                backgroundColor: Colori.bianco,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Punto extends StatelessWidget {
  const _Punto({required this.numero, required this.punto});

  final int numero;
  final PuntoPercorso punto;

  @override
  Widget build(BuildContext context) {
    final p = punto;
    final ridotto = movimentoRidotto(context);
    return Semantics(
      button: true,
      label: p.etichetta,
      onTapHint: p.suggerimentoTocca,
      onLongPressHint: p.suggerimentoTieni,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: p.onTocca ?? p.onApri,
        onLongPress: p.onTieni,
        child: SizedBox.square(
          dimension: 48,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Segnarla la fa sbocciare: il gesto da cui dipende la verifica
              // si sente fatto.
              AnimatedSwitcher(
                duration: ridotto ? Duration.zero : Ritmo.medio,
                switchInCurve: Ritmo.molla,
                transitionBuilder: (figlio, animazione) =>
                    ScaleTransition(scale: animazione, child: figlio),
                child: _Cerchio(
                  key: ValueKey(p.aspetto),
                  numero: numero,
                  aspetto: p.aspetto,
                  tratteggiato: p.inCoda && p.aspetto == AspettoPunto.daFare,
                ),
              ),
              if (p.inCoda)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colori.bianco,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colori.cenere, width: 2),
                    ),
                    child: const Icon(
                      Icons.cloud_off_rounded,
                      size: 12,
                      color: Colori.grafite,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cerchio extends StatelessWidget {
  const _Cerchio({
    super.key,
    required this.numero,
    required this.aspetto,
    required this.tratteggiato,
  });

  final int numero;
  final AspettoPunto aspetto;
  final bool tratteggiato;

  @override
  Widget build(BuildContext context) {
    final numeroScritto = Text(
      '$numero',
      style:
          Testi.titoli(
            aspetto == AspettoPunto.prossima ? 16 : 15,
            spaziatura: 0,
            altezza: 1,
            peso: 600,
          ).copyWith(
            color: aspetto == AspettoPunto.prossima
                ? Colori.bianco
                : Colori.inchiostro,
          ),
    );
    return switch (aspetto) {
      AspettoPunto.completata => _pieno(
        Colori.verde,
        const Icon(Icons.check_rounded, size: 22, color: Colori.bianco),
      ),
      AspettoPunto.saltata => _pieno(
        Colori.piombo,
        const Icon(Icons.redo_rounded, size: 20, color: Colori.bianco),
      ),
      AspettoPunto.prossima => Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colori.cobalto,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colori.cobalto.withValues(alpha: 0.16),
              spreadRadius: 7,
            ),
          ],
        ),
        child: numeroScritto,
      ),
      AspettoPunto.daFare when tratteggiato => CerchioTratteggiato(
        dimensione: 40,
        child: numeroScritto,
      ),
      AspettoPunto.daFare => Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colori.bianco,
          shape: BoxShape.circle,
          border: Border.all(color: Colori.inchiostro, width: 2.5),
        ),
        child: numeroScritto,
      ),
    };
  }

  static Widget _pieno(Color colore, Widget dentro) => Container(
    width: 40,
    height: 40,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: colore, shape: BoxShape.circle),
    child: dentro,
  );
}

/// Un cerchio dal bordo tratteggiato: un posto vuoto, che aspetta un segno o
/// la rete.
class CerchioTratteggiato extends StatelessWidget {
  const CerchioTratteggiato({
    super.key,
    this.dimensione = 44,
    this.colore = Colori.grafite,
    this.child,
  });

  final double dimensione;
  final Color colore;
  final Widget? child;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: dimensione,
    child: CustomPaint(
      painter: _Tratteggiato(colore),
      child: child == null ? null : Center(child: child),
    ),
  );
}

class _Tratteggiato extends CustomPainter {
  const _Tratteggiato(this.colore);

  final Color colore;

  @override
  void paint(Canvas canvas, Size size) {
    final centro = size.center(Offset.zero);
    canvas.drawCircle(centro, size.width / 2, Paint()..color = Colori.bianco);
    final cerchio = Path()
      ..addOval(Rect.fromCircle(center: centro, radius: size.width / 2 - 1.25));
    _aPuntini(
      canvas,
      cerchio,
      Paint()
        ..color = colore
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
      pieno: 5,
      vuoto: 4,
    );
  }

  @override
  bool shouldRepaint(_Tratteggiato vecchio) => vecchio.colore != colore;
}

/// Le curve di livello della carta e il percorso fra i punti.
class _Carta extends CustomPainter {
  const _Carta(this.centri, this.aspetti);

  final List<Offset> centri;
  final List<AspettoPunto> aspetti;

  @override
  void paint(Canvas canvas, Size size) {
    final livello = Paint()
      ..color = const Color(0xFFEEF0F5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (var y = 74.0; y < size.height + 40; y += 80) {
      final onda = (y ~/ 80).isEven ? 30.0 : -30.0;
      canvas.drawPath(
        Path()
          ..moveTo(-20, y)
          ..cubicTo(
            size.width * 0.25,
            y - onda,
            size.width * 0.45,
            y + onda,
            size.width * 0.6,
            y,
          )
          ..cubicTo(
            size.width * 0.8,
            y - onda,
            size.width * 0.9,
            y - onda / 2,
            size.width + 20,
            y,
          ),
        livello,
      );
    }

    final fatto = Paint()
      ..color = Colori.verde
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final daFare = Paint()
      ..color = Colori.piombo
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (var i = 0; i + 1 < centri.length; i++) {
      final (a, b) = (centri[i], centri[i + 1]);
      final mezzo = (b.dy - a.dy) / 2;
      final tratto = Path()
        ..moveTo(a.dx, a.dy)
        ..cubicTo(a.dx, a.dy + mezzo, b.dx, b.dy - mezzo, b.dx, b.dy);
      final percorso =
          aspetti[i] == AspettoPunto.completata ||
          aspetti[i] == AspettoPunto.saltata;
      if (percorso) {
        canvas.drawPath(tratto, fatto);
      } else {
        _aPuntini(canvas, tratto, daFare, pieno: 0.1, vuoto: 9);
      }
    }
  }

  @override
  bool shouldRepaint(_Carta vecchio) =>
      vecchio.centri.length != centri.length ||
      !_uguali(vecchio.centri, centri) ||
      !_uguali(vecchio.aspetti, aspetti);

  static bool _uguali<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Disegna [percorso] a tratti di [pieno] separati da [vuoto]. Con un tratto
/// cortissimo e la punta tonda vengono puntini.
void _aPuntini(
  Canvas canvas,
  Path percorso,
  Paint pennello, {
  required double pieno,
  required double vuoto,
}) {
  for (final PathMetric metrica in percorso.computeMetrics()) {
    for (var d = 0.0; d < metrica.length; d += pieno + vuoto) {
      canvas.drawPath(metrica.extractPath(d, d + pieno), pennello);
    }
  }
}
