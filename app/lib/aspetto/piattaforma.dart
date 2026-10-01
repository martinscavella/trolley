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
/// trascinando dal bordo. [dalBasso] per le schermate che creano qualcosa:
/// salgono dal basso e si chiudono con [PulsanteChiudi].
Route<T> rotta<T>(Widget pagina, {bool dalBasso = false}) => suIOS
    ? CupertinoPageRoute<T>(builder: (_) => pagina, fullscreenDialog: dalBasso)
    : MaterialPageRoute<T>(builder: (_) => pagina, fullscreenDialog: dalBasso);

Future<T?> apri<T>(
  BuildContext context,
  Widget pagina, {
  bool dalBasso = false,
}) => Navigator.of(context).push<T>(rotta<T>(pagina, dalBasso: dalBasso));

/// Il pulsante in alto a sinistra di una schermata salita dal basso. Su iOS 26
/// è un pulsante di sistema, di vetro come quello per tornare indietro.
class PulsanteChiudi extends StatelessWidget {
  const PulsanteChiudi({super.key});

  @override
  Widget build(BuildContext context) {
    void chiudi() => Navigator.of(context).maybePop();
    if (conVetroNativo) {
      return SizedBox.square(
        dimension: 38,
        child: AdaptiveButton.sfSymbol(
          onPressed: chiudi,
          sfSymbol: const SFSymbol('xmark', size: 17),
        ),
      );
    }
    if (suIOS) {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: chiudi,
        child: const Text('Annulla'),
      );
    }
    return IconButton(
      onPressed: chiudi,
      icon: const Icon(Icons.close),
      tooltip: 'Chiudi',
    );
  }
}
