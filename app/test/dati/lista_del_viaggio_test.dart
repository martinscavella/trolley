import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dati/conflitti.dart';
import 'package:trolley/dati/database.dart';
import 'package:trolley/dati/errori.dart';
import 'package:trolley/dominio/liste.dart';

import '../aiuti.dart';

/// La lista del viaggio (fase 2.4, 05-cose-da-portare.md) nei dati: chi porta
/// cosa, lo spostamento da una lista all'altra, le voci che tornano libere
/// quando chi le portava lascia il viaggio. Le regole di accesso stanno in
/// supabase/tests/lista_del_viaggio.sql.
void main() {
  late Ambiente ambiente;

  const marco = '22222222-2222-4222-8222-222222222222';

  setUp(() async {
    ambiente = Ambiente();
    ambiente.server
      ..viaggi.add(rigaViaggio('v', citta: 'Porto', paese: 'PT'))
      ..partecipazioni.addAll([
        rigaPartecipazione('v'),
        rigaPartecipazione('v', utente: marco, ruolo: 'partecipante'),
      ])
      ..utenti.add({
        'id': marco,
        'nome': 'Marco',
        'versione': 1,
        'eliminato_il': null,
      })
      ..voci.addAll([
        rigaDiVoce('spazzolino', viaggio: 'v', testo: 'Spazzolino'),
        rigaDiVoce(
          'adattatore',
          viaggio: 'v',
          testo: 'Adattatore',
          quantita: 2,
          tipo: 'viaggio',
          proprietario: marco,
          creatoDa: marco,
        ),
        rigaDiVoce(
          'crema',
          viaggio: 'v',
          testo: 'Crema solare',
          tipo: 'viaggio',
          proprietario: marco,
          assegnatoA: marco,
          creatoDa: marco,
        ),
      ]);
    await ambiente.accedi();
    await ambiente.archivio.aggiornaCopia();
  });

  tearDown(() => ambiente.chiudi());

  Future<List<VoceLista>> voci() => ambiente.archivio.osservaVoci('v').first;
  Future<VoceLista> voce(String id) async =>
      (await voci()).singleWhere((v) => v.id == id);
  Map<String, Object?> sulServer(String id) =>
      ambiente.server.voci.singleWhere((v) => v['id'] == id);

  test('una voce nuova della lista del viaggio non la porta nessuno', () async {
    await ambiente.archivio.aggiungiVoce(
      viaggioId: 'v',
      testo: 'Mazzo di carte',
      lista: TipoLista.viaggio,
    );
    final riga = ambiente.server.voci.last;
    expect(riga['tipo'], 'viaggio');
    expect(riga['assegnato_a'], isNull);
    expect(riga['proprietario_id'], idDiProva);
    expect((await voci()).last.tipo, 'viaggio');
  });

  test('una propria non la porta nessuno, anche se si prova', () async {
    await ambiente.archivio.aggiungiVoce(
      viaggioId: 'v',
      testo: 'Medicine',
      portaChi: marco,
    );
    expect(ambiente.server.voci.last['assegnato_a'], isNull);
  });

  test('chi la porta si cambia con la versione', () async {
    await ambiente.archivio.modificaVoce(await voce('adattatore'), {
      'assegnato_a': idDiProva,
    });
    expect(sulServer('adattatore')['assegnato_a'], idDiProva);
    expect((await voce('adattatore')).assegnatoA, idDiProva);
  });

  test('se intanto l\'ha presa Marco, si mostrano le due versioni: nessuno '
      'porta due adattatori senza saperlo', () async {
    final vista = await voce('adattatore');
    sulServer('adattatore')
      ..['assegnato_a'] = marco
      ..['versione'] = 2
      ..['modificato_da'] = marco;
    await expectLater(
      ambiente.archivio.modificaVoce(vista, {'assegnato_a': idDiProva}),
      throwsA(
        isA<Conflitto>()
            .having((c) => c.diversi, 'diversi', {'assegnato_a'})
            .having((c) => c.loro['assegnato_a'], 'loro', marco),
      ),
    );
    expect(sulServer('adattatore')['assegnato_a'], marco);
  });

  test('tenerle tutte e due: la voce in più nasce nella stessa lista '
      'dell\'altra, con chi la porta', () async {
    final vista = await voce('adattatore');
    sulServer('adattatore')
      ..['testo'] = 'Adattatore tipo A'
      ..['versione'] = 2;
    late Conflitto conflitto;
    try {
      await ambiente.archivio.modificaVoce(vista, {
        'testo': 'Adattatore universale',
        'assegnato_a': idDiProva,
      });
    } on Conflitto catch (c) {
      conflitto = c;
    }
    await ambiente.archivio.tieniTutteEDue(conflitto);
    final nuova = ambiente.server.voci.last;
    expect(nuova['testo'], 'Adattatore universale');
    expect(nuova['tipo'], 'viaggio');
    expect(nuova['assegnato_a'], idDiProva);
  });

  group('spostare una voce', () {
    test('dalla propria lista a quella del viaggio: la porta chi la sposta, '
        'con la sua spunta', () async {
      sulServer('spazzolino')['spuntata'] = true;
      await ambiente.archivio.aggiornaCopia();

      final nuova = await ambiente.archivio.spostaVoce(
        await voce('spazzolino'),
      );

      expect(sulServer('spazzolino')['eliminato_il'], isNotNull);
      expect(nuova.tipo, 'viaggio');
      expect(nuova.assegnatoA, idDiProva);
      expect(nuova.spuntata, isTrue);
      expect(nuova.testo, 'Spazzolino');
      expect((await voci()).map((v) => v.id), isNot(contains('spazzolino')));
      final chiamata = ambiente.server
          .chiamate('POST', '/rest/v1/rpc/sposta_voce')
          .single;
      expect(corpoDi(chiamata), {
        'p_voce': 'spazzolino',
        'p_versione': 1,
        'p_nuova': nuova.id,
      });
    });

    test('da quella del viaggio alla propria: una voce libera sì', () async {
      final nuova = await ambiente.archivio.spostaVoce(
        await voce('adattatore'),
      );
      expect(nuova.tipo, 'personale');
      expect(nuova.assegnatoA, isNull);
      expect(nuova.quantita, 2);
    });

    test(
      'quella che porta un altro no, e non si chiede niente al server',
      () async {
        await expectLater(
          ambiente.archivio.spostaVoce(await voce('crema')),
          throwsA(
            isA<ErroreTrolley>().having(
              (e) => e.messaggio,
              'messaggio',
              'La porta Marco: resta nella lista del viaggio.',
            ),
          ),
        );
        expect(
          ambiente.server.chiamate('POST', '/rest/v1/rpc/sposta_voce'),
          isEmpty,
        );
      },
    );

    test('se intanto Marco l\'ha solo spuntata, si sposta lo stesso', () async {
      final vista = await voce('adattatore');
      sulServer('adattatore')
        ..['spuntata'] = true
        ..['versione'] = 2;

      final nuova = await ambiente.archivio.spostaVoce(vista);

      expect(nuova.spuntata, isTrue);
      expect(
        ambiente.server.chiamate('POST', '/rest/v1/rpc/sposta_voce'),
        hasLength(2),
      );
    });

    test('se intanto Marco l\'ha presa, resta dov\'è e lo dice', () async {
      final vista = await voce('adattatore');
      sulServer('adattatore')
        ..['assegnato_a'] = marco
        ..['versione'] = 2;

      await expectLater(
        ambiente.archivio.spostaVoce(vista),
        throwsA(
          isA<ErroreTrolley>().having(
            (e) => e.messaggio,
            'messaggio',
            'Intanto l\'ha presa Marco: resta nella lista del viaggio.',
          ),
        ),
      );
      expect(sulServer('adattatore')['eliminato_il'], isNull);
      expect((await voce('adattatore')).assegnatoA, marco);
    });

    test('senza rete non si sposta, e lo dice', () async {
      ambiente.rete.disponibile = false;
      await expectLater(
        ambiente.archivio.spostaVoce(await voce('spazzolino')),
        throwsA(
          isA<ErroreTrolley>().having(
            (e) => e.serveLaRete,
            'serveLaRete',
            true,
          ),
        ),
      );
      expect(sulServer('spazzolino')['eliminato_il'], isNull);
    });
  });

  group('chi portava qualcosa lascia il viaggio', () {
    test('togliendo Marco, le sue voci tornano libere subito nella copia, e '
        'si sa chi le portava', () async {
      await ambiente.archivio.togliPartecipante('v', marco);
      final crema = await voce('crema');
      expect(crema.assegnatoA, isNull);
      expect(crema.lasciataDa, marco);
    });

    test('l\'avviso visto non torna, su questo telefono', () async {
      expect(
        await ambiente.archivio.osservaVociLasciateViste('v').first,
        isEmpty,
      );
      await ambiente.archivio.vociLasciateViste('v', ['crema']);
      await ambiente.archivio.vociLasciateViste('v', ['ombrellone', 'crema']);
      expect(await ambiente.archivio.osservaVociLasciateViste('v').first, {
        'crema',
        'ombrellone',
      });
    });
  });
}
