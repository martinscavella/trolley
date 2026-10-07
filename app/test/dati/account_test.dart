import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dati/account.dart';
import 'package:trolley/dati/archivio.dart';
import 'package:trolley/dati/database.dart';
import 'package:trolley/dati/errori.dart';
import 'package:trolley/dominio/chiusura_account.dart';
import 'package:trolley/misurazione/misurazione.dart';

import '../aiuti.dart';

/// I tuoi dati e chiudere l'account (U.1) nei dati: che cosa succede ai
/// viaggi, letto dalla copia; il file dei dati; la chiusura sul server, che
/// manda prima quello che aspetta; la copia che si svuota dopo. Le regole del
/// server stanno in supabase/tests/chiusura_account.sql.
void main() {
  late Ambiente ambiente;

  const marco = '22222222-2222-4222-8222-222222222222';
  const sara = '33333333-3333-4333-8333-333333333333';
  const luca = '44444444-4444-4444-8444-444444444444';

  Map<String, Object?> entrato(Map<String, Object?> riga, String quando) => {
    ...riga,
    'creato_il': quando,
  };

  setUp(() async {
    ambiente = Ambiente();
    ambiente.server
      ..viaggi.addAll([
        rigaViaggio(
          'porto',
          stato: 'definito',
          inizio: '2099-10-10',
          fine: '2099-10-12',
        ),
        rigaViaggio(
          'berlino',
          stato: 'definito',
          citta: 'Berlino',
          paese: 'DE',
          inizio: '2099-11-02',
          fine: '2099-11-03',
        ),
        rigaViaggio('lisbona', citta: 'Lisbona', periodo: 'maggio 2099'),
      ])
      ..partecipazioni.addAll([
        rigaPartecipazione('porto'),
        // Sara entra dopo Marco: il ruolo, se si chiude, passa a lui.
        entrato(
          rigaPartecipazione('porto', utente: sara, ruolo: 'partecipante'),
          '2026-10-02T10:00:00+00:00',
        ),
        entrato(
          rigaPartecipazione('porto', utente: marco, ruolo: 'partecipante'),
          '2026-10-01T10:00:00+00:00',
        ),
        rigaPartecipazione('berlino'),
        rigaPartecipazione('lisbona', ruolo: 'partecipante'),
        rigaPartecipazione('lisbona', utente: sara),
      ])
      ..utenti.addAll([
        {'id': marco, 'nome': 'Marco', 'versione': 1, 'eliminato_il': null},
        {'id': sara, 'nome': 'Sara', 'versione': 1, 'eliminato_il': null},
      ]);
    await ambiente.accedi();
    await ambiente.archivio.aggiornaCopia();
  });

  tearDown(() => ambiente.chiudi());

  test('chiudendo, il viaggio da soli si cancella, dagli altri si esce, e '
      'Porto passa a chi è entrato per primo', () async {
    final esito = cosaSuccede(
      await ambiente.archivio.viaggiDaChiudereConLAccount(),
    );
    expect([for (final v in esito.cancellati) v.id], ['berlino']);
    expect([
      for (final v in esito.lasciati) v.id,
    ], unorderedEquals(['porto', 'lisbona']));
    expect(esito.passaggi.single.$1.id, 'porto');
    expect(esito.passaggi.single.$2.nome, 'Marco');
  });

  test('chi ha chiuso l\'account resta fra chi non c\'è più, senza il suo '
      'nome', () async {
    ambiente.server
      ..partecipazioni.add(
        rigaPartecipazione(
          'porto',
          utente: luca,
          ruolo: 'partecipante',
          stato: 'uscito',
        ),
      )
      ..utenti.add({
        'id': luca,
        'nome': null,
        'versione': 2,
        'eliminato_il': '2026-10-06T18:00:00+00:00',
      });
    await ambiente.archivio.aggiornaCopia();

    final nomi = await ambiente.archivio.osservaNomi('porto').first;
    expect(nomi[luca], nomeAccountChiuso);
    final usciti = await ambiente.archivio.osservaUsciti('porto').first;
    expect(usciti.single.$2?.nome, 'Account chiuso');
  });

  test('i propri dati diventano un file JSON, con quello che manda il '
      'server', () async {
    final file = await scriviIMieiDati(
      ambiente.archivio,
      cartella: ambiente.cartella,
      oggi: DateTime(2026, 10, 6),
    );
    expect(file.path.split('/').last, 'trolley-dati-2026-10-06.json');
    final dati = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    expect(dati['formato'], 'trolley.dati');
    expect((dati['profilo'] as Map)['nome'], 'Giulia');
    expect(dati['viaggi'], hasLength(3));
    // Leggibile anche da una persona: un campo per riga.
    expect(file.readAsStringSync(), contains('\n  "formato": "trolley.dati"'));
  });

  test('senza rete i dati non si scaricano, e non resta nessun file', () async {
    ambiente.rete.disponibile = false;
    await expectLater(
      scriviIMieiDati(
        ambiente.archivio,
        cartella: ambiente.cartella,
        oggi: DateTime(2026, 10, 6),
      ),
      throwsA(isA<ErroreTrolley>()),
    );
    expect(
      ambiente.cartella.listSync().where((f) => f.path.endsWith('.json')),
      isEmpty,
    );
  });

  test('chiudere sul server: prima partono gli eventi, poi la chiusura, con '
      'la scelta sulla misurazione', () async {
    await ambiente.misurazione.registra(Eventi.viaggioCreato);
    await chiudiLAccountSulServer(
      archivio: ambiente.archivio,
      misurazione: ambiente.misurazione,
    );
    final ordine = [
      for (final r in ambiente.server.richieste)
        if (r.url.path == '/rest/v1/evento' ||
            r.url.path == '/rest/v1/rpc/chiudi_account')
          r.url.path,
    ];
    expect(ordine, ['/rest/v1/evento', '/rest/v1/rpc/chiudi_account']);
    expect(ambiente.server.chiusoConMisurazione, isTrue);
  });

  test('con la misurazione spenta, la chiusura lo dice al server', () async {
    await ambiente.misurazione.imposta(attiva: false);
    await chiudiLAccountSulServer(
      archivio: ambiente.archivio,
      misurazione: ambiente.misurazione,
    );
    expect(ambiente.server.chiusoConMisurazione, isFalse);
    expect(ambiente.server.chiamate('POST', '/rest/v1/evento'), isEmpty);
  });

  test(
    'senza rete l\'account non si chiude, e il telefono resta com\'è',
    () async {
      ambiente.rete.disponibile = false;
      await expectLater(
        chiudiLAccountSulServer(
          archivio: ambiente.archivio,
          misurazione: ambiente.misurazione,
        ),
        throwsA(isA<ErroreTrolley>()),
      );
      expect(ambiente.server.chiusoConMisurazione, isNull);
      expect(await ambiente.archivio.mieiViaggi(), hasLength(3));
    },
  );

  test('dopo la chiusura: via i propri documenti e la copia, restano i '
      'documenti di un altro account su questo telefono', () async {
    final db = ambiente.db;
    Future<void> documento(String id, String di) => db
        .into(db.documenti)
        .insert(
          DocumentiCompanion.insert(
            id: id,
            viaggioId: 'porto',
            nome: 'Biglietto $id',
            percorsoLocale: 'documenti/porto/$id.pdf',
            formato: 'pdf',
            sorgente: 'file',
            proprietarioId: di,
            creatoIl: DateTime(2026, 10, 6),
            pagine: const Value(1),
          ),
        );
    await documento('mio', idDiProva);
    await documento('suo', 'altro-account');
    await db
        .into(db.codaScrittura)
        .insert(
          CodaScritturaCompanion.insert(
            id: 'op',
            viaggioId: 'porto',
            gesto: GestoOffline.spuntaVoce,
            carico: '{}',
            creataIl: DateTime(2026, 10, 6),
          ),
        );
    expect(await ambiente.archivio.coda.quante(), 1);

    expect(await ambiente.documenti.eliminaQuelliDi(idDiProva), 1);
    await lasciaIlTelefono(
      archivio: ambiente.archivio,
      accesso: ambiente.server.supabase.auth,
    );

    expect(await db.select(db.viaggi).get(), isEmpty);
    expect(await db.select(db.partecipazioni).get(), isEmpty);
    expect(await db.select(db.utenti).get(), isEmpty);
    expect(await db.select(db.impostazioni).get(), isEmpty);
    expect(await ambiente.archivio.coda.quante(), 0);
    expect(
      [for (final d in await db.select(db.documenti).get()) d.id],
      ['suo'],
    );
    expect(ambiente.server.supabase.auth.currentUser, isNull);
  });
}
