import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/aspetto/elementi.dart';
import 'package:trolley/dati/acquisizione.dart';
import 'package:trolley/dati/database.dart';
import 'package:trolley/dominio/calendario.dart';
import 'package:trolley/dominio/tappe.dart';
import 'package:trolley/schermate/adesso.dart';
import 'package:trolley/schermate/viaggi.dart';

import '../aiuti.dart';

/// «Adesso», mentre il viaggio è in corso (fase 3.1): la tappa di adesso da
/// segnare con un tocco, cosa viene dopo, il documento di questo momento, una
/// spesa con un tocco e l'importo; la giornata libera, senza rete, due
/// viaggi in corso.
void main() {
  late Ambiente ambiente;

  setUp(() => ambiente = Ambiente());
  tearDown(() => ambiente.chiudi());

  final oggi = soloData(DateTime.now());
  String fra(int giorni) => scriviData(oggi.add(Duration(days: giorni)));
  DateTime alle(int ore, [int minuti = 0]) =>
      DateTime(oggi.year, oggi.month, oggi.day, ore, minuti);
  const marco = '22222222-2222-4222-8222-222222222222';

  /// Porto, cominciato ieri: oggi è il giorno 2 di 3, g2 dalle 9.
  Future<void> viaggio(
    WidgetTester tester, {
    List<Map<String, Object?>> tappe = const [],
    bool conMarco = false,
  }) async {
    ambiente.server
      ..viaggi.add(
        rigaViaggio('v', stato: 'definito', inizio: fra(-1), fine: fra(1)),
      )
      ..partecipazioni.add(rigaPartecipazione('v'))
      ..giorni.addAll([
        rigaGiorno('v', fra(-1), '10:00:00', '24:00:00', id: 'g1'),
        rigaGiorno('v', fra(0), '09:00:00', '24:00:00', id: 'g2'),
        rigaGiorno('v', fra(1), '00:00:00', '18:00:00', id: 'g3'),
      ])
      // Copie: il server finto cambia le righe che riceve.
      ..tappe.addAll([
        for (final t in tappe) {...t},
      ])
      ..tassi.add(rigaTasso('EUR', 1, fra(0)));
    if (conMarco) {
      ambiente.server
        ..partecipazioni.add(
          rigaPartecipazione('v', utente: marco, ruolo: 'partecipante'),
        )
        ..utenti.add({
          'id': marco,
          'nome': 'Marco',
          'versione': 1,
          'eliminato_il': null,
        });
    }
    await ambiente.accedi(tester: tester);
    await tester.runAsync(ambiente.archivio.aggiornaCopia);
  }

  /// La giornata di oggi: il Duomo già fatto, poi Lello alle 10:30, la torre
  /// alle 12, la cena dopo.
  final giornata = [
    rigaDiTappa(
      'duomo',
      viaggio: 'v',
      giorno: 'g2',
      titolo: 'Sé do Porto',
      durata: 60,
      stato: 'completata',
    ),
    rigaDiTappa(
      'lello',
      viaggio: 'v',
      giorno: 'g2',
      ordine: 2,
      titolo: 'Livraria Lello',
      durata: 60,
      ora: '10:30:00',
    ),
    rigaDiTappa(
      'torre',
      viaggio: 'v',
      giorno: 'g2',
      ordine: 3,
      titolo: 'Torre dos Clérigos',
      durata: 90,
      ora: '12:00:00',
    ),
    rigaDiTappa(
      'cena',
      viaggio: 'v',
      giorno: 'g2',
      ordine: 4,
      titolo: 'Cena',
      tipo: 'pasto',
      durata: 90,
    ),
  ];

  /// Lascia arrivare le scritture: il database vero non avanza nel tempo
  /// finto dei test.
  Future<void> aspetta(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> adesso(WidgetTester tester, DateTime quando) async {
    await ambiente.monta(
      tester,
      SchermataAdesso(viaggioId: 'v', orologio: () => quando),
    );
    await aspetta(tester);
  }

  Future<Documento> documento(
    WidgetTester tester,
    String nome, {
    required String giorno,
    Duration? ora,
  }) async => (await tester.runAsync(() async {
    final arrivo = File('${ambiente.cartella.path}/$nome.pdf')
      ..writeAsStringSync('contenuto');
    return ambiente.documenti.aggiungi(
      viaggioId: 'v',
      giornoId: giorno,
      ora: ora,
      nome: nome,
      sorgente: FileAcquisito(
        percorso: arrivo.path,
        sorgente: Sorgente.file,
        nome: '$nome.pdf',
      ),
    );
  }))!;

  Future<List<(String, Map<String, dynamic>)>> eventi(
    WidgetTester tester,
  ) async => [
    for (final e in await ambiente.eventi(tester))
      (e.nome, jsonDecode(e.proprieta) as Map<String, dynamic>),
    // Quelli già partiti.
    for (final r in ambiente.server.chiamate('POST', '/rest/v1/evento'))
      for (final e in (jsonDecode(r.body) as List).cast<Map<String, dynamic>>())
        (e['nome'] as String, e['proprieta'] as Map<String, dynamic>),
  ];

  Future<List<OperazioneInCoda>> inCoda(WidgetTester tester) async =>
      (await tester.runAsync(
        () => ambiente.db.select(ambiente.db.codaScrittura).get(),
      ))!;

  Finder pulsante(String etichetta) => find.descendant(
    of: find.byType(PulsanteGrande),
    matching: find.text(etichetta),
  );

  testWidgets('tre cose in un colpo d\'occhio: la tappa di adesso, cosa '
      'viene dopo e fra quanto, il documento di questo momento', (
    tester,
  ) async {
    await viaggio(tester, tappe: giornata);
    await documento(
      tester,
      'Biglietto Lello',
      giorno: 'g2',
      ora: const Duration(hours: 10, minutes: 30),
    );
    await adesso(tester, alle(11, 5));

    expect(find.text('PORTO · GIORNO 2 DI 3'), findsOneWidget);
    expect(find.text('ORA · 10:30–11:30'), findsOneWidget);
    expect(find.text('Livraria Lello'), findsOneWidget);
    expect(find.text('Visita · 1 h'), findsOneWidget);
    expect(find.text('DOPO · TRA 55 MINUTI'), findsOneWidget);
    expect(find.text('Torre dos Clérigos'), findsOneWidget);
    expect(find.text('12:00 · Visita · 1 h 30'), findsOneWidget);
    expect(find.text('IL DOCUMENTO DI ADESSO'), findsOneWidget);
    expect(find.text('Biglietto Lello'), findsOneWidget);
    // La tappa già fatta non è più quella di adesso.
    expect(find.text('Sé do Porto'), findsNothing);
  });

  testWidgets('«Fatta» segna la tappa con un tocco, durante il viaggio, e '
      'adesso diventa la seguente', (tester) async {
    await viaggio(tester, tappe: giornata);
    await adesso(tester, alle(11, 5));

    await tester.tap(find.text('Fatta'));
    await aspetta(tester);

    final lello = ambiente.server.tappe.singleWhere((t) => t['id'] == 'lello');
    expect(lello['stato'], StatoTappa.completata.codice);
    expect(lello['marcata_durante_il_viaggio'], isTrue);
    expect(find.text('ALLE 12:00–13:30'), findsOneWidget);
    expect(find.text('Torre dos Clérigos'), findsOneWidget);
    expect(find.text('DOPO · TRA 2 ORE E 25 MINUTI'), findsOneWidget);
    expect(find.text('Cena'), findsOneWidget);
    final marcata = (await eventi(tester))
        .singleWhere((e) => e.$1 == 'tappa_marcata');
    expect(marcata.$2, {'viaggio_id': 'v', 'durante_il_viaggio': true});
  });

  testWidgets('se il programma è indietro non si rimprovera niente: si dice '
      'da quando era in programma, e cosa resta', (tester) async {
    await viaggio(tester, tappe: giornata);
    await adesso(tester, alle(12, 10));

    expect(find.text('IN PROGRAMMA DALLE 10:30'), findsOneWidget);
    expect(find.text('Livraria Lello'), findsOneWidget);
    expect(find.text('Restano 3 tappe oggi, fino alle 15:00.'), findsOneWidget);
    // La torre doveva cominciare alle 12: non si dice «fra» un tempo passato.
    expect(find.text('DOPO'), findsOneWidget);
  });

  testWidgets('una giornata senza tappe si dice libera, e guarda a domani con '
      'il suo documento', (tester) async {
    await viaggio(
      tester,
      tappe: [
        rigaDiTappa(
          'mercato',
          viaggio: 'v',
          giorno: 'g3',
          titolo: 'Mercado do Bolhão',
          ora: '09:00:00',
          durata: 60,
        ),
        rigaDiTappa('foz', viaggio: 'v', giorno: 'g3', ordine: 2, durata: 60),
      ],
    );
    await documento(
      tester,
      'Volo di ritorno',
      giorno: 'g3',
      ora: const Duration(hours: 18, minutes: 40),
    );
    await adesso(tester, alle(11));

    expect(find.text('Oggi niente in programma'), findsOneWidget);
    expect(find.textContaining('DOMANI · '), findsOneWidget);
    expect(find.text('Mercado do Bolhão'), findsOneWidget);
    expect(
      find.text('09:00 · e un\'altra tappa, fino alle 11:00'),
      findsOneWidget,
    );
    expect(find.text('IL DOCUMENTO DI DOMANI'), findsOneWidget);
    expect(find.text('Volo di ritorno'), findsOneWidget);
    expect(pulsante('Aggiungi una tappa'), findsOneWidget);
  });

  testWidgets('senza rete lo dice una volta con l\'età della copia, i gesti '
      'funzionano e si contano quelli in attesa', (tester) async {
    await viaggio(tester, tappe: giornata);
    ambiente.rete.disponibile = false;
    await adesso(tester, alle(11, 5));

    expect(find.text('Sei offline'), findsOneWidget);
    expect(
      find.textContaining('Stai vedendo la copia sul telefono, aggiornata'),
      findsOneWidget,
    );
    await tester.tap(find.text('Salta'));
    await aspetta(tester);

    expect((await inCoda(tester)).single.gesto, GestoOffline.marcaTappa);
    expect(
      find.text('Una cosa fatta senza rete aspetta di partire'),
      findsOneWidget,
    );
    expect(find.text('Torre dos Clérigos'), findsWidgets);
    final apertura = (await eventi(tester))
        .singleWhere((e) => e.$1 == 'apertura_senza_rete');
    expect(apertura.$2, {'schermata': 'adesso', 'mancante': null});
  });

  testWidgets('una spesa costa un tocco più l\'importo: in euro, oggi, pagata '
      'da te per tutti', (tester) async {
    await viaggio(tester, tappe: giornata, conMarco: true);
    await adesso(tester, alle(11, 5));

    await tester.tap(pulsante('Spesa'));
    await aspetta(tester);
    expect(find.text('Una spesa'), findsOneWidget);
    expect(
      find.text(
        'In euro, oggi, pagata da te per tutti e due: il resto è già scelto.',
      ),
      findsOneWidget,
    );
    for (final tasto in ['1', '2', ',', '5']) {
      await tester.tap(find.text(tasto).last);
      await tester.pump();
    }
    expect(find.text('12,5'), findsOneWidget);
    await tester.tap(pulsante('Registra'));
    await aspetta(tester);

    expect(find.text('Una spesa'), findsNothing);
    final spesa = ambiente.server.spese.single;
    expect(spesa['importo'], 12.5);
    expect(spesa['valuta'], 'EUR');
    expect(spesa['data'], fra(0));
    expect(spesa['pagante_id'], idDiProva);
    expect(
      {for (final q in ambiente.server.quote) q['utente_id']: q['quota']},
      {idDiProva: 6.25, marco: 6.25},
    );
    final funzione = (await eventi(tester))
        .singleWhere((e) => e.$1 == 'funzione_usata_nel_viaggio');
    expect(funzione.$2, {'viaggio_id': 'v', 'funzione': 'spese'});
  });

  testWidgets('da soli non si parla di dividere, e senza importo non si '
      'registra', (tester) async {
    await viaggio(tester, tappe: giornata);
    await adesso(tester, alle(11, 5));

    await tester.tap(pulsante('Spesa'));
    await aspetta(tester);
    expect(find.text('In euro, oggi: il resto è già scelto.'), findsOneWidget);
    await tester.tap(pulsante('Registra'));
    await aspetta(tester);
    expect(find.text('Una spesa'), findsOneWidget);
    expect(ambiente.server.spese, isEmpty);
  });

  testWidgets('«Oggi» mostra la giornata come percorso, e porta a quella '
      'intera', (tester) async {
    await viaggio(tester, tappe: giornata);
    await adesso(tester, alle(11, 5));

    await tester.tap(find.text('Oggi'));
    await aspetta(tester);
    expect(find.text('Sé do Porto'), findsOneWidget);
    expect(find.text('Cena'), findsOneWidget);
    expect(pulsante('La giornata intera'), findsOneWidget);
  });

  testWidgets('con un viaggio in corso l\'app si apre su «adesso»', (
    tester,
  ) async {
    await viaggio(tester, tappe: giornata);
    await ambiente.monta(tester, SchermataViaggi(onCodice: (_) {}));
    await aspetta(tester);

    expect(find.byType(SchermataAdesso), findsOneWidget);
    expect(find.text('Adesso'), findsWidgets);
  });

  testWidgets('con due viaggi in corso si sceglie, e la scelta vale fino a '
      'sera', (tester) async {
    await viaggio(tester, tappe: giornata);
    ambiente.server
      ..viaggi.add(
        rigaViaggio(
          'w',
          stato: 'definito',
          citta: 'Milano',
          paese: 'IT',
          inizio: fra(0),
          fine: fra(1),
        ),
      )
      ..partecipazioni.add(rigaPartecipazione('w'))
      ..giorni.addAll([
        rigaGiorno('w', fra(0), '10:00:00', '24:00:00'),
        rigaGiorno('w', fra(1), '00:00:00', '18:00:00'),
      ]);
    await tester.runAsync(ambiente.archivio.aggiornaCopia);
    await ambiente.monta(tester, SchermataViaggi(onCodice: (_) {}));
    await aspetta(tester);

    expect(find.text('Due viaggi in corso'), findsOneWidget);
    await tester.tap(find.text('Milano'));
    await aspetta(tester);
    expect(find.text('MILANO · GIORNO 1 DI 2'), findsOneWidget);
    expect(
      await tester.runAsync(
        () => ambiente.archivio.viaggioSceltoOggi(DateTime.now()),
      ),
      'w',
    );
  });
}
