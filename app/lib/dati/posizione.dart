/// La posizione del telefono (08-mappa.md, regole 3 e 7): il puntino sulla
/// mappa mentre il viaggio è in corso, e la guida verso una tappa. Dietro
/// un'interfaccia, così le prove la sostituiscono.
///
/// Non lascia mai il telefono: non si scrive, non si manda al server, non va
/// negli eventi. Al fornitore di mappe arriva solo come partenza di un
/// percorso chiesto dalla persona. Si chiede solo «mentre si usa l'app»: in
/// sottofondo no, mai.
library;

import 'package:geolocator/geolocator.dart';

import '../dominio/mappa.dart';

enum PermessoPosizione {
  /// Si può usare.
  concesso,

  /// Non l'ha ancora chiesto nessuno: la prima volta lo chiede iOS.
  daChiedere,

  /// La persona ha detto di no: non si insiste (08, casi limite).
  negato,

  /// La localizzazione del telefono è spenta.
  spenta,
}

abstract interface class Posizione {
  Future<PermessoPosizione> permesso();

  /// Chiede il permesso, se non è già stato chiesto: iOS lo chiede una volta
  /// sola, e dopo un no risponde no senza mostrare niente.
  Future<PermessoPosizione> chiedi();

  /// Le posizioni man mano che ci si muove, finché qualcuno ascolta.
  Stream<Coordinate> segui();
}

/// Il telefono vero, con geolocator.
class PosizioneDelTelefono implements Posizione {
  const PosizioneDelTelefono();

  @override
  Future<PermessoPosizione> permesso() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return PermessoPosizione.spenta;
    }
    return _traduci(await Geolocator.checkPermission());
  }

  @override
  Future<PermessoPosizione> chiedi() async {
    final adesso = await permesso();
    if (adesso != PermessoPosizione.daChiedere) return adesso;
    return _traduci(await Geolocator.requestPermission());
  }

  @override
  Stream<Coordinate> segui() => Geolocator.getPositionStream(
    locationSettings: AppleSettings(
      accuracy: LocationAccuracy.best,
      // Chi cammina: iOS sa che non si va in auto.
      activityType: ActivityType.fitness,
      distanceFilter: 4,
      pauseLocationUpdatesAutomatically: true,
    ),
  ).map((p) => (lat: p.latitude, lon: p.longitude));

  static PermessoPosizione _traduci(LocationPermission p) => switch (p) {
    LocationPermission.always ||
    LocationPermission.whileInUse => PermessoPosizione.concesso,
    LocationPermission.denied => PermessoPosizione.daChiedere,
    LocationPermission.deniedForever ||
    LocationPermission.unableToDetermine => PermessoPosizione.negato,
  };
}
