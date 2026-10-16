import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dati/database.dart';
import 'package:trolley/dati/promemoria.dart';
import 'package:trolley/dominio/calendario.dart';
import 'package:trolley/dominio/notifiche.dart';
import 'package:trolley/misurazione/misurazione.dart';

import '../aiuti.dart';

/// I promemoria sul telefono (14-notifiche.md): dalla copia, ogni volta che
/// cambia, senza server; negli eventi solo il tipo.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Ambiente ambiente;
  late Promemoria promemoria;
  final oggi = soloData(DateTime.now());
  String fra(int giorni) => scriviData(oggi.add(Duration(days: giorni)));
  DateTime alle(int giorni, int ora) {
    final d = oggi.add(Duration(days: giorni));
    return DateTime(d.year, d.month, d.day, ora);
  }

  late DateTime adesso;
  String? io = idDiProva;

  setUp(() {
    ambiente = Ambiente();
    adesso = alle(0, 12);
    io = idDiProva;
    promemoria = Promemoria(
      ambiente.db,
      notifiche: ambiente.notifiche,
      misurazione: ambiente.misurazione,
      io: () => io,
      orologio: () => adesso,
      attesa: Duration.zero,
    );
  });
  tearDown(() async {
    await promemoria.ferma();
    await ambiente.chiudi();
  });

  /// Un viaggio a Porto che parte fra [inizio] giorni, con una cosa nella
  /// propria valigia ancora da mettere.
  Future<void> partenza({int inizio = 4, int fine = 6}) async {
    ambiente.server
      ..viaggi.add(
        rigaViaggio(
          'v',
          stato: 'definito',
          inizio: fra(inizio),
          fine: fra(fine),
        ),
      )
      ..partecipazioni.add(rigaPartecipazione('v'))
      ..voci.add(rigaDiVoce('crema', viaggio: 'v', testo: 'Crema'));
    await ambiente.accedi();
    await ambiente.archivio.aggiornaCopia();
  }

  Future<List<Map<String, Object?>>> eventi(String nome) async => [
    for (final e in await ambiente.db.select(ambiente.db.eventiInAttesa).get())
      if (e.nome == nome) jsonDecode(e.proprieta) as Map<String, Object?>,
  ];

  List<Notifica> programmate() => ambiente.notifiche.programmate;

  test('senza il permesso non si programma niente; con il permesso, dalla '
      'copia', () async {
    await partenza();
    await promemoria.ripianifica();
    expect(programmate(), isEmpty);

    ambiente.notifiche.attive = true;
    await promemoria.ripianifica();
    final [n] = programmate();
    expect(n.tipo, TipoNotifica.primaDiPartire);
    expect(n.quando, alle(2, 18));
    expect(n.titolo, startsWith('Si parte'));
    expect(
      n.testo,
      'Manca una cosa da mettere in valigia e sul telefono non c\'è ancora '
      'nessun documento.',
    );
    expect(n.dovePorta.viaggioId, 'v');
  });

  test('tutto in valigia e un documento sul telefono: non c\'è niente da '
      'dire, e il promemoria si toglie', () async {
    ambiente.notifiche.attive = true;
    await partenza();
    await promemoria.ripianifica();
    expect(programmate(), hasLength(1));

    await (ambiente.db.update(ambiente.db.vociLista))
        .write(const VociListaCompanion(spuntata: Value(true)));
    await ambiente.db
        .into(ambiente.db.documenti)
        .insert(
          DocumentiCompanion.insert(
            id: 'd',
            viaggioId: 'v',
            nome: 'Biglietto',
            percorsoLocale: 'documenti/d.pdf',
            formato: 'pdf',
            sorgente: 'file',
            proprietarioId: idDiProva,
            creatoIl: DateTime.now(),
          ),
        );
    await promemoria.ripianifica();
    expect(programmate(), isEmpty);
  });

  test(
    'passata l\'ora è arrivata: si conta, e non riparte il giorno dopo',
    () async {
      ambiente.notifiche.attive = true;
      await partenza();
      await promemoria.ripianifica();
      expect(programmate().single.quando, alle(2, 18));

      adesso = alle(2, 19);
      await promemoria.ripianifica();
      expect(programmate(), isEmpty);
      expect(await eventi(Eventi.notificaArrivata), [
        {'tipo': 'prima_di_partire'},
      ]);

      await promemoria.ripianifica();
      expect(await eventi(Eventi.notificaArrivata), hasLength(1));
    },
  );

  test(
    'le tappe di oggi segnate tutte tolgono il promemoria della sera',
    () async {
      ambiente.notifiche.attive = true;
      ambiente.server
        ..viaggi.add(
          rigaViaggio('v', stato: 'definito', inizio: fra(0), fine: fra(1)),
        )
        ..partecipazioni.add(rigaPartecipazione('v'))
        ..giorni.add(rigaGiorno('v', fra(0), '10:00:00', '22:00:00', id: 'g'))
        ..tappe.add(rigaDiTappa('t', viaggio: 'v', giorno: 'g'));
      await ambiente.accedi();
      await ambiente.archivio.aggiornaCopia();

      await promemoria.ripianifica();
      final [n] = programmate();
      expect(n.tipo, TipoNotifica.tappeDaSegnare);
      expect(n.quando, alle(0, 21));
      expect(n.dovePorta.giornoId, 'g');

      await (ambiente.db.update(ambiente.db.tappe))
          .write(const TappeCompanion(stato: Value('completata')));
      await promemoria.ripianifica();
      expect(programmate(), isEmpty);
    },
  );

  test('un tipo spento non parte, e riacceso riparte; si misura', () async {
    ambiente.notifiche.attive = true;
    await partenza();

    await promemoria.imposta(TipoNotifica.primaDiPartire, accesa: false);
    expect(await promemoria.spente(), {TipoNotifica.primaDiPartire});
    expect(programmate(), isEmpty);

    await promemoria.imposta(TipoNotifica.primaDiPartire, accesa: true);
    expect(await promemoria.spente(), isEmpty);
    expect(programmate(), hasLength(1));
    expect(await eventi(Eventi.notificaImpostata), [
      {'tipo': 'prima_di_partire', 'accesa': false},
      {'tipo': 'prima_di_partire', 'accesa': true},
    ]);
  });

  test(
    'il permesso: da chiedere, poi quello che risponde il telefono',
    () async {
      await partenza();
      expect(await promemoria.permesso(), PermessoNotifiche.daChiedere);
      expect(await promemoria.daProporre(), isTrue);

      expect(
        await promemoria.chiedi(da: 'viaggio'),
        PermessoNotifiche.concesso,
      );
      expect(await promemoria.permesso(), PermessoNotifiche.concesso);
      expect(await promemoria.daProporre(), isFalse);
      expect(programmate(), hasLength(1));
      expect(await eventi(Eventi.permessoNotifiche), [
        {'esito': 'concesso', 'da': 'viaggio'},
      ]);
    },
  );

  test('dopo un no del telefono non si insiste', () async {
    ambiente.notifiche.risposta = false;
    expect(
      await promemoria.chiedi(da: 'impostazioni'),
      PermessoNotifiche.negato,
    );
    expect(await promemoria.permesso(), PermessoNotifiche.negato);
    expect(await promemoria.daProporre(), isFalse);
    expect(await eventi(Eventi.permessoNotifiche), [
      {'esito': 'negato', 'da': 'impostazioni'},
    ]);
  });

  test('dopo «Non ora» il foglio torna da solo solo fra un mese', () async {
    await promemoria.nonOra();
    expect(await promemoria.daProporre(), isFalse);
    adesso = alle(29, 12);
    expect(await promemoria.daProporre(), isFalse);
    adesso = alle(30, 12);
    expect(await promemoria.daProporre(), isTrue);
    expect(await eventi(Eventi.permessoNotifiche), [
      {'esito': 'non_ora', 'da': 'viaggio'},
    ]);
  });

  test('una notifica toccata porta dove deve, e si conta', () async {
    final toccate = <DovePorta>[];
    final ascolto = promemoria.toccate.listen(toccate.add);
    addTearDown(ascolto.cancel);
    const dove = (
      tipo: TipoNotifica.tappeDaSegnare,
      viaggioId: 'v',
      giornoId: 'g',
    );
    ambiente.notifiche.tocca(dove);
    await pumpEventQueue();
    expect(toccate, [dove]);
    expect(await eventi(Eventi.notificaAperta), [
      {'tipo': 'tappe_da_segnare'},
    ]);
  });

  test('segue la copia: cambia, e si riprogramma da solo', () async {
    ambiente.notifiche.attive = true;
    await partenza();
    await promemoria.avvia();
    expect(programmate(), hasLength(1));
    final prima = ambiente.notifiche.programmazioni;

    await (ambiente.db.update(ambiente.db.vociLista))
        .write(const VociListaCompanion(spuntata: Value(true)));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(ambiente.notifiche.programmazioni, greaterThan(prima));
    expect(programmate().single.testo, isNot(contains('valigia')));
  });

  test('uscendo dall\'account si tolgono tutte', () async {
    ambiente.notifiche.attive = true;
    await partenza();
    await promemoria.ripianifica();
    expect(programmate(), hasLength(1));

    io = null;
    await promemoria.ripianifica();
    expect(programmate(), isEmpty);
  });
}
