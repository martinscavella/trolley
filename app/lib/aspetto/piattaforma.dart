/// Da che parte si sta: iOS o Android.
///
/// I contenuti e la navigazione sono quelli della tela, uguali ovunque
/// (ADR-007). Cambiano le icone, le transizioni fra pagine e i componenti di
/// sistema che restano: dialoghi, selettori, interruttori.
library;

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'movimento.dart';
import 'pagina.dart';

bool get suIOS => PlatformInfo.isIOS;

/// iOS 26 e successivi: dialoghi e selettori di sistema hanno il vetro vero.
bool get conVetroNativo => PlatformInfo.isIOS26OrHigher();

IconData icona({required IconData ios, required IconData android}) =>
    suIOS ? ios : android;

/// Una pagina che tiene la barra delle sezioni (ADR-013): si apre nella pila
/// della sezione, sotto la barra. Le pagine senza passano sopra la barra.
mixin ConLaBarra on Widget {
  /// Il viaggio che la pagina mostra, se ne mostra uno: toccando «Mappa» la
  /// mappa si apre su quello.
  String? get viaggioInVista => null;
}

/// Una pagina con il passaggio dell'app ([RottaTrolley]): uguale su iOS e
/// Android, e su iOS si torna indietro trascinando dal bordo.
Route<T> rotta<T>(Widget pagina) =>
    RottaTrolley<T>(builder: (_) => pagina, pagina: pagina);

/// Apre [pagina]. [dalBasso] per i fogli che creano o cambiano qualcosa: salgono
/// sopra la schermata di prima, come "Nuova idea" della tela ([Foglio]).
///
/// Una pagina [ConLaBarra] si apre nella pila dov'è chi la apre: dentro una
/// sezione, sotto la barra. Le altre si aprono nel navigatore principale,
/// sopra la barra (ADR-013).
Future<T?> apri<T>(
  BuildContext context,
  Widget pagina, {
  bool dalBasso = false,
}) => dalBasso
    ? apriFoglio<T>(context, pagina)
    : Navigator.of(
        context,
        rootNavigator: pagina is! ConLaBarra,
      ).push<T>(rotta<T>(pagina));

/// Apre [pagina] a tutto schermo, salendo dal basso: un documento da guardare.
Future<T?> apriAPienoSchermo<T>(BuildContext context, Widget pagina) =>
    Navigator.of(
      context,
      rootNavigator: true,
    ).push<T>(rottaAPienoSchermo<T>(pagina));

/// La rotta di [apriAPienoSchermo]: per chi sostituisce una pagina a pieno
/// schermo con un'altra.
Route<T> rottaAPienoSchermo<T>(Widget pagina) => suIOS
    ? CupertinoPageRoute<T>(builder: (_) => pagina, fullscreenDialog: true)
    : MaterialPageRoute<T>(builder: (_) => pagina, fullscreenDialog: true);
