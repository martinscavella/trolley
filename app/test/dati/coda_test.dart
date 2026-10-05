import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dati/coda.dart';
import 'package:trolley/dati/database.dart';
import 'package:trolley/dati/errori.dart';
import 'package:trolley/dominio/tappe.dart';

import '../aiuti.dart';

/// La coda dei gesti senza rete (02-sincronizzazione-e-offline.md §2), con le
/// tappe: aggiungere e segnare.
void main() {
  late Ambiente ambiente;
  late Coda coda;

  setUp(() async {
    ambiente = Ambiente();
    coda = ambiente.archivio.coda;
    ambiente.server
      ..viaggi.add(
        rigaViaggio(
          'v',
          stato: 'definito',
          inizio: '2026-10-10',
          fine: '2026-10-12',
        ),
      )
      ..partecipazioni.add(rigaPartecipazione('v'))
      ..giorni.add(
        rigaGiorno('v', '2026-10-11', '00:00:00', '24:00:00', id: 'g1'),
      );
    await ambiente.archivio.aggiornaCopia();
  });

  tearDown(() => ambiente.chiudi());

  NuovaTappa nuova(
    String id, {
    String viaggio = 'v',
    String giorno = 'g1',
    int minuti = 90,
  }) => NuovaTappa(
    id: id,
    viaggioId: viaggio,
    giornoId: giorno,
    ordine: 1,
    titolo: 'Tappa $id',
    tipo: TipoTappa.visita,
    durata: Duration(minutes: minuti),
  );

  Future<List<Tappa>> copia() => ambiente.db.select(ambiente.db.tappe).get();
  Future<List<OperazioneInCoda>> inCoda() =>
      ambiente.db.select(ambiente.db.codaScrittura).get();
  List<String> sulServer() => [
    for (final t in ambiente.server.tappe) t['id']! as String,
  ];

  test(
    'senza rete la tappa c\'è subito, e parte quando la rete torna',
    () async {
      ambiente.rete.disponibile = false;
      await coda.aggiungiTappa(nuova('t1'));

      final locale = (await copia()).single;
      expect(locale.titolo, 'Tappa t1');
      expect(locale.stato, 'da_fare');
      expect(await inCoda(), hasLength(1));
      expect(ambiente.server.tappe, isEmpty);

      ambiente.rete.disponibile = true;
      await coda.svuota();

      expect(sulServer(), ['t1']);
      expect(ambiente.server.tappe.single['eccedente'], isFalse);
      expect(await inCoda(), isEmpty);
      expect((await copia()).single.versione, 1);
    },
  );

  test('con il posto trovato, le coordinate viaggiano con la tappa: nella '
      'copia subito, sul server quando torna la rete (fase 3.2)', () async {
    ambiente.rete.disponibile = false;
    await coda.aggiungiTappa(
      NuovaTappa(
        id: 't1',
        viaggioId: 'v',
        giornoId: 'g1',
        ordine: 1,
        titolo: 'Livraria Lello',
        tipo: TipoTappa.visita,
        durata: const Duration(minutes: 60),
        luogo: 'Rua das Carmelitas 144, Porto',
        posto: (lat: 41.14686, lon: -8.61479),
      ),
    );
    final locale = (await copia()).single;
    expect((locale.lat, locale.lon), (41.14686, -8.61479));

    ambiente.rete.disponibile = true;
    await coda.svuota();
    final arrivata = ambiente.server.tappe.single;
    expect(arrivata['luogo_nome'], 'Rua das Carmelitas 144, Porto');
    expect((arrivata['lat'], arrivata['lon']), (41.14686, -8.61479));
    expect((await copia()).single.lat, 41.14686);
  });

  test('una tappa messa in coda prima della 3.2, senza coordinate, parte lo '
      'stesso', () async {
    ambiente.rete.disponibile = false;
    await coda.aggiungiTappa(nuova('t1'));
    expect((await copia()).single.lat, isNull);
    ambiente.rete.disponibile = true;
    await coda.svuota();
    expect(ambiente.server.tappe.single['lat'], isNull);
  });

  test('rimandata, non si aggiunge due volte', () async {
    ambiente.rete.disponibile = false;
    await coda.aggiungiTappa(nuova('t1'));
    // La prima volta è arrivata, ma la risposta si è persa per strada.
    ambiente.server.tappe.add(
      rigaDiTappa('t1', viaggio: 'v', giorno: 'g1', titolo: 'Tappa t1'),
    );

    ambiente.rete.disponibile = true;
    await coda.svuota();

    expect(sulServer(), ['t1']);
    expect(await inCoda(), isEmpty);
  });

  test(
    'al momento dell\'invio la capienza si ricontrolla: se intanto la '
    'giornata si è riempita, la tappa entra segnalata come eccedente',
    () async {
      ambiente.server.giorni.add(
        rigaGiorno('v', '2026-10-12', '00:00:00', '02:00:00', id: 'g2'),
      );
      await ambiente.archivio.aggiornaCopia();

      ambiente.rete.disponibile = false;
      await coda.aggiungiTappa(nuova('t1', giorno: 'g2', minuti: 60));
      // Nel frattempo qualcun altro ci mette un'ora e mezza.
      ambiente.server.tappe.add(
        rigaDiTappa('altra', viaggio: 'v', giorno: 'g2', durata: 90),
      );

      ambiente.rete.disponibile = true;
      await coda.svuota();

      final arrivata = ambiente.server.tappe.firstWhere((t) => t['id'] == 't1');
      expect(arrivata['eccedente'], isTrue);
      expect((await copia()).firstWhere((t) => t.id == 't1').eccedente, isTrue);
    },
  );

  test('aggiungere e poi segnare arrivano in quest\'ordine', () async {
    ambiente.rete.disponibile = false;
    await coda.aggiungiTappa(nuova('t1'));
    await coda.segnaTappa(
      tappaId: 't1',
      viaggioId: 'v',
      stato: StatoTappa.completata,
      duranteIlViaggio: true,
    );
    expect((await copia()).single.stato, 'completata');

    ambiente.rete.disponibile = true;
    await coda.svuota();

    final tappa = ambiente.server.tappe.single;
    expect(tappa['stato'], 'completata');
    expect(tappa['marcata_durante_il_viaggio'], isTrue);
    expect(tappa['marcata_il'], isNotNull);
    expect(
      [
        for (final r in ambiente.server.richieste)
          if (r.url.path == '/rest/v1/tappa' && r.method != 'GET') r.method,
      ],
      ['POST', 'PATCH'],
    );
  });

  test('riportata da fare, perde il segno', () async {
    ambiente.server.tappe.add(
      rigaDiTappa('t1', viaggio: 'v', giorno: 'g1', stato: 'completata'),
    );
    await ambiente.archivio.aggiornaCopia();

    await coda.segnaTappa(
      tappaId: 't1',
      viaggioId: 'v',
      stato: StatoTappa.daFare,
      duranteIlViaggio: true,
    );
    await coda.svuota();

    final tappa = ambiente.server.tappe.single;
    expect(tappa['stato'], 'da_fare');
    expect(tappa['marcata_il'], isNull);
    expect(tappa['marcata_durante_il_viaggio'], isFalse);
  });

  test('un rifiuto del server ferma solo quello che viene dopo nello stesso '
      'viaggio; al terzo si mette da parte e la coda va avanti', () async {
    ambiente.server
      ..viaggi.add(
        rigaViaggio(
          'w',
          stato: 'definito',
          inizio: '2026-11-01',
          fine: '2026-11-01',
        ),
      )
      ..giorni.add(
        rigaGiorno('w', '2026-11-01', '09:00:00', '20:00:00', id: 'gw'),
      );
    await ambiente.archivio.aggiornaCopia();

    ambiente.rete.disponibile = false;
    // Un segno su una tappa che sul server non c'è: lo rifiuterà.
    await coda.segnaTappa(
      tappaId: 'sparita',
      viaggioId: 'v',
      stato: StatoTappa.completata,
      duranteIlViaggio: true,
    );
    await coda.aggiungiTappa(nuova('t1'));
    await coda.aggiungiTappa(nuova('t2', viaggio: 'w', giorno: 'gw'));

    ambiente.rete.disponibile = true;
    await coda.svuota();

    // L'altro viaggio non aspetta; nello stesso viaggio, quello dietro sì.
    expect(sulServer(), ['t2']);
    var segno = (await inCoda()).firstWhere((o) => o.id != 't1');
    expect(segno.tentativi, 1);
    expect(segno.messaDaParte, isFalse);
    expect(segno.ultimoErrore, contains('non c\'è sul server'));

    await coda.svuota();
    await coda.svuota();

    segno = (await inCoda()).single;
    expect(segno.messaDaParte, isTrue);
    expect(segno.tentativi, Coda.tentativiMassimi);
    expect(sulServer(), containsAll(['t1', 't2']));
  });

  test('la copia riscaricata tiene quello che è ancora in coda', () async {
    ambiente.server.percorsi['POST /rest/v1/tappa'] = (_) async => risposta({
      'code': 'XX000',
      'message': 'guasto',
      'details': null,
      'hint': null,
    }, 500);

    await coda.aggiungiTappa(nuova('t1'));
    await ambiente.archivio.aggiornaCopia();

    expect((await copia()).single.id, 't1');
    expect((await inCoda()).single.tentativi, greaterThan(0));
  });

  test('messa da parte, si può scartare: una tappa mai arrivata esce anche '
      'dalla copia', () async {
    ambiente.server.percorsi['POST /rest/v1/tappa'] = (_) async => risposta({
      'code': '42501',
      'message': 'new row violates row-level security policy',
      'details': null,
      'hint': null,
    }, 403);
    ambiente.rete.disponibile = false;
    await coda.aggiungiTappa(nuova('t1'));
    ambiente.rete.disponibile = true;
    for (var i = 0; i < Coda.tentativiMassimi; i++) {
      await coda.svuota();
    }
    final op = (await inCoda()).single;
    expect(op.messaDaParte, isTrue);
    expect(op.ultimoErrore, contains('non fai più parte'));
    expect(Coda.titoloDi(op), 'Tappa t1');

    await coda.scarta(op.id);

    expect(await inCoda(), isEmpty);
    expect(await copia(), isEmpty);
  });

  test('messa da parte, si può riprovare', () async {
    ambiente.server.percorsi['POST /rest/v1/tappa'] = (_) async => risposta({
      'code': 'XX000',
      'message': 'guasto',
      'details': null,
      'hint': null,
    }, 500);
    ambiente.rete.disponibile = false;
    await coda.aggiungiTappa(nuova('t1'));
    ambiente.rete.disponibile = true;
    for (var i = 0; i < Coda.tentativiMassimi; i++) {
      await coda.svuota();
    }
    expect((await inCoda()).single.messaDaParte, isTrue);

    ambiente.server.percorsi.remove('POST /rest/v1/tappa');
    await coda.riprova('t1');

    expect(await inCoda(), isEmpty);
    expect(sulServer(), ['t1']);
  });

  group('le scritture che richiedono la rete', () {
    setUp(() async {
      ambiente.server.tappe.addAll([
        rigaDiTappa('a', viaggio: 'v', giorno: 'g1', ordine: 1, titolo: 'A'),
        rigaDiTappa('b', viaggio: 'v', giorno: 'g1', ordine: 2, titolo: 'B'),
      ]);
      await ambiente.archivio.aggiornaCopia();
    });

    Future<Tappa> tappa(String id) => (ambiente.db.select(
      ambiente.db.tappe,
    )..where((t) => t.id.equals(id))).getSingle();

    test('si cambia una tappa con la versione su cui si è deciso', () async {
      await ambiente.archivio.modificaTappa(await tappa('a'), {
        'titolo': 'A, ma più tardi',
        'durata_stimata_min': 120,
      });
      final cambiata = await tappa('a');
      expect(cambiata.titolo, 'A, ma più tardi');
      expect(cambiata.durataStimataMin, 120);
      expect(cambiata.versione, 2);
    });

    test('se qualcuno l\'ha cambiata nel frattempo si rifiuta, e si vede '
        'com\'è adesso', () async {
      final vista = await tappa('a');
      ambiente.server.tappe.first
        ..['titolo'] = 'Cambiata da Marco'
        ..['versione'] = 2;

      await expectLater(
        ambiente.archivio.modificaTappa(vista, {'titolo': 'La mia'}),
        throwsA(
          isA<ErroreTrolley>().having(
            (e) => e.codice,
            'codice',
            CodiciServer.versioneSuperata,
          ),
        ),
      );
      expect((await tappa('a')).titolo, 'Cambiata da Marco');
    });

    test(
      'togliere una tappa la marca sul server e la toglie dalla copia',
      () async {
        await ambiente.archivio.togliTappa(await tappa('a'));
        expect(ambiente.server.tappe.first['eliminato_il'], isNotNull);
        expect((await copia()).map((t) => t.id), ['b']);
      },
    );

    test('si riordina una giornata in una scrittura sola', () async {
      await ambiente.archivio.ordinaTappe('g1', ['b', 'a']);
      expect((await tappa('b')).ordine, 1);
      expect((await tappa('a')).ordine, 2);
    });

    test('spostata in un altro giorno, va in fondo', () async {
      ambiente.server.giorni.add(
        rigaGiorno('v', '2026-10-12', '00:00:00', '18:00:00', id: 'g2'),
      );
      ambiente.server.tappe.add(
        rigaDiTappa('c', viaggio: 'v', giorno: 'g2', ordine: 1, titolo: 'C'),
      );
      await ambiente.archivio.aggiornaCopia();

      await ambiente.archivio.spostaTappa(await tappa('a'), giornoId: 'g2');

      final spostata = await tappa('a');
      expect(spostata.giornoId, 'g2');
      expect(spostata.ordine, 2);
    });

    test('le tappe di un giorno uscito dalle date restano nella copia, da '
        'ricollocare', () async {
      ambiente.server.giorni.first['eliminato_il'] = '2026-10-01T10:00:00Z';
      await ambiente.archivio.aggiornaCopia();
      expect(await ambiente.db.select(ambiente.db.giorni).get(), isEmpty);
      expect((await copia()).map((t) => t.id), containsAll(['a', 'b']));
    });
  });
}
