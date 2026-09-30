import 'package:flutter/material.dart';

/// Tema provvisorio: nessun investimento sull'identità visiva finché il nome è
/// in codice (punti-aperti.md). Solo un colore e i default di Material.
const _seme = Color(0xFF1F5F4A);

final temaChiaro = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: _seme),
  useMaterial3: true,
);

final temaScuro = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: _seme,
    brightness: Brightness.dark,
  ),
  useMaterial3: true,
);
