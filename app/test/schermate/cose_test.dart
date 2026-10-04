import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/aspetto/elementi.dart';
import 'package:trolley/aspetto/timbro.dart';
import 'package:trolley/dati/database.dart';
import 'package:trolley/schermate/cose.dart';
import 'package:trolley/schermate/viaggio.dart';

import '../aiuti.dart';

/// Le cose da portare (fase 1.5): la lista c'è anche nelle idee, si scrive una
/// voce dopo l'altra, senza rete si legge e si spunta, e quello che è in
/// valigia scende in fondo senza sparire.
void main() {
  late Ambiente ambiente;

  setUp(() => ambiente = Ambiente());
  tearDown(() => ambiente.chiudi());

  /// Un'idea, Giappone in autunno, con le voci date.
  Future<void> idea(
    WidgetTester tester, {
    List<Map<String, Object?>> voci = const [],
  }) async {
    ambiente.server
      ..viaggi.add(
        rigaViaggio('v', citta: null, paese: 'JP', periodo: 'autunno 2099'),
      )
      ..partecipazioni.add(rigaPartecipazione('v'))
      ..voci.addAll(voci);
    await ambiente.accedi(tester: tester);
    await tester.runAsync(ambiente.archivio.aggiornaCopia);
  }

  Future<List<(String, Map<String, dynamic>)>> eventi(
    WidgetTester tester,
  ) async => [
    for (final e in await ambiente.eventi(tester))
      (e.nome, jsonDecode(e.proprieta) as Map<String, dynamic>),
    for (final r in ambiente.server.chiamate('POST', '/rest/v1/evento'))
      for (final e in (jsonDecode(r.body) as List).cast<Map<String, dynamic>>())
        (e['nome'] as String, e['proprieta'] as Map<String, dynamic>),
  ];

  Future<List<OperazioneInCoda>> inCoda(WidgetTester tester) async =>
      (await tester.runAsync(
        () => ambiente.db.select(ambiente.db.codaScrittura).get(),
      ))!;

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

  /// Il cerchio di una voce, come lo trova VoiceOver.
  Finder cerchio(String inizio) => find.bySemanticsLabel(RegExp('^$inizio,'));

  testWidgets('dall\'idea si scrive la lista, una voce dopo l\'altra, e il '
      'primo elemento si misura', (tester) async {
    await idea(tester);
    await ambiente.monta(tester, const SchermataViaggio(viaggioId: 'v'));

    await tester.scrollUntilVisible(find.text('Scrivi la lista'), 200);
    // Che non resti sotto la barra in basso.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(find.text('Cose da portare'), findsOneWidget);
    await tester.tap(find.text('Scrivi la lista'));
    await tester.pumpAndSettle();

    expect(find.text('Aggiungi una cosa…'), findsOneWidget);
    for (final cosa in ['Passaporto', 'Adattatore tipo A']) {
      await tester.enterText(find.byType(TextField).last, cosa);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await aspetta(tester);
    }

    expect(find.text('Passaporto'), findsOneWidget);
    expect(find.text('Adattatore tipo A'), findsOneWidget);
    expect(find.text('DA METTERE · 2'), findsOneWidget);
    expect(find.text('0 di 2'), findsOneWidget);
    final righe = ambiente.server.voci;
    expect(righe.map((r) => r['testo']), ['Passaporto', 'Adattatore tipo A']);
    expect(righe.every((r) => r['tipo'] == 'personale'), isTrue);

    final registrati = await eventi(tester);
    expect(
      registrati.singleWhere((e) => e.$1 == 'primo_elemento_aggiunto').$2,
      containsPair('tipo', 'voce'),
    );
    expect(
      registrati.singleWhere((e) => e.$1 == 'funzione_usata_nel_viaggio').$2,
      {'viaggio_id': 'v', 'funzione': 'liste'},
    );
    // Nessun testo negli eventi (07, regola 1).
    expect(
      jsonEncode([for (final e in registrati) e.$2]),
      isNot(contains('Passaporto')),
    );
  });

  testWidgets('senza rete si legge e si spunta: la voce scende in valigia e '
      'parte quando torna la rete', (tester) async {
    await idea(
      tester,
      voci: [
        rigaDiVoce('passaporto', viaggio: 'v'),
        rigaDiVoce('magliette', viaggio: 'v', testo: 'Magliette', quantita: 5),
      ],
    );
    ambiente.rete.disponibile = false;
    await ambiente.monta(tester, const SchermataCose(viaggioId: 'v'));

    expect(find.byType(SeiOffline), findsOneWidget);
    expect(find.text('× 5'), findsOneWidget);
    // Aggiungere richiede la rete, e lo dice prima.
    expect(
      find.text(
        'Senza rete si spunta e basta: per aggiungere serve la connessione.',
      ),
      findsOneWidget,
    );

    await tester.tap(cerchio('Passaporto'));
    await aspetta(tester);
    // Resta un attimo dov'era, poi scende.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('IN VALIGIA · 1'), findsOneWidget);
    expect(find.text('DA METTERE · 1'), findsOneWidget);
    expect(
      find.text('Le spunte restano qui e partono quando torna la rete.'),
      findsOneWidget,
    );
    // È in coda, e partirà con la rete (l'invio è provato in
    // test/dati/liste_test.dart).
    final op = (await inCoda(tester)).single;
    expect(op.gesto, GestoOffline.spuntaVoce);
    expect(ambiente.server.voci.first['spuntata'], isFalse);

    final registrati = await eventi(tester);
    expect(
      registrati.where(
        (e) => e.$1 == 'apertura_senza_rete' && e.$2['schermata'] == 'liste',
      ),
      hasLength(1),
    );
  });

  testWidgets('tutto in valigia: il timbro; «…» rimette tutto da mettere', (
    tester,
  ) async {
    await idea(
      tester,
      voci: [
        rigaDiVoce('passaporto', viaggio: 'v', spuntata: true),
        rigaDiVoce('felpa', viaggio: 'v', testo: 'Felpa'),
      ],
    );
    await ambiente.monta(tester, const SchermataCose(viaggioId: 'v'));
    expect(find.byType(Timbro), findsNothing);

    await tester.tap(cerchio('Felpa'));
    await aspetta(tester);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.byType(Timbro), findsOneWidget);
    expect(find.text('IN VALIGIA · 2'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Altro'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rimetti tutto da mettere'));
    await aspetta(tester);

    expect(find.byType(Timbro), findsNothing);
    expect(find.text('DA METTERE · 2'), findsOneWidget);
    expect(ambiente.server.voci.every((v) => v['spuntata'] == false), isTrue);
  });

  testWidgets('una voce si cambia con la rete: quante; senza rete lo dice '
      'prima', (tester) async {
    await idea(
      tester,
      voci: [rigaDiVoce('magliette', viaggio: 'v', testo: 'Magliette')],
    );
    await ambiente.monta(tester, const SchermataCose(viaggioId: 'v'));

    await tester.tap(find.bySemanticsLabel('Cambia Magliette'));
    await tester.pumpAndSettle();
    expect(find.text('La voce'), findsOneWidget);
    expect(find.text('Niente da salvare'), findsOneWidget);

    final piu = find.byIcon(Icons.add_rounded).last;
    for (var i = 0; i < 4; i++) {
      await tester.tap(piu);
      await tester.pump();
    }
    await tester.tap(
      find.descendant(
        of: find.byType(PulsanteGrande),
        matching: find.text('Salva'),
      ),
    );
    await aspetta(tester);

    expect(find.text('La voce'), findsNothing);
    expect(ambiente.server.voci.single['quantita'], 5);
    expect(find.text('× 5'), findsOneWidget);

    ambiente.rete.disponibile = false;
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Cambia Magliette × 5'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Magliette leggere');
    await tester.pump();
    expect(find.text('Serve la connessione'), findsWidgets);
  });
}
