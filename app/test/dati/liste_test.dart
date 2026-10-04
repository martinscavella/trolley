import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dati/coda.dart';
import 'package:trolley/dati/database.dart';
import 'package:trolley/dati/errori.dart';

import '../aiuti.dart';

/// Le cose da portare (05-cose-da-portare.md) nei dati: la copia, la spunta
/// senza rete con la coda, aggiungere e cambiare con la rete.
void main() {
  late Ambiente ambiente;
  late Coda coda;

  setUp(() async {
    ambiente = Ambiente();
    coda = ambiente.archivio.coda;
    // Un'idea: le liste non aspettano le date (05, regola 4).
    ambiente.server
      ..viaggi.add(rigaViaggio('v', citta: null, paese: 'JP'))
      ..partecipazioni.add(rigaPartecipazione('v'))
      ..voci.addAll([
        rigaDiVoce('passaporto', viaggio: 'v'),
        rigaDiVoce('magliette', viaggio: 'v', testo: 'Magliette', quantita: 5),
      ]);
    await ambiente.accedi();
    await ambiente.archivio.aggiornaCopia();
  });

  tearDown(() => ambiente.chiudi());

  Future<List<VoceLista>> mie() => ambiente.archivio.osservaVoci('v').first;
  Future<VoceLista> voce(String id) async =>
      (await mie()).singleWhere((v) => v.id == id);
  Future<List<OperazioneInCoda>> inCoda() =>
      ambiente.db.select(ambiente.db.codaScrittura).get();
  Map<String, Object?> sulServer(String id) =>
      ambiente.server.voci.singleWhere((v) => v['id'] == id);

  test('la copia porta le voci con quante, e si leggono anche senza rete', () async {
    ambiente.rete.disponibile = false;
    final voci = await mie();
    expect(voci.map((v) => v.testo), ['Passaporto', 'Magliette']);
    expect(voci.last.quantita, 5);
    expect(voci.every((v) => !v.spuntata), isTrue);
  });

  test('della copia si vedono la lista del viaggio e la propria, mai la '
      'personale di un altro', () async {
    // Il server non la manda; se arrivasse, non si mostrerebbe (05, regola 3).
    ambiente.server.voci.addAll([
      rigaDiVoce('sua', viaggio: 'v', proprietario: 'altro', creatoDa: 'altro'),
      rigaDiVoce(
        'comune',
        viaggio: 'v',
        tipo: 'viaggio',
        proprietario: 'altro',
        creatoDa: 'altro',
      ),
    ]);
    await ambiente.archivio.aggiornaCopia();
    expect((await mie()).map((v) => v.id), [
      'passaporto',
      'magliette',
      'comune',
    ]);
  });

  group('spuntare, anche senza rete', () {
    test('senza rete la spunta c\'è subito, e parte quando la rete torna, '
        'senza versione', () async {
      ambiente.rete.disponibile = false;
      await coda.spuntaVoce(
        voceId: 'passaporto',
        viaggioId: 'v',
        spuntata: true,
        testo: 'Passaporto',
      );

      expect((await voce('passaporto')).spuntata, isTrue);
      expect(sulServer('passaporto')['spuntata'], isFalse);
      expect((await inCoda()).single.gesto, GestoOffline.spuntaVoce);

      ambiente.rete.disponibile = true;
      await coda.svuota();

      expect(sulServer('passaporto')['spuntata'], isTrue);
      final inviata = ambiente.server.chiamate('PATCH', '/rest/v1/voce_lista');
      expect(corpoDi(inviata.single), {'spuntata': true});
      expect(await inCoda(), isEmpty);
      expect((await voce('passaporto')).versione, 2);
    });

    test('spuntata e poi tolta: arrivano in ordine, e vince l\'ultima', () async {
      ambiente.rete.disponibile = false;
      for (final spuntata in [true, false]) {
        await coda.spuntaVoce(
          voceId: 'magliette',
          viaggioId: 'v',
          spuntata: spuntata,
          testo: 'Magliette',
        );
      }
      expect((await voce('magliette')).spuntata, isFalse);

      ambiente.rete.disponibile = true;
      await coda.svuota();

      expect(sulServer('magliette')['spuntata'], isFalse);
      expect(
        ambiente.server.chiamate('PATCH', '/rest/v1/voce_lista').map(corpoDi),
        [
          {'spuntata': true},
          {'spuntata': false},
        ],
      );
    });

    test('una copia riscaricata non perde la spunta ancora in coda', () async {
      ambiente.server.percorsi['PATCH /rest/v1/voce_lista'] = (_) async =>
          risposta({'code': '42501', 'message': 'no'}, 403);
      ambiente.rete.disponibile = false;
      await coda.spuntaVoce(
        voceId: 'passaporto',
        viaggioId: 'v',
        spuntata: true,
        testo: 'Passaporto',
      );
      ambiente.rete.disponibile = true;
      await ambiente.archivio.aggiornaCopia();

      expect((await voce('passaporto')).spuntata, isTrue);
      expect((await inCoda()).single.tentativi, 1);
    });

    test('una voce tolta da un altro telefono: dopo i rifiuti la spunta va da '
        'parte, e dice quale', () async {
      ambiente.server.voci.removeWhere((v) => v['id'] == 'passaporto');
      await coda.spuntaVoce(
        voceId: 'passaporto',
        viaggioId: 'v',
        spuntata: true,
        testo: 'Passaporto',
      );
      for (var i = 0; i < Coda.tentativiMassimi; i++) {
        await coda.svuota();
      }

      final op = (await inCoda()).single;
      expect(op.messaDaParte, isTrue);
      expect(Coda.cosaNonEArrivato(op), 'La spunta di «Passaporto» non è arrivata.');
      expect(op.ultimoErrore, contains('non c\'è sul server'));
      expect(Coda.voceDi(op), 'passaporto');

      await coda.scarta(op.id);
      expect(await inCoda(), isEmpty);
    });
  });

  group('aggiungere e cambiare, con la rete', () {
    test('una voce nuova va nella lista personale, a nome di chi la scrive', () async {
      final nuova = await ambiente.archivio.aggiungiVoce(
        viaggioId: 'v',
        testo: '  Adattatore tipo A ',
        quantita: 2,
      );

      final riga = ambiente.server.voci.last;
      expect(riga['testo'], 'Adattatore tipo A');
      expect(riga['quantita'], 2);
      expect(riga['tipo'], 'personale');
      expect(riga['proprietario_id'], idDiProva);
      expect(riga['creato_da'], idDiProva);
      expect(nuova.testo, 'Adattatore tipo A');
      expect((await mie()).last.id, riga['id']);
    });

    test('senza rete non si aggiunge, e lo dice', () async {
      ambiente.rete.disponibile = false;
      await expectLater(
        ambiente.archivio.aggiungiVoce(viaggioId: 'v', testo: 'Ombrello'),
        throwsA(
          isA<ErroreTrolley>().having((e) => e.serveLaRete, 'serveLaRete', true),
        ),
      );
      expect(await mie(), hasLength(2));
    });

    test('un testo vuoto non si aggiunge', () async {
      await expectLater(
        ambiente.archivio.aggiungiVoce(viaggioId: 'v', testo: '   '),
        throwsA(isA<ErroreTrolley>()),
      );
      expect(ambiente.server.chiamate('POST', '/rest/v1/voce_lista'), isEmpty);
    });

    test('si cambia con la versione; una versione superata si rifiuta e la '
        'copia si rifà', () async {
      await ambiente.archivio.modificaVoce(await voce('magliette'), {
        'testo': 'Magliette leggere',
        'quantita': 4,
      });
      expect(sulServer('magliette')['testo'], 'Magliette leggere');
      expect((await voce('magliette')).quantita, 4);
      expect((await voce('magliette')).versione, 2);

      // Un altro telefono la cambia nel frattempo.
      final vecchia = await voce('magliette');
      sulServer('magliette')
        ..['testo'] = 'Magliette pesanti'
        ..['versione'] = 3;
      await expectLater(
        ambiente.archivio.modificaVoce(vecchia, {'testo': 'Magliette e basta'}),
        throwsA(
          isA<ErroreTrolley>().having(
            (e) => e.codice,
            'codice',
            CodiciServer.versioneSuperata,
          ),
        ),
      );
      // Non si fonde niente: si vede quella nuova, e si sceglie.
      expect(sulServer('magliette')['testo'], 'Magliette pesanti');
      expect((await voce('magliette')).testo, 'Magliette pesanti');
    });

    test('tolta, esce dalla lista ma resta marcata sul server', () async {
      await ambiente.archivio.togliVoce(await voce('passaporto'));
      expect(sulServer('passaporto')['eliminato_il'], isNotNull);
      expect((await mie()).map((v) => v.id), ['magliette']);
    });
  });
}
