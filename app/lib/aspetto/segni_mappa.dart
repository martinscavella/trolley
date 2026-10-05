/// I segni sopra la mappa, come nella tela (50–54): le tappe come punti
/// numerati — verdi quelle fatte, cobalto la prossima con il suo alone,
/// d'inchiostro le altre —, il puntino della persona, e sulla mappa del
/// viaggio un colore per giorno.
library;

import 'package:flutter/material.dart';

import '../dominio/mappa.dart';
import 'movimento.dart';
import 'tavolozza.dart';
import 'testi.dart';

/// Quanto spazio occupa un segno: abbastanza per il dito (44 punti).
const latoSegno = 48.0;

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
  const PuntinoPosizione({super.key});

  static const lato = 32.0;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Sei qui',
    child: SizedBox.square(
      dimension: lato,
      child: Center(
        child: Container(
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
        ),
      ),
    ),
  );
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

/// Chi ringraziare sotto la mappa: il fornitore e i dati (ADR-006). Una riga
/// piccola, sopra la scheda in basso.
class Attribuzione extends StatelessWidget {
  const Attribuzione(this.testo, {super.key});

  final String testo;

  @override
  Widget build(BuildContext context) => testo.isEmpty
      ? const SizedBox.shrink()
      : Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colori.bianco.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            testo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Testi.didascalia.copyWith(
              fontSize: 9,
              height: 1.3,
              color: Colori.grafite,
            ),
          ),
        );
}
