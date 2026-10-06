import 'dart:io';

import 'package:drift/drift.dart' show Value;
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

  test(
    'passare dalla versione 1 rifà la copia e lascia la coda com\'era',
    () async {
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
      final versione = await dopo
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(versione.read<int>('user_version'), 10);
    },
  );

  test('passare dalla versione 2 alla 3 aggiunge i documenti e non tocca né la '
      'copia né la coda', () async {
    final cartella = await Directory.systemTemp.createTemp('trolley');
    addTearDown(() => cartella.delete(recursive: true));
    final file = File('${cartella.path}/trolley.sqlite');

    // Un telefono con la versione 2: un viaggio nella copia, un gesto offline.
    final prima = DatabaseLocale(NativeDatabase(file));
    final adesso = DateTime.utc(2026, 10, 2, 9);
    await prima
        .into(prima.viaggi)
        .insert(
          ViaggiCompanion.insert(
            id: 'v1',
            versione: 3,
            scaricatoIl: adesso,
            stato: 'definito',
            creatoreId: 'u1',
            importato: false,
            verificato: false,
            creatoIl: adesso.toIso8601String(),
          ),
        );
    await prima
        .into(prima.codaScrittura)
        .insert(
          CodaScritturaCompanion.insert(
            id: 'op1',
            viaggioId: 'v1',
            gesto: GestoOffline.marcaTappa,
            carico: '{"tappa_id":"t1","stato":"completata"}',
            creataIl: adesso,
          ),
        );
    await prima.close();

    // Com'era la versione 2: senza la tabella dei documenti.
    final dopo = DatabaseLocale(
      NativeDatabase(
        file,
        setup: (grezzo) => grezzo
          ..execute('DROP TABLE documento')
          ..execute('DROP TABLE tasso_cambio')
          ..execute('PRAGMA user_version = 2'),
      ),
    );
    addTearDown(dopo.close);

    // Senza rete la copia deve restare: la versione 3 non la butta.
    expect((await dopo.select(dopo.viaggi).get()).single.versione, 3);
    final coda = await dopo.select(dopo.codaScrittura).get();
    expect(coda.single.carico, '{"tappa_id":"t1","stato":"completata"}');
    await dopo
        .into(dopo.documenti)
        .insert(
          DocumentiCompanion.insert(
            id: 'd1',
            viaggioId: 'v1',
            nome: 'Carta d\'imbarco',
            percorsoLocale: 'documenti/v1/d1.pdf',
            formato: 'pdf',
            sorgente: 'file',
            proprietarioId: 'u1',
            creatoIl: adesso,
          ),
        );
    expect(await dopo.select(dopo.documenti).get(), hasLength(1));
    final versione = await dopo.customSelect('PRAGMA user_version').getSingle();
    expect(versione.read<int>('user_version'), 10);
  });

  test('passare dalla versione 3 alla 4 rifà solo la copia delle spese, e '
      'lascia copia, coda e documenti com\'erano', () async {
    final cartella = await Directory.systemTemp.createTemp('trolley');
    addTearDown(() => cartella.delete(recursive: true));
    final file = File('${cartella.path}/trolley.sqlite');

    // Un telefono con la versione 3: un viaggio, una spesa registrata
    // offline, un documento.
    final prima = DatabaseLocale(NativeDatabase(file));
    final adesso = DateTime.utc(2026, 10, 3, 9);
    await prima
        .into(prima.viaggi)
        .insert(
          ViaggiCompanion.insert(
            id: 'v1',
            versione: 2,
            scaricatoIl: adesso,
            stato: 'definito',
            creatoreId: 'u1',
            importato: false,
            verificato: false,
            creatoIl: adesso.toIso8601String(),
          ),
        );
    await prima
        .into(prima.codaScrittura)
        .insert(
          CodaScritturaCompanion.insert(
            id: 's1',
            viaggioId: 'v1',
            gesto: GestoOffline.registraSpesa,
            carico: '{"id":"s1","importo":"12.40","valuta":"EUR"}',
            creataIl: adesso,
          ),
        );
    await prima
        .into(prima.documenti)
        .insert(
          DocumentiCompanion.insert(
            id: 'd1',
            viaggioId: 'v1',
            nome: 'Passaporto',
            percorsoLocale: 'documenti/v1/d1.jpg',
            formato: 'immagine',
            sorgente: 'scansione',
            proprietarioId: 'u1',
            creatoIl: adesso,
          ),
        );
    await prima.close();

    // Com'era la versione 3: la spesa senza chi e quando, e niente tassi.
    final dopo = DatabaseLocale(
      NativeDatabase(
        file,
        setup: (grezzo) => grezzo
          ..execute('DROP TABLE spesa')
          ..execute(
            'CREATE TABLE spesa (id TEXT NOT NULL PRIMARY KEY, '
            'versione INTEGER NOT NULL, eliminato_il TEXT, '
            'scaricato_il INTEGER NOT NULL, viaggio_id TEXT NOT NULL, '
            'importo TEXT NOT NULL, valuta TEXT NOT NULL, tasso_usato TEXT, '
            'tasso_al TEXT, pagante_id TEXT NOT NULL, data TEXT NOT NULL, '
            'descrizione TEXT)',
          )
          ..execute('DROP TABLE tasso_cambio')
          ..execute('PRAGMA user_version = 3'),
      ),
    );
    addTearDown(dopo.close);

    expect((await dopo.select(dopo.viaggi).get()).single.versione, 2);
    final coda = await dopo.select(dopo.codaScrittura).get();
    expect(coda.single.gesto, GestoOffline.registraSpesa);
    expect(coda.single.carico, '{"id":"s1","importo":"12.40","valuta":"EUR"}');
    expect((await dopo.select(dopo.documenti).get()).single.nome, 'Passaporto');
    final colonne = await dopo.customSelect('PRAGMA table_info(spesa)').get();
    expect(
      colonne.map((c) => c.read<String>('name')),
      containsAll(['creato_da', 'creato_il']),
    );
    expect(await dopo.select(dopo.tassiCambio).get(), isEmpty);
    final versione = await dopo.customSelect('PRAGMA user_version').getSingle();
    expect(versione.read<int>('user_version'), 10);
  });

  test('passare dalla versione 4 alla 5 rifà solo la copia delle voci, e '
      'lascia copia, coda e documenti com\'erano', () async {
    final cartella = await Directory.systemTemp.createTemp('trolley');
    addTearDown(() => cartella.delete(recursive: true));
    final file = File('${cartella.path}/trolley.sqlite');

    // Un telefono con la versione 4: un viaggio, una spesa nella coda, un
    // documento.
    final prima = DatabaseLocale(NativeDatabase(file));
    final adesso = DateTime.utc(2026, 10, 3, 18);
    await prima
        .into(prima.viaggi)
        .insert(
          ViaggiCompanion.insert(
            id: 'v1',
            versione: 2,
            scaricatoIl: adesso,
            stato: 'idea',
            creatoreId: 'u1',
            importato: false,
            verificato: false,
            creatoIl: adesso.toIso8601String(),
          ),
        );
    await prima
        .into(prima.codaScrittura)
        .insert(
          CodaScritturaCompanion.insert(
            id: 's1',
            viaggioId: 'v1',
            gesto: GestoOffline.registraSpesa,
            carico: '{"id":"s1","importo":"8.00","valuta":"EUR"}',
            creataIl: adesso,
          ),
        );
    await prima
        .into(prima.documenti)
        .insert(
          DocumentiCompanion.insert(
            id: 'd1',
            viaggioId: 'v1',
            nome: 'Passaporto',
            percorsoLocale: 'documenti/v1/d1.jpg',
            formato: 'immagine',
            sorgente: 'scansione',
            proprietarioId: 'u1',
            creatoIl: adesso,
          ),
        );
    await prima.close();

    // Com'era la versione 4: la voce senza quante, chi e quando.
    final dopo = DatabaseLocale(
      NativeDatabase(
        file,
        setup: (grezzo) => grezzo
          ..execute('DROP TABLE voce_lista')
          ..execute(
            'CREATE TABLE voce_lista (id TEXT NOT NULL PRIMARY KEY, '
            'versione INTEGER NOT NULL, eliminato_il TEXT, '
            'scaricato_il INTEGER NOT NULL, viaggio_id TEXT NOT NULL, '
            'testo TEXT NOT NULL, tipo TEXT NOT NULL, '
            'proprietario_id TEXT NOT NULL, assegnato_a TEXT, '
            'spuntata INTEGER NOT NULL)',
          )
          ..execute('PRAGMA user_version = 4'),
      ),
    );
    addTearDown(dopo.close);

    expect((await dopo.select(dopo.viaggi).get()).single.versione, 2);
    final coda = await dopo.select(dopo.codaScrittura).get();
    expect(coda.single.gesto, GestoOffline.registraSpesa);
    expect(coda.single.carico, '{"id":"s1","importo":"8.00","valuta":"EUR"}');
    expect((await dopo.select(dopo.documenti).get()).single.nome, 'Passaporto');
    final colonne = await dopo
        .customSelect('PRAGMA table_info(voce_lista)')
        .get();
    expect(
      colonne.map((c) => c.read<String>('name')),
      containsAll(['quantita', 'creato_da', 'creato_il']),
    );
    final versione = await dopo.customSelect('PRAGMA user_version').getSingle();
    expect(versione.read<int>('user_version'), 10);
  });

  test('passare dalla versione 5 alla 6 aggiunge note e configurazione, e '
      'lascia copia e coda com\'erano', () async {
    final cartella = await Directory.systemTemp.createTemp('trolley');
    addTearDown(() => cartella.delete(recursive: true));
    final file = File('${cartella.path}/trolley.sqlite');

    final prima = DatabaseLocale(NativeDatabase(file));
    final adesso = DateTime.utc(2026, 10, 3, 20);
    await prima
        .into(prima.viaggi)
        .insert(
          ViaggiCompanion.insert(
            id: 'v1',
            versione: 4,
            scaricatoIl: adesso,
            stato: 'definito',
            creatoreId: 'u1',
            importato: false,
            verificato: false,
            creatoIl: adesso.toIso8601String(),
          ),
        );
    await prima
        .into(prima.codaScrittura)
        .insert(
          CodaScritturaCompanion.insert(
            id: 'op1',
            viaggioId: 'v1',
            gesto: GestoOffline.spuntaVoce,
            carico: '{"voce_id":"x","spuntata":true}',
            creataIl: adesso,
          ),
        );
    await prima.close();

    // Com'era la versione 5: senza note né configurazione.
    final dopo = DatabaseLocale(
      NativeDatabase(
        file,
        setup: (grezzo) => grezzo
          ..execute('DROP TABLE nota')
          ..execute('DROP TABLE configurazione')
          ..execute('PRAGMA user_version = 5'),
      ),
    );
    addTearDown(dopo.close);

    expect((await dopo.select(dopo.viaggi).get()).single.versione, 4);
    expect(
      (await dopo.select(dopo.codaScrittura).get()).single.gesto,
      GestoOffline.spuntaVoce,
    );
    expect(await dopo.select(dopo.note).get(), isEmpty);
    expect(await dopo.select(dopo.configurazioni).get(), isEmpty);
    final versione = await dopo.customSelect('PRAGMA user_version').getSingle();
    expect(versione.read<int>('user_version'), 10);
  });

  test('passare dalla versione 6 alla 7 aggiunge rimborso e date delle '
      'partecipazioni, e lascia copia e coda com\'erano', () async {
    final cartella = await Directory.systemTemp.createTemp('trolley');
    addTearDown(() => cartella.delete(recursive: true));
    final file = File('${cartella.path}/trolley.sqlite');

    final prima = DatabaseLocale(NativeDatabase(file));
    final adesso = DateTime.utc(2026, 10, 4, 18);
    await prima
        .into(prima.partecipazioni)
        .insert(
          PartecipazioniCompanion.insert(
            id: 'p1',
            versione: 1,
            scaricatoIl: adesso,
            viaggioId: 'v1',
            utenteId: 'u1',
            ruolo: 'creatore',
            stato: 'attivo',
          ),
        );
    // Una spesa registrata senza rete: la riga nella copia e il gesto in coda.
    await prima
        .into(prima.spese)
        .insert(
          SpeseCompanion.insert(
            id: 's1',
            versione: 0,
            scaricatoIl: adesso,
            viaggioId: 'v1',
            importo: '12.40',
            valuta: 'EUR',
            paganteId: 'u1',
            data: '2026-10-04',
            creatoDa: 'u1',
            creatoIl: adesso.toIso8601String(),
          ),
        );
    await prima
        .into(prima.codaScrittura)
        .insert(
          CodaScritturaCompanion.insert(
            id: 's1',
            viaggioId: 'v1',
            gesto: GestoOffline.registraSpesa,
            carico: '{"id":"s1","importo":"12.40"}',
            creataIl: adesso,
          ),
        );
    await prima.close();

    // Com'era la versione 6: senza rimborso, senza le date delle
    // partecipazioni.
    final dopo = DatabaseLocale(
      NativeDatabase(
        file,
        setup: (grezzo) => grezzo
          ..execute('ALTER TABLE spesa DROP COLUMN rimborso')
          ..execute('ALTER TABLE partecipazione DROP COLUMN creato_il')
          ..execute('ALTER TABLE partecipazione DROP COLUMN modificato_il')
          ..execute('ALTER TABLE voce_lista DROP COLUMN lasciata_da')
          ..execute('PRAGMA user_version = 6'),
      ),
    );
    addTearDown(dopo.close);

    final spesa = (await dopo.select(dopo.spese).get()).single;
    expect(spesa.versione, 0);
    expect(spesa.rimborso, isFalse);
    final partecipazione =
        (await dopo.select(dopo.partecipazioni).get()).single;
    expect(partecipazione.stato, 'attivo');
    expect(partecipazione.creatoIl, isNull);
    final coda = (await dopo.select(dopo.codaScrittura).get()).single;
    expect(coda.gesto, GestoOffline.registraSpesa);
    expect(coda.carico, '{"id":"s1","importo":"12.40"}');
    final versione = await dopo.customSelect('PRAGMA user_version').getSingle();
    expect(versione.read<int>('user_version'), 10);
  });

  test('passare dalla versione 7 alla 8 aggiunge chi portava una voce, e '
      'lascia copia, coda e segni com\'erano', () async {
    final cartella = await Directory.systemTemp.createTemp('trolley');
    addTearDown(() => cartella.delete(recursive: true));
    final file = File('${cartella.path}/trolley.sqlite');

    final prima = DatabaseLocale(NativeDatabase(file));
    final adesso = DateTime.utc(2026, 10, 4, 20);
    // Una voce del viaggio spuntata senza rete: la riga nella copia e la
    // spunta in coda.
    await prima
        .into(prima.vociLista)
        .insert(
          VociListaCompanion.insert(
            id: 'x1',
            versione: 3,
            scaricatoIl: adesso,
            viaggioId: 'v1',
            testo: 'Adattatore',
            quantita: 2,
            tipo: 'viaggio',
            proprietarioId: 'u1',
            assegnatoA: const Value('u2'),
            spuntata: true,
            creatoDa: 'u1',
            creatoIl: adesso.toIso8601String(),
          ),
        );
    await prima
        .into(prima.codaScrittura)
        .insert(
          CodaScritturaCompanion.insert(
            id: 'op1',
            viaggioId: 'v1',
            gesto: GestoOffline.spuntaVoce,
            carico: '{"voce_id":"x1","spuntata":true,"testo":"Adattatore"}',
            creataIl: adesso,
          ),
        );
    await prima
        .into(prima.impostazioni)
        .insert(
          ImpostazioniCompanion.insert(chiave: 'benvenuto:v1', valore: 'si'),
        );
    await prima.close();

    // Com'era la versione 7: le voci non sapevano chi le portava prima.
    final dopo = DatabaseLocale(
      NativeDatabase(
        file,
        setup: (grezzo) => grezzo
          ..execute('ALTER TABLE voce_lista DROP COLUMN lasciata_da')
          ..execute('PRAGMA user_version = 7'),
      ),
    );
    addTearDown(dopo.close);

    final voce = (await dopo.select(dopo.vociLista).get()).single;
    expect(voce.testo, 'Adattatore');
    expect(voce.assegnatoA, 'u2');
    expect(voce.spuntata, isTrue);
    expect(voce.lasciataDa, isNull);
    final coda = (await dopo.select(dopo.codaScrittura).get()).single;
    expect(coda.gesto, GestoOffline.spuntaVoce);
    expect(coda.carico, contains('"voce_id":"x1"'));
    expect(
      (await dopo.select(dopo.impostazioni).get()).single.chiave,
      'benvenuto:v1',
    );
    final versione = await dopo.customSelect('PRAGMA user_version').getSingle();
    expect(versione.read<int>('user_version'), 10);
  });

  test('passare dalla versione 8 alla 9 aggiunge chi è stato sul posto, e '
      'lascia copia, coda, documenti e segni com\'erano', () async {
    final cartella = await Directory.systemTemp.createTemp('trolley');
    addTearDown(() => cartella.delete(recursive: true));
    final file = File('${cartella.path}/trolley.sqlite');

    final prima = DatabaseLocale(NativeDatabase(file));
    final adesso = DateTime.utc(2026, 10, 6, 9);
    // In viaggio: la partecipazione nella copia, una spesa registrata senza
    // rete in coda, un documento, e un esito «sul posto» che aspetta la rete.
    await prima
        .into(prima.partecipazioni)
        .insert(
          PartecipazioniCompanion.insert(
            id: 'p1',
            versione: 2,
            scaricatoIl: adesso,
            viaggioId: 'v1',
            utenteId: 'u1',
            ruolo: 'creatore',
            stato: 'attivo',
          ),
        );
    await prima
        .into(prima.codaScrittura)
        .insert(
          CodaScritturaCompanion.insert(
            id: 'op1',
            viaggioId: 'v1',
            gesto: GestoOffline.registraSpesa,
            carico: '{"id":"s1","importo":"12.40","valuta":"EUR"}',
            creataIl: adesso,
          ),
        );
    await prima
        .into(prima.documenti)
        .insert(
          DocumentiCompanion.insert(
            id: 'd1',
            viaggioId: 'v1',
            nome: 'Carta d\'imbarco',
            percorsoLocale: 'documenti/v1/d1.pdf',
            formato: 'pdf',
            sorgente: 'file',
            proprietarioId: 'u1',
            creatoIl: adesso,
          ),
        );
    await prima
        .into(prima.impostazioni)
        .insert(
          ImpostazioniCompanion.insert(
            chiave: 'sul_posto:v1',
            valore: adesso.toIso8601String(),
          ),
        );
    await prima.close();

    // Com'era la versione 8: le partecipazioni non sapevano chi era sul posto.
    final dopo = DatabaseLocale(
      NativeDatabase(
        file,
        setup: (grezzo) => grezzo
          ..execute('ALTER TABLE partecipazione DROP COLUMN sul_posto_il')
          ..execute('PRAGMA user_version = 8'),
      ),
    );
    addTearDown(dopo.close);

    final partecipazione =
        (await dopo.select(dopo.partecipazioni).get()).single;
    expect(partecipazione.ruolo, 'creatore');
    expect(partecipazione.sulPostoIl, isNull);
    final coda = (await dopo.select(dopo.codaScrittura).get()).single;
    expect(coda.gesto, GestoOffline.registraSpesa);
    expect(coda.carico, contains('"importo":"12.40"'));
    expect(await dopo.select(dopo.documenti).get(), hasLength(1));
    expect(
      (await dopo.select(dopo.impostazioni).get()).single.chiave,
      'sul_posto:v1',
    );
    final versione = await dopo.customSelect('PRAGMA user_version').getSingle();
    expect(versione.read<int>('user_version'), 10);
  });

  test('passare dalla versione 9 alla 10 aggiunge la verifica, la deroga e '
      'i traguardi, e lascia copia, coda e segni com\'erano', () async {
    final cartella = await Directory.systemTemp.createTemp('trolley');
    addTearDown(() => cartella.delete(recursive: true));
    final file = File('${cartella.path}/trolley.sqlite');

    final prima = DatabaseLocale(NativeDatabase(file));
    final adesso = DateTime.utc(2026, 10, 12, 20);
    // L'ultimo giorno: una tappa segnata senza rete aspetta in coda.
    await prima
        .into(prima.partecipazioni)
        .insert(
          PartecipazioniCompanion.insert(
            id: 'p1',
            versione: 2,
            scaricatoIl: adesso,
            viaggioId: 'v1',
            utenteId: 'u1',
            ruolo: 'creatore',
            stato: 'attivo',
            sulPostoIl: const Value('2026-10-10T12:00:00Z'),
          ),
        );
    await prima
        .into(prima.codaScrittura)
        .insert(
          CodaScritturaCompanion.insert(
            id: 'op1',
            viaggioId: 'v1',
            gesto: GestoOffline.marcaTappa,
            carico: '{"tappa_id":"t1","stato":"completata"}',
            creataIl: adesso,
          ),
        );
    await prima.close();

    // Com'era la versione 9: niente verifica, deroga e traguardi.
    final dopo = DatabaseLocale(
      NativeDatabase(
        file,
        setup: (grezzo) => grezzo
          ..execute('ALTER TABLE partecipazione DROP COLUMN verificato')
          ..execute('ALTER TABLE viaggio DROP COLUMN verifica_per_deroga')
          ..execute('DROP TABLE traguardo')
          ..execute('PRAGMA user_version = 9'),
      ),
    );
    addTearDown(dopo.close);

    final partecipazione =
        (await dopo.select(dopo.partecipazioni).get()).single;
    expect(partecipazione.sulPostoIl, '2026-10-10T12:00:00Z');
    expect(partecipazione.verificato, isNull);
    final coda = (await dopo.select(dopo.codaScrittura).get()).single;
    expect(coda.gesto, GestoOffline.marcaTappa);
    expect(coda.carico, contains('"tappa_id":"t1"'));
    expect(await dopo.select(dopo.traguardi).get(), isEmpty);
    final versione = await dopo.customSelect('PRAGMA user_version').getSingle();
    expect(versione.read<int>('user_version'), 10);
  });

  test('una spunta in coda sopravvive alla copia ricreata', () async {
    await db
        .into(db.codaScrittura)
        .insert(
          CodaScritturaCompanion.insert(
            id: 'op1',
            viaggioId: 'v1',
            gesto: GestoOffline.spuntaVoce,
            carico: '{"voce_id":"x","spuntata":true,"testo":"Passaporto"}',
            creataIl: DateTime.utc(2026, 10, 3),
          ),
        );
    await db.ricreaCopia();
    final coda = (await db.select(db.codaScrittura).get()).single;
    expect(coda.gesto, GestoOffline.spuntaVoce);
    expect(coda.carico, contains('"voce_id":"x"'));
  });

  test('ricreare la copia non tocca i documenti', () async {
    await db
        .into(db.documenti)
        .insert(
          DocumentiCompanion.insert(
            id: 'd1',
            viaggioId: 'v1',
            nome: 'Passaporto',
            percorsoLocale: 'documenti/v1/d1.jpg',
            formato: 'immagine',
            sorgente: 'scansione',
            proprietarioId: 'u1',
            creatoIl: DateTime.utc(2026, 10, 3),
          ),
        );
    await db.ricreaCopia();
    expect((await db.select(db.documenti).get()).single.nome, 'Passaporto');
  });

  test('le tabelle della copia sono tutte e sole quelle del server', () {
    final copia = db.tabelleCopia.map((t) => t.actualTableName).toSet();
    final soloQui = {
      'coda_scrittura',
      'documento',
      'evento_in_attesa',
      'impostazione',
    };
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
