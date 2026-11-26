/// I segni sopra la mappa, come nella tela (50–54): le tappe come punti
/// numerati — verdi quelle fatte, cobalto la prossima con il suo alone,
/// d'inchiostro le altre —, il puntino della persona, e sulla mappa del
/// viaggio un colore per giorno.
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../dominio/mappa.dart';
import 'movimento.dart';
import 'tavolozza.dart';
import 'testi.dart';

/// Quanto spazio occupa un segno: abbastanza per il dito (44 punti).
const latoSegno = 48.0;

/// Il quadrato dell'immagine di un segno per la mappa di Google: più grande
/// del segno, perché l'alone del segno scelto, ingrandito, ci stia intero.
/// Il segno sta al centro, e la mappa lo appoggia dal centro.
const latoImmagineSegno = 72.0;

/// Una tappa sulla mappa.
class SegnoSullaMappa extends StatelessWidget {
  const SegnoSullaMappa({
    super.key,
    required this.numero,
    required this.segno,
    required this.etichetta,
    required this.onTap,
    this.colore,
    this.scelto = false,
  });

  final int numero;
  final SegnoTappa segno;

  /// Cosa legge VoiceOver: «2, Livraria Lello, la prossima».
  final String etichetta;
  final VoidCallback onTap;

  /// Sulla mappa del viaggio: il colore del giorno al posto dei segni.
  final Color? colore;

  /// Toccato: la sua scheda è aperta.
  final bool scelto;

