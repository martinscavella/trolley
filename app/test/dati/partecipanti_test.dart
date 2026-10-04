import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dati/archivio.dart';
import 'package:trolley/dati/coda.dart';
import 'package:trolley/dati/database.dart';
import 'package:trolley/dati/errori.dart';

import '../aiuti.dart';

/// Chi partecipa (03-partecipanti-e-inviti.md) nei dati: entrare da un
/// invito, uscire, togliere qualcuno, passare il ruolo, gli inviti in
/// sospeso, il viaggio lasciato che non sparisce in silenzio, il benvenuto.
/// Le regole di accesso stanno in supabase/tests/partecipanti.sql.
void main() {
  late Ambiente ambiente;

  const marco = '22222222-2222-4222-8222-222222222222';

  setUp(() async {
    ambiente = Ambiente();
    ambiente.server
      ..viaggi.add(
        rigaViaggio(
          'v',
          stato: 'definito',
          inizio: '2099-10-10',
          fine: '2099-10-12',
        ),
      )
      ..giorni.add(rigaGiorno('v', '2099-10-10', '10:00:00', '24:00:00'))
      ..partecipazioni.addAll([
        rigaPartecipazione('v'),
        rigaPartecipazione('v', utente: marco, ruolo: 'partecipante'),
      ])
      ..utenti.add({
        'id': marco,
        'nome': 'Marco',
        'versione': 1,
        'eliminato_il': null,
      });
    await ambiente.accedi();
    await ambiente.archivio.aggiornaCopia();
  });

  tearDown(() => ambiente.chiudi());

  Future<List<(Partecipazione, Utente?)>> attivi() =>
      ambiente.archivio.osservaPartecipanti('v').first;
  Future<List<(Partecipazione, Utente?)>> usciti() =>
      ambiente.archivio.osservaUsciti('v').first;
  Future<List<OperazioneInCoda>> inCoda() =>
      ambiente.db.select(ambiente.db.codaScrittura).get();

  /// Chi è entrato non è più chi ha creato il viaggio, ma un invitato.
  void diventaInvitato() {
    ambiente.server.partecipazioni
      ..clear()
      ..addAll([
        rigaPartecipazione('v', utente: marco),
        rigaPartecipazione('v', ruolo: 'partecipante'),
      ]);
  }

  test('chi c\'è: chi è responsabile per primo; chi non c\'è più a parte, '
      'con il suo nome', () async {
    ambiente.server.partecipazioni.add(
      rigaPartecipazione(
        'v',
        utente: 'luca',
        ruolo: 'partecipante',
        stato: 'uscito',
      ),
    );
    ambiente.server.utenti.add({
      'id': 'luca',
      'nome': 'Luca',
      'versione': 1,
      'eliminato_il': null,
    });
    await ambiente.archivio.aggiornaCopia();
    expect(
      [for (final (p, _) in await attivi()) p.ruolo],
      ['creatore', 'partecipante'],
    );
    expect([for (final (_, u) in await usciti()) u?.nome], ['Luca']);
    // Le sue spese restano sue: il nome si legge ancora (03, regola 8).
    expect((await ambiente.archivio.osservaNomi('v').first)['luca'], 'Luca');
  });

  group('entrare da un invito', () {
    test('la prima volta si entra, e si dice che è un arrivo nuovo; il secondo '
        'link riconosce chi è già dentro', () async {
      ambiente.server.viaggi.add(
        rigaViaggio('w', citta: 'Vienna', paese: 'AT'),
      );
      ambiente.server.inviti.add({
        'token': 'WWWW2345',
        'viaggio_id': 'w',
        'creato_da': marco,
        'creato_il': '2026-10-01T10:00:00Z',
        'eliminato_il': null,
      });
      final primo = await ambiente.archivio.accettaInvito('WWWW2345');
      expect(primo, (viaggioId: 'w', giaDentro: false));
      expect(await ambiente.archivio.osservaViaggio('w').first, isNotNull);

      final secondo = await ambiente.archivio.accettaInvito('WWWW2345');
      expect(secondo, (viaggioId: 'w', giaDentro: true));
    });

    test('un link ritirato lo dice', () async {
      await expectLater(
        ambiente.archivio.accettaInvito('ZZZZ9999'),
        throwsA(
          isA<ErroreTrolley>().having(
            (e) => e.messaggio,
            'messaggio',
            contains('ritirato'),
          ),
        ),
      );
    });
  });

  group('uscire', () {
    test('chi partecipa esce: prima partono i gesti in coda, poi il viaggio '
        'esce dal telefono con tutto quello che gli era agganciato', () async {
      diventaInvitato();
      await ambiente.archivio.aggiornaCopia();
      ambiente.rete.disponibile = false;
      await ambiente.archivio.coda.registraSpesa(
        NuovaSpesa(
          id: 's1',
          viaggioId: 'v',
          centesimi: 1250,
          valuta: 'EUR',
          paganteId: idDiProva,
          data: DateTime(2099, 10, 10),
        ),
      );
      ambiente.rete.disponibile = true;

      await ambiente.archivio.esciDalViaggio('v');

      // La spesa fatta senza rete è arrivata prima di uscire: resta agli altri.
      expect(ambiente.server.spese.map((s) => s['id']), ['s1']);
      expect(
        ambiente.server.partecipazioni.singleWhere(
          (p) => p['utente_id'] == idDiProva,
        )['stato'],
        'uscito',
      );
      expect(await ambiente.archivio.osservaViaggio('v').first, isNull);
      expect(await ambiente.archivio.osservaGiorni('v').first, isEmpty);
      expect(await ambiente.archivio.osservaSpese('v').first, isEmpty);
      expect(await attivi(), isEmpty);
      expect(await inCoda(), isEmpty);
      // Uscire da qui non è un viaggio sparito: nessun avviso.
      expect(await ambiente.archivio.osservaViaggiLasciati().first, isEmpty);
    });

    test(
      'chi è responsabile non esce senza passare il ruolo, e lo dice',
      () async {
        await expectLater(
          ambiente.archivio.esciDalViaggio('v'),
          throwsA(
            isA<ErroreTrolley>().having(
              (e) => e.messaggio,
              'messaggio',
              contains('responsabile qualcun altro'),
            ),
          ),
        );
        expect(await ambiente.archivio.osservaViaggio('v').first, isNotNull);
      },
    );

    test('senza rete non si esce, e lo dice', () async {
      diventaInvitato();
      await ambiente.archivio.aggiornaCopia();
      ambiente.rete.disponibile = false;
      await expectLater(
        ambiente.archivio.esciDalViaggio('v'),
        throwsA(
          isA<ErroreTrolley>().having((e) => e.serveLaRete, 'rete', true),
        ),
      );
      expect(await ambiente.archivio.osservaViaggio('v').first, isNotNull);
    });
  });

  group('i poteri di chi è responsabile', () {
    test('togliere qualcuno: la copia prende le righe che tornano, e lui passa '
        'fra chi non c\'è più', () async {
      await ambiente.archivio.togliPartecipante('v', marco);
      expect((await attivi()).length, 1);
      expect([for (final (_, u) in await usciti()) u?.nome], ['Marco']);
    });

    test(
      'passare il ruolo: uno solo è responsabile, e il viaggio segue',
      () async {
        await ambiente.archivio.rendiResponsabile('v', marco);
        final ruoli = {
          for (final (p, _) in await attivi()) p.utenteId: p.ruolo,
        };
        expect(ruoli, {marco: 'creatore', idDiProva: 'partecipante'});
        expect(
          (await ambiente.archivio.osservaViaggio('v').first)!.creatoreId,
          marco,
        );
      },
    );

    test('se nel frattempo il ruolo è passato, il server rifiuta e la copia '
        'mostra com\'è adesso', () async {
      diventaInvitato();
      await expectLater(
        ambiente.archivio.togliPartecipante('v', marco),
        throwsA(
          isA<ErroreTrolley>().having(
            (e) => e.messaggio,
            'messaggio',
            contains('Solo chi è responsabile'),
          ),
        ),
      );
      final ruoli = {for (final (p, _) in await attivi()) p.utenteId: p.ruolo};
      expect(ruoli[marco], 'creatore');
    });
  });

  group('gli inviti in sospeso', () {
    test('si leggono dal server, e si ritirano tutti insieme', () async {
      await ambiente.archivio.creaInvito('v');
      await ambiente.archivio.creaInvito('v');
      final inviti = await ambiente.archivio.invitiValidi('v');
      expect(inviti.length, 2);
      expect(inviti.first.creatoDa, idDiProva);

      await ambiente.archivio.ritiraInviti('v');
      expect(await ambiente.archivio.invitiValidi('v'), isEmpty);
    });

    test('togliere qualcuno ritira i link di prima', () async {
      await ambiente.archivio.creaInvito('v');
      await ambiente.archivio.togliPartecipante('v', marco);
      expect(await ambiente.archivio.invitiValidi('v'), isEmpty);
    });
  });

  group('il viaggio lasciato non sparisce in silenzio', () {
    test(
      'tolti dal viaggio: un avviso con il nome e il motivo; i gesti in coda '
      'che non arriveranno si contano e si tolgono',
      () async {
        diventaInvitato();
        await ambiente.archivio.aggiornaCopia();
        ambiente.rete.disponibile = false;
        await ambiente.archivio.coda.registraSpesa(
          NuovaSpesa(
            id: 's1',
            viaggioId: 'v',
            centesimi: 800,
            valuta: 'EUR',
            paganteId: idDiProva,
            data: DateTime(2099, 10, 10),
          ),
        );
        // Mentre era offline, chi è responsabile l'ha tolto.
        ambiente.server.partecipazioni.singleWhere(
          (p) => p['utente_id'] == idDiProva,
        )['stato'] = 'rimosso';
        ambiente.server.percorsi['POST /rest/v1/rpc/registra_spesa'] = (_) async =>
            risposta({
              'code': '42501',
              'message': 'new row violates row-level security policy',
              'details': null,
              'hint': null,
            }, 403);
        ambiente.rete.disponibile = true;

        await ambiente.archivio.aggiornaCopia();

        expect(await ambiente.archivio.osservaViaggio('v').first, isNull);
        expect(await inCoda(), isEmpty);
        final lasciati = await ambiente.archivio.osservaViaggiLasciati().first;
        expect(lasciati.length, 1);
        expect(lasciati.single.viaggioId, 'v');
        expect(lasciati.single.nome, 'Porto');
        expect(lasciati.single.motivo, MotivoUscita.rimosso);
        expect(lasciati.single.gestiPersi, 1);

        await ambiente.archivio.dimenticaViaggioLasciato('v');
        expect(await ambiente.archivio.osservaViaggiLasciati().first, isEmpty);
      },
    );

    test('rientrati con un invito, l\'avviso se ne va', () async {
      diventaInvitato();
      await ambiente.archivio.aggiornaCopia();
      final mia = ambiente.server.partecipazioni.singleWhere(
        (p) => p['utente_id'] == idDiProva,
      );
      mia['stato'] = 'uscito';
      await ambiente.archivio.aggiornaCopia();
      expect(
        (await ambiente.archivio.osservaViaggiLasciati().first).single.motivo,
        MotivoUscita.uscito,
      );

      mia['stato'] = 'attivo';
      await ambiente.archivio.aggiornaCopia();
      expect(await ambiente.archivio.osservaViaggiLasciati().first, isEmpty);
    });

    test('un viaggio che non era sul telefono non fa nessun avviso', () async {
      ambiente.server.partecipazioni.add(
        rigaPartecipazione('altro', ruolo: 'partecipante', stato: 'rimosso'),
      );
      await ambiente.archivio.aggiornaCopia();
      expect(await ambiente.archivio.osservaViaggiLasciati().first, isEmpty);
    });
  });

  group('il benvenuto di chi entra da un invito', () {
    test('c\'è finché non si aggiunge qualcosa di proprio', () async {
      expect(await ambiente.archivio.osservaBenvenuto('v').first, isFalse);
      await ambiente.archivio.segnaBenvenuto('v');
      expect(await ambiente.archivio.osservaBenvenuto('v').first, isTrue);

      // Una spesa di Marco non è un contributo proprio.
      ambiente.server.spese.add(
        rigaDiSpesa(
          'sua',
          viaggio: 'v',
          data: '2099-10-10',
          pagante: marco,
          creatoDa: marco,
        ),
      );
      await ambiente.archivio.aggiornaCopia();
      expect(await ambiente.archivio.osservaBenvenuto('v').first, isTrue);

      await ambiente.archivio.aggiungiVoce(viaggioId: 'v', testo: 'Passaporto');
      expect(await ambiente.archivio.osservaBenvenuto('v').first, isFalse);
    });

    test('si chiude con la ×', () async {
      await ambiente.archivio.segnaBenvenuto('v');
      await ambiente.archivio.chiudiBenvenuto('v');
      expect(await ambiente.archivio.osservaBenvenuto('v').first, isFalse);
    });
  });
}
