import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/aspetto/barra.dart';
import 'package:trolley/aspetto/movimento.dart';
import 'package:trolley/aspetto/tavolozza.dart';

/// La barra (tela, 126): cambiando voce, la pillola bianca scivola dalla
/// voce di prima alla nuova e si allunga sul suo nome; con «Riduci
/// movimento» ci va e basta.
void main() {
  Widget barra(
    String attiva, {
    double larghezza = 350,
    bool community = false,
    double scala = 1,
  }) {
    VoceBarra voce(String nome, IconData icona) => VoceBarra(
      icona: icona,
      etichetta: nome,
      attiva: nome == attiva,
      onTap: () {},
    );
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scala)),
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: larghezza,
              child: BarraPrincipale(
                prima: [
                  voce('Viaggi', Icons.luggage_outlined),
                  voce('Mappa', Icons.public_rounded),
                ],
                dopo: [
                  VoceBarra(
                    simbolo: (colore) => SimboloPassaporto(colore: colore),
                    etichetta: 'Passaporto',
                    attiva: attiva == 'Passaporto',
                    onTap: () {},
                  ),
                  if (community) voce('Community', Icons.group_outlined),
                ],
                onAggiungi: () {},
                etichettaAggiungi: 'Nuovo viaggio',
              ),
            ),
          ),
        ),
      ),
    );
  }

  Rect pillola(WidgetTester tester) => tester.getRect(
    find.descendant(
      of: find.byType(BarraPrincipale),
      matching: find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color == Colori.bianco,
      ),
    ),
  );

  testWidgets('la pillola scivola dalla voce di prima alla nuova, e il nome '
      'va con lei', (tester) async {
    await tester.pumpWidget(barra('Viaggi'));
    final daViaggi = pillola(tester);
    expect(find.text('Viaggi'), findsOneWidget);
    expect(find.text('Passaporto'), findsNothing);

    await tester.pumpWidget(barra('Passaporto'));
    await tester.pump(Ritmo.medio ~/ 3);
    final aMeta = pillola(tester);
    // Partita, non ancora arrivata: è fra le due, e i nomi si scambiano.
    expect(aMeta.left, greaterThan(daViaggi.left));
    expect(find.text('Passaporto'), findsOneWidget);

    await tester.pumpAndSettle();
    final suPassaporto = pillola(tester);
    expect(suPassaporto.left, greaterThan(aMeta.left));
    expect(find.text('Viaggi'), findsNothing);
    expect(find.text('Passaporto'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Passaporto')),
      matchesSemantics(
        label: 'Passaporto',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
  });

  testWidgets('una corsa interrotta riparte da dov\'era, senza salti', (
    tester,
  ) async {
    await tester.pumpWidget(barra('Viaggi'));
    await tester.pumpWidget(barra('Passaporto'));
    await tester.pump(Ritmo.medio ~/ 3);
    final interrotta = pillola(tester);

    await tester.pumpWidget(barra('Mappa'));
    await tester.pump();
    expect(pillola(tester).left, closeTo(interrotta.left, 1));
    await tester.pumpAndSettle();
    expect(find.text('Mappa'), findsOneWidget);
  });

  testWidgets('con Riduci movimento la pillola ci va e basta', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(barra('Passaporto'));
    final arrivo = pillola(tester);
    await tester.pumpWidget(barra('Viaggi'));
    await tester.pumpWidget(barra('Passaporto'));
    expect(pillola(tester), arrivo);
  });

  testWidgets('su un telefono stretto, col testo grande, il nome si accorcia '
      'e non esce', (tester) async {
    await tester.pumpWidget(
      barra('Passaporto', larghezza: 300, community: true, scala: 1.6),
    );
    final dentro = tester.getRect(find.byType(BarraPrincipale));
    final p = pillola(tester);
    expect(p.left, greaterThanOrEqualTo(dentro.left));
    expect(p.right, lessThanOrEqualTo(dentro.right));
    expect(tester.takeException(), isNull);
  });
}
