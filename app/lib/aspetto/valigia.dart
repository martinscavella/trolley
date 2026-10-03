/// I pezzi delle cose da portare, come li disegna la tela (fila «Biglietti —
/// Fase 1.5», 19–23): il cerchio da spuntare e la barra della valigia.
///
/// Il verde dice «fatto», come per le tappe: una voce in valigia, un pezzo
/// della barra pieno.
library;

import 'dart:math';

import 'package:flutter/material.dart';

import 'movimento.dart';
import 'tavolozza.dart';

/// Il cerchio a sinistra di una voce: vuoto con il bordo d'inchiostro, pieno
/// di verde con la spunta bianca quando la voce è in valigia. A VoiceOver lo
/// dice il pulsante che lo contiene.
class CerchioSpunta extends StatelessWidget {
  const CerchioSpunta({super.key, required this.spuntata});

  final bool spuntata;

  @override
  Widget build(BuildContext context) {
    final ridotto = movimentoRidotto(context);
    return AnimatedContainer(
      duration: ridotto ? Duration.zero : Ritmo.breve,
      curve: Ritmo.curva,
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: spuntata ? Colori.verde : Colori.bianco,
        border: spuntata
            ? null
            : Border.all(color: Colori.inchiostro, width: 2.5),
      ),
      child: AnimatedScale(
        scale: spuntata ? 1 : 0.4,
        duration: ridotto ? Duration.zero : Ritmo.medio,
        curve: Ritmo.molla,
        child: AnimatedOpacity(
          opacity: spuntata ? 1 : 0,
          duration: ridotto ? Duration.zero : Ritmo.breve,
          child: const Icon(
            Icons.check_rounded,
            size: 18,
            color: Colori.bianco,
          ),
        ),
      ),
    );
  }
}

/// Quanto è piena la valigia: un pezzo per voce, verde quelli in valigia.
/// Con tante voci i pezzi diventano una barra continua, che si legge meglio
/// di cento tacche.
class BarraValigia extends StatelessWidget {
  const BarraValigia({
    super.key,
    required this.fatte,
    required this.tutte,
    this.altezza = 10,
  });

  final int fatte;
  final int tutte;
  final double altezza;

  /// Oltre questo numero di voci, una barra sola.
  static const pezziMassimi = 24;

  @override
  Widget build(BuildContext context) {
    if (tutte == 0) return SizedBox(height: altezza);
    if (tutte > pezziMassimi) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: SizedBox(
          height: altezza,
          child: Stack(
            children: [
              const Positioned.fill(child: ColoredBox(color: Colori.cenere)),
              FractionallySizedBox(
                widthFactor: min(1, fatte / tutte),
                child: const ColoredBox(color: Colori.verde),
              ),
            ],
          ),
        ),
      );
    }
    return SizedBox(
      height: altezza,
      child: Row(
        children: [
          for (var i = 0; i < tutte; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            Expanded(
              child: AnimatedContainer(
                duration: movimentoRidotto(context)
                    ? Duration.zero
                    : Ritmo.medio,
                curve: Ritmo.curva,
                decoration: BoxDecoration(
                  color: i < fatte ? Colori.verde : Colori.cenere,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
