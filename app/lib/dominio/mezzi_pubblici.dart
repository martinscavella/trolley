/// Il percorso con i mezzi pubblici, a passi (CR-07, passo 3; 04, regola
/// 37; tela, 164): a piedi fino alla fermata, la linea con la direzione e
/// l'ora, quante fermate, dove scendere, a piedi fino alla tappa.
///
/// Lo dà Google (Routes API, i mezzi pubblici) e si mostra solo finché è
/// aperto: non si tiene (ADR-015). Qui si legge la risposta, si uniscono i
/// tratti a piedi, e si capisce a che passo si è dalla posizione.
library;

import 'dart:math';

import 'mappa.dart';

/// Che mezzo è una linea.
enum Veicolo { metro, bus, tram, treno, traghetto, altro }

/// Un passo del percorso: dove comincia e finisce, quanto dura.
sealed class PassoMezzi {
  const PassoMezzi({
    required this.inizio,
    required this.fine,
    required this.durata,
  });

  final Coordinate inizio;
  final Coordinate fine;
  final Duration durata;
}

/// Un tratto a piedi: fino alla fermata [verso], o fino alla tappa se è
/// `null`.
class APiediFino extends PassoMezzi {
  const APiediFino({
    required super.inizio,
    required super.fine,
    required super.durata,
    required this.metri,
    this.verso,
  });

  final double metri;
  final String? verso;
}

/// Un tratto su una linea.
class SullaLinea extends PassoMezzi {
  const SullaLinea({
    required super.inizio,
    required super.fine,
    required super.durata,
    required this.linea,
    required this.veicolo,
    this.direzione,
    this.sali,
    this.scendi,
    this.partenza,
    this.arrivo,
    this.fermate,
  });

  /// Il nome corto della linea («M1», «5C»), o quello lungo.
  final String linea;
  final Veicolo veicolo;

  /// Verso dove va («Vanløse»).
  final String? direzione;

  /// Le fermate dove si sale e si scende.
  final String? sali;
  final String? scendi;
  final DateTime? partenza;
  final DateTime? arrivo;

  /// Quante fermate si fanno.
  final int? fermate;
}

/// Il percorso intero.
class PercorsoMezzi {
  const PercorsoMezzi({
    required this.passi,
    required this.durata,
    this.linea = const [],
  });

  final List<PassoMezzi> passi;
  final Duration durata;

  /// La linea del percorso, per «Vedi sulla mappa»: senza i passi.
  final List<Coordinate> linea;

  Iterable<SullaLinea> get linee => passi.whereType<SullaLinea>();

  /// Quante volte si cambia linea.
  int get cambi => max(0, linee.length - 1);

  /// Il mezzo che dà il nome al percorso: quello della prima linea.
  Veicolo? get veicolo => linee.firstOrNull?.veicolo;

  /// A che ora si arriva, partendo [adesso]: dopo l'ultima linea, più la
  /// strada a piedi che resta.
  DateTime arrivo(DateTime adesso) {
    final orari = orariDeiPassi(adesso);
    return orari.isEmpty
        ? adesso.add(durata)
        : orari.last.add(passi.last.durata);
  }

  /// A che ora comincia ogni passo, partendo [adesso]: le linee all'ora di
  /// Google, i tratti a piedi quando finisce il passo prima.
  List<DateTime> orariDeiPassi(DateTime adesso) {
    final orari = <DateTime>[];
    var t = adesso;
    for (final p in passi) {
      final inizio = p is SullaLinea && p.partenza != null ? p.partenza! : t;
      orari.add(inizio);
      t = p is SullaLinea && p.arrivo != null
          ? p.arrivo!
          : inizio.add(p.durata);
    }
    return orari;
  }
}

/// Il percorso dalla risposta di Google; `null` se Google non ne ha uno.
PercorsoMezzi? percorsoDaGoogle(Map<String, dynamic> json) {
  final rotte = json['routes'];
  if (rotte is! List || rotte.isEmpty) return null;
  final rotta = rotte.first as Map<String, dynamic>;
  final passi = <PassoMezzi>[];
  // I tratti a piedi di Google sono svolta per svolta: si uniscono.
  ({Coordinate inizio, Coordinate fine, double metri, Duration durata})? piedi;
  void chiudiPiedi(String? verso) {
    final p = piedi;
    if (p == null) return;
    passi.add(
      APiediFino(
        inizio: p.inizio,
        fine: p.fine,
        durata: p.durata,
        metri: p.metri,
        verso: verso,
      ),
    );
    piedi = null;
  }

  for (final gamba in (rotta['legs'] as List? ?? const [])) {
    for (final passo in ((gamba as Map)['steps'] as List? ?? const [])) {
      final s = passo as Map<String, dynamic>;
      final inizio = _punto(s['startLocation']);
      final fine = _punto(s['endLocation']);
      if (inizio == null || fine == null) continue;
      final durata = _durata(s['staticDuration']);
      final metri = (s['distanceMeters'] as num?)?.toDouble() ?? 0;
      final transito = s['transitDetails'] as Map<String, dynamic>?;
      if (s['travelMode'] == 'TRANSIT' && transito != null) {
        final fermate = transito['stopDetails'] as Map<String, dynamic>?;
        final sali = _nome(fermate?['departureStop']);
        chiudiPiedi(sali);
        final linea = transito['transitLine'] as Map<String, dynamic>?;
        passi.add(
          SullaLinea(
            inizio: inizio,
            fine: fine,
            durata: durata,
            linea:
                (linea?['nameShort'] as String?) ??
                (linea?['name'] as String?) ??
                '',
            veicolo: _veicolo((linea?['vehicle'] as Map?)?['type'] as String?),
            direzione: transito['headsign'] as String?,
            sali: sali,
            scendi: _nome(fermate?['arrivalStop']),
            partenza: _ora(fermate?['departureTime']),
            arrivo: _ora(fermate?['arrivalTime']),
            fermate: (transito['stopCount'] as num?)?.toInt(),
          ),
        );
      } else {
        final p = piedi;
        piedi = p == null
            ? (inizio: inizio, fine: fine, metri: metri, durata: durata)
            : (
                inizio: p.inizio,
                fine: fine,
                metri: p.metri + metri,
                durata: p.durata + durata,
              );
      }
    }
  }
  chiudiPiedi(null);
  if (passi.isEmpty) return null;
  final polilinea =
      (rotta['polyline'] as Map?)?['encodedPolyline'] as String? ?? '';
  return PercorsoMezzi(
    passi: passi,
    durata: _durata(rotta['duration']),
    linea: decodificaPolilinea(polilinea),
  );
}

