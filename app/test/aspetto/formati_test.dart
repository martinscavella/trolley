import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/aspetto/formati.dart';
import 'package:trolley/aspetto/tavolozza.dart';

void main() {
  group('intervalloDate', () {
    test('stesso mese: si scrive il mese una volta', () {
      expect(
        intervalloDate(DateTime(2026, 10, 10), DateTime(2026, 10, 12)),
        '10–12 ottobre 2026',
      );
    });

    test('mesi diversi', () {
      expect(
        intervalloDate(DateTime(2026, 10, 28), DateTime(2026, 11, 3)),
        '28 ottobre – 3 novembre 2026',
      );
    });

    test('anni diversi', () {
      expect(
        intervalloDate(DateTime(2026, 12, 30), DateTime(2027, 1, 2)),
        '30 dicembre 2026 – 2 gennaio 2027',
      );
    });

    test('un giorno solo', () {
      expect(
        intervalloDate(DateTime(2026, 10, 10), DateTime(2026, 10, 10)),
        '10 ottobre 2026',
      );
    });
  });

  test('i giorni di viaggio contano gli estremi, anche con l\'ora legale', () {
    expect(giorniDiViaggio(DateTime(2026, 10, 10), DateTime(2026, 10, 12)), 3);
    expect(giorniDiViaggio(DateTime(2026, 10, 24), DateTime(2026, 10, 26)), 3);
  });

  test('iniziali', () {
    expect(iniziali('Giulia Rossi'), 'GR');
    expect(iniziali('marco'), 'M');
    expect(iniziali('  Anna   Maria  Bianchi '), 'AM');
    expect(iniziali('élodie'), 'É');
    expect(iniziali(''), '?');
  });

  test('bandiera dal codice del paese', () {
    expect(bandiera('it'), '🇮🇹');
    expect(bandiera('PT'), '🇵🇹');
    expect(bandiera(null), isNull);
    expect(bandiera('ITA'), isNull);
    expect(bandiera('1T'), isNull);
  });

  test('singolare e plurale', () {
    expect(quanti(1, 'viaggio', 'viaggi'), '1 viaggio');
    expect(quanti(3, 'viaggio', 'viaggi'), '3 viaggi');
    expect(quanti(0, 'viaggio', 'viaggi'), '0 viaggi');
  });

  test('la copertina dipende solo dal viaggio', () {
    const id = '5f0c1a2e-8a4b-4c1d-9e2f-0a1b2c3d4e5f';
    expect(copertinaPer(id).inizio, copertinaPer(id).inizio);
    expect(indiceStabile(id, 10), indiceStabile(id, 10));
    expect(indiceStabile(id, 10), inInclusiveRange(0, 9));
  });
}
