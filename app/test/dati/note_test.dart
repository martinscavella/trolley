import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dati/conflitti.dart';
import 'package:trolley/dati/database.dart';
import 'package:trolley/dati/errori.dart';

import '../aiuti.dart';

/// Le note del viaggio e la configurazione (fase 1.6) nei dati.
void main() {
  late Ambiente ambiente;

  setUp(() async {
    ambiente = Ambiente();
    ambiente.server
      ..viaggi.add(
        rigaViaggio(
          'v',
          stato: 'definito',
          inizio: '2036-10-10',
          fine: '2036-10-12',
        ),
      )
      ..partecipazioni.add(rigaPartecipazione('v'))
      ..partecipazioni.add(
        rigaPartecipazione('v', utente: 'marco', ruolo: 'partecipante'),
      )
      ..note.addAll([
        rigaDiNota('vecchia', viaggio: 'v'),
        rigaDiNota(
          'wifi',
          viaggio: 'v',
          origine: 'scritta',
          testo: 'Wifi\nAlfama_5G',
          creatoIl: '2026-10-03T10:00:00Z',
        ),
      ]);
    await ambiente.accedi();
    await ambiente.archivio.aggiornaCopia();
  });

  tearDown(() => ambiente.chiudi());

  Future<List<Nota>> note() => ambiente.archivio.osservaNote('v').first;
  Future<Nota> nota(String id) async =>
      (await note()).singleWhere((n) => n.id == id);
  Map<String, Object?> sulServer(String id) =>
      ambiente.server.note.singleWhere((n) => n['id'] == id);

  /// Marco cambia la nota dal suo telefono.
  void marcoCambia(String id, Map<String, Object?> valori) => sulServer(id)
    ..addAll(valori)
    ..['versione'] = (sulServer(id)['versione']! as int) + 1
    ..['modificato_da'] = 'marco'
    ..['modificato_il'] = '2036-10-04T16:42:00Z';

  Future<Conflitto> conflittoDa(Future<void> scrittura) => scrittura.then(
    (_) => fail('doveva trovare due versioni'),
    onError: (Object e) => e as Conflitto,
  );

  test('la copia porta le note del viaggio, e si leggono senza rete', () async {
    ambiente.rete.disponibile = false;
    final vecchia = await nota('vecchia');
    expect(vecchia.origine, 'incollata');
    expect((await nota('wifi')).origine, 'scritta');
  });

  test('una nota scritta a mano si salva come scritta', () async {
    await ambiente.archivio.salvaNota(
      viaggioId: 'v',
      testo: 'Treno per Sintra\n15:20 da Rossio',
    );
    expect(ambiente.server.note.last['origine'], 'scritta');
  });

  test(
    'cambiata, il testo nuovo va sul server con la versione vista',
    () async {
      await ambiente.archivio.cambiaNota(
        await nota('wifi'),
        '  Wifi\nAlfama_5G · casa-24  ',
      );
      final riga = sulServer('wifi');
      expect(riga['testo'], 'Wifi\nAlfama_5G · casa-24');
      expect(riga['versione'], 2);
      expect((await nota('wifi')).testo, 'Wifi\nAlfama_5G · casa-24');
    },
  );

  test(
    'una risposta incollata non si cambia, e una nota non si svuota',
    () async {
      await expectLater(
        ambiente.archivio.cambiaNota(await nota('vecchia'), 'Altro'),
        throwsA(isA<ErroreTrolley>()),
      );
      await expectLater(
        ambiente.archivio.cambiaNota(await nota('wifi'), '   '),
        throwsA(isA<ErroreTrolley>()),
      );
      expect(ambiente.server.chiamate('PATCH', '/rest/v1/nota'), isEmpty);
    },
  );

  test('se Marco l\'ha riscritta intanto, si mostrano le due versioni e non '
      'si fondono', () async {
    final vista = await nota('wifi');
    marcoCambia('wifi', {'testo': 'Wifi\nAlfama_5G, router dietro la tv'});

    final c = await conflittoDa(
      ambiente.archivio.cambiaNota(vista, 'Wifi\nAlfama_5G · casa-24'),
    );
    expect(c.cosa, CosaInConflitto.nota);
    expect(c.mia['testo'], 'Wifi\nAlfama_5G · casa-24');
    expect(c.loro['testo'], 'Wifi\nAlfama_5G, router dietro la tv');
    expect(c.autoreId, 'marco');
    expect(c.possonoConvivere, isTrue);
    // Finché non si sceglie, sul server resta quella di Marco, e la copia
    // la mostra.
    expect(sulServer('wifi')['testo'], 'Wifi\nAlfama_5G, router dietro la tv');
    expect((await nota('wifi')).testo, 'Wifi\nAlfama_5G, router dietro la tv');

    await ambiente.archivio.tieniLaTua(c);
    expect(sulServer('wifi')['testo'], 'Wifi\nAlfama_5G · casa-24');
  });

  test('«tienile tutte e due»: quella di Marco resta, la propria diventa una '
      'nota in più', () async {
    final vista = await nota('wifi');
    marcoCambia('wifi', {'testo': 'Wifi di Marco'});
    final c = await conflittoDa(
      ambiente.archivio.cambiaNota(vista, 'Wifi mio'),
    );

    await ambiente.archivio.tieniTutteEDue(c);
    expect(sulServer('wifi')['testo'], 'Wifi di Marco');
    final nuova = ambiente.server.note.last;
    expect(nuova['testo'], 'Wifi mio');
    expect(nuova['origine'], 'scritta');
    expect(
      (await note()).map((n) => n.testo),
      containsAll(['Wifi mio', 'Wifi di Marco']),
    );
  });

  test(
    'togliendo una nota che Marco ha appena riscritto, prima la si vede',
    () async {
      final vista = await nota('wifi');
      marcoCambia('wifi', {'testo': 'Wifi di Marco'});
      final c = await conflittoDa(ambiente.archivio.togliNota(vista));
      expect(c.laTogli, isTrue);
      expect(sulServer('wifi')['eliminato_il'], isNull);
    },
  );

  test('una risposta incollata si salva com\'è, a nome di chi la incolla, e '
      'una sola volta', () async {
    final nota = await ambiente.archivio.salvaNota(
      viaggioId: 'v',
      testo: '  Ecco il vostro itinerario!\n```\nGIORNO 1\n```  ',
      origine: 'incollata',
    );
    final riga = ambiente.server.note.last;
    expect(riga['testo'], 'Ecco il vostro itinerario!\n```\nGIORNO 1\n```');
    expect(riga['origine'], 'incollata');
    expect(riga['creato_da'], idDiProva);
    expect(nota.id, riga['id']);
    expect((await note()).map((n) => n.id), contains(nota.id));
    expect(ambiente.server.chiamate('POST', '/rest/v1/nota'), hasLength(1));
  });

  test('senza rete non si salva, e lo dice', () async {
    ambiente.rete.disponibile = false;
    await expectLater(
      ambiente.archivio.salvaNota(viaggioId: 'v', testo: 'GIORNO 1'),
      throwsA(
        isA<ErroreTrolley>().having((e) => e.serveLaRete, 'serveLaRete', true),
      ),
    );
  });

  test('un testo vuoto o sterminato non si salva', () async {
    await expectLater(
      ambiente.archivio.salvaNota(viaggioId: 'v', testo: '  '),
      throwsA(isA<ErroreTrolley>()),
    );
    await expectLater(
      ambiente.archivio.salvaNota(viaggioId: 'v', testo: 'x' * 20001),
      throwsA(isA<ErroreTrolley>()),
    );
    expect(ambiente.server.chiamate('POST', '/rest/v1/nota'), isEmpty);
  });

  test('tolta, esce dalle note ma resta marcata sul server', () async {
    await ambiente.archivio.togliNota(await nota('vecchia'));
    expect(sulServer('vecchia')['eliminato_il'], isNotNull);
    expect((await note()).map((n) => n.id), ['wifi']);
  });

  test(
    'i modelli da consigliare arrivano dal server, non dal codice',
    () async {
      expect(await ambiente.archivio.osservaModelliSuggeriti().first, [
        'Claude Sonnet 5 o superiore',
        'il modello di punta di ChatGPT',
      ]);
      // Cambiano sul server: alla prossima copia cambiano anche qui.
      ambiente.server.configurazione.single['valore'] = ['Claude Opus 5'];
      await ambiente.archivio.aggiornaCopia();
      expect(await ambiente.archivio.osservaModelliSuggeriti().first, [
        'Claude Opus 5',
      ]);
    },
  );

  test('senza configurazione non si consiglia niente', () async {
    ambiente.server.configurazione.clear();
    await ambiente.archivio.aggiornaCopia();
    expect(await ambiente.archivio.osservaModelliSuggeriti().first, isEmpty);
  });
}
