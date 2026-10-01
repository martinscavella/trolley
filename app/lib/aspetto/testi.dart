import 'package:flutter/widgets.dart';

/// La scala tipografica, ricalcata su quella di iOS. Il carattere è quello di
/// sistema: SF Pro su iOS, Roboto su Android. Il colore lo decide chi la usa.
abstract final class Testi {
  static const titoloGrande = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.37,
    height: 1.12,
  );

  static const titolo = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.36,
    height: 1.15,
  );

  static const titoloSezione = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.35,
  );

  static const evidenza = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.43,
  );

  static const corpo = TextStyle(
    fontSize: 17,
    letterSpacing: -0.43,
    height: 1.3,
  );

  static const secondario = TextStyle(
    fontSize: 15,
    letterSpacing: -0.23,
    height: 1.33,
  );

  static const didascalia = TextStyle(fontSize: 13, letterSpacing: -0.08);

  static const etichetta = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );
}
