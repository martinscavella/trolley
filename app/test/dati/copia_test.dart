import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dati/archivio.dart';
import 'package:trolley/dati/database.dart';
import 'package:trolley/dati/errori.dart';
import 'package:trolley/dominio/calendario.dart';
import 'package:trolley/dominio/tappe.dart';

import '../aiuti.dart';

/// La copia selettiva (02 §1, fase 3.3): i viaggi non finiti interi a ogni
/// apertura, quello che si apre da solo, i finiti quando li si apre. E la
/// preparazione prima di partire.
void main() {
  late DatabaseLocale db;
  late ReteFinta rete;
  late ServerFinto server;
  late Archivio archivio;

  final oggi = soloData(DateTime.now());
  String fra(int giorni) => scriviData(oggi.add(Duration(days: giorni)));

  setUp(() {
    db = DatabaseLocale(NativeDatabase.memory());
    rete = ReteFinta();
    server = ServerFinto(rete);
    archivio = Archivio(db, server.supabase, rete: rete);

    // Un viaggio finito il mese scorso, uno in programma, un'idea.
    for (final (id, inizio, fine) in [
      ('finito', fra(-40), fra(-38)),
      ('futuro', fra(2), fra(4)),
    ]) {
      server.viaggi.add(
        rigaViaggio(id, stato: 'definito', inizio: inizio, fine: fine),
      );
      server.giorni.add(rigaGiorno(id, inizio, '10:00:00', '24:00:00'));
      server.tappe.add(
        rigaDiTappa('t-$id', viaggio: id, giorno: 'g-$id-$inizio'),
      );
      server.spese.add(rigaDiSpesa('s-$id', viaggio: id, data: inizio));
    }
    server.viaggi.add(rigaViaggio('idea', periodo: 'agosto 2099'));
    server.voci.add(rigaDiVoce('v-idea', viaggio: 'idea'));
    for (final id in ['finito', 'futuro', 'idea']) {
      server.partecipazioni.add(rigaPartecipazione(id));
    }
    server.tassi.add(rigaTasso('USD', 1.1, fra(0)));
  });

  tearDown(() async {
    await rete.chiudi();
    await db.close();
  });

  /// I viaggi di cui si è chiesto al server il contenuto, nell'ultima
  /// richiesta delle tappe.
  String tappeChieste() => server
      .chiamate('GET', '/rest/v1/tappa')
      .last
      .url
      .queryParameters['viaggio_id']!;

  Future<List<String>> tappeNellaCopia() async => [
    for (final t in await db.select(db.tappe).get()) t.titolo,
  ];

  test('all\'apertura si riscaricano interi i viaggi non finiti; di quelli '
      'finiti, solo il biglietto', () async {
    await archivio.aggiornaCopia();

    expect(tappeChieste(), contains('futuro'));
    expect(tappeChieste(), contains('idea'));
    expect(tappeChieste(), isNot(contains('finito')));
    // L'elenco c'è tutto.
    expect(await db.select(db.viaggi).get(), hasLength(3));
    expect((await db.select(db.tappe).get()).map((t) => t.viaggioId), [
      'futuro',
    ]);
    expect(await archivio.copiaDelViaggio('futuro'), isNotNull);
    expect(await archivio.copiaDelViaggio('idea'), isNotNull);
    expect(await archivio.copiaDelViaggio('finito'), isNull);
  });

  test('aprire un viaggio finito lo scarica, e da allora resta sul telefono '
      'anche quando l\'apertura dopo non lo riscarica', () async {
    await archivio.aggiornaCopia(viaggioId: 'finito');
    expect(tappeChieste(), contains('finito'));
    expect(tappeChieste(), isNot(contains('futuro')));
    expect(await archivio.osservaTappe('finito').first, hasLength(1));
    final prima = await archivio.copiaDelViaggio('finito');
    expect(prima, isNotNull);

    // Sul server cambia, ma all'apertura dell'app non si riscarica.
    (server.tappe.firstWhere((t) => t['id'] == 't-finito'))['titolo'] =
        'Cais da Ribeira';
    await archivio.aggiornaCopia();

    expect(
      (await archivio.osservaTappe('finito').first).single.titolo,
      'Livraria Lello',
    );
    expect(await archivio.osservaSpese('finito').first, hasLength(1));
    expect(await archivio.copiaDelViaggio('finito'), prima);

    // Riaprendolo, sì.
    await archivio.aggiornaCopia(viaggioId: 'finito');
    expect(
      (await archivio.osservaTappe('finito').first).single.titolo,
      'Cais da Ribeira',
    );
  });

  test('aprire un viaggio riscarica solo quello: gli altri restano come '
      'erano', () async {
    await archivio.aggiornaCopia();
    server.tappe.add(
      rigaDiTappa(
        't-nuova',
        viaggio: 'futuro',
        giorno: 'g-futuro-${fra(2)}',
        titolo: 'Torre dos Clérigos',
        ordine: 2,
      ),
    );
    server.voci.add(rigaDiVoce('v-nuova', viaggio: 'idea', testo: 'Ombrello'));

    await archivio.aggiornaCopia(viaggioId: 'futuro');

    expect(await archivio.osservaTappe('futuro').first, hasLength(2));
    // L'idea non si è riscaricata: la voce nuova arriverà con lei.
    expect(await db.select(db.vociLista).get(), hasLength(1));
  });

  test('un viaggio che non c\'è più esce dalla copia con tutto quello che '
      'c\'era dentro, anche se era finito', () async {
    await archivio.aggiornaCopia(viaggioId: 'finito');
    server.viaggi.removeWhere((v) => v['id'] == 'finito');

    await archivio.aggiornaCopia();

    expect(await tappeNellaCopia(), ['Livraria Lello']); // quella del futuro
    expect(await archivio.osservaSpese('finito').first, isEmpty);
    expect(await archivio.copiaDelViaggio('finito'), isNull);
  });

  test('i gesti in coda di un viaggio finito ci si rimettono sopra anche se '
      'la copia non lo riscarica', () async {
    await archivio.aggiornaCopia(viaggioId: 'finito');
    rete.disponibile = false;
    await archivio.coda.segnaTappa(
      tappaId: 't-finito',
      viaggioId: 'finito',
      stato: StatoTappa.completata,
      duranteIlViaggio: false,
    );
    rete.disponibile = true;
    // Il server non risponde come dovrebbe e la coda la tiene: la copia la
    // mostra lo stesso.
    server.percorsi['PATCH /rest/v1/tappa'] = (_) async =>
        risposta({'code': 'XX000', 'message': 'riprova'}, 500);

    await archivio.aggiornaCopia();

    expect(
      (await archivio.osservaTappe('finito').first).single.stato,
      'completata',
    );
  });

  group('prepararlo per l\'uso senza rete', () {
    test('scarica tutto il viaggio e i tassi anche se sono di poco fa, e se '
        'lo ricorda', () async {
      await archivio.aggiornaCopia();
      final tassiPrima = server.chiamate('GET', '/rest/v1/tasso_cambio').length;
      expect(await archivio.osservaPreparato('futuro').first, isNull);

      await archivio.preparaViaggio('futuro');

      expect(tappeChieste(), contains('futuro'));
      expect(
        server.chiamate('GET', '/rest/v1/tasso_cambio'),
        hasLength(tassiPrima + 1),
      );
      final preparato = await archivio.osservaPreparato('futuro').first;
      expect(preparato, isNotNull);
      expect(
        DateTime.now().toUtc().difference(preparato!),
        lessThan(const Duration(minutes: 1)),
      );
    });

    test('senza rete lo dice, e il viaggio non risulta preparato', () async {
      await archivio.aggiornaCopia();
      rete.disponibile = false;

      await expectLater(
        archivio.preparaViaggio('futuro'),
        throwsA(
          isA<ErroreTrolley>().having((e) => e.serveLaRete, 'rete', isTrue),
        ),
      );
      expect(await archivio.osservaPreparato('futuro').first, isNull);
    });

    test('se i tassi non arrivano, il viaggio è preparato lo stesso', () async {
      await archivio.aggiornaCopia();
      server.percorsi['GET /rest/v1/tasso_cambio'] = (_) async =>
          risposta({'code': 'XX000', 'message': 'non ora'}, 500);

      await archivio.preparaViaggio('futuro');

      expect(await archivio.osservaPreparato('futuro').first, isNotNull);
    });
  });
}
