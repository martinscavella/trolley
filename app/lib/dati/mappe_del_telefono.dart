/// Le Mappe del telefono (08-mappa.md, regola 6): dove si consegna una tappa
/// quando la mappa di Trolley non c'è — senza rete, senza fornitore, oltre il
/// tetto di ADR-006 — o quando si va coi mezzi o in auto. Possono avere le
/// loro mappe scaricate. Dietro un'interfaccia, come ogni cosa che esce
/// dall'app (04-integrazioni.md).
library;

import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

import '../dominio/mappa.dart';

abstract interface class MappeDelTelefono {
  /// Apre le Mappe con le indicazioni a piedi fino a [posto], o fino a
  /// [indirizzo] se il posto non si sa. `false` se non si sono aperte.
  Future<bool> portami({
    required String nome,
    Coordinate? posto,
    String? indirizzo,
  });
}

/// Apple Mappe su iOS, Google Maps su Android.
class MappeDiSistema implements MappeDelTelefono {
  const MappeDiSistema();

  @override
  Future<bool> portami({
    required String nome,
    Coordinate? posto,
    String? indirizzo,
  }) async {
    final indirizzoWeb = indirizzoPerLeMappe(
      nome: nome,
      posto: posto,
      indirizzo: indirizzo,
      apple: !Platform.isAndroid,
    );
    if (indirizzoWeb == null) return false;
    try {
      return await launchUrl(
        indirizzoWeb,
        mode: LaunchMode.externalApplication,
      );
    } on Object {
      return false;
    }
  }
}

/// Il link che apre le Mappe sulle indicazioni a piedi. `null` se non c'è
/// né un posto né un indirizzo.
Uri? indirizzoPerLeMappe({
  required String nome,
  Coordinate? posto,
  String? indirizzo,
  bool apple = true,
}) {
  final dove = posto != null
      ? '${posto.lat},${posto.lon}'
      : [nome, ?indirizzo].where((t) => t.trim().isNotEmpty).join(', ');
  if (posto == null && (indirizzo == null || indirizzo.trim().isEmpty)) {
    return null;
  }
  return apple
      ? Uri.https('maps.apple.com', '/', {
          'daddr': dove,
          'dirflg': 'w',
          if (posto != null) 'q': nome,
        })
      : Uri.https('www.google.com', '/maps/dir/', {
          'api': '1',
          'destination': dove,
          'travelmode': 'walking',
        });
}
