/// Da che parte si sta: iOS con il vetro di sistema, iOS precedente, Android.
///
/// L'interfaccia segue la piattaforma (ADR-007): su iOS 26 e successivi barre,
/// pulsanti flottanti e dialoghi sono componenti UIKit con il Liquid Glass vero;
/// su Android sono Material. I contenuti sono disegnati da Flutter, uguali ovunque.
library;

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

bool get suIOS => PlatformInfo.isIOS;

/// iOS 26 e successivi: il vetro lo disegna il sistema.
bool get conVetroNativo => PlatformInfo.isIOS26OrHigher();

IconData icona({required IconData ios, required IconData android}) =>
    suIOS ? ios : android;

/// Una pagina con la transizione della piattaforma: su iOS si torna indietro
/// trascinando dal bordo.
Route<T> rotta<T>(Widget pagina) => suIOS
    ? CupertinoPageRoute<T>(builder: (_) => pagina)
    : MaterialPageRoute<T>(builder: (_) => pagina);

Future<T?> apri<T>(BuildContext context, Widget pagina) =>
    Navigator.of(context).push<T>(rotta<T>(pagina));
