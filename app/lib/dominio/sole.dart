/// Dove sta il sole: il punto della Terra che in un dato momento lo ha a
/// picco. Il mappamondo ci disegna il giorno e la notte veri (tela, 144).
///
/// Le formule approssimate dell'almanacco nautico: sbagliano di meno di un
/// grado fino al 2050, che sulla Terra intera è meno di un dito.
library;

import 'dart:math';

import 'mappa.dart';

Coordinate sottoIlSole(DateTime quando) {
  // I giorni dal mezzogiorno del 1° gennaio 2000, in tempo universale.
  final d = (quando.toUtc().millisecondsSinceEpoch - 946728000000) / 86400000;
  double radianti(double gradi) => gradi * pi / 180;
  // Dove sta il sole sull'eclittica.
  final anomalia = radianti((357.529 + 0.98560028 * d) % 360);
  final media = (280.459 + 0.98564736 * d) % 360;
  final eclittica = radianti(
    media + 1.915 * sin(anomalia) + 0.020 * sin(2 * anomalia),
  );
  final inclinazione = radianti(23.439 - 0.00000036 * d);
  final declinazione = asin(sin(inclinazione) * sin(eclittica));
  final ascensione =
      atan2(cos(inclinazione) * sin(eclittica), cos(eclittica)) * 180 / pi;
  // Il tempo siderale di Greenwich, in gradi.
  final siderale = (18.697374558 + 24.06570982441908 * d) % 24 * 15;
  return (
    lat: declinazione * 180 / pi,
    lon: (ascensione - siderale + 540) % 360 - 180,
  );
}