  @override
  Widget build(BuildContext context) {
    final ridotto = movimentoRidotto(context);
    final prossima = segno == SegnoTappa.prossima && colore == null;
    final raggio = colore != null ? 12.0 : (prossima ? 17.0 : 14.0);
    final fondo =
        colore ??
        switch (segno) {
          SegnoTappa.fatta => Colori.verde,
          SegnoTappa.saltata => Colori.piombo,
          SegnoTappa.prossima => Colori.cobalto,
          SegnoTappa.daFare => Colori.inchiostro,
        };
    final dentro = colore == null && segno == SegnoTappa.fatta
        ? const Icon(Icons.check_rounded, size: 18, color: Colori.bianco)
        : colore == null && segno == SegnoTappa.saltata
        ? const Icon(Icons.redo_rounded, size: 16, color: Colori.bianco)
        : Text(
            '$numero',
            style: Testi.titoli(
              colore != null ? 11 : (prossima ? 14 : 13),
              spaziatura: 0,
              altezza: 1,
            ).copyWith(color: Colori.bianco),
          );
    return Semantics(
      button: true,
      selected: scelto,
      label: etichetta,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: latoSegno,
          child: Center(
            child: AnimatedScale(
              scale: scelto ? 1.25 : 1,
              duration: ridotto ? Duration.zero : Ritmo.medio,
              curve: Ritmo.molla,
              child: AnimatedSwitcher(
                duration: ridotto ? Duration.zero : Ritmo.medio,
                switchInCurve: Ritmo.molla,
                transitionBuilder: (figlio, animazione) =>
                    ScaleTransition(scale: animazione, child: figlio),
                child: Container(
                  key: ValueKey((segno, colore)),
                  width: raggio * 2 + 6,
                  height: raggio * 2 + 6,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: fondo,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colori.bianco, width: 3),
                    boxShadow: [
                      if (prossima)
                        BoxShadow(
                          color: Colori.cobalto.withValues(alpha: 0.18),
                          spreadRadius: 6,
                        )
                      else
                        BoxShadow(
                          color: Colori.inchiostro.withValues(alpha: 0.18),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  child: dentro,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dove si trova la persona: un puntino cobalto con il suo alone.
class PuntinoPosizione extends StatelessWidget {
  const PuntinoPosizione({super.key, this.conVerso = false});

  static const lato = 32.0;

  /// Con il cono: il quadrato è più grande, perché il cono ci stia.
  static const latoConVerso = 88.0;

  /// Con il cono chiaro verso l'alto: dove punta il telefono, nella guida
  /// (tela, 163). Lo gira la mappa.
  final bool conVerso;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Sei qui',
    child: SizedBox.square(
      dimension: conVerso ? latoConVerso : lato,
      child: CustomPaint(
        painter: conVerso ? const _Cono() : null,
        child: Center(child: _puntino()),
      ),
    ),
  );

  Widget _puntino() => Container(
    width: 20,
    height: 20,
    decoration: BoxDecoration(
      color: Colori.cobalto,
      shape: BoxShape.circle,
      border: Border.all(color: Colori.bianco, width: 3),
      boxShadow: [
        BoxShadow(
          color: Colori.cobalto.withValues(alpha: 0.15),
          spreadRadius: 6,
        ),
      ],
    ),
  );
}

/// Il cono della direzione: dal centro verso l'alto, che sfuma.
class _Cono extends CustomPainter {
  const _Cono();

  @override
  void paint(Canvas canvas, Size size) {
    final centro = size.center(Offset.zero);
    final raggio = size.width / 2;
    const apertura = 0.5;
    final cono = Path()
      ..moveTo(centro.dx, centro.dy)
      ..arcTo(
        Rect.fromCircle(center: centro, radius: raggio),
        -pi / 2 - apertura,
        2 * apertura,
        false,
      )
      ..close();
    canvas.drawPath(
      cono,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colori.cobalto.withValues(alpha: 0.35),
            Colori.cobalto.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: centro, radius: raggio)),
    );
  }

  @override
  bool shouldRepaint(_Cono vecchio) => false;
}

/// Il numero di una tappa in una riga o in una scheda: il cerchio della
/// tela, cobalto per la prossima, d'inchiostro per le altre.
class NumeroTappa extends StatelessWidget {
  const NumeroTappa({
    super.key,
    required this.numero,
    required this.segno,
    this.lato = 36,
  });

  final int numero;
  final SegnoTappa segno;
  final double lato;

  @override
  Widget build(BuildContext context) => Container(
    width: lato,
    height: lato,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: switch (segno) {
        SegnoTappa.prossima => Colori.cobalto,
        SegnoTappa.fatta => Colori.verde,
        SegnoTappa.saltata => Colori.piombo,
        SegnoTappa.daFare => Colori.inchiostro,
      },
    ),
    child: switch (segno) {
      SegnoTappa.fatta => Icon(
        Icons.check_rounded,
        size: lato * 0.55,
        color: Colori.bianco,
      ),
      _ => Text(
        '$numero',
        style: Testi.titoli(
          lato * 0.39,
          spaziatura: 0,
          altezza: 1,
        ).copyWith(color: Colori.bianco),
      ),
    },
  );
}

/// Il logo di Google, in basso al centro su ogni mappa a tutto schermo
/// (scelta dell'utente, 27 novembre 2026). La mappa lo mette nell'angolo in
/// basso della zona che le si lascia: la zona è una striscia larga quanto
/// il logo (circa 101 punti, a 7 dal bordo), in mezzo. Su iPhone, sotto, la
/// mappa aggiunge da sola la zona sicura e un bordo: il logo sta circa
/// [sopraLaZonaSicura] punti sopra la zona sicura, più quello che si lascia.
double latoPerIlLogo(double larghezza) =>
    max(0, (larghezza - 2 * (101 / 2 + 7)) / 2);

/// Quanto sta il fondo del logo sopra la zona sicura, con niente sotto.
const sopraLaZonaSicura = 9.0;

/// Quanto è alto il logo.
const altezzaDelLogo = 18.0;

/// Dice quanto è alto quello che contiene, ogni volta che cambia: le
/// schede sopra la mappa di Google, perché la mappa lasci libero quello
/// spazio (e ci tenga sopra il marchio di Google).
class MisuraAltezza extends SingleChildRenderObjectWidget {
  const MisuraAltezza({
    super.key,
    required this.onAltezza,
    required super.child,
  });

  final ValueChanged<double> onAltezza;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderMisuraAltezza(onAltezza);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderMisuraAltezza renderObject,
  ) => renderObject.onAltezza = onAltezza;
}

/// La misura di [MisuraAltezza].
class RenderMisuraAltezza extends RenderProxyBox {
  RenderMisuraAltezza(this.onAltezza);

  ValueChanged<double> onAltezza;
  double? _ultima;

  @override
  void performLayout() {
    super.performLayout();
    final altezza = size.height;
    if (altezza == _ultima) return;
    _ultima = altezza;
    WidgetsBinding.instance.addPostFrameCallback((_) => onAltezza(altezza));
  }
}
