import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'tavolozza.dart';

const _icone = [
  Icons.flight_takeoff_rounded,
  Icons.luggage_rounded,
  Icons.landscape_rounded,
  Icons.beach_access_rounded,
  Icons.explore_rounded,
  Icons.directions_boat_rounded,
  Icons.hiking_rounded,
  Icons.location_city_rounded,
];

/// La copertina di un viaggio: una sfumatura e un'icona in filigrana, scelte
/// dall'id così lo stesso viaggio ha sempre la stessa faccia.
///
/// Non dice niente del viaggio: è riconoscibilità, non contenuto.
class Copertina extends StatelessWidget {
  const Copertina({super.key, required this.chiave, this.raggio = 0});

  final String chiave;
  final double raggio;

  @override
  Widget build(BuildContext context) {
    final sfumatura = copertinaPer(chiave);
    final icona = _icone[indiceStabile('$chiave·icona', _icone.length)];
    return ClipRSuperellipse(
      borderRadius: BorderRadius.circular(raggio),
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: sfumatura.gradiente),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Un riflesso morbido in alto a sinistra: dà volume senza rumore.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.9, -1),
                  radius: 1.1,
                  colors: [Color(0x40FFFFFF), Color(0x00FFFFFF)],
                ),
              ),
            ),
            // Intera, così si riconosce: un'icona tagliata sembra una macchia.
            Positioned(
              right: 18,
              top: 18,
              child: Transform.rotate(
                angle: -0.1,
                child: Icon(icona, size: 96, color: const Color(0x33FFFFFF)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// La copertina che vola dalla scheda nell'elenco alla testata del viaggio,
/// arrotondando o raddrizzando gli angoli durante il volo.
class CopertinaEroe extends StatelessWidget {
  const CopertinaEroe({super.key, required this.chiave, required this.raggio});

  final String chiave;
  final double raggio;

  static const raggioScheda = 26.0;

  @override
  Widget build(BuildContext context) => Hero(
    tag: 'copertina-$chiave',
    // L'animazione va da 0 a 1 all'andata e da 1 a 0 al ritorno: 0 è la
    // scheda, 1 è la testata, in entrambe le direzioni.
    flightShuttleBuilder: (_, animazione, _, _, _) => AnimatedBuilder(
      animation: animazione,
      builder: (_, _) => Copertina(
        chiave: chiave,
        raggio: lerpDouble(raggioScheda, 0, animazione.value)!,
      ),
    ),
    child: Copertina(chiave: chiave, raggio: raggio),
  );
}
