import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dati/confini.dart';

/// La terra a puntini del mappamondo (tela, 144): dai confini veri.
void main() {
  final confini = Confini.daByte(
    ByteData.sublistView(File('assets/confini.bin').readAsBytesSync()),
  );

  test('circa un punto su quattro è terra, e ogni puntino ha il suo paese', () {
    final p = confini.puntini;
    expect(p.length / 12000, closeTo(0.28, 0.03));
    expect(p.punti.length, p.length * 3);
    final paesi = {for (var i = 0; i < p.length; i++) p.paese(i)};
    expect(paesi, containsAll(['IT', 'JP', 'BR', 'RU', 'US', 'AU']));
  });

  test('un paese a cavallo dei 180 gradi ha i suoi puntini', () {
    final p = confini.puntini;
    final russi = [
      for (var i = 0; i < p.length; i++)
        if (p.paese(i) == 'RU') i,
    ];
    expect(russi.length, greaterThan(200));
  });

  test('un punto della Terra sa di che paese è; il mare di nessuno', () {
    expect(confini.paeseIn(39.5, -8.0), 'PT');
    expect(confini.paeseIn(35.7, 139.7), 'JP');
    expect(confini.paeseIn(40.0, -30.0), isNull);
    // San Marino sta dentro l'Italia, ma non è Italia.
    expect(confini.paeseIn(43.0, 12.0), 'IT');
  });
}
