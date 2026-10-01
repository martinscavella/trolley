import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dominio/calendario.dart';

void main() {
  test('le date si leggono e si scrivono come sul server', () {
    expect(leggiData('2026-10-10'), DateTime.utc(2026, 10, 10));
    expect(leggiData('2026-10-10T15:30:00'), DateTime.utc(2026, 10, 10));
    expect(leggiData(null), isNull);
    expect(leggiData('domani'), isNull);
    expect(scriviData(DateTime(2026, 3, 7, 23, 59)), '2026-03-07');
  });

  test('gli orari sono distanze dalla mezzanotte, fino a 24:00', () {
    expect(leggiOra('10:30:00'), const Duration(hours: 10, minutes: 30));
    expect(leggiOra('09:05'), const Duration(hours: 9, minutes: 5));
    expect(leggiOra('24:00:00'), const Duration(hours: 24));
    expect(leggiOra('25:00:00'), isNull);
    expect(leggiOra('mezzogiorno'), isNull);
    expect(leggiOra(null), isNull);
    expect(scriviOra(const Duration(hours: 10, minutes: 5)), '10:05:00');
    expect(scriviOra(const Duration(hours: 24)), '24:00:00');
  });

  test(
    'i giorni di calendario contano gli estremi, anche con l\'ora legale',
    () {
      expect(
        giorniDiCalendario(DateTime(2026, 10, 10), DateTime(2026, 10, 12)),
        3,
      );
      expect(
        giorniDiCalendario(DateTime(2026, 10, 24), DateTime(2026, 10, 26)),
        3,
      );
      expect(
        giorniDiCalendario(DateTime(2026, 10, 10), DateTime(2026, 10, 10)),
        1,
      );
    },
  );

  test('aggiungere mesi si ferma all\'ultimo giorno del mese', () {
    expect(
      aggiungiMesi(DateTime.utc(2027, 1, 31), 1),
      DateTime.utc(2027, 2, 28),
    );
    expect(
      aggiungiMesi(DateTime.utc(2028, 1, 31), 1),
      DateTime.utc(2028, 2, 29),
    );
    expect(
      aggiungiMesi(DateTime.utc(2026, 10, 1), 12),
      DateTime.utc(2027, 10, 1),
    );
    expect(
      aggiungiMesi(DateTime.utc(2026, 11, 15), 3),
      DateTime.utc(2027, 2, 15),
    );
  });
}
