import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dati/coda.dart';
import 'package:trolley/dati/database.dart';
import 'package:trolley/dati/errori.dart';
import 'package:trolley/dati/mappe.dart';
import 'package:trolley/dominio/calendario.dart';
import 'package:trolley/misurazione/misurazione.dart';

import '../aiuti.dart';

/// Le coordinate di Google si tengono al massimo 30 giorni (ADR-014):
/// aggiornando la copia si chiede al server di rinnovare quelle vecchie, e
/// sul telefono quelle scadute vanno via anche senza rete.
void main() {
  late Ambiente ambiente;

  final oggi = soloData(DateTime.now());
  String fra(int giorni) => scriviData(oggi.add(Duration(days: giorni)));
  String giorniFa(int giorni) =>
      DateTime.now().toUtc().subtract(Duration(days: giorni)).toIso8601String();

  setUp(() {
    ambiente = Ambiente();
    final server = ambiente.server;
    for (final (id, stato, inizio) in [
      ('copenaghen', 'definito', fra(3)),
      ('chiuso', 'chiuso', fra(-40)),
    ]) {
      server.viaggi.add(
        rigaViaggio(id, stato: stato, inizio: inizio, fine: inizio),
      );
      server.giorni.add(rigaGiorno(id, inizio, '09:00:00', '22:00:00'));
      server.partecipazioni.add(rigaPartecipazione(id));
    }
    final giorno = 'g-copenaghen-${fra(3)}';
    server.tappe.addAll([
      // Di 25 giorni: da rinnovare.
      rigaDiTappa(
        'rosenborg',
        viaggio: 'copenaghen',
        giorno: giorno,
        placeId: 'ChIJ-rosenborg',
        lat: 55.6858,
        lon: 12.5770,
        coordinateIl: giorniFa(25),
      ),
      // Di ieri.
      rigaDiTappa(
        'nyhavn',
        viaggio: 'copenaghen',
        giorno: giorno,
        ordine: 2,
        placeId: 'ChIJ-nyhavn',
        lat: 55.6798,
        lon: 12.5911,
        coordinateIl: giorniFa(1),
      ),
      // Un posto di prima, senza place_id.
      rigaDiTappa(
        'torvehallerne',
        viaggio: 'copenaghen',
        giorno: giorno,
        ordine: 3,
        luogo: 'Frederiksborggade 21',
        lat: 55.6838,
        lon: 12.5697,
      ),
    ]);
  });

  tearDown(() async {
    await ambiente.rete.chiudi();
    await ambiente.db.close();
  });

  Future<Tappa> tappa(String id) => (ambiente.db.select(
    ambiente.db.tappe,
  )..where((t) => t.id.equals(id))).getSingle();

  Future<List<Map<String, dynamic>>> eventi() async => [
    for (final e in await ambiente.db.select(ambiente.db.eventiInAttesa).get())
      if (e.nome == Eventi.coordinateRinnovate)
        jsonDecode(e.proprieta) as Map<String, dynamic>,
  ];

  test('aggiornando la copia si rinnovano le coordinate più vecchie di 20 '
      'giorni, e quelle nuove vanno nella copia', () async {
    final adesso = DateTime.now().toUtc();
    ambiente.mappe.rinnovo = (viaggioId, giorni) => RinnovoCoordinate(
      rinnovate: [
        CoordinateRinnovate(
          tappaId: 'rosenborg',
          placeId: 'ChIJ-rosenborg-2',
          posto: (lat: 55.6859, lon: 12.5771),
          il: adesso,
        ),
      ],
      mancate: 1,
    );

    await ambiente.archivio.aggiornaCopia();

    expect(ambiente.mappe.rinnovi, [(viaggioId: 'copenaghen', giorni: 20)]);
    final rosenborg = await tappa('rosenborg');
    expect(rosenborg.placeId, 'ChIJ-rosenborg-2');
    expect(rosenborg.lat, 55.6859);
    expect(rosenborg.lon, 12.5771);
    expect(DateTime.parse(rosenborg.coordinateIl!), adesso);
    // Le altre restano com'erano.
    expect((await tappa('nyhavn')).lat, 55.6798);
    expect((await tappa('torvehallerne')).luogoNome, 'Frederiksborggade 21');
    // Quante, mai quali né dove.
    expect(await eventi(), [
      {'viaggio_id': 'copenaghen', 'tappe': 1, 'mancate': 1},
    ]);
  });

  test('un posto che Google non sa dire non si richiede a ogni '
      'aggiornamento: dopo un\'ora; preparando il viaggio sì', () async {
    ambiente.mappe.rinnovo = (_, _) => const RinnovoCoordinate(mancate: 1);

    await ambiente.archivio.aggiornaCopia();
    await ambiente.archivio.aggiornaCopia(viaggioId: 'copenaghen');
    expect(ambiente.mappe.rinnovi, hasLength(1));

    await ambiente.archivio.preparaViaggio('copenaghen');
    expect(ambiente.mappe.rinnovi, hasLength(2));
    expect(await eventi(), hasLength(2));
  });

  test(
    'non si chiede niente se nessuna è vecchia, né per i viaggi chiusi',
    () async {
      ambiente.server.tappe.removeWhere((t) => t['id'] == 'rosenborg');
      ambiente.server.tappe.add(
        rigaDiTappa(
          'vecchia-chiusa',
          viaggio: 'chiuso',
          giorno: 'g-chiuso-${fra(-40)}',
          placeId: 'ChIJ-vecchia',
          lat: 1,
          lon: 1,
          coordinateIl: giorniFa(25),
        ),
      );

      await ambiente.archivio.aggiornaCopia();
      await ambiente.archivio.aggiornaCopia(viaggioId: 'chiuso');

      expect(ambiente.mappe.rinnovi, isEmpty);
      expect(await eventi(), isEmpty);
    },
  );

  test('si rinnovano anche le coordinate già tolte dal server', () async {
    ambiente.server.tappe.removeWhere((t) => t['id'] == 'rosenborg');
    ambiente.server.tappe.add(
      rigaDiTappa(
        'tivoli',
        viaggio: 'copenaghen',
        giorno: 'g-copenaghen-${fra(3)}',
        placeId: 'ChIJ-tivoli',
      ),
    );

    await ambiente.archivio.aggiornaCopia();

    expect(ambiente.mappe.rinnovi.single.viaggioId, 'copenaghen');
  });

  test('preparando il viaggio si rinnovano tutte, tranne quelle di oggi: '
      'durano per tutto il viaggio', () async {
    await ambiente.archivio.preparaViaggio('copenaghen');

    expect(ambiente.mappe.rinnovi.last, (viaggioId: 'copenaghen', giorni: 1));
  });

  test(
    'se il rinnovo non riesce la copia c\'è lo stesso, e non si conta',
    () async {
      ambiente.mappe.rinnovo = (_, _) =>
          throw const ErroreTrolley('Serve la connessione', serveLaRete: true);

      await ambiente.archivio.aggiornaCopia();

      expect((await tappa('rosenborg')).lat, 55.6858);
      expect(await eventi(), isEmpty);
    },
  );

  test(
    'sul telefono le coordinate di Google di più di 30 giorni vanno via '
    'anche senza rete; il posto resta, e i posti di prima non si toccano',
    () async {
      await ambiente.archivio.aggiornaCopia();
      // Il viaggio chiuso, aperto 40 giorni fa: la copia non lo riscarica.
      await ambiente.db
          .into(ambiente.db.tappe)
          .insert(
            rigaTappa(
              rigaDiTappa(
                'vecchia',
                viaggio: 'chiuso',
                giorno: 'g-chiuso-${fra(-40)}',
                placeId: 'ChIJ-vecchia',
                lat: 1,
                lon: 2,
                coordinateIl: giorniFa(31),
              ),
              DateTime.now(),
            ),
          );
      ambiente.rete.disponibile = false;

      await ambiente.archivio.scadiCoordinate();

      final vecchia = await tappa('vecchia');
      expect(vecchia.placeId, 'ChIJ-vecchia');
      expect(vecchia.lat, isNull);
      expect(vecchia.lon, isNull);
      expect(vecchia.coordinateIl, isNull);
      expect((await tappa('rosenborg')).lat, 55.6858);
      expect((await tappa('torvehallerne')).lat, 55.6838);
    },
  );

  test('la risposta del server: si prende solo quello che si legge', () {
    final rinnovo = rinnovoDaServer({
      'rinnovate': [
        {
          'id': 'rosenborg',
          'place_id': 'ChIJ-rosenborg',
          'lat': 55,
          'lon': 12.5,
          'coordinate_il': '2026-11-27T10:00:00+00:00',
        },
        {'id': 'senza-posto', 'place_id': 'x', 'lat': null, 'lon': 1},
        {
          'id': 'fuori',
          'place_id': 'x',
          'lat': 200,
          'lon': 1,
          'coordinate_il': '2026-11-27T10:00:00+00:00',
        },
      ],
      'mancate': 2,
    });
    expect(rinnovo.rinnovate.single.tappaId, 'rosenborg');
    expect(rinnovo.rinnovate.single.posto, (lat: 55.0, lon: 12.5));
    expect(rinnovo.rinnovate.single.il, DateTime.utc(2026, 11, 27, 10));
    expect(rinnovo.mancate, 2);
    expect(rinnovoDaServer({}).rinnovate, isEmpty);
    expect(rinnovoDaServer({'mancate': -1}).mancate, 0);
  });
}
