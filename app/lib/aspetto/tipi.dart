/// Come si riconosce un tipo di tappa a colpo d'occhio: un colore e
/// un'icona. I colori sono quelli della tela: cobalto per quello che si
/// visita, pomodoro per i pasti, ottanio per quello che si fa a piedi, grigio
/// per il resto.
library;

import 'package:flutter/material.dart';

import '../dominio/tappe.dart';
import 'tavolozza.dart';

/// Il colore di un tipo, per i pezzi della striscia della giornata.
Color coloreTipo(TipoTappa? tipo) => switch (tipo) {
  TipoTappa.visita || TipoTappa.museo || TipoTappa.spettacolo => Colori.cobalto,
  TipoTappa.pasto => Colori.pomodoro,
  TipoTappa.passeggiata || TipoTappa.escursione => Colori.ottanio,
  _ => Colori.piombo,
};

/// Il colore di un'icona su fondo chiaro: scuro abbastanza da leggersi.
Color coloreIconaTipo(TipoTappa? tipo) => switch (tipo) {
  TipoTappa.pasto => const Color(0xFFD9472B),
  TipoTappa.pausa || TipoTappa.altro || null => Colori.grafite,
  _ => coloreTipo(tipo),
};

IconData iconaTipo(TipoTappa? tipo) => switch (tipo) {
  TipoTappa.visita => Icons.account_balance_outlined,
  TipoTappa.museo => Icons.museum_outlined,
  TipoTappa.pasto => Icons.restaurant_rounded,
  TipoTappa.passeggiata => Icons.directions_walk_rounded,
  TipoTappa.spettacolo => Icons.theater_comedy_outlined,
  TipoTappa.escursione => Icons.hiking_rounded,
  TipoTappa.pausa => Icons.coffee_outlined,
  TipoTappa.altro || null => Icons.place_outlined,
};
