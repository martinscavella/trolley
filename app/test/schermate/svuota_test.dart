import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/aspetto/elementi.dart';
import 'package:trolley/dominio/calendario.dart';
import 'package:trolley/schermate/giornata.dart';
import 'package:trolley/schermate/viaggio.dart';

import '../aiuti.dart';

/// Svuotare un giorno o tutto il viaggio (tela, 59 e 60), e l'avviso di una
/// tappa con lo stesso nome nello stesso giorno: le regole che servono dopo
/// un itinerario incollato due volte.
void main() {
  late Ambiente ambiente;

  setUp(() => ambiente = Ambiente());
  tearDown(() => ambiente.chiudi());

  final oggi = soloData(DateTime.now());
  String fra(int giorni) => scriviData(oggi.add(Duration(days: giorni)));

  /// Un viaggio fra un mese: due tappe il primo giorno, una il secondo.
  Future<void> viaggio(WidgetTester tester) async {
    ambiente.server
      ..viaggi.add(
        rigaViaggio('v', stato: 'definito', inizio: fra(30), fine: fra(31)),
      )
      ..partecipazioni.add(rigaPartecipazione('v'))
      ..giorni.addAll([
        rigaGiorno('v', fra(30), '10:00:00', '24:00:00', id: 'g1'),
        rigaGiorno('v', fra(31), '00:00:00', '18:00:00', id: 'g2'),
      ])
      ..tappe.addAll([
        rigaDiTappa('a', viaggio: 'v', giorno: 'g1', titolo: 'Nyhavn'),
        rigaDiTappa(
          'b',
          viaggio: 'v',
          giorno: 'g1',
          ordine: 2,
          titolo: 'Tivoli',
          stato: 'completata',
        ),
        rigaDiTappa('c', viaggio: 'v', giorno: 'g2', titolo: 'Christiania'),
      ]);
    await ambiente.accedi(tester: tester);
    await tester.runAsync(ambiente.archivio.aggiornaCopia);
  }

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

  Future<List<String>> nellaCopia(WidgetTester tester) async => [
    for (final t in (await tester.runAsync(
      () => ambiente.archivio.osservaTappe('v').first,
    ))!)
      t.id,
  ];

  List<String> tolteSulServer() => [
    for (final t in ambiente.server.tappe)
      if (t['eliminato_il'] != null) t['id']! as String,
  ];

  testWidgets('svuotare la giornata chiede, dicendo quante, e toglie solo le '
      'sue: anche quelle segnate', (tester) async {
    await viaggio(tester);
    await ambiente.monta(
      tester,
      const SchermataGiornata(viaggioId: 'v', giornoId: 'g1'),
    );
    await tester.scrollUntilVisible(pulsante('Svuota la giornata'), 200);
    await tester.tap(pulsante('Svuota la giornata'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Togliere le 2 tappe di'), findsOneWidget);
    expect(find.textContaining('Anche quelle già segnate.'), findsOneWidget);
    await tester.tap(find.text('Togli 2 tappe'));
    await aspetta(tester);

    expect(tolteSulServer(), unorderedEquals(['a', 'b']));
    expect(await nellaCopia(tester), ['c']);
    // Una scrittura sola, per tutte e due.
    expect(ambiente.server.chiamate('PATCH', '/rest/v1/tappa'), hasLength(1));
  });

  testWidgets('ripensandoci non si toglie niente', (tester) async {
    await viaggio(tester);
    await ambiente.monta(
      tester,
      const SchermataGiornata(viaggioId: 'v', giornoId: 'g1'),
    );
    await tester.scrollUntilVisible(pulsante('Svuota la giornata'), 200);
    await tester.tap(pulsante('Svuota la giornata'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annulla').last);
    await aspetta(tester);

    expect(tolteSulServer(), isEmpty);
    expect(await nellaCopia(tester), hasLength(3));
  });

  testWidgets('senza rete non si svuota, e lo dice prima', (tester) async {
    await viaggio(tester);
    ambiente.rete.disponibile = false;
    await ambiente.monta(
      tester,
      const SchermataGiornata(viaggioId: 'v', giornoId: 'g1'),
    );
    await tester.scrollUntilVisible(pulsante('Svuota la giornata'), 200);
    expect(find.text('Serve la connessione'), findsOneWidget);
    await tester.tap(pulsante('Svuota la giornata'));
    await tester.pumpAndSettle();
    expect(find.text('Togli 2 tappe'), findsNothing);
  });

  testWidgets('dal viaggio si tolgono tutte le tappe, di tutti i giorni', (
    tester,
  ) async {
    await viaggio(tester);
    await ambiente.monta(tester, const SchermataViaggio(viaggioId: 'v'));
    await aspetta(tester);
    final togli = find.text('Togli tutte le tappe del viaggio (3)');
    await tester.scrollUntilVisible(togli, 200);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(togli);
    await tester.pumpAndSettle();

    expect(find.text('Togliere tutte le 3 tappe del viaggio?'), findsOneWidget);
    await tester.tap(find.text('Togli 3 tappe'));
    await aspetta(tester);

    expect(tolteSulServer(), unorderedEquals(['a', 'b', 'c']));
    expect(await nellaCopia(tester), isEmpty);
    expect(find.textContaining('Togli tutte le tappe'), findsNothing);
  });

  testWidgets('una tappa nuova con il nome di una che c\'è già nel giorno: '
      'lo si dice, senza impedirlo', (tester) async {
    await viaggio(tester);
    await ambiente.monta(
      tester,
      const SchermataGiornata(viaggioId: 'v', giornoId: 'g1'),
    );
    await tester.scrollUntilVisible(pulsante('Aggiungi una tappa'), 200);
    await tester.tap(pulsante('Aggiungi una tappa'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'nyhavn');
    await tester.pump();
    expect(find.text('C\'è già «Nyhavn» in questo giorno.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Rosenborg');
    await tester.pump();
    expect(find.textContaining('C\'è già'), findsNothing);
  });
}
