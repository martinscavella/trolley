import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dati/archivio.dart';
import 'package:trolley/dati/database.dart';
import 'package:trolley/dati/destinazioni.dart';
import 'package:trolley/dati/errori.dart';
import 'package:trolley/dati/lettura.dart';
import 'package:trolley/dominio/calendario.dart';
import 'package:trolley/dominio/giornate.dart';
import 'package:trolley/dominio/periodo.dart';

import '../aiuti.dart';

void main() {
  late DatabaseLocale db;
  late ReteFinta rete;
  late ServerFinto server;
  late Archivio archivio;

  setUp(() {
    db = DatabaseLocale(NativeDatabase.memory());
    rete = ReteFinta();
    server = ServerFinto();
    archivio = Archivio(db, server.supabase, rete: rete);
  });

  tearDown(() async {
    await rete.chiudi();
    await db.close();
  });

  group('creare un viaggio', () {
    test('con le date: i giorni li calcola l\'app, la copia prende quello che '
        'torna dal server', () async {
      final id = await archivio.creaViaggio(
        destinazione: const Destinazione(
          tipo: TipoDestinazione.citta,
          nome: 'Porto',
          paese: 'PT',
        ),
        programma: Programma(
          inizio: DateTime(2026, 10, 10),
          fine: DateTime(2026, 10, 12),
          arrivo: const Duration(hours: 10),
          partenza: const Duration(hours: 18),
        ),
      );

      final c = corpoDi(server.richieste.single);
      expect(c['p_id'], id);
      expect(c['p_destinazione_citta'], 'Porto');
      expect(c['p_destinazione_paese'], 'PT');
      expect(c['p_periodo'], isNull);
      expect(c['p_data_inizio'], '2026-10-10');
      expect(c['p_data_fine'], '2026-10-12');
      expect(c['p_ora_arrivo'], '10:00:00');
      expect(c['p_ora_partenza'], '18:00:00');
      final giorni = (c['p_giorni'] as List).cast<Map<String, dynamic>>();
      expect(giorni.map((g) => [g['data'], g['inizio'], g['fine']]), [
        ['2026-10-10', '10:00:00', '24:00:00'],
        ['2026-10-11', '00:00:00', '24:00:00'],
        ['2026-10-12', '00:00:00', '18:00:00'],
      ]);

      final viaggio = await archivio.osservaViaggio(id).first;
      expect(viaggio!.stato, 'definito');
      final nellaCopia = await archivio.osservaGiorni(id).first;
      expect(nellaCopia.map((g) => g.finestra.capienza), const [
        Duration(hours: 14),
        Duration(hours: 24),
        Duration(hours: 18),
      ]);
      expect(await archivio.osservaPartecipanti(id).first, hasLength(1));
      expect(rete.disponibile, isTrue);
    });

    test('un\'idea porta il suo periodo, e nessun giorno', () async {
      final id = await archivio.creaViaggio(
        destinazione: const Destinazione.aMano('Dolomiti', paese: 'IT'),
        periodo: const MeseDi(2027, 8),
      );

      final c = corpoDi(server.richieste.single);
      expect(c['p_destinazione_citta'], 'Dolomiti');
      expect(c['p_periodo'], 'agosto 2027');
      expect(c['p_data_inizio'], isNull);
      expect(c['p_giorni'], isEmpty);
      final idea = await archivio.osservaViaggio(id).first;
      expect(idea!.periodo, const MeseDi(2027, 8));
      expect(await archivio.osservaGiorni(id).first, isEmpty);
    });

    test('senza rete lo dice, e la rete risulta assente', () async {
      server.percorsi['POST /rest/v1/rpc/crea_viaggio'] = (_) =>
          throw const SocketException('nessuna rete');

      await expectLater(
        archivio.creaViaggio(
          destinazione: const Destinazione.aMano('Dolomiti'),
        ),
        throwsA(
          isA<ErroreTrolley>().having(
            (e) => e.serveLaRete,
            'serveLaRete',
            true,
          ),
        ),
      );
      expect(rete.disponibile, isFalse);
      expect(await db.select(db.viaggi).get(), isEmpty);
    });
  });

  group('le date di un viaggio che c\'è già', () {
    late Viaggio idea;

    setUp(() async {
      final id = await archivio.creaViaggio(
        destinazione: const Destinazione.aMano('Porto', paese: 'PT'),
        periodo: const MeseDi(2027, 8),
      );
      idea = (await archivio.osservaViaggio(id).first)!;
      server.richieste.clear();
    });

    test('fissarle manda la versione su cui si è deciso', () async {
      await archivio.programma(
        idea,
        Programma(
          inizio: DateTime(2027, 8, 1),
          fine: DateTime(2027, 8, 1),
          arrivo: const Duration(hours: 9),
          partenza: const Duration(hours: 20),
        ),
      );

      final c = corpoDi(server.richieste.single);
      expect(c['p_viaggio'], idea.id);
      expect(c['p_versione'], idea.versione);
      expect((c['p_giorni'] as List).single, containsPair('fine', '20:00:00'));
      final definito = (await archivio.osservaViaggio(idea.id).first)!;
      expect(definito.stato, 'definito');
      expect(definito.versione, idea.versione + 1);
      expect(await archivio.osservaGiorni(idea.id).first, hasLength(1));
    });

    test(
      'su una versione superata si rifiuta, e la copia si riscarica',
      () async {
        server.percorsi['POST /rest/v1/rpc/programma_viaggio'] = (_) async =>
            risposta({
              'code': 'TR409',
              'message': 'versione superata: attesa 2, ricevuta 1',
              'details': null,
              'hint': null,
            }, 400);
        server.percorsi['GET /rest/v1/viaggio'] = (_) async => risposta([
          rigaViaggio(idea.id, versione: 2, periodo: 'settembre 2027'),
        ]);

        await expectLater(
          archivio.programma(
            idea,
            Programma(
              inizio: DateTime(2027, 8, 1),
              fine: DateTime(2027, 8, 2),
              arrivo: const Duration(hours: 9),
              partenza: const Duration(hours: 20),
            ),
          ),
          throwsA(
            isA<ErroreTrolley>()
                .having(
                  (e) => e.codice,
                  'codice',
                  CodiciServer.versioneSuperata,
                )
                .having(
                  (e) => e.messaggio,
                  'messaggio',
                  contains('Qualcun altro'),
                ),
          ),
        );
        final adesso = (await archivio.osservaViaggio(idea.id).first)!;
        expect(adesso.versione, 2);
        expect(adesso.periodoApprossimativo, 'settembre 2027');
      },
    );

    test(
      'se il viaggio non è più nello stato visto, non si scrive e lo si dice',
      () async {
        // Qualcuno ha già fissato le date: l'aggiornamento non trova l'idea.
        server.percorsi['PATCH /rest/v1/viaggio'] = (_) async => risposta([]);

        await expectLater(
          archivio.cambiaPeriodo(idea, const MeseDi(2027, 9)),
          throwsA(
            isA<ErroreTrolley>().having(
              (e) => e.messaggio,
              'messaggio',
              contains('cambiato nel frattempo'),
            ),
          ),
        );
        final patch = server.richieste.firstWhere((r) => r.method == 'PATCH');
        expect(patch.url.queryParameters['stato'], 'eq.idea');
        expect(corpoDi(patch), {
          'periodo_approssimativo': 'settembre 2027',
          'versione': idea.versione,
        });
      },
    );
  });

  test('riscaricare la copia porta i giorni, e tiene a parte le idee in '
      'archivio', () async {
    server.percorsi['GET /rest/v1/viaggio'] = (_) async => risposta([
      rigaViaggio(
        'v',
        stato: 'definito',
        inizio: '2026-10-10',
        fine: '2026-10-11',
      ),
      rigaViaggio('w', stato: 'archiviato', periodo: 'agosto 2025'),
    ]);
    server.percorsi['GET /rest/v1/partecipazione'] = (_) async =>
        risposta([rigaPartecipazione('v'), rigaPartecipazione('w')]);
    server.percorsi['GET /rest/v1/giorno'] = (r) async {
      expect(r.url.queryParameters['eliminato_il'], 'is.null');
      return risposta([
        rigaGiorno('v', '2026-10-10', '10:00:00', '24:00:00'),
        rigaGiorno('v', '2026-10-11', '00:00:00', '18:00:00'),
      ]);
    };

    await archivio.aggiornaCopia();

    expect(await archivio.osservaGiorni('v').first, hasLength(2));
    final attivi = await archivio.osservaViaggiInElenco().first;
    expect(attivi.map((v) => v.viaggio.id), ['v']);
    final archiviati = await archivio
        .osservaViaggiInElenco(archiviati: true)
        .first;
    expect(archiviati.map((v) => v.viaggio.id), ['w']);
  });

  test(
    'vanno in archivio solo le idee scadute e sollecitate da due settimane',
    () async {
      final oggi = DateTime.now();
      String mese(int mesiFa) =>
          MeseDi.di(aggiungiMesi(soloData(oggi), -mesiFa)).testo;
      final creata = DateTime.now().subtract(const Duration(days: 400)).toUtc();
      await db.batch((b) {
        for (final (id, periodo) in [
          ('scaduta', mese(3)),
          ('appena', mese(2)),
          ('futura', MeseDi.di(aggiungiMesi(soloData(oggi), 3)).testo),
        ]) {
          b.insert(
            db.viaggi,
            ViaggiCompanion.insert(
              id: id,
              versione: 4,
              scaricatoIl: DateTime.now().toUtc(),
              stato: 'idea',
              periodoApprossimativo: Value(periodo),
              creatoreId: idDiProva,
              importato: false,
              verificato: false,
              creatoIl: creata.toIso8601String(),
            ),
          );
        }
      });
      Future<Viaggio> leggi(String id) async =>
          (await archivio.osservaViaggio(id).first)!;
      await archivio.segnaSollecitata(
        await leggi('scaduta'),
        oggi.subtract(const Duration(days: 20)),
      );
      await archivio.segnaSollecitata(
        await leggi('appena'),
        oggi.subtract(const Duration(days: 3)),
      );
      await archivio.segnaSollecitata(await leggi('futura'), oggi);
      server.percorsi['PATCH /rest/v1/viaggio'] = (r) async {
        expect(r.url.queryParameters['id'], 'eq.scaduta');
        expect(corpoDi(r), {'stato': 'archiviato', 'versione': 4});
        return risposta([
          rigaViaggio(
            'scaduta',
            stato: 'archiviato',
            versione: 5,
            periodo: mese(3),
          ),
        ]);
      };

      final archiviate = await archivio.archiviaIdeeScadute(oggi);

      expect(archiviate.map((v) => v.id), ['scaduta']);
      expect(server.richieste.where((r) => r.method == 'PATCH'), hasLength(1));
      expect((await leggi('scaduta')).stato, 'archiviato');
      expect((await leggi('appena')).stato, 'idea');
    },
  );

  test(
    'il sollecito vale per la scadenza: un periodo nuovo ne vuole un altro',
    () async {
      await db
          .into(db.viaggi)
          .insert(
            ViaggiCompanion.insert(
              id: 'i',
              versione: 1,
              scaricatoIl: DateTime.now().toUtc(),
              stato: 'idea',
              periodoApprossimativo: const Value('agosto 2026'),
              creatoreId: idDiProva,
              importato: false,
              verificato: false,
              creatoIl: '2026-01-01T00:00:00Z',
            ),
          );
      final idea = (await archivio.osservaViaggio('i').first)!;
      await archivio.segnaSollecitata(idea, DateTime(2026, 8, 20));
      await archivio.segnaSollecitata(idea, DateTime(2026, 8, 25));
      expect(await archivio.sollecitataIl(idea), DateTime.utc(2026, 8, 20));

      final spostata = idea.copyWith(
        periodoApprossimativo: const Value('ottobre 2026'),
      );
      expect(await archivio.sollecitataIl(spostata), isNull);
    },
  );
}
