import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dominio/eta.dart';

void main() {
  group('etaCompiuta', () {
    test('il giorno del compleanno gli anni sono compiuti', () {
      expect(etaCompiuta(DateTime(2010, 9, 30), DateTime(2026, 9, 30)), 16);
    });

    test('il giorno prima no', () {
      expect(etaCompiuta(DateTime(2010, 9, 30), DateTime(2026, 9, 29)), 15);
    });

    test('nato il 29 febbraio: compie gli anni il primo marzo', () {
      expect(etaCompiuta(DateTime(2008, 2, 29), DateTime(2026, 2, 28)), 17);
      expect(etaCompiuta(DateTime(2008, 2, 29), DateTime(2026, 3, 1)), 18);
    });
  });

  test('16 anni per l\'account, 18 per la parte pubblica', () {
    final oggi = DateTime(2026, 9, 30);
    final sedicenne = DateTime(2010, 9, 30);
    expect(puoCreareAccount(sedicenne, oggi), isTrue);
    expect(puoAverePartePubblica(sedicenne, oggi), isFalse);
    expect(puoCreareAccount(DateTime(2010, 10, 1), oggi), isFalse);
    expect(puoAverePartePubblica(DateTime(2008, 9, 30), oggi), isTrue);
  });
}
