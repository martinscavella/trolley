import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dominio/divisione.dart';

void main() {
  group('parti uguali', () {
    test('la somma torna sempre: i centesimi che avanzano vanno ai primi', () {
      expect(partiUguali(1000, ['g', 'm', 's']), {
        'g': 334,
        'm': 333,
        's': 333,
      });
      expect(partiUguali(4200, ['g', 'm', 's']), {
        'g': 1400,
        'm': 1400,
        's': 1400,
      });
      expect(partiUguali(1, ['g', 'm']), {'g': 1, 'm': 0});
      expect(partiUguali(500, []), isEmpty);
    });

    test('quanto manca alle parti, e se sono uguali', () {
      expect(mancaAlleParti(4200, [2000, 1200, 600]), 400);
      expect(mancaAlleParti(4200, [2000, 2200, 600]), -600);
      expect(mancaAlleParti(4200, [1400, 1400, 1400]), 0);
      expect(inPartiUguali(1000, {'g': 334, 'm': 333, 's': 333}), isTrue);
      expect(inPartiUguali(4200, {'g': 2000, 'm': 1200, 's': 1000}), isFalse);
    });
  });

  group('chi c\'era', () {
    final entrata = DateTime.utc(2026, 10, 1);
    final presenze = [
      Presenza('giulia', entrato: entrata),
      Presenza('marco', entrato: DateTime.utc(2026, 10, 5)),
      Presenza('luca', entrato: entrata, uscito: DateTime.utc(2026, 10, 3)),
    ];

    test('una spesa senza quote è di chi era nel viaggio quando è stata '
        'registrata', () {
      expect(
        chiCera(
          DateTime.utc(2026, 10, 2),
          presenze: presenze,
          pagante: 'giulia',
        ),
        ['giulia', 'luca'],
      );
      expect(
        chiCera(
          DateTime.utc(2026, 10, 6),
          presenze: presenze,
          pagante: 'giulia',
        ),
        ['giulia', 'marco'],
      );
    });

    test('chi paga c\'è sempre', () {
      expect(
        chiCera(DateTime.utc(2026, 10, 6), presenze: presenze, pagante: 'luca'),
        ['luca', 'giulia', 'marco'],
      );
    });
  });

  group('saldi', () {
    test('chi ha messo più della sua parte riceve, chi meno dà; la somma è '
        'zero', () {
      final saldi = calcolaSaldi(
        [
          SpesaDaDividere(
            pagante: 'sara',
            centesimi: 8400,
            valuta: 'EUR',
            quote: partiUguali(8400, ['giulia', 'marco', 'sara']),
          ),
          SpesaDaDividere(
            pagante: 'giulia',
            centesimi: 3600,
            valuta: 'EUR',
            quote: partiUguali(3600, ['giulia', 'marco', 'sara']),
          ),
        ],
        mia: 'EUR',
        perEuro: const {},
      );
      expect(saldi.netti, {'sara': 4400, 'giulia': -400, 'marco': -4000});
      expect(saldi.pari, isFalse);
    });

    test('in un\'altra valuta si converte con l\'ultimo tasso, e '
        'l\'arrotondamento non lascia centesimi in giro', () {
      final saldi = calcolaSaldi(
        [
          SpesaDaDividere(
            pagante: 'giulia',
            centesimi: 10000,
            valuta: 'MAD',
            quote: partiUguali(10000, ['giulia', 'marco', 'sara']),
          ),
        ],
        mia: 'EUR',
        perEuro: const {'MAD': 11.0},
      );
      expect(saldi.netti.values.fold(0, (a, b) => a + b), 0);
      expect(saldi.di('giulia'), closeTo(606, 1));
    });

    test('senza tasso una valuta resta fuori, e si dice', () {
      final saldi = calcolaSaldi(
        [
          const SpesaDaDividere(
            pagante: 'giulia',
            centesimi: 10000,
            valuta: 'MAD',
            quote: {'giulia': 5000, 'marco': 5000},
          ),
        ],
        mia: 'EUR',
        perEuro: const {},
      );
      expect(saldi.senzaTasso, {'MAD'});
      expect(saldi.netti, isEmpty);
    });

    test('un rimborso chiude il saldo', () {
      final spese = [
        const SpesaDaDividere(
          pagante: 'giulia',
          centesimi: 2000,
          valuta: 'EUR',
          quote: {'giulia': 1000, 'marco': 1000},
        ),
        const SpesaDaDividere(
          pagante: 'marco',
          centesimi: 1000,
          valuta: 'EUR',
          quote: {'giulia': 1000},
          rimborso: true,
        ),
      ];
      final saldi = calcolaSaldi(spese, mia: 'EUR', perEuro: const {});
      expect(saldi.pari, isTrue);
      expect(pareggia(saldi.netti), isEmpty);
    });
  });

  group('il giro più corto', () {
    test('un debito verso un credito uguale è un passaggio solo', () {
      expect(pareggia({'giulia': 1220, 'sara': -1220, 'marco': 0}), [
        const Passaggio(da: 'sara', a: 'giulia', centesimi: 1220),
      ]);
    });

    test('sempre il debito più grande verso il credito più grande', () {
      final passaggi = pareggia({
        'giulia': 1840,
        'sara': -1220,
        'marco': -620,
      });
      expect(passaggi, [
        const Passaggio(da: 'sara', a: 'giulia', centesimi: 1220),
        const Passaggio(da: 'marco', a: 'giulia', centesimi: 620),
      ]);
    });

    test('al più uno meno delle persone, e pareggia davvero', () {
      final netti = {'a': 5000, 'b': 2500, 'c': -3000, 'd': -3000, 'e': -1500};
      final passaggi = pareggia(netti);
      expect(passaggi.length, lessThanOrEqualTo(netti.length - 1));
      final resto = {...netti};
      for (final m in passaggi) {
        resto[m.da] = resto[m.da]! + m.centesimi;
        resto[m.a] = resto[m.a]! - m.centesimi;
      }
      expect(resto.values.every((n) => n == 0), isTrue);
    });

    test('quanti passaggi servirebbero spesa per spesa', () {
      final spese = [
        SpesaDaDividere(
          pagante: 'sara',
          centesimi: 8400,
          valuta: 'EUR',
          quote: partiUguali(8400, ['giulia', 'marco', 'sara']),
        ),
        SpesaDaDividere(
          pagante: 'giulia',
          centesimi: 3600,
          valuta: 'EUR',
          quote: partiUguali(3600, ['giulia', 'marco', 'sara']),
        ),
        const SpesaDaDividere(
          pagante: 'marco',
          centesimi: 1500,
          valuta: 'EUR',
          quote: {'marco': 750, 'sara': 750},
        ),
      ];
      // giulia↔sara, marco→sara (al netto), giulia←marco.
      expect(passaggiUnoAUno(spese, mia: 'EUR', perEuro: const {}), 3);
    });
  });

  group('forse la stessa spesa', () {
    SpesaRegistrata<String> spesa(
      String id,
      String chi,
      int centesimi,
      DateTime quando,
    ) => SpesaRegistrata(
      spesa: id,
      creatore: chi,
      centesimi: centesimi,
      valuta: 'EUR',
      registrata: quando,
    );
    final ore = DateTime.utc(2026, 10, 11, 20);

    test('stesso importo, stessa valuta, due persone, pochi minuti', () {
      expect(
        forseDoppie([
          spesa('mia', 'giulia', 3600, ore.add(const Duration(minutes: 3))),
          spesa('sua', 'marco', 3600, ore),
          spesa('altra', 'sara', 3600, ore.add(const Duration(hours: 2))),
          spesa('diversa', 'sara', 3500, ore),
        ]),
        [('sua', 'mia')],
      );
    });

    test('due spese uguali della stessa persona sono due spese', () {
      expect(
        forseDoppie([
          spesa('a', 'giulia', 300, ore),
          spesa('b', 'giulia', 300, ore.add(const Duration(minutes: 1))),
        ]),
        isEmpty,
      );
    });
  });
}
