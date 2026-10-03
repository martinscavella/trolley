import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;
import 'package:trolley/dati/database.dart';
import 'package:trolley/misurazione/misurazione.dart';

void main() {
  late DatabaseLocale db;

  setUp(() => db = DatabaseLocale(NativeDatabase.memory()));
  tearDown(() => db.close());

  test(
    'ricreare la copia non tocca la coda, gli eventi e le impostazioni',
    () async {
      final adesso = DateTime.now().toUtc();
      await db
          .into(db.viaggi)
          .insert(
            ViaggiCompanion.insert(
              id: 'v1',
              versione: 1,
              scaricatoIl: adesso,
              stato: 'idea',
              creatoreId: 'u1',
              importato: false,
              verificato: false,
              creatoIl: adesso.toIso8601String(),
            ),
          );
      await db
          .into(db.codaScrittura)
          .insert(
            CodaScritturaCompanion.insert(
              id: 'op1',
              viaggioId: 'v1',
              gesto: GestoOffline.registraSpesa,
              carico: '{"importo":"12.50"}',
              creataIl: adesso,
            ),
          );
      await db
          .into(db.eventiInAttesa)
          .insert(
            EventiInAttesaCompanion.insert(
              id: 'e1',
              nome: 'viaggio_creato',
              proprieta: '{}',
              avvenutoIl: adesso,
            ),
          );
      await db
          .into(db.impostazioni)
          .insert(
            ImpostazioniCompanion.insert(
              chiave: 'misurazione_attiva',
              valore: 'no',
            ),
          );

      await db.ricreaCopia();

      expect(await db.select(db.viaggi).get(), isEmpty);
      final coda = await db.select(db.codaScrittura).get();
      expect(coda.single.id, 'op1');
      expect(coda.single.gesto, GestoOffline.registraSpesa);
      expect(coda.single.carico, '{"importo":"12.50"}');
      expect(await db.select(db.eventiInAttesa).get(), hasLength(1));
      expect(await db.select(db.impostazioni).get(), hasLength(1));
    },
  );

  test('passare dalla versione 1 alla 2 rifà la copia e lascia la coda '
      'com\'era', () async {
    final cartella = await Directory.systemTemp.createTemp('trolley');
    addTearDown(() => cartella.delete(recursive: true));
    final file = File('${cartella.path}/trolley.sqlite');

    // Un telefono che ha ancora la versione 1, con un gesto fatto offline.
    final prima = DatabaseLocale(NativeDatabase(file));
    await prima
        .into(prima.codaScrittura)
        .insert(
          CodaScritturaCompanion.insert(
            id: 'op1',
            viaggioId: 'v1',
            gesto: GestoOffline.aggiungiTappa,
            carico: '{"id":"t1","titolo":"Livraria Lello"}',
            creataIl: DateTime.utc(2026, 10, 1, 9),
          ),
        );
    await prima.close();

    // La tabella delle tappe com'era nella versione 1, e la versione 1.
    final dopo = DatabaseLocale(
      NativeDatabase(
        file,
        setup: (grezzo) => grezzo
          ..execute('DROP TABLE tappa')
          ..execute(
            'CREATE TABLE tappa (id TEXT NOT NULL PRIMARY KEY, '
            'versione INTEGER NOT NULL, eliminato_il TEXT, '
            'scaricato_il INTEGER NOT NULL, viaggio_id TEXT NOT NULL, '
            'giorno_id TEXT NOT NULL, ordine INTEGER NOT NULL, '
            'titolo TEXT NOT NULL, luogo_nome TEXT, lat REAL, lon REAL, '
            'durata_stimata_min INTEGER NOT NULL, ora_inizio TEXT, '
            'stato TEXT NOT NULL, marcata_il TEXT, '
            'marcata_durante_il_viaggio INTEGER NOT NULL, '
            'eccedente INTEGER NOT NULL)',
          )
          ..execute('PRAGMA user_version = 1'),
      ),
    );
    addTearDown(dopo.close);

    final coda = await dopo.select(dopo.codaScrittura).get();
    expect(coda.single.id, 'op1');
    expect(coda.single.gesto, GestoOffline.aggiungiTappa);
    expect(coda.single.carico, '{"id":"t1","titolo":"Livraria Lello"}');
    expect(coda.single.creataIl, DateTime.utc(2026, 10, 1, 9));
    final colonne = await dopo.customSelect('PRAGMA table_info(tappa)').get();
    expect(
      colonne.map((c) => c.read<String>('name')),
      containsAll(['tipo', 'creato_da', 'creato_il']),
    );
    final versione = await dopo.customSelect('PRAGMA user_version').getSingle();
    expect(versione.read<int>('user_version'), 2);
  });

  test('le tabelle della copia sono tutte e sole quelle del server', () {
    final copia = db.tabelleCopia.map((t) => t.actualTableName).toSet();
    final soloQui = {'coda_scrittura', 'evento_in_attesa', 'impostazione'};
    final tutte = db.allTables.map((t) => t.actualTableName).toSet();
    expect(copia.union(soloQui), tutte);
    expect(copia.intersection(soloQui), isEmpty);
  });

  group('misurazione', () {
    late Misurazione misurazione;

    setUp(() {
      misurazione = Misurazione(
        db,
        SupabaseClient('http://localhost', 'chiave-finta'),
        versioneApp: 'prova',
      );
    });

    test('registra in locale, con l\'orario del gesto', () async {
      final prima = DateTime.now().toUtc();
      await misurazione.registra(Eventi.viaggioCreato, {
        'stato_iniziale': 'idea',
      });
      final evento = (await db.select(db.eventiInAttesa).get()).single;
      expect(evento.nome, 'viaggio_creato');
      expect(evento.proprieta, '{"stato_iniziale":"idea"}');
      expect(evento.avvenutoIl.isBefore(prima), isFalse);
    });

    test(
      'se la persona rifiuta non si scrive niente, e l\'arretrato si butta',
      () async {
        await misurazione.registra(Eventi.viaggioCreato);
        await misurazione.imposta(attiva: false);
        expect(await db.select(db.eventiInAttesa).get(), isEmpty);

        await misurazione.registra(Eventi.invitoCreato);
        expect(await db.select(db.eventiInAttesa).get(), isEmpty);

        await misurazione.imposta(attiva: true);
        await misurazione.registra(Eventi.invitoCreato);
        expect(await db.select(db.eventiInAttesa).get(), hasLength(1));
      },
    );

    test('senza accesso l\'invio non fa niente e non perde eventi', () async {
      await misurazione.registra(Eventi.viaggioCreato);
      await misurazione.invia();
      expect(await db.select(db.eventiInAttesa).get(), hasLength(1));
    });
  });
}
