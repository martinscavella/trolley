import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dominio/giornate.dart';

void main() {
  group('generaGiorni', () {
    test(
      'primo giorno dall\'arrivo, ultimo fino alla partenza, in mezzo pieni',
      () {
        final giorni = generaGiorni(
          dataInizio: DateTime(2026, 10, 10),
          dataFine: DateTime(2026, 10, 12),
          oraArrivo: const Duration(hours: 10),
          oraPartenza: const Duration(hours: 18),
        );
        expect(giorni, [
          FinestraGiorno(
            data: DateTime.utc(2026, 10, 10),
            inizio: const Duration(hours: 10),
            fine: fineGiornata,
          ),
          FinestraGiorno(
            data: DateTime.utc(2026, 10, 11),
            inizio: inizioGiornata,
            fine: fineGiornata,
          ),
          FinestraGiorno(
            data: DateTime.utc(2026, 10, 12),
            inizio: inizioGiornata,
            fine: const Duration(hours: 18),
          ),
        ]);
        expect(giorni.first.capienza, const Duration(hours: 14));
      },
    );

    test('un giorno solo va dall\'arrivo alla partenza', () {
      final giorni = generaGiorni(
        dataInizio: DateTime(2026, 10, 10),
        dataFine: DateTime(2026, 10, 10),
        oraArrivo: const Duration(hours: 9),
        oraPartenza: const Duration(hours: 20),
      );
      expect(giorni, hasLength(1));
      expect(giorni.single.capienza, const Duration(hours: 11));
    });

    test('attraversa il cambio dell\'ora legale senza saltare giorni', () {
      final giorni = generaGiorni(
        dataInizio: DateTime(2026, 10, 24),
        dataFine: DateTime(2026, 10, 27),
        oraArrivo: const Duration(hours: 12),
        oraPartenza: const Duration(hours: 12),
      );
      expect(giorni.map((g) => g.data.day), [24, 25, 26, 27]);
    });

    test('rifiuta un giorno senza tempo', () {
      expect(
        () => generaGiorni(
          dataInizio: DateTime(2026, 10, 10),
          dataFine: DateTime(2026, 10, 10),
          oraArrivo: const Duration(hours: 18),
          oraPartenza: const Duration(hours: 9),
        ),
        throwsArgumentError,
      );
    });

    test('rifiuta date invertite', () {
      expect(
        () => generaGiorni(
          dataInizio: DateTime(2026, 10, 12),
          dataFine: DateTime(2026, 10, 10),
          oraArrivo: const Duration(hours: 10),
          oraPartenza: const Duration(hours: 18),
        ),
        throwsArgumentError,
      );
    });
  });

  group('entraNellaGiornata', () {
    const capienza = Duration(hours: 4);

    test('entra finché la somma non supera la capienza', () {
      expect(
        entraNellaGiornata(
          capienza: capienza,
          durateMinuti: [90, 60],
          nuovaMinuti: 90,
        ),
        isTrue,
      );
    });

    test('non entra se sfora anche di un minuto', () {
      expect(
        entraNellaGiornata(
          capienza: capienza,
          durateMinuti: [90, 60],
          nuovaMinuti: 91,
        ),
        isFalse,
      );
    });
  });
}
