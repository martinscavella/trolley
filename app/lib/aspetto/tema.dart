import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'tavolozza.dart';
import 'testi.dart';

/// I temi per i componenti di sistema che restano (dialoghi, selettori,
/// interruttori, avvisi): lo stesso cobalto e lo stesso carattere della tela.
/// Solo chiari, come la tela.
final temaMaterialChiaro = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colori.cobalto,
    primary: Colori.cobalto,
    surface: Colori.nebbia,
  ),
  scaffoldBackgroundColor: Colori.nebbia,
  fontFamily: Testi.dmSans,
  useMaterial3: true,
);

/// Lo scuro non c'è: l'app resta chiara anche col telefono in scuro.
final temaMaterialScuro = temaMaterialChiaro;

const temaCupertinoChiaro = CupertinoThemeData(
  brightness: Brightness.light,
  primaryColor: Colori.cobalto,
  scaffoldBackgroundColor: Colori.nebbia,
  textTheme: CupertinoTextThemeData(
    primaryColor: Colori.cobalto,
    textStyle: TextStyle(
      fontFamily: Testi.dmSans,
      fontSize: 17,
      color: Colori.inchiostro,
    ),
  ),
);

const temaCupertinoScuro = temaCupertinoChiaro;
