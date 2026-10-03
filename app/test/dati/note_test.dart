import 'package:flutter_test/flutter_test.dart';
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
          inizio: '2026-10-10',
          fine: '2026-10-12',
        ),
      )
      ..partecipazioni.add(rigaPartecipazione('v'))
      ..note.add(rigaDiNota('vecchia', viaggio: 'v'));
    await ambiente.accedi();
    await ambiente.archivio.aggiornaCopia();
  });

  tearDown(() => ambiente.chiudi());

  Future<List<Nota>> note() => ambiente.archivio.osservaNote('v').first;

  test('la copia porta le note del viaggio, e si leggono senza rete', () async {
    ambiente.rete.disponibile = false;
    final [nota] = await note();
    expect(nota.id, 'vecchia');
    expect(nota.origine, 'incollata');
  });

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
    final [nota] = await note();
    await ambiente.archivio.togliNota(nota);
    expect(ambiente.server.note.single['eliminato_il'], isNotNull);
    expect(await note(), isEmpty);
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
