/// Come si riconosce un mezzo (CR-07; tela, 166–169): il nome e un'icona.
library;

import 'package:flutter/material.dart';

import '../dominio/tragitti.dart';
import 'formati.dart';

/// Il nome, come titolo di una scelta: «A piedi», «Con i mezzi».
String nomeMezzo(Mezzo m) => switch (m) {
  Mezzo.aPiedi => 'A piedi',
  Mezzo.bici => 'In bici',
  Mezzo.mezzi => 'Con i mezzi',
  Mezzo.monopattino => 'Monopattino',
  Mezzo.auto => 'In auto',
  Mezzo.taxi => 'In taxi',
};

/// Il nome dentro una frase: «ci vai a piedi», «in monopattino».
String mezzoInFrase(Mezzo m) => switch (m) {
  Mezzo.monopattino => 'in monopattino',
  _ => nomeMezzo(m).toLowerCase(),
};

IconData iconaMezzo(Mezzo? m) => switch (m) {
  Mezzo.aPiedi => Icons.directions_walk_rounded,
  Mezzo.bici => Icons.pedal_bike_rounded,
  Mezzo.mezzi => Icons.directions_transit_rounded,
  Mezzo.monopattino => Icons.electric_scooter_rounded,
  Mezzo.auto => Icons.directions_car_rounded,
  Mezzo.taxi => Icons.local_taxi_rounded,
  null => Icons.alt_route_rounded,
};

/// «circa 15 min»: la stima, che non è mai esatta.
String circa(Duration d) => 'circa ${durataBreve(d)}';
