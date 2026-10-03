import 'package:flutter/widgets.dart';

/// La scala tipografica della tela: titoli, codici e numeri in Unbounded,
/// testo in DM Sans. Il colore lo decide chi la usa.
abstract final class Testi {
  static const unbounded = 'Unbounded';
  static const dmSans = 'DM Sans';

  /// Un titolo in Unbounded. È un carattere variabile: il peso si dà come
  /// variazione, come fa il browser con cui è stata disegnata la tela.
  static TextStyle titoli(
    double grandezza, {
    double spaziatura = -0.01,
    double altezza = 1.15,
    double peso = 700,
  }) => TextStyle(
    fontFamily: unbounded,
    fontSize: grandezza,
    fontWeight: peso >= 800
        ? FontWeight.w800
        : peso >= 700
        ? FontWeight.w700
        : FontWeight.w600,
    fontVariations: [FontVariation('wght', peso)],
    letterSpacing: grandezza * spaziatura,
    height: altezza,
  );

  /// "Trolley" nell'accesso.
  static final marchio = titoli(50, spaziatura: -0.02, altezza: 1, peso: 800);

  /// Il codice di tre lettere di un biglietto: «LIS».
  static TextStyle codice(double grandezza) =>
      titoli(grandezza, spaziatura: -0.02, altezza: 0.95, peso: 800);

  /// Il titolo di una schermata: "Come ti chiami?".
  static final titoloGrande = titoli(30);

  /// "I tuoi viaggi".
  static final titolo = titoli(26);

  /// Il titolo di un foglio che sale dal basso.
  static final titoloFoglio = titoli(24);

  /// Il nome di un'idea sul suo biglietto.
  static final titoloScheda = titoli(22, altezza: 1.2);

  static final titoloSezione = titoli(16, altezza: 1.2, peso: 600);

  /// Un numero o una data sulla matrice di un biglietto: «12 mag».
  static final numero = titoli(17, spaziatura: 0, altezza: 1.2, peso: 600);

  static const evidenza = TextStyle(
    fontFamily: dmSans,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  static const corpo = TextStyle(
    fontFamily: dmSans,
    fontSize: 16,
    height: 1.45,
  );

  /// Il testo dei campi.
  static const campo = TextStyle(fontFamily: dmSans, fontSize: 17);

  static const pulsante = TextStyle(
    fontFamily: dmSans,
    fontSize: 17,
    fontWeight: FontWeight.w700,
  );

  static const secondario = TextStyle(
    fontFamily: dmSans,
    fontSize: 14,
    height: 1.4,
  );

  static const didascalia = TextStyle(
    fontFamily: dmSans,
    fontSize: 13,
    height: 1.45,
  );

  /// Sopra i campi: "Email", "Nome".
  static const etichetta = TextStyle(
    fontFamily: dmSans,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  /// Le capsule: «Prossima · 13:00».
  static const pillola = TextStyle(
    fontFamily: dmSans,
    fontSize: 13,
    fontWeight: FontWeight.w700,
  );

  /// Le scritte piccole in maiuscolo dei biglietti: «IN CORSO», «DAL».
  static const sezione = TextStyle(
    fontFamily: dmSans,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.5,
    height: 1.3,
  );

  /// Le voci della barra in basso.
  static const voceBarra = TextStyle(
    fontFamily: dmSans,
    fontSize: 14,
    fontWeight: FontWeight.w700,
  );
}
