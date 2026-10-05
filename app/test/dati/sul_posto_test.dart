import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dati/database.dart';
import 'package:trolley/dati/destinazioni.dart';
import 'package:trolley/dati/posizione.dart';
import 'package:trolley/dati/sul_posto.dart';
import 'package:trolley/dominio/calendario.dart';

import '../aiuti.dart';

/// «Sul posto» (fase 3.4): il telefono guarda dov'è mentre il viaggio è in
/// corso, lo confronta con la meta, e al server manda solo l'esito.
void main() {
  late Ambiente ambiente;
  final elenco = ElencoDestinazioni.daTesto(
    File('assets/destinazioni.tsv').readAsStringSync(),
  );

  final oggi = soloData(DateTime.now());
  String fra(int giorni) => scriviData(oggi.add(Duration(days: giorni)));

  const porto = (lat: 41.1496, lon: -8.6110);
  const lisbona = (lat: 38.7223, lon: -9.1393);

  setUp(() => ambiente = Ambiente());
  tearDown(() => ambiente.chiudi());

  Future<Viaggio> viaggio({
    int inizio = -1,
    int fine = 1,
    String? citta = 'Porto',
  }) async {
    ambiente.server
      ..viaggi.add(
        rigaViaggio(
          'v',
          stato: 'definito',
          citta: citta,
          inizio: fra(inizio),
          fine: fra(fine),
        ),
      )
      ..partecipazioni.add(rigaPartecipazione('v'));
    await ambiente.accedi();
    await ambiente.archivio.aggiornaCopia();
    return (await ambiente.archivio.leggiViaggio('v'))!;
  }

  Future<bool> controlla(Viaggio v) => controllaSulPosto(
    viaggio: v,
    archivio: ambiente.archivio,
    posizione: ambiente.posizione,
    elenco: () async => elenco,
  );

  Map<String, Object?> mia() => ambiente.server.partecipazioni.single;

  test('a Porto durante il viaggio a Porto: al server va solo il sì, e da '
      'allora non si guarda più', () async {
    final v = await viaggio();
    ambiente.posizione.dove = porto;

    expect(await controlla(v), isTrue);

    final chiamata = ambiente.server
        .chiamate('POST', '/rest/v1/rpc/segna_sul_posto')
        .single;
    expect(corpoDi(chiamata), {'p_viaggio': 'v'});
    expect(mia()['sul_posto_il'], isNotNull);
    final copia = await ambiente.db.select(ambiente.db.partecipazioni).get();
    expect(copia.single.sulPostoIl, isNotNull);

    expect(await controlla(v), isFalse);
    expect(ambiente.posizione.volteQui, 1);
  });

  test('a Lisbona durante il viaggio a Porto non si è sul posto, e non si '
      'dice niente', () async {
    final v = await viaggio();
    ambiente.posizione.dove = lisbona;

    expect(await controlla(v), isFalse);
    expect(
      ambiente.server.chiamate('POST', '/rest/v1/rpc/segna_sul_posto'),
      isEmpty,
    );
    expect(await ambiente.archivio.sulPosto('v'), isFalse);
  });

  test('per un viaggio in un paese intero basta il paese', () async {
    final v = await viaggio(citta: null);
    ambiente.posizione.dove = lisbona;

    expect(await controlla(v), isTrue);
  });

  test(
    'prima della partenza, o senza permesso, non si guarda nemmeno',
    () async {
      final futuro = await viaggio(inizio: 2, fine: 3);
      ambiente.posizione.dove = porto;
      expect(await controlla(futuro), isFalse);
      expect(ambiente.posizione.volteQui, 0);

      ambiente.server.viaggi.single['data_inizio'] = fra(-1);
      await ambiente.archivio.aggiornaCopia();
      final inCorso = (await ambiente.archivio.leggiViaggio('v'))!;
      ambiente.posizione.stato = PermessoPosizione.negato;
      expect(await controlla(inCorso), isFalse);
      expect(ambiente.posizione.volteQui, 0);
    },
  );

  test('senza rete l\'esito si ricorda, e parte quando torna', () async {
    final v = await viaggio();
    ambiente.posizione.dove = porto;
    ambiente.rete.disponibile = false;

    expect(await controlla(v), isTrue);
    expect(mia()['sul_posto_il'], isNull);
    // Per questo telefono è sul posto: non si riguarda.
    expect(await ambiente.archivio.sulPosto('v'), isTrue);

    ambiente.rete.disponibile = true;
    await ambiente.archivio.aggiornaCopia();

    expect(mia()['sul_posto_il'], isNotNull);
    final segni = await ambiente.db.select(ambiente.db.impostazioni).get();
    expect(segni.where((s) => s.chiave.startsWith('sul_posto:')), isEmpty);
    expect(await ambiente.archivio.sulPosto('v'), isTrue);
  });

  test('se il server dice che il viaggio non è più in corso, l\'esito si '
      'lascia', () async {
    final v = await viaggio();
    ambiente.posizione.dove = porto;
    ambiente.rete.disponibile = false;
    await controlla(v);
    // Tornati a casa dopo una settimana senza rete.
    ambiente.server.viaggi.single
      ..['data_inizio'] = fra(-10)
      ..['data_fine'] = fra(-8);
    ambiente.rete.disponibile = true;

    await ambiente.archivio.aggiornaCopia();

    expect(mia()['sul_posto_il'], isNull);
    final segni = await ambiente.db.select(ambiente.db.impostazioni).get();
    expect(segni.where((s) => s.chiave.startsWith('sul_posto:')), isEmpty);
  });
}
