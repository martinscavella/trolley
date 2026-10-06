import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dati/chiusura.dart';
import 'package:trolley/dati/errori.dart';
import 'package:trolley/dominio/calendario.dart';
import 'package:trolley/dominio/traguardi.dart';
import 'package:trolley/dominio/verifica.dart';

import '../aiuti.dart';

/// La chiusura (fase 4.1): chiudere sul server, dire se è verificato per sé,
/// prendere i traguardi, misurare.
void main() {
  late Ambiente ambiente;

  setUp(() => ambiente = Ambiente());
  tearDown(() => ambiente.chiudi());

  final oggi = soloData(DateTime.now());
  String fra(int giorni) => scriviData(oggi.add(Duration(days: giorni)));
  const marco = '22222222-2222-4222-8222-222222222222';

  /// Porto, due giorni finiti ieri, con una tappa fatta per giorno.
  Future<void> viaggio({
    int inizio = -2,
    int fine = -1,
    bool sulPosto = true,
    bool segnateDurante = true,
    bool conMarco = false,
    String stato = 'definito',
    bool deroga = false,
  }) async {
    ambiente.server
      ..viaggi.add(
        rigaViaggio('v', stato: stato, inizio: fra(inizio), fine: fra(fine))
          ..['verifica_per_deroga'] = deroga,
      )
      ..partecipazioni.add(
        rigaPartecipazione('v')
          ..['sul_posto_il'] = sulPosto ? '${fra(inizio)}T12:00:00Z' : null,
      )
      ..giorni.addAll([
        rigaGiorno('v', fra(inizio), '10:00:00', '24:00:00', id: 'g1'),
        rigaGiorno('v', fra(fine), '00:00:00', '18:00:00', id: 'g2'),
      ])
      ..tappe.addAll([
        for (final (id, giorno) in [('t1', 'g1'), ('t2', 'g2')])
          rigaDiTappa(id, viaggio: 'v', giorno: giorno, stato: 'completata')
            ..['marcata_durante_il_viaggio'] = segnateDurante,
      ]);
    if (conMarco) {
      ambiente.server.partecipazioni.add(
        rigaPartecipazione('v', utente: marco, ruolo: 'partecipante'),
      );
    }
    await ambiente.accedi();
    await ambiente.archivio.aggiornaCopia();
  }

  Future<EsitoChiusura> chiudi({bool aMano = false}) => chiudiIlViaggio(
    viaggioId: 'v',
    archivio: ambiente.archivio,
    misurazione: ambiente.misurazione,
    aMano: aMano,
  );

  Future<Map<String, dynamic>> evento(String nome) async {
    final tutti = [
      for (final e
          in await ambiente.db.select(ambiente.db.eventiInAttesa).get())
        (e.nome, jsonDecode(e.proprieta) as Map<String, dynamic>),
      for (final r in ambiente.server.chiamate('POST', '/rest/v1/evento'))
        for (final e
            in (jsonDecode(r.body) as List).cast<Map<String, dynamic>>())
          (e['nome'] as String, e['proprieta'] as Map<String, dynamic>),
    ];
    return tutti.singleWhere((e) => e.$1 == nome).$2;
  }

  Map<String, Object?> mia() => ambiente.server.partecipazioni.firstWhere(
    (p) => p['utente_id'] == idDiProva,
  );

  test('finito ieri: si chiude, è verificato, i traguardi arrivano e si '
      'misura', () async {
    await viaggio();
    final daChiudere = await viaggiDaChiudere(
      ambiente.archivio,
      DateTime.now(),
    );
    expect(daChiudere.map((v) => v.id), ['v']);

    final esito = await chiudi();

    expect(ambiente.server.viaggi.single['stato'], 'chiuso');
    expect(esito.verifica.verificato, isTrue);
    expect(mia()['verificato'], isTrue);
    expect(esito.nuovi, {
      Traguardo.primoViaggioVerificato,
      Traguardo.ogniGiornoUnaTappa,
    });
    final presi = await ambiente.archivio.leggiTraguardi();
    expect(presi.map((t) => t.tipo), containsAll(['primo_viaggio_verificato']));
    expect(await viaggiDaChiudere(ambiente.archivio, DateTime.now()), isEmpty);
    expect(await evento('viaggio_chiuso'), {
      'viaggio_id': 'v',
      'verificato': true,
      'mancate': <String>[],
      'punti_viaggio': 1.1,
      'per_deroga': false,
      'a_mano': false,
      'tappe': 2,
      'segnate_durante': 2,
    });
  });

  test('senza essere stati sul posto si chiude lo stesso, senza traguardi; '
      'si misura che cosa è mancato', () async {
    await viaggio(sulPosto: false);

    final esito = await chiudi();

    expect(esito.verifica.verificato, isFalse);
    expect(esito.verifica.mancanti, {CondizioneVerifica.sulPosto});
    expect(mia()['verificato'], isFalse);
    expect(ambiente.server.traguardi, isEmpty);
    expect((await evento('viaggio_chiuso'))['mancate'], ['sul_posto']);
  });

  test('tappe segnate dopo la fine non valgono', () async {
    await viaggio(segnateDurante: false);

    final esito = await chiudi();

    expect(esito.verifica.mancanti, {CondizioneVerifica.tappeSegnate});
  });

  test(
    'con la deroga è verificato anche senza esserci, e lo si dice',
    () async {
      await viaggio(sulPosto: false, deroga: true);

      final esito = await chiudi();

      expect(esito.verifica.verificato, isTrue);
      expect((await evento('viaggio_chiuso'))['per_deroga'], isTrue);
    },
  );

  test('chiuso da un compagno: non si richiude, ma la propria verifica si '
      'scrive', () async {
    await viaggio(stato: 'chiuso');
    expect(
      (await viaggiDaChiudere(ambiente.archivio, DateTime.now())).single.id,
      'v',
    );

    await chiudi();

    expect(
      ambiente.server.chiamate('POST', '/rest/v1/rpc/chiudi_viaggio'),
      isEmpty,
    );
    expect(mia()['verificato'], isTrue);
  });

  test('senza rete non si chiude, e resta da chiudere', () async {
    await viaggio();
    ambiente.rete.disponibile = false;

    await expectLater(
      chiudi(),
      throwsA(isA<ErroreTrolley>().having((e) => e.serveLaRete, 'rete', true)),
    );
    expect(ambiente.server.viaggi.single['stato'], 'definito');
    expect(
      await viaggiDaChiudere(ambiente.archivio, DateTime.now()),
      hasLength(1),
    );
  });

  test('prima della fine lo chiude a mano chi è responsabile; chi partecipa '
      'no', () async {
    await viaggio(inizio: -1, fine: 1, conMarco: true);
    expect(await viaggiDaChiudere(ambiente.archivio, DateTime.now()), isEmpty);

    await chiudi(aMano: true);
    expect(ambiente.server.viaggi.single['stato'], 'chiuso');
    expect((await evento('viaggio_chiuso'))['a_mano'], isTrue);
  });

  test('chi partecipa non chiude prima della fine, e lo dice', () async {
    await viaggio(inizio: -1, fine: 1, conMarco: true);
    mia()['ruolo'] = 'partecipante';

    await expectLater(
      chiudi(aMano: true),
      throwsA(
        isA<ErroreTrolley>().having(
          (e) => e.messaggio,
          'messaggio',
          contains('Solo chi è responsabile'),
        ),
      ),
    );
    expect(ambiente.server.viaggi.single['stato'], 'definito');
  });
}
