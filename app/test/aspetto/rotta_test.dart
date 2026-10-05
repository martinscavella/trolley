import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/aspetto/movimento.dart';
import 'package:trolley/aspetto/piattaforma.dart';

/// Il passaggio fra le pagine (RottaTrolley): la nuova entra da destra, si
/// torna indietro trascinando dal bordo, con «Riduci movimento» sfuma.
void main() {
  Future<void> app(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => apri<void>(
                context,
                const Scaffold(body: Center(child: Text('Seconda'))),
              ),
              child: const Text('Prima'),
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('la pagina nuova entra da destra, e a metà è già quasi tutta '
      'dentro: parte veloce', (tester) async {
    await app(tester);
    await tester.tap(find.text('Prima'));
    await tester.pump();
    await tester.pump(RitmoPagine.avanti ~/ 3);
    final x = tester.getTopLeft(find.text('Seconda')).dx;
    final centro = tester.getCenter(find.byType(MaterialApp)).dx;
    // Un terzo del tempo, più di metà della strada.
    expect(x, lessThan(centro + 400 * 0.5));
    await tester.pumpAndSettle();
    expect(find.text('Prima'), findsNothing);
    expect(find.text('Seconda'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('su iOS si torna indietro trascinando dal bordo sinistro', (
    tester,
  ) async {
    await app(tester);
    await tester.tap(find.text('Prima'));
    await tester.pumpAndSettle();

    final dito = await tester.startGesture(const Offset(5, 300));
    await dito.moveBy(const Offset(40, 0));
    await dito.moveBy(const Offset(400, 0));
    await dito.up();
    await tester.pumpAndSettle();

    expect(find.text('Seconda'), findsNothing);
    expect(find.text('Prima'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('trascinata poco e lasciata, la pagina torna al suo posto', (
    tester,
  ) async {
    await app(tester);
    await tester.tap(find.text('Prima'));
    await tester.pumpAndSettle();

    final dito = await tester.startGesture(const Offset(5, 300));
    await dito.moveBy(const Offset(30, 0));
    await tester.pump(const Duration(seconds: 1));
    await dito.moveBy(const Offset(20, 0));
    await tester.pump(const Duration(seconds: 1));
    await dito.up();
    await tester.pumpAndSettle();

    expect(find.text('Seconda'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('con «Riduci movimento» la pagina compare sfumando, senza '
      'scorrere', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await app(tester);
    await tester.tap(find.text('Prima'));
    await tester.pump();
    await tester.pump(RitmoPagine.avanti ~/ 2);
    expect(tester.getTopLeft(find.text('Seconda')).dx, lessThan(400));
    expect(find.byType(FadeTransition), findsWidgets);
    await tester.pumpAndSettle();
    expect(find.text('Seconda'), findsOneWidget);
  });
}
