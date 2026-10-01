import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'tavolozza.dart';

/// Temi per Android (Material) e iOS (Cupertino). Stesso accento, stessi sfondi.
final temaMaterialChiaro = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: Tavolozza.accentoDinamico.color),
  scaffoldBackgroundColor: const Color(0xFFF2F2F7),
  useMaterial3: true,
);

final temaMaterialScuro = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: Tavolozza.accentoDinamico.darkColor,
    brightness: Brightness.dark,
  ),
  scaffoldBackgroundColor: const Color(0xFF000000),
  useMaterial3: true,
);

const temaCupertinoChiaro = CupertinoThemeData(
  brightness: Brightness.light,
  primaryColor: Tavolozza.accentoDinamico,
  scaffoldBackgroundColor: CupertinoColors.systemGroupedBackground,
);

const temaCupertinoScuro = CupertinoThemeData(
  brightness: Brightness.dark,
  primaryColor: Tavolozza.accentoDinamico,
  scaffoldBackgroundColor: CupertinoColors.systemGroupedBackground,
);
