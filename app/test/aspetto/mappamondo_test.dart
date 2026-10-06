import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/aspetto/mappamondo.dart';
import 'package:trolley/dati/confini.dart';

/// Il globo del mappamondo (tela, 66): la proiezione e i gesti.
void main() {
  void vicino((double, double, double) punto, (double, double, double) atteso) {
    expect(punto.$1, closeTo(atteso.$1, 1e-6));
    expect(punto.$2, closeTo(atteso.$2, 1e-6));
    expect(punto.$3, closeTo(atteso.$3, 1e-6));
  }

  test('il centro sta davanti, l\'est a destra, il nord in alto, gli '
      'antipodi dietro', () {
    final o = Ortografica((lat: 0, lon: 0));
    vicino(o.coordinata((lat: 0, lon: 0)), (0, 0, 1));
    vicino(o.coordinata((lat: 0, lon: 90)), (1, 0, 0));
    vicino(o.coordinata((lat: 90, lon: 0)), (0, 1, 0));
    vicino(o.coordinata((lat: 0, lon: 180)), (0, 0, -1));
  });

  test('girato verso una meta, la meta è al centro', () {
    for (final meta in [
      (lat: 41.15, lon: -8.61),
      (lat: 35.0, lon: 135.77),
      (lat: -33.9, lon: 151.2),
    ]) {
      vicino(Ortografica(meta).coordinata(meta), (0, 0, 1));
    }
  });

  testWidgets('si disegna, si trascina e si gira verso un altro paese', (
    tester,
  ) async {
    Confini.usa(
      Confini.daByte(
        ByteData.sublistView(File('assets/confini.bin').readAsBytesSync()),
      ),
    );
    Widget globo(({double lat, double lon}) centro) => MaterialApp(
      home: Center(
        child: Mappamondo(
          grattati: const {'PT', 'JP', 'VA'},
          centro: centro,
          punti: const {'VA': (lat: 41.9, lon: 12.45)},
          etichetta: 'Mappamondo: 3 paesi visitati',
        ),
      ),
    );
    await tester.pumpWidget(globo((lat: 41.15, lon: -8.61)));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Mappamondo: 3 paesi visitati'), findsOne);

    await tester.fling(find.byType(Mappamondo), const Offset(-200, 40), 800);
    await tester.pumpAndSettle();
    await tester.pumpWidget(globo((lat: 35.0, lon: 135.77)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
