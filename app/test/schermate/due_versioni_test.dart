import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/aspetto/elementi.dart';
import 'package:trolley/dati/conflitti.dart';
import 'package:trolley/dominio/conflitti.dart';
import 'package:trolley/schermate/cose.dart';
import 'package:trolley/schermate/due_versioni.dart';
import 'package:trolley/schermate/foglio_voce.dart';

import '../aiuti.dart';

/// Due versioni (fase 2.2; tela, 34–36): si vedono la propria e quella già
/// salvata, con chi e quando; si sceglie con un tocco, e chiudendo senza
/// scegliere quello che si era scritto resta lì.
void main() {
  late Ambiente ambiente;
  const marco = 'marco';

  setUp(() => ambiente = Ambiente());
  tearDown(() => ambiente.chiudi());

  Future<void> viaggio(
    WidgetTester tester, {
    List<Map<String, Object?>> voci = const [],
  }) async {
    ambiente.server
      ..viaggi.add(
        rigaViaggio('v', citta: null, paese: 'JP', periodo: 'autunno 2099'),
      )
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
      ..voci.addAll(voci);
    await ambiente.accedi(tester: tester);
    await tester.runAsync(ambiente.archivio.aggiornaCopia);
  }

  /// Gli eventi misurati, come `nome {proprietà}`.
  Future<List<String>> eventi(WidgetTester tester) async => [
    for (final e in await ambiente.eventi(tester)) '${e.nome} ${e.proprieta}',
    for (final r in ambiente.server.chiamate('POST', '/rest/v1/evento'))
      for (final e in (jsonDecode(r.body) as List).cast<Map<String, dynamic>>())
        '${e['nome']} ${jsonEncode(e['proprieta'])}',
  ];

  /// Lascia arrivare le scritture: il database vero non avanza nel tempo
  /// finto dei test.
  Future<void> aspetta(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Finder pulsante(String etichetta) => find.descendant(
    of: find.byType(PulsanteGrande),
    matching: find.text(etichetta),
  );

  /// Cambia il testo della voce [testo] nel suo foglio e salva.
  Future<void> riscrivi(WidgetTester tester, String testo, String nuovo) async {
    await tester.tap(find.bySemanticsLabel('Cambia $testo'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(FoglioVoce),
        matching: find.byType(TextField),
      ),
      nuovo,
    );
    await tester.pump();
    await tester.tap(pulsante('Salva'));
    // Il rifiuto, la rilettura, e i nomi per la schermata delle due.
    await aspetta(tester);
    await aspetta(tester);
  }

  testWidgets('riscritta da un altro telefono: si vedono le due, e si tengono '
      'tutte e due', (tester) async {
    await viaggio(
      tester,
      voci: [rigaDiVoce('a', viaggio: 'v', testo: 'Adattatore')],
    );
    await ambiente.monta(tester, const SchermataCose(viaggioId: 'v'));
    // Intanto, dall'altro telefono della stessa persona.
    ambiente.server.voci.single
      ..['testo'] = 'Adattatore tipo A'
      ..['quantita'] = 2
      ..['versione'] = 2
      ..['modificato_da'] = idDiProva;

    await riscrivi(tester, 'Adattatore', 'Adattatore universale');

    expect(find.text('Due versioni'), findsOneWidget);
    expect(find.text('LA TUA'), findsOneWidget);
    expect(find.text('DALL\'ALTRO TELEFONO'), findsOneWidget);
    expect(find.text('Adattatore universale'), findsOneWidget);
    expect(find.text('Adattatore tipo A'), findsOneWidget);
    expect(pulsante('Tieni l\'altra'), findsOneWidget);

    await tester.tap(pulsante('Tienile tutte e due'));
    await aspetta(tester);

    expect(find.text('Due versioni'), findsNothing);
    expect(find.text('La voce'), findsNothing);
    expect(
      ambiente.server.voci.map((v) => v['testo']),
      unorderedEquals(['Adattatore tipo A', 'Adattatore universale']),
    );
    final misurati = await eventi(tester);
    expect(misurati, contains('conflitto_mostrato {"tipo":"voce"}'));
    expect(
      misurati,
      contains('conflitto_risolto {"tipo":"voce","scelta":"entrambe"}'),
    );
  });

  testWidgets('chiudendo senza scegliere si torna al foglio, con quello che '
      'si era scritto', (tester) async {
    await viaggio(
      tester,
      voci: [rigaDiVoce('a', viaggio: 'v', testo: 'Adattatore')],
    );
    await ambiente.monta(tester, const SchermataCose(viaggioId: 'v'));
    ambiente.server.voci.single
      ..['testo'] = 'Adattatore tipo A'
      ..['versione'] = 2;

    await riscrivi(tester, 'Adattatore', 'Adattatore universale');
    await tester.tap(find.bySemanticsLabel('Chiudi'));
    await tester.pumpAndSettle();

    expect(find.text('Due versioni'), findsNothing);
    expect(find.text('La voce'), findsOneWidget);
    expect(find.text('Adattatore universale'), findsOneWidget);
    expect(ambiente.server.voci.single['testo'], 'Adattatore tipo A');
    final misurati = await eventi(tester);
    expect(misurati, contains('conflitto_mostrato {"tipo":"voce"}'));
    expect(misurati.where((e) => e.startsWith('conflitto_risolto')), isEmpty);
  });

  testWidgets('una spesa cambiata da Marco: si dice chi e quando, e si tiene '
      'la sua', (tester) async {
    await viaggio(tester);
    final conflitto = Conflitto(
      cosa: CosaInConflitto.spesa,
      id: 's',
      viaggioId: 'v',
      mia: {
        'importo': 4200,
        'valuta': 'EUR',
        'data': '2026-10-10',
        'descrizione': 'Cena da Cantinho',
        campoEliminato: false,
      },
      loro: {
        'importo': 4800,
        'valuta': 'EUR',
        'data': '2026-10-10',
        'descrizione': 'Cena da Cantinho',
        campoEliminato: false,
      },
      versioneLoro: 3,
      autoreId: marco,
      salvataIl: DateTime(2026, 10, 3, 19, 5),
    );
    await ambiente.monta(tester, SchermataDueVersioni(conflitto: conflitto));
    await aspetta(tester);

    expect(find.text('DI MARCO'), findsOneWidget);
    expect(find.text('salvata il 3 ott, 19:05'), findsOneWidget);
    expect(find.text('42,00\u00a0€'), findsOneWidget);
    expect(find.text('48,00\u00a0€'), findsOneWidget);
    expect(find.text('Cena da Cantinho'), findsNWidgets(2));
    expect(find.textContaining('Sui soldi non si indovina'), findsOneWidget);
    expect(pulsante('Tienile tutte e due'), findsNothing);

    await tester.tap(pulsante('Tieni quella di Marco'));
    await aspetta(tester);
    expect(
      ambiente.server.chiamate('POST', '/rest/v1/rpc/cambia_spesa'),
      isEmpty,
    );
    expect(
      await eventi(tester),
      contains('conflitto_risolto {"tipo":"spesa","scelta":"loro"}'),
    );
  });

  testWidgets('tolta da Marco mentre la si cambiava: si può rimetterla, ma '
      'senza rete lo dice prima', (tester) async {
    await viaggio(tester);
    final conflitto = Conflitto(
      cosa: CosaInConflitto.voce,
      id: 'a',
      viaggioId: 'v',
      mia: {
        'testo': 'Adattatore universale',
        'quantita': 1,
        campoEliminato: false,
      },
      loro: {'testo': 'Adattatore', 'quantita': 1, campoEliminato: true},
      versioneLoro: 2,
      autoreId: marco,
      salvataIl: DateTime.now(),
    );
    ambiente.rete.disponibile = false;
    await ambiente.monta(tester, SchermataDueVersioni(conflitto: conflitto));
    await aspetta(tester);

    expect(find.text('Tolta'), findsOneWidget);
    expect(find.textContaining('Marco ha tolto questa voce'), findsOneWidget);
    expect(pulsante('Rimettila con la tua'), findsOneWidget);
    expect(pulsante('Lasciala tolta'), findsOneWidget);
    expect(pulsante('Tienile tutte e due'), findsNothing);
    expect(find.text('Serve la connessione'), findsOneWidget);
  });

  testWidgets('una voce del viaggio: si vede chi la porta; se nella propria '
      'la portava chi è uscito, la propria non si tiene', (tester) async {
    const luca = '33333333-3333-4333-8333-333333333333';
    ambiente.server
      ..partecipazioni.add(
        rigaPartecipazione(
          'v',
          utente: luca,
          ruolo: 'partecipante',
          stato: 'uscito',
        ),
      )
      ..utenti.add({
        'id': luca,
        'nome': 'Luca',
        'versione': 1,
        'eliminato_il': null,
      });
    await viaggio(
      tester,
      voci: [
        rigaDiVoce(
          'a',
          viaggio: 'v',
          testo: 'Adattatore',
          tipo: 'viaggio',
          lasciataDa: luca,
        ),
      ],
    );
    final conflitto = Conflitto(
      cosa: CosaInConflitto.voce,
      id: 'a',
      viaggioId: 'v',
      mia: {
        'testo': 'Adattatore universale',
        'quantita': 1,
        'assegnato_a': luca,
        campoEliminato: false,
      },
      loro: {
        'testo': 'Adattatore',
        'quantita': 1,
        'assegnato_a': null,
        campoEliminato: false,
      },
      versioneLoro: 2,
      autoreId: marco,
      salvataIl: DateTime.now(),
    );
    await ambiente.monta(tester, SchermataDueVersioni(conflitto: conflitto));
    // Il contesto legge nomi, voce e chi c'è dalla copia.
    await aspetta(tester);
    await aspetta(tester);

    expect(find.text('Chi la porta'), findsNWidgets(2));
    expect(find.text('Luca'), findsOneWidget);
    expect(find.text('Nessuno'), findsOneWidget);
    expect(find.text('Luca non è più nel viaggio'), findsWidgets);
    await tester.tap(pulsante('Tieni la tua'));
    await aspetta(tester);
    expect(find.text('Due versioni'), findsOneWidget);
    expect(ambiente.server.chiamate('PATCH', '/rest/v1/voce_lista'), isEmpty);
  });
}
