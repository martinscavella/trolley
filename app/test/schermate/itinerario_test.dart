import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/aspetto/elementi.dart';
import 'package:trolley/dominio/calendario.dart';
import 'package:trolley/schermate/note.dart';
import 'package:trolley/schermate/viaggio.dart';

import '../aiuti.dart';

/// L'itinerario con un assistente (fase 1.6): si copia la richiesta, si
/// incolla la risposta, si vede cosa entra e si aggiunge. La risposta si salva
/// sempre come nota.
void main() {
  late Ambiente ambiente;

  setUp(() => ambiente = Ambiente());
  tearDown(() => ambiente.chiudi());

  final oggi = soloData(DateTime.now());
  String fra(int giorni) => scriviData(oggi.add(Duration(days: giorni)));

  /// Porto, un giorno solo fra due settimane: dalle 10 alle 18, otto ore.
  Future<void> viaggio(WidgetTester tester) async {
    ambiente.server
      ..viaggi.add(
        rigaViaggio(
          'v',
          stato: 'definito',
          inizio: fra(14),
          fine: fra(14),
          arrivo: '10:00:00',
          partenza: '18:00:00',
        ),
      )
      ..partecipazioni.add(rigaPartecipazione('v'))
      ..giorni.add(rigaGiorno('v', fra(14), '10:00:00', '18:00:00', id: 'g1'));
    await ambiente.accedi(tester: tester);
    await tester.runAsync(ambiente.archivio.aggiornaCopia);
  }

  /// Gli appunti del telefono, finti.
  String? appunti;
  void appuntiFinti(WidgetTester tester) {
    appunti = null;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (chiamata) async {
        switch (chiamata.method) {
          case 'Clipboard.setData':
            appunti = (chiamata.arguments as Map)['text'] as String?;
          case 'Clipboard.getData':
            return {'text': appunti};
          case 'Clipboard.hasStrings':
            return {'value': appunti != null};
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
  }

  Finder pulsante(String etichetta) => find.descendant(
    of: find.byType(PulsanteGrande),
    matching: find.text(etichetta),
  );

  Future<List<(String, Map<String, dynamic>)>> eventi(
    WidgetTester tester,
  ) async => [
    for (final e in await ambiente.eventi(tester))
      (e.nome, jsonDecode(e.proprieta) as Map<String, dynamic>),
    for (final r in ambiente.server.chiamate('POST', '/rest/v1/evento'))
      for (final e in (jsonDecode(r.body) as List).cast<Map<String, dynamic>>())
        (e['nome'] as String, e['proprieta'] as Map<String, dynamic>),
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

  Future<void> apriItinerario(WidgetTester tester) async {
    await ambiente.monta(tester, const SchermataViaggio(viaggioId: 'v'));
    // Aprire il viaggio riscarica la copia: la si lascia finire.
    await aspetta(tester);
    final ingresso = find.text('Un itinerario con il tuo assistente');
    await tester.scrollUntilVisible(ingresso, 200);
    // Che non resti sotto la barra in basso.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(ingresso);
    await tester.pumpAndSettle();
  }

  const risposta = '''
Ecco una giornata a Porto!

```
TROLLEY ITINERARIO
DESTINAZIONE: Porto
GIORNO 1
10:30 | Livraria Lello | visita | 60 | Rua das Carmelitas
12:00 | Pranzo al Mercado do Bolhão | pasto | 90
14:00 | Torre dei Clérigos | visita | 60
15:30 | Palácio da Bolsa | visita | 120
18:00 | Crociera sul Douro | escursione | 180
```
''';

  testWidgets('si copia la richiesta, si incolla la risposta, si aggiunge '
      'quello che entra; la risposta resta come nota', (tester) async {
    appuntiFinti(tester);
    await viaggio(tester);
    await apriItinerario(tester);

    expect(find.text('L\'itinerario con il tuo assistente'), findsOneWidget);
    // I modelli da consigliare vengono dalla configurazione del server.
    await tester.scrollUntilVisible(
      find.textContaining('Claude Sonnet 5 o superiore'),
      200,
      scrollable: find
          .ancestor(
            of: find.text('Che ritmo?'),
            matching: find.byType(Scrollable),
          )
          .first,
    );

    await tester.tap(pulsante('Copia la richiesta'));
    await aspetta(tester);
    expect(find.text('Copiata · copia di nuovo'), findsOneWidget);
    expect(appunti, contains('viaggio a Porto, Portogallo'));
    expect(appunti, contains('dalle 10:00 alle 18:00'));
    expect(appunti, contains('TROLLEY ITINERARIO'));

    appunti = risposta;
    await tester.tap(pulsante('Ho la risposta'));
    await tester.pumpAndSettle();
    expect(find.text('Incolla la risposta dell\'assistente'), findsOneWidget);
    await tester.tap(find.text('Incolla'));
    await aspetta(tester);
    await tester.tap(pulsante('Leggi'));
    await aspetta(tester);

    // L'anteprima: le prime quattro entrano, la crociera no.
    expect(find.text('Cosa ho trovato'), findsOneWidget);
    expect(find.text('Livraria Lello'), findsOneWidget);
    expect(find.text('Non entra: ne mancano 30 min'), findsOneWidget);
    expect(find.text('Restano 2 h 30.'), findsOneWidget);
    await tester.tap(pulsante('Aggiungi 4 tappe'));
    await aspetta(tester);

    expect(find.text('Cosa ho trovato'), findsNothing);
    final tappe = (await tester.runAsync(
      () => ambiente.archivio.osservaTappe('v').first,
    ))!;
    expect(tappe.map((t) => t.titolo), [
      'Livraria Lello',
      'Pranzo al Mercado do Bolhão',
      'Torre dei Clérigos',
      'Palácio da Bolsa',
    ]);
    expect(tappe.first.oraInizio, '10:30:00');
    expect(tappe.first.luogoNome, 'Rua das Carmelitas');
    expect(tappe[1].tipo, 'pasto');

    final nota = ambiente.server.note.single;
    expect(nota['origine'], 'incollata');
    expect(nota['testo'], contains('Crociera sul Douro'));

    final registrati = await eventi(tester);
    final nomi = [for (final e in registrati) e.$1];
    expect(nomi, containsAll(['prompt_esportato', 'incollato_riuscito']));
    expect(nomi, isNot(contains('incollato_non_interpretato')));
    expect(
      registrati.singleWhere((e) => e.$1 == 'primo_elemento_aggiunto').$2,
      containsPair('tipo', 'tappa'),
    );
    // Azioni, mai contenuti.
    expect(
      jsonEncode([for (final e in registrati) e.$2]),
      isNot(contains('Livraria')),
    );
  });

  testWidgets('la stessa risposta incollata due volte non raddoppia la '
      'giornata: le tappe che ci sono già si dicono e non si aggiungono', (
    tester,
  ) async {
    appuntiFinti(tester);
    await viaggio(tester);
    Future<void> incolla() async {
      await apriItinerario(tester);
      appunti = risposta;
      await tester.tap(pulsante('Ho la risposta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Incolla'));
      await aspetta(tester);
      await tester.tap(pulsante('Leggi'));
      await aspetta(tester);
    }

    await incolla();
    await tester.tap(pulsante('Aggiungi 4 tappe'));
    await aspetta(tester);
    // Il messaggio «Aggiunte 4 tappe» se ne va da solo.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    await incolla();
    expect(find.textContaining('4 ci sono già'), findsOneWidget);
    expect(find.text('C\'è già in questo giorno'), findsNWidgets(4));
    // Resta solo la crociera, che non entra: niente da aggiungere.
    expect(find.text('Scegline almeno una'), findsOneWidget);
    final tappe = (await tester.runAsync(
      () => ambiente.archivio.osservaTappe('v').first,
    ))!;
    expect(tappe, hasLength(4));
  });

  testWidgets('le coordinate dell\'assistente entrano con la tappa, se sono '
      'vicine al viaggio', (tester) async {
    appuntiFinti(tester);
    await viaggio(tester);
    await apriItinerario(tester);
    appunti = '''
```
TROLLEY ITINERARIO
GIORNO 1
10:30 | Livraria Lello | visita | 60 | Rua das Carmelitas 144 | 41.14686, -8.61479
12:00 | Pranzo | pasto | 60 | Lisbona, per sbaglio | 38.72230, -9.13930
```
''';
    await tester.tap(pulsante('Ho la risposta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Incolla'));
    await aspetta(tester);
    await tester.tap(pulsante('Leggi'));
    await aspetta(tester);
    expect(find.textContaining('2 con il posto sulla mappa'), findsOneWidget);
    await tester.tap(pulsante('Aggiungi 2 tappe'));
    await aspetta(tester);

    final tappe = (await tester.runAsync(
      () => ambiente.archivio.osservaTappe('v').first,
    ))!;
    expect((tappe[0].lat, tappe[0].lon), (41.14686, -8.61479));
    // Lisbona è a trecento chilometri da Porto: niente posto.
    expect(tappe[1].lat, isNull);
  });

  testWidgets('una risposta senza tappe: il testo è salvo, e si dice cosa si '
      'cercava', (tester) async {
    appuntiFinti(tester);
    await viaggio(tester);
    await apriItinerario(tester);

    await tester.tap(pulsante('Ho la risposta'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(EditableText).last,
      'A Porto vi consiglio la Livraria Lello e una francesinha.',
    );
    await tester.pump();
    await tester.tap(pulsante('Leggi'));
    await aspetta(tester);

    expect(find.text('Non ho trovato tappe'), findsOneWidget);
    expect(
      find.textContaining('Il testo è salvo.', findRichText: true),
      findsOneWidget,
    );
    expect(ambiente.server.note.single['testo'], contains('francesinha'));
    final nomi = [for (final e in await eventi(tester)) e.$1];
    expect(nomi, contains('incollato_non_interpretato'));
    expect(nomi, isNot(contains('incollato_riuscito')));
  });

  testWidgets('senza rete la richiesta si copia, ma la risposta non si legge, '
      'e lo dice prima', (tester) async {
    appuntiFinti(tester);
    await viaggio(tester);
    ambiente.rete.disponibile = false;
    await apriItinerario(tester);

    await tester.tap(pulsante('Copia la richiesta'));
    await aspetta(tester);
    expect(appunti, contains('TROLLEY ITINERARIO'));

    await tester.tap(pulsante('Ho la risposta'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).last, risposta);
    await tester.pump();
    expect(find.text('Serve la connessione'), findsOneWidget);
    expect(ambiente.server.note, isEmpty);
  });

  testWidgets('da una nota si rilegge l\'itinerario; un altro posto si '
      'segnala', (tester) async {
    await viaggio(tester);
    ambiente.server.note.add(
      rigaDiNota(
        'n',
        viaggio: 'v',
        testo: 'DESTINAZIONE: Lisbona\nGIORNO 1\n10:00 | Torre di Belém | visita | 60',
      ),
    );
    await tester.runAsync(ambiente.archivio.aggiornaCopia);
    await ambiente.monta(
      tester,
      const SchermataNota(notaId: 'n', viaggioId: 'v'),
    );

    expect(find.text('Risposta incollata'), findsOneWidget);
    await tester.tap(pulsante('Leggi di nuovo l\'itinerario'));
    await tester.pumpAndSettle();

    expect(find.text('Cosa ho trovato'), findsOneWidget);
    expect(
      find.textContaining('Parla di Lisbona.', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Torre di Belém'), findsOneWidget);
  });
}
