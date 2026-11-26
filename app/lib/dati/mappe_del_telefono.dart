/// Le Mappe del telefono (08-mappa.md, regola 6): dove si consegna una tappa
/// quando la guida di Trolley non c'è — senza rete, senza fornitore, oltre il
/// tetto di ADR-006 — o quando si va coi mezzi o in auto. Dalla guida, chi
/// preferisce apre Google Maps (tela, 163). Possono avere le
/// loro mappe scaricate. Dietro un'interfaccia, come ogni cosa che esce
/// dall'app (04-integrazioni.md).
library;

import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

import '../dominio/mappa.dart';

abstract interface class MappeDelTelefono {
  /// Apre le Mappe con le indicazioni a piedi fino a [posto], o fino a
  /// [indirizzo] se il posto non si sa. [conGoogle]: Google Maps anche su
  /// iPhone, sul posto di Google [placeId] se c'è. `false` se non si sono
  /// aperte.
  Future<bool> portami({
    required String nome,
    Coordinate? posto,
    String? indirizzo,
    String? placeId,
    bool conGoogle = false,
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
    String? placeId,
    bool conGoogle = false,
  }) async {
    final indirizzoWeb = indirizzoPerLeMappe(
      nome: nome,
      posto: posto,
      indirizzo: indirizzo,
      placeId: placeId,
      apple: !conGoogle && !Platform.isAndroid,
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
/// né un posto né un indirizzo. Google Maps va dritto al posto di Google
/// [placeId], se c'è; il link apre l'app se c'è, altrimenti il sito.
Uri? indirizzoPerLeMappe({
  required String nome,
  Coordinate? posto,
  String? indirizzo,
  String? placeId,
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
          if (placeId != null && placeId.isNotEmpty)
            'destination_place_id': placeId,
          'travelmode': 'walking',
        });
}
