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
