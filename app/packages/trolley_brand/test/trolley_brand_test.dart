import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trolley_brand/trolley_brand.dart';

void main() {
  testWidgets('Splash completes once and paints all stages', (tester) async {
    int completed = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Center(
      child: TrolleySplash(onCompleted: () => completed++),
    ))));
    await tester.pump(); // Establish the ticker's first frame before timing it.
    for (final milliseconds in [560, 160, 560, 1300, 1300, 920]) {
      await tester.pump(Duration(milliseconds: milliseconds));
      expect(tester.takeException(), isNull);
    }
    await tester.pump(const Duration(milliseconds: 20));
    expect(completed, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(completed, 1);
  });

  testWidgets('Reduced motion completes immediately', (tester) async {
    int completed = 0;
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: TrolleySplash(onCompleted: () => completed++),
    )));
    await tester.pump();
    expect(completed, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('All loaders animate and dispose without ticker leaks',
      (tester) async {
    for (final style in TrolleyLoaderStyle.values) {
      await tester.pumpWidget(MaterialApp(
          home: Center(
        child: TrolleyLoader(key: ValueKey(style), style: style),
      )));
      for (int frame = 0; frame < 5; frame++) {
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
      }
    }
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('Static logos render on both backgrounds', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Column(children: [
      SizedBox(width: 200, child: TrolleyLogo()),
      SizedBox(width: 60, child: TrolleyLogo(symbolOnly: true)),
      ColoredBox(
          color: trolleyBlue,
          child: SizedBox(width: 200, child: TrolleyLogo(color: Colors.white))),
    ])));
    expect(tester.takeException(), isNull);
  });
}
