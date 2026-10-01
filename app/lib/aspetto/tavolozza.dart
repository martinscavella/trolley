/// I colori dell'app.
///
/// Sono i colori di sistema di iOS, risolti per chiaro e scuro, usati anche su
/// Android perché i contenuti restino gli stessi. L'unico colore nostro è
/// l'accento, provvisorio come il nome (punti-aperti.md: nessun investimento
/// sull'identità visiva prima del nome definitivo).
library;

import 'package:flutter/cupertino.dart';

class Tavolozza {
  const Tavolozza._({
    required this.scuro,
    required this.sfondo,
    required this.superficie,
    required this.riempimento,
    required this.testo,
    required this.testoSecondario,
    required this.testoTerziario,
    required this.separatore,
    required this.accento,
    required this.suAccento,
    required this.pericolo,
  });

  static const accentoDinamico = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF0E9A6F),
    darkColor: Color(0xFF4CD9A6),
  );

  final bool scuro;

  /// Lo sfondo delle pagine.
  final Color sfondo;

  /// Schede e pannelli, un gradino sopra lo sfondo.
  final Color superficie;

  /// Il fondo dei campi di testo.
  final Color riempimento;

  final Color testo;
  final Color testoSecondario;
  final Color testoTerziario;
  final Color separatore;
  final Color accento;

  /// Testo e icone sopra l'accento.
  final Color suAccento;
  final Color pericolo;

  static Tavolozza of(BuildContext context) {
    Color r(Color c) => CupertinoDynamicColor.resolve(c, context);
    final scuro = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    return Tavolozza._(
      scuro: scuro,
      sfondo: r(CupertinoColors.systemGroupedBackground),
      superficie: r(CupertinoColors.secondarySystemGroupedBackground),
      riempimento: r(CupertinoColors.tertiarySystemFill),
      testo: r(CupertinoColors.label),
      testoSecondario: r(CupertinoColors.secondaryLabel),
      testoTerziario: r(CupertinoColors.tertiaryLabel),
      separatore: r(CupertinoColors.separator),
      accento: r(accentoDinamico),
      suAccento: scuro ? const Color(0xFF03261B) : const Color(0xFFFFFFFF),
      pericolo: r(CupertinoColors.systemRed),
    );
  }
}

/// Una sfumatura a due colori, per le copertine dei viaggi.
class Sfumatura {
  const Sfumatura(this.inizio, this.fine);

  final Color inizio;
  final Color fine;

  LinearGradient get gradiente => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [inizio, fine],
  );
}

const _copertine = [
  Sfumatura(Color(0xFFFF7E5F), Color(0xFFFEB47B)), // tramonto
  Sfumatura(Color(0xFF2193B0), Color(0xFF6DD5ED)), // oceano
  Sfumatura(Color(0xFF7F7FD5), Color(0xFF91EAE4)), // lavanda
  Sfumatura(Color(0xFF11998E), Color(0xFF38EF7D)), // foresta
  Sfumatura(Color(0xFFEC6F66), Color(0xFFF3A183)), // corallo
  Sfumatura(Color(0xFF4568DC), Color(0xFFB06AB3)), // crepuscolo
  Sfumatura(Color(0xFFF7971E), Color(0xFFFFD200)), // agrumi
  Sfumatura(Color(0xFF43CEA2), Color(0xFF185A9D)), // laguna
  Sfumatura(Color(0xFF8E2DE2), Color(0xFF4A00E0)), // notte
  Sfumatura(Color(0xFFFF5F6D), Color(0xFFFFC371)), // pesca
];

const _coloriAvatar = [
  Color(0xFFFF6B6B),
  Color(0xFFFFA94D),
  Color(0xFF40C057),
  Color(0xFF339AF0),
  Color(0xFF845EF7),
  Color(0xFFF06595),
  Color(0xFF12B886),
  Color(0xFF5C7CFA),
];

/// La copertina di un viaggio: sempre la stessa per lo stesso viaggio.
Sfumatura copertinaPer(String chiave) =>
    _copertine[indiceStabile(chiave, _copertine.length)];

Color coloreAvatar(String chiave) =>
    _coloriAvatar[indiceStabile(chiave, _coloriAvatar.length)];

/// Un indice che dipende solo dalla chiave, uguale a ogni avvio e su ogni telefono.
int indiceStabile(String chiave, int quanti) {
  var h = 0;
  for (final c in chiave.codeUnits) {
    h = (h * 31 + c) & 0x3fffffff;
  }
  return h % quanti;
}
