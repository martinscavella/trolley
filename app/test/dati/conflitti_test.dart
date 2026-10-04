import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dati/conflitti.dart';
import 'package:trolley/dati/database.dart';
import 'package:trolley/dati/errori.dart';
import 'package:trolley/dominio/conflitti.dart';

import '../aiuti.dart';

/// Due persone online cambiano la stessa cosa (02 §3): quando si riscrive
/// senza chiedere, quando si mostrano le due versioni, e cosa fa ogni scelta.
void main() {
  late Ambiente ambiente;
  const marco = 'marco';

  setUp(() async {
    ambiente = Ambiente();
    ambiente.server
      ..viaggi.add(
        rigaViaggio(
          'v',
          stato: 'definito',
          inizio: '2026-10-10',
          fine: '2026-10-11',
        ),
      )
      ..partecipazioni.addAll([
        rigaPartecipazione('v'),
        rigaPartecipazione('v', utente: marco, ruolo: 'partecipante'),
      ])
      ..giorni.addAll([
        rigaGiorno('v', '2026-10-10', '10:00:00', '24:00:00', id: 'g1'),
        rigaGiorno('v', '2026-10-11', '00:00:00', '18:00:00', id: 'g2'),
      ])
      ..tappe.addAll([
        rigaDiTappa(
          't',
          viaggio: 'v',
          giorno: 'g1',
          titolo: 'Torre',
          durata: 60,
        ),
        rigaDiTappa(
          'c',
          viaggio: 'v',
          giorno: 'g2',
          titolo: 'Cais',
          durata: 60,
        ),
      ])
      ..voci.add(rigaDiVoce('a', viaggio: 'v', testo: 'Adattatore'));
    await ambiente.accedi();
    await ambiente.archivio.aggiornaCopia();
  });

  tearDown(() => ambiente.chiudi());

  Future<Tappa?> tappa(String id) => (ambiente.db.select(
    ambiente.db.tappe,
  )..where((t) => t.id.equals(id))).getSingleOrNull();
  Map<String, Object?> sulServer(String id) =>
      ambiente.server.tappe.singleWhere((t) => t['id'] == id);

  /// Marco cambia la tappa dal suo telefono.
  void marcoCambia(String id, Map<String, Object?> valori) => sulServer(id)
    ..addAll(valori)
    ..['versione'] = (sulServer(id)['versione']! as int) + 1
    ..['modificato_da'] = marco
    ..['modificato_il'] = '2026-10-04T16:42:00Z';

  Future<Conflitto> conflittoDa(Future<void> scrittura) => scrittura.then(
    (_) => fail('doveva trovare due versioni'),
    onError: (Object e) => e as Conflitto,
  );

  test('se Marco ha solo segnato la tappa, si cambia senza chiedere niente, '
      'e il segno resta', () async {
    final vista = (await tappa('t'))!;
    marcoCambia('t', {'stato': 'completata'});

    await ambiente.archivio.modificaTappa(vista, {
      'titolo': 'Torre dos Clérigos',
    });

    expect(sulServer('t')['titolo'], 'Torre dos Clérigos');
    expect(sulServer('t')['stato'], 'completata');
    expect((await tappa('t'))!.versione, 3);
  });

  test('se Marco ha scritto proprio quello che si voleva, è fatta', () async {
    final vista = (await tappa('t'))!;
    marcoCambia('t', {'durata_stimata_min': 90});

    await ambiente.archivio.modificaTappa(vista, {'durata_stimata_min': 90});

    expect(ambiente.server.chiamate('PATCH', '/rest/v1/tappa'), hasLength(1));
    expect((await tappa('t'))!.versione, 2);
  });

  group('due versioni di una tappa', () {
    test('si sa cosa cambia, chi ha scritto l\'altra e quando, e la copia '
        'ha la sua', () async {
      final vista = (await tappa('t'))!;
      marcoCambia('t', {'ora_inizio': '12:00:00', 'durata_stimata_min': 60});

      final c = await conflittoDa(
        ambiente.archivio.modificaTappa(vista, {
          'ora_inizio': '11:30:00',
          'durata_stimata_min': 90,
        }),
      );

      expect(c.cosa, CosaInConflitto.tappa);
      expect(c.viaggioId, 'v');
      expect(c.autoreId, marco);
      expect(c.salvataIl, DateTime.utc(2026, 10, 4, 16, 42));
      expect(c.diversi, {'ora_inizio', 'durata_stimata_min'});
      expect(c.mia['ora_inizio'], '11:30:00');
      expect(c.loro['ora_inizio'], '12:00:00');
      expect(c.possonoConvivere, isFalse);
      expect((await tappa('t'))!.oraInizio, '12:00:00');
    });

    test('«Tieni la tua» la rende esattamente come la propria: anche quello '
        'che aveva cambiato solo Marco', () async {
      final vista = (await tappa('t'))!;
      marcoCambia('t', {'ora_inizio': '12:00:00'});
      final c = await conflittoDa(
        ambiente.archivio.modificaTappa(vista, {
          'titolo': 'Torre dos Clérigos',
        }),
      );

      await ambiente.archivio.tieniLaTua(c);

      expect(sulServer('t')['titolo'], 'Torre dos Clérigos');
      expect(sulServer('t')['ora_inizio'], isNull);
      final ultima = ambiente.server.chiamate('PATCH', '/rest/v1/tappa').last;
      expect(corpoDi(ultima)['versione'], 2);
      expect((await tappa('t'))!.titolo, 'Torre dos Clérigos');
    });

    test('se intanto è cambiata ancora, «Tieni la tua» trova due versioni '
        'nuove', () async {
      final vista = (await tappa('t'))!;
      marcoCambia('t', {'titolo': 'Torre'});
      marcoCambia('t', {'durata_stimata_min': 30});
      final c = await conflittoDa(
        ambiente.archivio.modificaTappa(vista, {'durata_stimata_min': 90}),
      );
      marcoCambia('t', {'durata_stimata_min': 45});

      final ancora = await conflittoDa(ambiente.archivio.tieniLaTua(c));
      expect(ancora.loro['durata_stimata_min'], 45);
      expect(ancora.versioneLoro, 4);
    });

    test('spostata in un altro giorno, tenendo la propria va in fondo a quel '
        'giorno', () async {
      final vista = (await tappa('t'))!;
      marcoCambia('t', {'durata_stimata_min': 30});
      final c = await conflittoDa(
        ambiente.archivio.spostaTappa(vista, giornoId: 'g2'),
      );

      await ambiente.archivio.tieniLaTua(c);

      expect(sulServer('t')['giorno_id'], 'g2');
      expect(sulServer('t')['ordine'], 2);
      expect(sulServer('t')['durata_stimata_min'], 60);
    });
  });

  group('una cosa tolta', () {
    test('Marco l\'ha tolta mentre la si cambiava: si può rimetterla con la '
        'propria versione', () async {
      final vista = (await tappa('t'))!;
      marcoCambia('t', {'eliminato_il': '2026-10-04T16:42:00Z'});

      final c = await conflittoDa(
        ambiente.archivio.modificaTappa(vista, {
          'titolo': 'Torre dos Clérigos',
        }),
      );
      expect(c.tolta, isTrue);
      expect(c.laTogli, isFalse);
      expect(await tappa('t'), isNull);

      await ambiente.archivio.tieniLaTua(c);
      expect(sulServer('t')['eliminato_il'], isNull);
      expect((await tappa('t'))!.titolo, 'Torre dos Clérigos');
    });

    test('togliendola, se Marco l\'aveva cambiata si guarda prima; «Tieni la '
        'tua» la toglie', () async {
      final vista = (await tappa('t'))!;
      marcoCambia('t', {'titolo': 'Torre e chiesa'});

      final c = await conflittoDa(ambiente.archivio.togliTappa(vista));
      expect(c.laTogli, isTrue);
      expect(c.loro['titolo'], 'Torre e chiesa');
      expect((await tappa('t'))!.titolo, 'Torre e chiesa');

      await ambiente.archivio.tieniLaTua(c);
      expect(sulServer('t')['eliminato_il'], isNotNull);
      expect(await tappa('t'), isNull);
    });

    test(
      'togliendola, se Marco l\'aveva solo segnata si toglie e basta',
      () async {
        final vista = (await tappa('t'))!;
        marcoCambia('t', {'stato': 'saltata'});
        await ambiente.archivio.togliTappa(vista);
        expect(sulServer('t')['eliminato_il'], isNotNull);
      },
    );
  });

  group('due versioni di una voce', () {
    Map<String, Object?> voceSulServer() => ambiente.server.voci.single;

    test(
      'si possono tenere tutte e due: la propria diventa una voce nuova',
      () async {
        final vista = (await ambiente.archivio.osservaVoci('v').first).single;
        voceSulServer()
          ..['testo'] = 'Adattatore tipo A'
          ..['quantita'] = 2
          ..['versione'] = 2;

        final c = await conflittoDa(
          ambiente.archivio.modificaVoce(vista, {
            'testo': 'Adattatore universale',
          }),
        );
        expect(c.possonoConvivere, isTrue);

        await ambiente.archivio.tieniTutteEDue(c);
        final voci = await ambiente.archivio.osservaVoci('v').first;
        expect(
          voci.map((v) => (v.testo, v.quantita)),
          unorderedEquals([
            ('Adattatore tipo A', 2),
            ('Adattatore universale', 1),
          ]),
        );
      },
    );

    test('una tappa non si tiene doppia', () async {
      final vista = (await tappa('t'))!;
      marcoCambia('t', {'titolo': 'Torre e chiesa'});
      final c = await conflittoDa(
        ambiente.archivio.modificaTappa(vista, {
          'titolo': 'Torre dos Clérigos',
        }),
      );
      await expectLater(
        ambiente.archivio.tieniTutteEDue(c),
        throwsA(isA<ErroreTrolley>()),
      );
    });
  });

  test('senza rete la scelta non parte, e lo dice', () async {
    final vista = (await tappa('t'))!;
    marcoCambia('t', {'titolo': 'Torre e chiesa'});
    final c = await conflittoDa(
      ambiente.archivio.modificaTappa(vista, {'titolo': 'Torre dos Clérigos'}),
    );
    ambiente.rete.disponibile = false;
    await expectLater(
      ambiente.archivio.tieniLaTua(c),
      throwsA(isA<ErroreTrolley>().having((e) => e.serveLaRete, 'rete', true)),
    );
    expect(eliminato(c.loro), isFalse);
  });
}
