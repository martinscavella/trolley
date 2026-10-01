import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dominio/periodo.dart';

void main() {
  test('un mese va dal primo all\'ultimo giorno', () {
    const agosto = MeseDi(2027, 8);
    expect(agosto.testo, 'agosto 2027');
    expect(agosto.primoGiorno, DateTime.utc(2027, 8, 1));
    expect(agosto.ultimoGiorno, DateTime.utc(2027, 8, 31));
    expect(const MeseDi(2028, 2).ultimoGiorno, DateTime.utc(2028, 2, 29));
  });

  test('le stagioni sono di tre mesi, e l\'inverno prende due anni', () {
    const estate = StagioneDi(2027, Stagione.estate);
    expect(estate.testo, 'estate 2027');
    expect(estate.primoGiorno, DateTime.utc(2027, 6, 1));
    expect(estate.ultimoGiorno, DateTime.utc(2027, 8, 31));

    const inverno = StagioneDi(2026, Stagione.inverno);
    expect(inverno.testo, 'inverno 2026–27');
    expect(inverno.primoGiorno, DateTime.utc(2026, 12, 1));
    expect(inverno.ultimoGiorno, DateTime.utc(2027, 2, 28));

    expect(const StagioneDi(2099, Stagione.inverno).testo, 'inverno 2099–00');
  });

  test('si rilegge quello che si scrive', () {
    final periodi = <Periodo>[
      const MeseDi(2027, 1),
      const MeseDi(2027, 12),
      const StagioneDi(2027, Stagione.primavera),
      const StagioneDi(2027, Stagione.autunno),
      const StagioneDi(2027, Stagione.inverno),
    ];
    for (final p in periodi) {
      expect(Periodo.leggi(p.testo), p, reason: p.testo);
    }
  });

  test(
    'si legge con qualche tolleranza, e quello che non si capisce è nulla',
    () {
      expect(Periodo.leggi(' Agosto 2027 '), const MeseDi(2027, 8));
      expect(
        Periodo.leggi('inverno 2026-27'),
        const StagioneDi(2026, Stagione.inverno),
      );
      expect(Periodo.leggi('inverno 2026–28'), isNull);
      expect(Periodo.leggi('inverno 2026'), isNull);
      expect(Periodo.leggi('un weekend di primavera'), isNull);
      expect(Periodo.leggi('agostoo 2027'), isNull);
      expect(Periodo.leggi(''), isNull);
      expect(Periodo.leggi(null), isNull);
    },
  );

  test('la stagione di una data: gennaio è nell\'inverno dell\'anno prima', () {
    expect(
      Stagione.di(DateTime(2027, 1, 10)),
      const StagioneDi(2026, Stagione.inverno),
    );
    expect(
      Stagione.di(DateTime(2026, 12, 1)),
      const StagioneDi(2026, Stagione.inverno),
    );
    expect(
      Stagione.di(DateTime(2026, 10, 1)),
      const StagioneDi(2026, Stagione.autunno),
    );
  });

  test('si propongono il mese e la stagione in corso, e i seguenti', () {
    final oggi = DateTime(2026, 10, 1);
    final mesi = Periodo.mesiDa(oggi);
    expect(mesi, hasLength(12));
    expect(mesi.first, const MeseDi(2026, 10));
    expect(mesi[3], const MeseDi(2027, 1));
    expect(mesi.last, const MeseDi(2027, 9));

    expect(Periodo.stagioniDa(oggi), const [
      StagioneDi(2026, Stagione.autunno),
      StagioneDi(2026, Stagione.inverno),
      StagioneDi(2027, Stagione.primavera),
      StagioneDi(2027, Stagione.estate),
    ]);
  });
}
