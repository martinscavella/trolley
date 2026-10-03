import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/aspetto/formati.dart';
import 'package:trolley/aspetto/tavolozza.dart';
import 'package:trolley/dominio/giornate.dart';
import 'package:trolley/dominio/periodo.dart';

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

  test('il colore delle iniziali dipende solo dalla chiave', () {
    const id = '5f0c1a2e-8a4b-4c1d-9e2f-0a1b2c3d4e5f';
    expect(coloreAvatar(id), coloreAvatar(id));
    expect(indiceStabile(id, 10), indiceStabile(id, 10));
    expect(indiceStabile(id, 10), inInclusiveRange(0, 9));
  });

  test('un periodo si dice corto quando l\'anno è quello di adesso', () {
    final oggi = DateTime(2026, 10, 1);
    expect(etichettaPeriodo(const MeseDi(2026, 11), oggi), 'Novembre');
    expect(etichettaPeriodo(const MeseDi(2027, 1), oggi), 'Gennaio 2027');
    expect(
      etichettaPeriodo(const StagioneDi(2026, Stagione.autunno), oggi),
      'Autunno',
    );
    expect(
      etichettaPeriodo(const StagioneDi(2026, Stagione.inverno), oggi),
      'Inverno 2026–27',
    );
  });

  test('orari e durate', () {
    expect(ora(const Duration(hours: 9, minutes: 5)), '09:05');
    expect(ora(const Duration(hours: 24)), 'mezzanotte');
    expect(durata(const Duration(hours: 14)), '14 h');
    expect(durata(const Duration(hours: 13, minutes: 30)), '13 h 30 min');
    expect(durata(const Duration(minutes: 45)), '45 min');
  });

  test('la finestra di una giornata, a parole', () {
    FinestraGiorno g(int da, int a) => FinestraGiorno(
      data: DateTime.utc(2026, 10, 10),
      inizio: Duration(hours: da),
      fine: Duration(hours: a),
    );
    expect(finestraDelGiorno(g(10, 24)), 'dalle 10:00');
    expect(finestraDelGiorno(g(0, 18)), 'fino alle 18:00');
    expect(finestraDelGiorno(g(0, 24)), 'tutto il giorno');
    expect(finestraDelGiorno(g(9, 20)), 'dalle 09:00 alle 20:00');
  });

  test('quanto tempo fa', () {
    final adesso = DateTime(2026, 10, 3, 12);
    expect(
      quantoFa(adesso.subtract(const Duration(seconds: 30)), adesso),
      'poco fa',
    );
    expect(
      quantoFa(adesso.subtract(const Duration(minutes: 5)), adesso),
      '5 minuti fa',
    );
    expect(
      quantoFa(adesso.subtract(const Duration(hours: 3)), adesso),
      '3 ore fa',
    );
    expect(quantoFa(DateTime(2026, 10, 2, 8), adesso), 'ieri');
    expect(quantoFa(DateTime(2026, 9, 29, 8), adesso), '4 giorni fa');
  });

  test('il codice del biglietto: tre lettere dalla destinazione', () {
    expect(codiceDestinazione('Lisbona'), 'LIS');
    expect(codiceDestinazione('Città del Messico'), 'CIT');
    expect(codiceDestinazione('Malmö'), 'MAL');
    expect(codiceDestinazione('Ho Chi Minh'), 'HOC');
    expect(codiceDestinazione('Bo'), 'BO');
    expect(codiceDestinazione(null), '?');
    expect(codiceDestinazione('  '), '?');
  });

  test('le durate corte e i giorni del viaggio', () {
    expect(durataBreve(const Duration(hours: 2)), '2 h');
    expect(durataBreve(const Duration(minutes: 90)), '1 h 30');
    expect(durataBreve(const Duration(minutes: 65)), '1 h 05');
    expect(durataBreve(const Duration(minutes: 45)), '45 min');
    expect(nomeDelGiorno(DateTime.utc(2026, 10, 10)), 'Sabato 10 ottobre');
    expect(giornoBreve(DateTime.utc(2026, 10, 11)), 'Domenica 11');
  });
}
