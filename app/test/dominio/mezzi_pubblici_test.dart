import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dominio/mezzi_pubblici.dart';

/// Una risposta di Google con i mezzi, com'è (Routes API, `TRANSIT`): due
/// passi a piedi fino a Kongens Nytorv, la metro M1 fino a Nørreport, il
/// bus 5C, l'ultimo tratto a piedi fino a Rosenborg.
Map<String, dynamic> rispostaDiGoogle() {
  Map<String, dynamic> ll(double lat, double lon) => {
    'latLng': {'latitude': lat, 'longitude': lon},
  };
  Map<String, dynamic> piedi(List<double> da, List<double> a, int m, int s) => {
    'travelMode': 'WALK',
    'distanceMeters': m,
    'staticDuration': '${s}s',
    'startLocation': ll(da[0], da[1]),
    'endLocation': ll(a[0], a[1]),
  };
  Map<String, dynamic> linea(
    List<double> da,
    List<double> a, {
    required String nome,
    required String tipo,
    required String verso,
    required String sali,
    required String scendi,
    required String parte,
    required String arriva,
    required int fermate,
  }) => {
    'travelMode': 'TRANSIT',
    'distanceMeters': 2000,
    'staticDuration': '300s',
    'startLocation': ll(da[0], da[1]),
    'endLocation': ll(a[0], a[1]),
    'transitDetails': {
      'stopDetails': {
        'departureStop': {'name': sali},
        'arrivalStop': {'name': scendi},
        'departureTime': parte,
        'arrivalTime': arriva,
      },
      'headsign': verso,
      'stopCount': fermate,
      'transitLine': {
        'nameShort': nome,
        'vehicle': {'type': tipo},
      },
    },
  };
  return {
    'routes': [
      {
        'duration': '1320s',
        'distanceMeters': 3400,
        'polyline': {'encodedPolyline': '_p~iF~ps|U_ulLnnqC_mqNvxq`@'},
        'legs': [
          {
            'steps': [
              piedi([55.6800, 12.5800], [55.6805, 12.5820], 120, 100),
              piedi([55.6805, 12.5820], [55.6810, 12.5850], 180, 140),
              linea(
                [55.6810, 12.5850],
                [55.6830, 12.5710],
                nome: 'M1',
                tipo: 'SUBWAY',
                verso: 'Vanløse',
                sali: 'Kongens Nytorv',
                scendi: 'Nørreport',
                parte: '2026-11-28T10:32:00Z',
                arriva: '2026-11-28T10:37:00Z',
                fermate: 3,
              ),
              linea(
                [55.6830, 12.5710],
                [55.6850, 12.5760],
                nome: '5C',
                tipo: 'BUS',
                verso: 'Husum',
                sali: 'Nørreport St.',
                scendi: 'Sølvtorvet',
                parte: '2026-11-28T10:41:00Z',
                arriva: '2026-11-28T10:43:00Z',
                fermate: 1,
              ),
              piedi([55.6850, 12.5760], [55.6857, 12.5773], 400, 300),
            ],
          },
        ],
      },
    ],
  };
}

void main() {
  group('il percorso da Google', () {
    test('i tratti a piedi si uniscono, e vanno fino alla fermata dove si '
        'sale; l\'ultimo fino alla tappa', () {
      final p = percorsoDaGoogle(rispostaDiGoogle())!;

      expect(p.passi, hasLength(4));
      final primo = p.passi[0] as APiediFino;
      expect(primo.metri, 300);
      expect(primo.durata, const Duration(seconds: 240));
      expect(primo.verso, 'Kongens Nytorv');
      expect(primo.inizio, (lat: 55.68, lon: 12.58));
      expect(primo.fine, (lat: 55.681, lon: 12.585));
      expect((p.passi[3] as APiediFino).verso, isNull);
    });

    test('le linee: il nome, il mezzo, la direzione, le fermate, le ore', () {
      final p = percorsoDaGoogle(rispostaDiGoogle())!;
      final metro = p.passi[1] as SullaLinea;

      expect(metro.linea, 'M1');
      expect(metro.veicolo, Veicolo.metro);
      expect(metro.direzione, 'Vanløse');
      expect(metro.sali, 'Kongens Nytorv');
      expect(metro.scendi, 'Nørreport');
      expect(metro.fermate, 3);
      expect(metro.partenza, DateTime.utc(2026, 11, 28, 10, 32).toLocal());
      expect((p.passi[2] as SullaLinea).veicolo, Veicolo.bus);
      expect(p.cambi, 1);
      expect(p.veicolo, Veicolo.metro);
      expect(p.durata, const Duration(minutes: 22));
    });

    test('gli orari: le linee all\'ora di Google, a piedi quando finisce il '
        'passo prima; si arriva dopo l\'ultimo tratto', () {
      final p = percorsoDaGoogle(rispostaDiGoogle())!;
      final adesso = DateTime.utc(2026, 11, 28, 10, 25).toLocal();
      final orari = p.orariDeiPassi(adesso);

      expect(orari[0], adesso);
      expect(orari[1], DateTime.utc(2026, 11, 28, 10, 32).toLocal());
      expect(orari[3], DateTime.utc(2026, 11, 28, 10, 43).toLocal());
      expect(p.arrivo(adesso), DateTime.utc(2026, 11, 28, 10, 48).toLocal());
    });

    test('la linea per la mappa', () {
      final p = percorsoDaGoogle(rispostaDiGoogle())!;
      expect(p.linea, [
        (lat: 38.5, lon: -120.2),
        (lat: 40.7, lon: -120.95),
        (lat: 43.252, lon: -126.453),
      ]);
    });

    test('senza un percorso, niente', () {
      expect(percorsoDaGoogle({}), isNull);
      expect(percorsoDaGoogle({'routes': []}), isNull);
    });
  });

  group('il passo di adesso', () {
    final p = percorsoDaGoogle(rispostaDiGoogle())!;

    test('quello la cui strada è più vicina', () {
      expect(passoDiAdesso(p.passi, (lat: 55.6801, lon: 12.5805)), 0);
      expect(passoDiAdesso(p.passi, (lat: 55.6820, lon: 12.5780)), 1);
      expect(passoDiAdesso(p.passi, (lat: 55.6855, lon: 12.5770)), 3);
    });

    test('non torna indietro', () {
      expect(
        passoDiAdesso(p.passi, (lat: 55.6801, lon: 12.5805), almeno: 2),
        2,
      );
    });
  });

  test('dove si è va a Google arrotondato a circa cento metri', () {
    expect(arrotondataACento((lat: 55.68049, lon: 12.58361)), (
      lat: 55.68,
      lon: 12.584,
    ));
  });
}
