/// La posizione del telefono (08-mappa.md, regole 3 e 7): il puntino sulla
/// mappa mentre il viaggio è in corso, e la guida verso una tappa. Dietro
/// un'interfaccia, così le prove la sostituiscono.
///
/// Non lascia mai il telefono: non si scrive, non si manda al server, non va
/// negli eventi. Al fornitore di mappe arriva solo come partenza di un
/// percorso chiesto dalla persona; per la verifica del viaggio si confronta
/// qui con la meta, e al server va solo l'esito (dati/sul_posto.dart). Si chiede solo «mentre si usa l'app»: in
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

  /// Dov'è il telefono adesso, all'ingrosso: per la verifica del viaggio
  /// basta la città (dominio/verifica.dart). `null` se non si sa in pochi
  /// secondi, o senza permesso.
  Future<Coordinate?> qui();

  /// Apre le impostazioni dell'app, dove si concede il permesso dopo un no.
  Future<bool> apriImpostazioni();
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
  Stream<Coordinate> segui() async* {
    // Quella che il telefono sa già, se è di adesso: la strada parte subito,
    // senza aspettare il primo segnale.
    try {
      final ultima = await Geolocator.getLastKnownPosition();
      if (ultima != null &&
          DateTime.now().difference(ultima.timestamp) < _fresca &&
          ultima.accuracy <= 100) {
        yield (lat: ultima.latitude, lon: ultima.longitude);
      }
    } on Object {
      // Non la sa: si aspetta il segnale.
    }
    yield* Geolocator.getPositionStream(
      locationSettings: AppleSettings(
        accuracy: LocationAccuracy.best,
        // Chi cammina: iOS sa che non si va in auto.
        activityType: ActivityType.fitness,
        distanceFilter: 4,
        // Mai in pausa: a telefono fermo iOS la metterebbe prima ancora della
        // prima posizione, e non la riprende da solo. «Portami» restava a
        // cercare dove si è, finché un'altra app non accendeva il GPS.
        pauseLocationUpdatesAutomatically: false,
      ),
    ).map((p) => (lat: p.latitude, lon: p.longitude));
  }

  /// Quanto vecchia può essere una posizione già nota per partire da lì.
  static const _fresca = Duration(minutes: 1);

  @override
  Future<Coordinate?> qui() async {
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: AppleSettings(
          // La città, non la via: più in fretta, e con meno batteria.
          accuracy: LocationAccuracy.low,
          timeLimit: const Duration(seconds: 15),
        ),
      );
      return (lat: p.latitude, lon: p.longitude);
    } on Object {
      return null;
    }
  }

  @override
  Future<bool> apriImpostazioni() => Geolocator.openAppSettings();

  static PermessoPosizione _traduci(LocationPermission p) => switch (p) {
    LocationPermission.always ||
    LocationPermission.whileInUse => PermessoPosizione.concesso,
    LocationPermission.denied => PermessoPosizione.daChiedere,
    LocationPermission.deniedForever ||
    LocationPermission.unableToDetermine => PermessoPosizione.negato,
  };
}
