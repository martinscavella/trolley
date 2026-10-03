/// Da che parte si sta: iOS o Android.
///
/// I contenuti e la navigazione sono quelli della tela, uguali ovunque
/// (ADR-007). Cambiano le icone, le transizioni fra pagine e i componenti di
/// sistema che restano: dialoghi, selettori, interruttori.
library;

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'pagina.dart';

bool get suIOS => PlatformInfo.isIOS;

/// iOS 26 e successivi: dialoghi e selettori di sistema hanno il vetro vero.
bool get conVetroNativo => PlatformInfo.isIOS26OrHigher();

IconData icona({required IconData ios, required IconData android}) =>
    suIOS ? ios : android;

/// Una pagina con la transizione della piattaforma: su iOS si torna indietro
/// trascinando dal bordo.
Route<T> rotta<T>(Widget pagina) => suIOS
    ? CupertinoPageRoute<T>(builder: (_) => pagina)
    : MaterialPageRoute<T>(builder: (_) => pagina);

/// Apre [pagina]. [dalBasso] per i fogli che creano o cambiano qualcosa: salgono
/// sopra la schermata di prima, come "Nuova idea" della tela ([Foglio]).
Future<T?> apri<T>(
  BuildContext context,
  Widget pagina, {
  bool dalBasso = false,
}) => dalBasso
    ? apriFoglio<T>(context, pagina)
    : Navigator.of(context).push<T>(rotta<T>(pagina));

/// Apre [pagina] a tutto schermo, salendo dal basso: un documento da guardare.
Future<T?> apriAPienoSchermo<T>(BuildContext context, Widget pagina) =>
    Navigator.of(context).push<T>(
      suIOS
          ? CupertinoPageRoute<T>(builder: (_) => pagina, fullscreenDialog: true)
          : MaterialPageRoute<T>(builder: (_) => pagina, fullscreenDialog: true),
    );