/// A che passo si è, da [qui]: quello la cui strada è più vicina, mai
/// tornando indietro da [almeno].
int passoDiAdesso(List<PassoMezzi> passi, Coordinate qui, {int almeno = 0}) {
  var migliore = almeno;
  var distanza = double.infinity;
  for (var i = almeno; i < passi.length; i++) {
    final d = distanzaDalSegmento(qui, passi[i].inizio, passi[i].fine);
    if (d < distanza) {
      distanza = d;
      migliore = i;
    }
  }
  return migliore;
}

/// Quanto è lontano [p] dal segmento [a]–[b], in metri: abbastanza preciso
/// per una città.
double distanzaDalSegmento(Coordinate p, Coordinate a, Coordinate b) {
  final kx = 111320 * cos(p.lat * pi / 180);
  const ky = 110540.0;
  final ax = (a.lon - p.lon) * kx, ay = (a.lat - p.lat) * ky;
  final bx = (b.lon - p.lon) * kx, by = (b.lat - p.lat) * ky;
  final dx = bx - ax, dy = by - ay;
  final lunga = dx * dx + dy * dy;
  final t = lunga == 0 ? 0.0 : (-(ax * dx + ay * dy) / lunga).clamp(0.0, 1.0);
  final x = ax + t * dx, y = ay + t * dy;
  return sqrt(x * x + y * y);
}

/// I punti di una polilinea codificata di Google.
List<Coordinate> decodificaPolilinea(String codificata) {
  final punti = <Coordinate>[];
  var i = 0, lat = 0, lon = 0;
  int prossimo() {
    var risultato = 0, spostamento = 0, b = 0;
    do {
      b = codificata.codeUnitAt(i++) - 63;
      risultato |= (b & 0x1f) << spostamento;
      spostamento += 5;
    } while (b >= 0x20 && i < codificata.length);
    return (risultato & 1) != 0 ? ~(risultato >> 1) : risultato >> 1;
  }

  while (i < codificata.length) {
    lat += prossimo();
    if (i >= codificata.length) break;
    lon += prossimo();
    punti.add((lat: lat / 1e5, lon: lon / 1e5));
  }
  return punti;
}

/// Circa cento metri: quanto si dice a Google di dove si è (decisioni,
/// CR-05).
Coordinate arrotondataACento(Coordinate c) => (
  lat: (c.lat * 1000).roundToDouble() / 1000,
  lon: (c.lon * 1000).roundToDouble() / 1000,
);

Coordinate? _punto(Object? v) {
  final ll = (v as Map?)?['latLng'] as Map?;
  final lat = (ll?['latitude'] as num?)?.toDouble();
  final lon = (ll?['longitude'] as num?)?.toDouble();
  return coordinate(lat, lon);
}

/// «123s» → 123 secondi.
Duration _durata(Object? v) {
  if (v is! String || !v.endsWith('s')) return Duration.zero;
  final secondi = double.tryParse(v.substring(0, v.length - 1));
  return Duration(seconds: secondi?.round() ?? 0);
}

DateTime? _ora(Object? v) =>
    v is String ? DateTime.tryParse(v)?.toLocal() : null;

String? _nome(Object? fermata) => (fermata as Map?)?['name'] as String?;

Veicolo _veicolo(String? tipo) => switch (tipo) {
  'SUBWAY' || 'METRO_RAIL' => Veicolo.metro,
  'BUS' || 'INTERCITY_BUS' || 'TROLLEYBUS' || 'SHARE_TAXI' => Veicolo.bus,
  'TRAM' || 'LIGHT_RAIL' || 'MONORAIL' || 'CABLE_CAR' => Veicolo.tram,
  'RAIL' ||
  'HEAVY_RAIL' ||
  'COMMUTER_TRAIN' ||
  'HIGH_SPEED_TRAIN' ||
  'LONG_DISTANCE_TRAIN' => Veicolo.treno,
  'FERRY' => Veicolo.traghetto,
  _ => Veicolo.altro,
};
