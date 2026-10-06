import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dati/confini.dart';
import 'package:trolley/dati/paesi.dart';

/// I confini del mappamondo (ADR-005), incorporati nell'app.
void main() {
  final confini = Confini.daByte(
    ByteData.sublistView(File('assets/confini.bin').readAsBytesSync()),
  );

  test('il file si legge: un paese, un contorno, i punti sulla sfera', () {
    final dati = ByteData(2 + 2 + 2 + 2 + 3 * 4)
      ..setUint16(0, 1, Endian.little)
      ..setUint8(2, 'X'.codeUnitAt(0))
      ..setUint8(3, 'Y'.codeUnitAt(0))
      ..setUint16(4, 1, Endian.little)
      ..setUint16(6, 3, Endian.little);
    for (final (i, (lon, lat)) in [(0, 0), (9000, 0), (0, 9000)].indexed) {
      dati
        ..setInt16(8 + i * 4, lon, Endian.little)
        ..setInt16(10 + i * 4, lat, Endian.little);
    }
    final letti = Confini.daByte(dati);
    expect(letti.codici, ['XY']);
    final punti = letti.contorni('XY').single;
    const atteso = [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0];
    for (var i = 0; i < atteso.length; i++) {
      expect(punti[i], closeTo(atteso[i], 1e-6));
    }
    expect(letti.contorni('ZZ'), isEmpty);
  });

  test('i paesi hanno i loro contorni, con i codici dell\'elenco', () {
    for (final codice in ['IT', 'PT', 'FR', 'JP', 'US', 'BR', 'AU']) {
      expect(confini.contorni(codice), isNotEmpty, reason: codice);
    }
    final senzaNome = confini.codici.where((c) => c != '--').toSet()
      ..removeAll(nomiDeiPaesi.keys);
    expect(senzaNome, isEmpty);
  });

  test('ogni punto sta sulla sfera, e ogni contorno è chiuso', () {
    for (final codice in confini.codici) {
      for (final punti in confini.contorni(codice)) {
        expect(punti.length ~/ 3, greaterThanOrEqualTo(4));
        for (var i = 0; i < punti.length; i += 3) {
          final r = sqrt(
            pow(punti[i], 2) + pow(punti[i + 1], 2) + pow(punti[i + 2], 2),
          );
          expect(r, closeTo(1, 1e-5));
        }
        final n = punti.length;
        expect(punti.sublist(n - 3), punti.sublist(0, 3), reason: codice);
      }
    }
  });

  test('i territori d\'oltremare sono paesi a sé: chi va a Parigi non gratta '
      'la Guyana', () {
    for (final codice in ['GF', 'GP', 'MQ', 'RE', 'SJ']) {
      expect(confini.contorni(codice), isNotEmpty, reason: codice);
    }
    // In Francia restano il continente e la Corsica: le longitudini stanno
    // fra -5 e 10 gradi.
    for (final punti in confini.contorni('FR')) {
      for (var i = 0; i < punti.length; i += 3) {
        final lon = atan2(punti[i + 1], punti[i]) * 180 / pi;
        expect(lon, inInclusiveRange(-6, 11));
      }
    }
  });

  test('i paesi troppo piccoli per il globo non hanno contorni: lì va un '
      'punto', () {
    for (final codice in ['VA', 'SM', 'MC']) {
      expect(confini.contorni(codice), isEmpty, reason: codice);
    }
  });
}
