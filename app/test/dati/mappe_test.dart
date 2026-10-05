import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trolley/dati/errori.dart';
import 'package:trolley/dati/mappe.dart';
import 'package:trolley/dati/mappe_del_telefono.dart';
import 'package:trolley/dominio/navigazione.dart';

/// Il fornitore di mappe dietro la sua interfaccia (fase 3.2, ADR-006):
/// come si leggono le sue risposte, cosa gli si chiede, cosa si conta.
void main() {
  /// Una risposta di `/v1/geocode/autocomplete` con `format=json`.
  final ricerca = {
    'results': [
      {
        'name': 'Livraria Lello',
        'country': 'Portogallo',
        'country_code': 'pt',
        'city': 'Porto',
        'postcode': '4050-161',
        'street': 'Rua das Carmelitas',
        'housenumber': '144',
        'lon': -8.61479,
        'lat': 41.14686,
        'formatted':
            'Livraria Lello, Rua das Carmelitas 144, 4050-161 Porto, '
            'Portogallo',
        'address_line1': 'Livraria Lello',
        'address_line2': 'Rua das Carmelitas 144, 4050-161 Porto, Portogallo',
        'result_type': 'amenity',
        'place_id': 'abc',
      },
      {
        'country': 'Portogallo',
        'city': 'Porto',
        'street': 'Rua de Cedofeita',
        'housenumber': '22',
        'lon': -8.6175,
        'lat': 41.1513,
        'address_line1': 'Rua de Cedofeita 22',
        'result_type': 'building',
      },
      {
        'name': 'Vila Nova de Gaia',
        'country': 'Portogallo',
        'city': 'Vila Nova de Gaia',
        'lon': -8.6118,
        'lat': 41.1239,
        'result_type': 'city',
      },
      // Senza coordinate non serve: non si mette sulla mappa.
      {'name': 'Da nessuna parte', 'result_type': 'amenity'},
    ],
  };

  /// Una risposta di `/v1/routing`, GeoJSON: un tratto, tre passi.
  final strada = {
    'type': 'FeatureCollection',
    'features': [
      {
        'type': 'Feature',
        'properties': {
          'mode': 'walk',
          'distance': 450,
          'distance_units': 'meters',
          'time': 360.4,
          'legs': [
            {
              'distance': 450,
              'time': 360.4,
              'steps': [
                {
                  'from_index': 0,
                  'to_index': 2,
                  'distance': 330,
                  'time': 264,
                  'instruction': {
                    'text': 'Cammina verso est su Rua das Carmelitas.',
                    'type': 'StartAt',
                  },
                },
                {
                  'from_index': 2,
                  'to_index': 3,
                  'distance': 120,
                  'time': 96.4,
                  'instruction': {
                    'text': 'Svolta a destra su Rua das Flores.',
                    'type': 'Right',
                  },
                },
                {
                  'from_index': 3,
                  'to_index': 3,
                  'distance': 0,
                  'time': 0,
                  'instruction': {
                    'text': 'Sei arrivato a destinazione.',
                    'type': 'DestinationReached',
                  },
                },
              ],
            },
          ],
        },
        'geometry': {
          'type': 'MultiLineString',
          'coordinates': [
            [
              [-8.6160, 41.1470],
              [-8.6155, 41.1469],
              [-8.6150, 41.1468],
              [-8.6148, 41.1459],
            ],
          ],
        },
      },
    ],
  };

  group('le risposte di Geoapify', () {
    test('i posti: il nome, l\'indirizzo corto, che cosa sono', () {
      final luoghi = luoghiDaGeoapify(ricerca);
      expect(luoghi, hasLength(3));
      final lello = luoghi[0];
      expect(lello.nome, 'Livraria Lello');
      expect(lello.indirizzo, 'Rua das Carmelitas 144, Porto');
      expect(lello.posto, (lat: 41.14686, lon: -8.61479));
      expect(lello.tipo, TipoLuogo.posto);
      expect(luoghi[1].nome, 'Rua de Cedofeita 22');
      expect(luoghi[1].indirizzo, 'Porto');
      expect(luoghi[1].tipo, TipoLuogo.indirizzo);
      expect(luoghi[2].nome, 'Vila Nova de Gaia');
      expect(luoghi[2].indirizzo, 'Portogallo');
      expect(luoghi[2].tipo, TipoLuogo.zona);
    });

    test('una risposta senza risultati non è un errore', () {
      expect(luoghiDaGeoapify({'results': []}), isEmpty);
      expect(luoghiDaGeoapify({'altro': 1}), isEmpty);
    });

    test('il percorso: la linea, i passi, la lunghezza e il tempo', () {
      final p = percorsoDaGeoapify(strada)!;
      expect(p.punti, hasLength(4));
      expect(p.punti.first, (lat: 41.1470, lon: -8.6160));
      expect(p.metri, 450);
      expect(p.durata, const Duration(seconds: 360));
      expect(
        [for (final s in p.passi) s.manovra],
        [Manovra.partenza, Manovra.aDestra, Manovra.arrivo],
      );
      expect(p.passi[1].istruzione, 'Svolta a destra su Rua das Flores.');
      expect((p.passi[1].da, p.passi[1].a), (2, 3));
    });

    test('un percorso con due tratti: gli indici continuano', () {
      final due = jsonDecode(jsonEncode(strada)) as Map<String, dynamic>;
      final f = (due['features'] as List).first as Map<String, dynamic>;
      final legs = (f['properties'] as Map)['legs'] as List;
      legs.add(legs.first);
      final linee = (f['geometry'] as Map)['coordinates'] as List;
      linee.add(linee.first);
      final p = percorsoDaGeoapify(due)!;
      expect(p.punti, hasLength(8));
      expect(p.passi, hasLength(6));
      expect((p.passi[4].da, p.passi[4].a), (6, 7));
    });

    test('senza percorso, niente', () {
      expect(percorsoDaGeoapify({'features': []}), isNull);
      expect(percorsoDaGeoapify({}), isNull);
    });

    test('le manovre che non si conoscono vanno dritte', () {
      expect(manovraDaGeoapify('SharpLeft'), Manovra.strettaASinistra);
      expect(manovraDaGeoapify('TransitTransfer'), Manovra.mezzi);
      expect(manovraDaGeoapify('Qualcosa'), Manovra.dritto);
      expect(manovraDaGeoapify(null), Manovra.dritto);
    });
  });

  group('le risposte vere, registrate il 5 ottobre 2026', () {
    Map<String, dynamic> leggi(String nome) =>
        jsonDecode(File('test/dati/risposte/$nome.json').readAsStringSync())
            as Map<String, dynamic>;

    test('«lello» vicino a Porto: la libreria, una volta per indirizzo', () {
      final luoghi = luoghiDaGeoapify(leggi('geoapify_ricerca'));
      expect(luoghi.first.nome, 'Lello & Irmao Bookstore');
      expect(luoghi.first.indirizzo, 'Rua das Carmelitas, Porto');
      expect(luoghi.first.tipo, TipoLuogo.posto);
      expect(
        luoghi.any(
          (l) =>
              l.nome == 'Livraria Lello e Irmão' &&
              l.indirizzo == 'Rua das Carmelitas 144, Porto',
        ),
        isTrue,
      );
      for (final l in luoghi) {
        expect(l.posto.lat, closeTo(41.147, 0.01));
      }
    });

    test(
      'a piedi dalla libreria alla torre: la linea, le svolte, l\'arrivo',
      () {
        final p = percorsoDaGeoapify(leggi('geoapify_percorso'))!;
        expect(p.metri, 230);
        expect(p.durata.inSeconds, 225);
        expect(p.punti, hasLength(25));
        expect(p.passi.first.manovra, Manovra.partenza);
        expect(p.passi[1].manovra, Manovra.aSinistra);
        expect(p.passi.last.manovra, Manovra.arrivo);
        expect(p.passi.last.istruzione, 'La tua destinazione è sulla destra.');
        expect(p.passi.last.a, 24);
        // Alla partenza la prossima svolta è la prima a sinistra.
        final a = p.avanzamento(p.punti.first);
        expect(a.prossima!.manovra, Manovra.aSinistra);
        expect(a.metriRimasti, closeTo(230, 25));
      },
    );
  });

  group('cosa si scrive come «Dove»', () {
    const lello = Luogo(
      nome: 'Livraria Lello',
      indirizzo: 'Rua das Carmelitas 144, Porto',
      posto: (lat: 41.14686, lon: -8.61479),
    );

    test('se il posto ha il nome della tappa basta l\'indirizzo', () {
      expect(
        lello.dove(titolo: 'livraria lello '),
        'Rua das Carmelitas 144, Porto',
      );
    });

    test('altrimenti il nome con l\'indirizzo', () {
      expect(
        lello.dove(titolo: 'Libri'),
        'Livraria Lello, Rua das Carmelitas 144, Porto',
      );
      expect(lello.dove(), 'Livraria Lello, Rua das Carmelitas 144, Porto');
    });

    test('un indirizzo è già sé stesso', () {
      const via = Luogo(
        nome: 'Rua de Cedofeita 22',
        indirizzo: 'Porto',
        posto: (lat: 41.15, lon: -8.61),
      );
      expect(via.dove(), 'Rua de Cedofeita 22, Porto');
      const solo = Luogo(nome: 'Porto', posto: (lat: 41.15, lon: -8.61));
      expect(solo.dove(), 'Porto');
    });
  });

  group('le chiamate', () {
    late List<http.Request> chieste;
    late http.Response Function(http.Request) risponde;

    MappeGeoapify mappe() => MappeGeoapify(
      chiave: 'chiave-di-prova',
      client: MockClient((r) async {
        chieste.add(r);
        return risponde(r);
      }),
    );

    setUp(() {
      chieste = [];
      risponde = (r) => http.Response(
        jsonEncode(r.url.path.contains('routing') ? strada : ricerca),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    test('la ricerca in italiano, vicino alla meta, con la chiave', () async {
      final m = mappe();
      final trovati = await m.cerca(
        ' lello ',
        vicinoA: (lat: 41.152, lon: -8.622),
      );
      expect(trovati.first.nome, 'Livraria Lello');
      final q = chieste.single.url;
      expect(q.host, 'api.geoapify.com');
      expect(q.path, '/v1/geocode/autocomplete');
      expect(q.queryParameters['text'], 'lello');
      expect(q.queryParameters['lang'], 'it');
      expect(q.queryParameters['bias'], 'proximity:-8.622,41.152');
      // Nella zona del viaggio: la vicinanza da sola pesa poco.
      expect(q.queryParameters['filter'], 'circle:-8.622,41.152,40000');
      expect(q.queryParameters['apiKey'], 'chiave-di-prova');
      expect(m.consumo.ricerche, 1);
    });

    test('se nella zona non c\'è niente, si cerca ovunque: una ricerca in '
        'più', () async {
      risponde = (r) => http.Response(
        jsonEncode(
          r.url.queryParameters.containsKey('filter')
              ? {'results': []}
              : ricerca,
        ),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
      final m = mappe();
      final trovati = await m.cerca('lello', vicinoA: (lat: 45.4, lon: 9.2));
      expect(trovati, isNotEmpty);
      expect(chieste, hasLength(2));
      expect(chieste.last.url.queryParameters.containsKey('filter'), isFalse);
      expect(m.consumo.ricerche, 2);
    });

    test('senza una zona, ovunque e una volta sola', () async {
      final m = mappe();
      await m.cerca('lello');
      expect(chieste.single.url.queryParameters.containsKey('bias'), isFalse);
    });

    test('un testo vuoto non si cerca, e non si paga', () async {
      final m = mappe();
      expect(await m.cerca('   '), isEmpty);
      expect(chieste, isEmpty);
      expect(m.consumo.nullo, isTrue);
    });

    test('il percorso a piedi, dai due capi', () async {
      final m = mappe();
      final p = await m.percorsoAPiedi(
        (lat: 41.147, lon: -8.616),
        (lat: 41.1459, lon: -8.6148),
      );
      expect(p.metri, 450);
      final q = chieste.single.url;
      expect(q.path, '/v1/routing');
      expect(q.queryParameters['waypoints'], '41.147,-8.616|41.1459,-8.6148');
      expect(q.queryParameters['mode'], 'walk');
      // Senza i dettagli le indicazioni non hanno il tipo di svolta.
      expect(q.queryParameters['details'], 'instruction_details');
      expect(q.queryParameters['lang'], 'it');
      expect(m.consumo.percorsi, 1);
    });

    test('un rifiuto del fornitore si dice, senza inventare', () async {
      risponde = (_) => http.Response('{"error":"Unauthorized"}', 401);
      final m = mappe();
      await expectLater(
        m.cerca('lello'),
        throwsA(
          isA<ErroreTrolley>().having(
            (e) => e.serveLaRete,
            'serveLaRete',
            isFalse,
          ),
        ),
      );
    });

    test('senza rete lo dice, e propone le Mappe del telefono', () async {
      final m = MappeGeoapify(
        chiave: 'k',
        client: MockClient((_) => throw const SocketException('nessuna rete')),
      );
      await expectLater(
        m.percorsoAPiedi((lat: 41, lon: -8), (lat: 41.1, lon: -8.1)),
        throwsA(
          isA<ErroreTrolley>()
              .having((e) => e.serveLaRete, 'serveLaRete', isTrue)
              .having((e) => e.messaggio, 'messaggio', contains('Mappe')),
        ),
      );
    });

    test('senza chiave il fornitore non c\'è', () {
      expect(MappeGeoapify(chiave: '').disponibili, isFalse);
      expect(const MappeAssenti().disponibili, isFalse);
    });
  });

  test('il consumo di una schermata è la differenza', () {
    const prima = ConsumoMappe(riquadri: 10, ricerche: 1);
    const dopo = ConsumoMappe(riquadri: 34, ricerche: 1, percorsi: 2);
    final fatto = dopo - prima;
    expect(fatto.proprieta, {'riquadri': 24, 'ricerche': 0, 'percorsi': 2});
    expect((prima - prima).nullo, isTrue);
  });

  group('le Mappe del telefono', () {
    test('con il posto: le indicazioni a piedi fino alle coordinate', () {
      final u = indirizzoPerLeMappe(
        nome: 'Livraria Lello',
        posto: (lat: 41.14686, lon: -8.61479),
      )!;
      expect(u.host, 'maps.apple.com');
      expect(u.queryParameters['daddr'], '41.14686,-8.61479');
      expect(u.queryParameters['dirflg'], 'w');
      expect(u.queryParameters['q'], 'Livraria Lello');
    });

    test('senza il posto: l\'indirizzo scritto', () {
      final u = indirizzoPerLeMappe(
        nome: 'Cena',
        indirizzo: 'Rua das Flores 12, Porto',
      )!;
      expect(u.queryParameters['daddr'], 'Cena, Rua das Flores 12, Porto');
    });

    test('né posto né indirizzo: non si apre niente', () {
      expect(indirizzoPerLeMappe(nome: 'Cena'), isNull);
    });

    test('su Android, Google Maps', () {
      final u = indirizzoPerLeMappe(
        nome: 'Livraria Lello',
        posto: (lat: 41.14686, lon: -8.61479),
        apple: false,
      )!;
      expect(u.host, 'www.google.com');
      expect(u.queryParameters['destination'], '41.14686,-8.61479');
      expect(u.queryParameters['travelmode'], 'walking');
    });
  });
}
