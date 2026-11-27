import 'dart:convert';
import 'dart:io';

import 'package:google_navigation_flutter/google_navigation_flutter.dart' as g;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trolley/aspetto/segni_mappa.dart';
import 'package:trolley/dati/errori.dart';
import 'package:trolley/dati/guida.dart';
import 'package:trolley/dati/guida_google.dart';
import 'package:trolley/dati/mappa_google.dart';
import 'package:trolley/dati/mappe.dart';
import 'package:trolley/dominio/tragitti.dart';

import '../dominio/mezzi_pubblici_test.dart' show rispostaDiGoogle;

import 'package:trolley/dati/mappe_del_telefono.dart';
import 'package:trolley/dominio/mappa.dart';

/// Il fornitore di mappe dietro la sua interfaccia (fase 3.2, ADR-006,
/// ADR-014): come si leggono le sue risposte, cosa gli si chiede, cosa si
/// conta.
void main() {
  /// Una risposta di Google `places:autocomplete`, con la maschera della
  /// funzione `mappe`.
  final ricerca = {
    'suggestions': [
      {
        'placePrediction': {
          'placeId': 'ChIJ-lello',
          'structuredFormat': {
            'mainText': {'text': 'Livraria Lello'},
            'secondaryText': {'text': 'Rua das Carmelitas 144, Porto'},
          },
          'types': ['book_store', 'point_of_interest', 'establishment'],
        },
      },
      {
        'placePrediction': {
          'placeId': 'ChIJ-cedofeita',
          'structuredFormat': {
            'mainText': {'text': 'Rua de Cedofeita 22'},
            'secondaryText': {'text': 'Porto'},
          },
          'types': ['street_address', 'geocode'],
        },
      },
      {
        'placePrediction': {
          'placeId': 'ChIJ-gaia',
          'structuredFormat': {
            'mainText': {'text': 'Vila Nova de Gaia'},
            'secondaryText': {'text': 'Portogallo'},
          },
          'types': ['locality', 'political', 'geocode'],
        },
      },
      // Una ricerca suggerita, senza posto: si scarta.
      {
        'queryPrediction': {
          'text': {'text': 'librerie a Porto'},
        },
      },
      // Lo stesso posto due volte: una basta.
      {
        'placePrediction': {
          'placeId': 'ChIJ-lello',
          'structuredFormat': {
            'mainText': {'text': 'Livraria Lello'},
          },
        },
      },
    ],
  };

  /// Una risposta di Google `places/{id}` con `id,location,formattedAddress`.
  final dettaglio = {
    'id': 'ChIJ-lello',
    'location': {'latitude': 41.14686, 'longitude': -8.61479},
    'formattedAddress': 'R. das Carmelitas 144, 4050-161 Porto, Portogallo',
  };

  group('le risposte di Google', () {
    test('i posti: il place_id, il nome, l\'indirizzo corto, che cosa '
        'sono', () {
      final luoghi = luoghiDaGoogle(ricerca);
      expect(luoghi, hasLength(3));
      final lello = luoghi[0];
      expect(lello.id, 'ChIJ-lello');
      expect(lello.nome, 'Livraria Lello');
      expect(lello.indirizzo, 'Rua das Carmelitas 144, Porto');
      expect(lello.tipo, TipoLuogo.posto);
      expect(luoghi[1].tipo, TipoLuogo.indirizzo);
      expect(luoghi[2].nome, 'Vila Nova de Gaia');
      expect(luoghi[2].tipo, TipoLuogo.zona);
    });

    test('una risposta senza suggerimenti non è un errore', () {
      expect(luoghiDaGoogle({}), isEmpty);
      expect(luoghiDaGoogle({'suggestions': []}), isEmpty);
    });

    test('il posto scelto: dove sta e l\'indirizzo', () {
      final p = postoDaGoogle(dettaglio, 'ChIJ-lello')!;
      expect(p.id, 'ChIJ-lello');
      expect(p.posto, (lat: 41.14686, lon: -8.61479));
      expect(p.indirizzo, startsWith('R. das Carmelitas 144'));
      expect(postoDaGoogle({'id': 'x'}, 'x'), isNull);
      expect(
        postoDaGoogle({
          'location': {'latitude': 200, 'longitude': 0},
        }, 'x'),
        isNull,
      );
    });
  });

  group('le chiamate, dal nostro server', () {
    late List<http.Request> chieste;
    late http.Response Function(http.Request) risponde;
    String? gettone = 'gettone-di-giulia';

    const indirizzo = 'https://progetto.supabase.co/functions/v1/mappe';

    MappeGoogle mappe() => MappeGoogle(
      indirizzo: indirizzo,
      chiavePubblica: 'sb_publishable_prova',
      accesso: () => gettone,
      client: MockClient((r) async {
        chieste.add(r);
        return risponde(r);
      }),
    );

    Map<String, dynamic> corpo(http.Request r) =>
        jsonDecode(r.body) as Map<String, dynamic>;
    Map<String, dynamic> parametri(http.Request r) =>
        corpo(r)['parametri'] as Map<String, dynamic>;

    setUp(() {
      chieste = [];
      gettone = 'gettone-di-giulia';
      risponde = (r) => http.Response(
        jsonEncode(switch (r.url.path.split('/').last) {
          'guida' => {'ok': true},
          'posto' => dettaglio,
          _ => ricerca,
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    test('la ricerca va al server, per il viaggio, con l\'accesso, la '
        'sessione e senza chiave del fornitore', () async {
      final m = mappe();
      final trovati = await m.cerca(
        ' lello ',
        viaggioId: 'porto',
        vicinoA: (lat: 41.152, lon: -8.622),
        sessione: 'sessione-1',
      );
      expect(trovati.first.nome, 'Livraria Lello');
      final r = chieste.single;
      expect(r.method, 'POST');
      expect(r.url.toString(), '$indirizzo/cerca');
      // Il testo cercato sta nel corpo: nell'indirizzo finirebbe nei registri.
      expect(r.url.query, isEmpty);
      expect(r.headers['authorization'], 'Bearer gettone-di-giulia');
      expect(r.headers['apikey'], 'sb_publishable_prova');
      expect(corpo(r)['viaggio'], 'porto');
      final q = parametri(r);
      expect(q['testo'], 'lello');
      expect(q['lingua'], 'it');
      expect(q['sessione'], 'sessione-1');
      // Vicino alla zona del viaggio, una ricerca sola.
      expect((q['lat'], q['lon'], q['raggio']), (41.152, -8.622, 40000.0));
      expect(r.body, isNot(contains('AIza')));
      expect(m.consumo.ricerche, 1);
    });

    test('senza una zona, ovunque, senza sessione se non c\'è', () async {
      final m = mappe();
      await m.cerca('lello', viaggioId: 'porto');
      final q = parametri(chieste.single);
      expect(q.containsKey('lat'), isFalse);
      expect(q.containsKey('sessione'), isFalse);
    });

    test('il posto scelto, nella stessa sessione: si conta fra i '
        'dettagli', () async {
      final m = mappe();
      final p = await m.posto(
        'ChIJ-lello',
        viaggioId: 'porto',
        sessione: 'sessione-1',
      );
      expect(p.posto, (lat: 41.14686, lon: -8.61479));
      final r = chieste.single;
      expect(r.url.toString(), '$indirizzo/posto');
      expect(parametri(r), {
        'id': 'ChIJ-lello',
        'lingua': 'it',
        'sessione': 'sessione-1',
      });
      expect((m.consumo.ricerche, m.consumo.dettagli), (0, 1));
    });

    test('un posto senza coordinate non si inventa', () async {
      risponde = (_) => http.Response('{"id":"x"}', 200);
      await expectLater(
        mappe().posto('x', viaggioId: 'porto'),
        throwsA(isA<ErroreTrolley>()),
      );
    });

    test('un testo vuoto non si cerca, e non si paga', () async {
      final m = mappe();
      expect(await m.cerca('   ', viaggioId: 'porto'), isEmpty);
      expect(chieste, isEmpty);
      expect(m.consumo.nullo, isTrue);
    });

    test('prima di guidare il server conta la destinazione: solo il '
        'viaggio, nessun posto', () async {
      final m = mappe();
      await m.guidaConsentita(viaggioId: 'porto');
      final r = chieste.single;
      expect(r.url.toString(), '$indirizzo/guida');
      expect(r.headers['authorization'], 'Bearer gettone-di-giulia');
      expect(corpo(r), {'viaggio': 'porto', 'parametri': <String, Object>{}});
      expect(m.consumo.destinazioni, 1);
    });

    test('il rinnovo delle coordinate: solo il viaggio e i giorni, e non '
        'conta sul consumo di una schermata', () async {
      risponde = (_) => http.Response(
        jsonEncode({
          'rinnovate': [
            {
              'id': 't-1',
              'place_id': 'ChIJ-lello',
              'lat': 41.1469,
              'lon': -8.6149,
              'coordinate_il': '2026-11-27T10:00:00+00:00',
            },
          ],
          'mancate': 0,
        }),
        200,
      );
      final m = mappe();
      final rinnovo = await m.rinnovaCoordinate(viaggioId: 'porto', giorni: 1);
      final r = chieste.single;
      expect(r.url.toString(), '$indirizzo/rinnova');
      expect(r.headers['authorization'], 'Bearer gettone-di-giulia');
      expect(corpo(r), {
        'viaggio': 'porto',
        'parametri': {'giorni': 1},
      });
      expect(rinnovo.rinnovate.single.tappaId, 't-1');
      expect(m.consumo.nullo, isTrue);
    });

    test('al tetto di oggi lo dice, e conta la chiamata fra le fermate, non '
        'fra quelle pagate', () async {
      risponde = (_) => http.Response('{"codice":"tetto"}', 429);
      final m = mappe();
      await expectLater(
        m.cerca('lello', viaggioId: 'porto'),
        throwsA(
          isA<ErroreTrolley>()
              .having((e) => e.codice, 'codice', CodiciServer.tettoMappe)
              .having((e) => e.messaggio, 'messaggio', contains('a mano')),
        ),
      );
      await expectLater(
        m.guidaConsentita(viaggioId: 'porto'),
        throwsA(
          isA<ErroreTrolley>()
              .having((e) => e.codice, 'codice', CodiciServer.tettoMappe)
              .having((e) => e.messaggio, 'messaggio', contains('guide')),
        ),
      );
      expect(m.consumo.fermati, 2);
      expect(m.consumo.ricerche, 0);
      expect(m.consumo.destinazioni, 0);
    });

    test(
      'un rifiuto del server o del fornitore si dice, senza inventare',
      () async {
        for (final stato in [401, 403, 502]) {
          risponde = (_) => http.Response('{"codice":"x"}', stato);
          await expectLater(
            mappe().cerca('lello', viaggioId: 'porto'),
            throwsA(
              isA<ErroreTrolley>()
                  .having((e) => e.serveLaRete, 'serveLaRete', isFalse)
                  .having((e) => e.codice, 'codice', isNull),
            ),
          );
        }
      },
    );

    test('i mezzi: dove si è va arrotondato a circa cento metri, con il '
        'posto di Google; si contano come mezzi', () async {
      risponde = (_) => http.Response(
        jsonEncode(rispostaDiGoogle()),
        200,
        headers: {'content-type': 'application/json'},
      );
      final m = mappe();
      final percorso = await m.mezzi(
        viaggioId: 'porto',
        da: (lat: 55.68049, lon: 12.58361),
        a: (lat: 55.6857, lon: 12.5773),
        placeId: 'ChIJ-rosenborg',
      );

      final r = chieste.single;
      expect(r.url.path, '/functions/v1/mappe/mezzi');
      expect(corpo(r)['viaggio'], 'porto');
      expect(parametri(r), {
        'da': {'lat': 55.68, 'lon': 12.584},
        'a': {'lat': 55.6857, 'lon': 12.5773},
        'posto': 'ChIJ-rosenborg',
        'lingua': 'it',
      });
      expect(percorso!.passi, hasLength(4));
      expect(m.consumo.mezzi, 1);
    });

    test('i mezzi, senza un percorso: niente', () async {
      risponde = (_) => http.Response('{}', 200);
      expect(
        await mappe().mezzi(
          viaggioId: 'porto',
          da: (lat: 55.68, lon: 12.58),
          a: (lat: 55.68, lon: 12.57),
        ),
        isNull,
      );
    });

    test('senza rete lo dice, e propone le Mappe del telefono', () async {
      final m = MappeGoogle(
        indirizzo: indirizzo,
        chiavePubblica: 'k',
        accesso: () => 'g',
        client: MockClient((_) => throw const SocketException('nessuna rete')),
      );
      await expectLater(
        m.guidaConsentita(viaggioId: 'porto'),
        throwsA(
          isA<ErroreTrolley>()
              .having((e) => e.serveLaRete, 'serveLaRete', isTrue)
              .having((e) => e.messaggio, 'messaggio', contains('Mappe')),
        ),
      );
    });

    test('senza accesso non si manda un gettone', () async {
      gettone = null;
      await mappe().cerca('lello', viaggioId: 'porto');
      expect(chieste.single.headers.containsKey('authorization'), isFalse);
    });

    test('senza indirizzo il fornitore non c\'è', () {
      expect(
        MappeGoogle(
          indirizzo: '',
          chiavePubblica: 'k',
          accesso: () => null,
        ).disponibili,
        isFalse,
      );
      expect(const MappeAssenti().disponibili, isFalse);
      expect(const GuidaAssente().disponibile, isFalse);
    });
  });

  test('la direzione in cui si cammina, per girare la mappa', () {
    const a = g.LatLng(latitude: 45.46, longitude: 9.19);
    expect(
      direzioneFra(a, const g.LatLng(latitude: 45.47, longitude: 9.19)),
      closeTo(0, 0.5),
    );
    expect(
      direzioneFra(a, const g.LatLng(latitude: 45.46, longitude: 9.20)),
      closeTo(90, 0.5),
    );
    expect(
      direzioneFra(a, const g.LatLng(latitude: 45.45, longitude: 9.19)),
      closeTo(180, 0.5),
    );
    expect(
      metriFra(a, const g.LatLng(latitude: 45.461, longitude: 9.19)),
      closeTo(111, 1),
    );
  });

  test('le svolte di Google diventano le nostre icone', () {
    expect(svoltaDaGoogle(g.Maneuver.turnRight), Svolta.aDestra);
    expect(svoltaDaGoogle(g.Maneuver.turnSharpLeft), Svolta.strettaASinistra);
    expect(
      svoltaDaGoogle(g.Maneuver.turnSlightRight),
      Svolta.leggermenteADestra,
    );
    expect(svoltaDaGoogle(g.Maneuver.turnKeepLeft), Svolta.tieniLaSinistra);
    expect(svoltaDaGoogle(g.Maneuver.forkRight), Svolta.tieniLaDestra);
    expect(svoltaDaGoogle(g.Maneuver.roundaboutLeftClockwise), Svolta.rotonda);
    expect(svoltaDaGoogle(g.Maneuver.turnUTurnClockwise), Svolta.inversione);
    expect(svoltaDaGoogle(g.Maneuver.destinationLeft), Svolta.arrivo);
    expect(svoltaDaGoogle(g.Maneuver.straight), Svolta.dritto);
    expect(svoltaDaGoogle(g.Maneuver.depart), Svolta.dritto);
  });

  test('le risposte della guida di Google: che cosa dire, e quando '
      'restano solo le Mappe', () {
    expect(esitoDaGoogle(g.NavigationRouteStatus.statusOk), EsitoGuida.ok);
    expect(
      esitoDaGoogle(g.NavigationRouteStatus.routeNotFound),
      EsitoGuida.nonTrovata,
    );
    expect(
      esitoDaGoogle(g.NavigationRouteStatus.quotaExceeded),
      EsitoGuida.tetto,
    );
    expect(
      esitoDaGoogle(g.NavigationRouteStatus.networkError),
      EsitoGuida.senzaRete,
    );
    expect(
      esitoDaGoogle(g.NavigationRouteStatus.locationUnavailable),
      EsitoGuida.senzaPosizione,
    );
    expect(
      esitoDaGoogle(g.NavigationRouteStatus.apiKeyNotAuthorized),
      EsitoGuida.nonDisponibile,
    );
  });

  testWidgets('il segno di una tappa diventa un\'immagine per la mappa di '
      'Google, della sua misura', (tester) async {
    final byte = await tester.runAsync(
      () => immagineDelWidget(
        SegnoSullaMappa(
          numero: 2,
          segno: SegnoTappa.prossima,
          etichetta: '2, Rosenborg',
          onTap: () {},
        ),
        latoSegno,
        3,
      ),
    );
    expect(byte, isNotNull);
    // Un PNG di 48 punti a densità 3: 144 pixel di lato.
    expect(byte!.sublist(1, 4), 'PNG'.codeUnits);
    final larghezza =
        byte[16] << 24 | byte[17] << 16 | byte[18] << 8 | byte[19];
    expect(larghezza, 144);
  });

  test('il consumo di una schermata è la differenza', () {
    const prima = ConsumoMappe(ricerche: 1, schede: 2);
    const dopo = ConsumoMappe(
      ricerche: 1,
      schede: 3,
      destinazioni: 2,
      mezzi: 1,
    );
    final fatto = dopo - prima;
    expect(fatto.proprieta, {
      'ricerche': 0,
      'dettagli': 0,
      'schede': 1,
      'destinazioni': 2,
      'mezzi': 1,
      'fermati': 0,
    });
    expect((prima - prima).nullo, isTrue);
  });

  group('le Mappe del telefono', () {
    test('con un mezzo: i mezzi pubblici, l\'auto, la bici', () {
      const posto = (lat: 41.14686, lon: -8.61479);
      Uri google(Mezzo m) => indirizzoPerLeMappe(
        nome: 'Lello',
        posto: posto,
        apple: false,
        mezzo: m,
      )!;
      expect(google(Mezzo.mezzi).queryParameters['travelmode'], 'transit');
      expect(google(Mezzo.taxi).queryParameters['travelmode'], 'driving');
      expect(
        google(Mezzo.monopattino).queryParameters['travelmode'],
        'bicycling',
      );
      final apple = indirizzoPerLeMappe(
        nome: 'Lello',
        posto: posto,
        mezzo: Mezzo.mezzi,
      )!;
      expect(apple.queryParameters['dirflg'], 'r');
    });

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
      expect(u.queryParameters.containsKey('destination_place_id'), isFalse);
    });

    test('dalla guida, Google Maps dritto al posto di Google', () {
      final u = indirizzoPerLeMappe(
        nome: 'Livraria Lello',
        posto: (lat: 41.14686, lon: -8.61479),
        placeId: 'ChIJ-lello',
        apple: false,
      )!;
      expect(u.queryParameters['destination_place_id'], 'ChIJ-lello');
    });
  });
}
