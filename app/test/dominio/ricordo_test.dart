import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dominio/ricordo.dart';
import 'package:trolley/dominio/stato_viaggio.dart';
import 'package:trolley/dominio/traguardi.dart';

/// Il ricordo (fase 4.2; 10-chiusura-e-ricordo.md): chi entra nel
/// passaporto, le sue pagine, che cosa gratta il mappamondo.
void main() {
  group('il passaporto', () {
    test('ci sono i viaggi chiusi, propri, verificati o no', () {
      expect(
        nelPassaporto(
          stato: StatoViaggio.chiuso,
          partecipazione: 'attivo',
          eliminato: false,
        ),
        isTrue,
      );
      for (final stato in [
        StatoViaggio.idea,
        StatoViaggio.definito,
        StatoViaggio.inCorso,
        StatoViaggio.archiviato,
      ]) {
        expect(
          nelPassaporto(
            stato: stato,
            partecipazione: 'attivo',
            eliminato: false,
          ),
          isFalse,
          reason: '$stato',
        );
      }
    });

    test('non quelli da cui si è usciti, né quelli tolti', () {
      expect(
        nelPassaporto(
          stato: StatoViaggio.chiuso,
          partecipazione: 'uscito',
          eliminato: false,
        ),
        isFalse,
      );
      expect(
        nelPassaporto(
          stato: StatoViaggio.chiuso,
          partecipazione: 'attivo',
          eliminato: true,
        ),
        isFalse,
      );
    });

    test('le pagine sono gli anni, dal più recente, e dentro un anno il '
        'viaggio più recente viene prima', () {
      final viaggi = [
        ('Atene', DateTime(2025, 8, 3)),
        ('Porto', DateTime(2026, 10, 10)),
        ('Kyoto', DateTime(2025, 4, 3)),
        ('Lisbona', DateTime(2026, 5, 12)),
      ];
      final pagine = perAnno(viaggi, (v) => v.$2);
      expect([for (final (anno, _) in pagine) anno], [2026, 2025]);
      expect(
        [
          for (final (_, vv) in pagine) [for (final v in vv) v.$1],
        ],
        [
          ['Porto', 'Lisbona'],
          ['Atene', 'Kyoto'],
        ],
      );
      expect(perAnno(const <(String, DateTime)>[], (v) => v.$2), isEmpty);
    });
  });

  group('il mappamondo', () {
    test('un paese si gratta una volta, nell\'ordine delle mete', () {
      expect(
        paesiGrattati([
          (citta: 'Porto', paese: 'PT'),
          (citta: null, paese: 'JP'),
          (citta: 'Lisbona', paese: 'PT'),
          (citta: 'Val di Funes', paese: null),
        ]),
        ['PT', 'JP'],
      );
    });

    test('una città si gratta una volta, senza badare a maiuscole e accenti; '
        'con lo stesso nome in due paesi sono due', () {
      final citta = cittaGrattate([
        (citta: 'Malmö', paese: 'SE'),
        (citta: 'malmo', paese: 'SE'),
        (citta: 'Valencia', paese: 'ES'),
        (citta: 'Valencia', paese: 'VE'),
        (citta: null, paese: 'JP'),
      ]);
      expect(
        [for (final c in citta) c.citta],
        ['Malmö', 'Valencia', 'Valencia'],
      );
    });

    test('una città scritta a mano senza paese non compare (ADR-005)', () {
      expect(chiaveCitta((citta: 'Val di Funes', paese: null)), isNull);
      expect(cittaGrattate([(citta: 'Val di Funes', paese: null)]), isEmpty);
      expect(chiaveCitta((citta: 'Val di Funes', paese: 'IT')), isNotNull);
    });

    test('«Dieci città» e «Tre paesi» contano come il mappamondo', () {
      ViaggioVerificato v(String id, String? citta, String? paese) => (
        id: id,
        inizio: DateTime(2026, 5, 1),
        fine: DateTime(2026, 5, 2),
        paese: paese,
        citta: citta,
        persone: 1,
        responsabile: false,
        fattePerGiorno: const [1, 1],
      );
      final verificati = [
        v('a', 'Malmö', 'SE'),
        v('b', 'Malmo', 'SE'),
        v('c', 'Val di Funes', null),
        v('d', 'Porto', 'PT'),
      ];
      expect(contati(Traguardo.dieciCitta, verificati), 2);
      expect(contati(Traguardo.trePaesi, verificati), 2);
    });
  });

  group('grattare col dito', () {
    final oggi = DateTime(2026, 10, 6);
    test('un paese è da grattare se è arrivato con un viaggio finito '
        'nell\'ultimo mese, e non è ancora scoperto', () {
      final visite = [
        (paese: 'PT', fine: DateTime(2025, 5, 17)),
        (paese: 'JP', fine: DateTime(2026, 10, 2)),
        (paese: 'GR', fine: DateTime(2026, 9, 10)),
        (paese: null, fine: DateTime(2026, 10, 1)),
      ];
      expect(daGrattare(visite, scoperti: {}, oggi: oggi), ['GR', 'JP']);
      expect(daGrattare(visite, scoperti: {'GR'}, oggi: oggi), ['JP']);
    });

    test('tornare in un paese già visto non lo rimette sotto la patina', () {
      final visite = [
        (paese: 'PT', fine: DateTime(2025, 5, 17)),
        (paese: 'PT', fine: DateTime(2026, 10, 2)),
      ];
      expect(daGrattare(visite, scoperti: {}, oggi: oggi), isEmpty);
    });

    test('dopo un mese il paese è sul mappamondo e basta: chi reinstalla non '
        'trova una fila di paesi da grattare', () {
      final visite = [(paese: 'JP', fine: DateTime(2026, 9, 5))];
      expect(daGrattare(visite, scoperti: {}, oggi: oggi), isEmpty);
      expect(daGrattare(visite, scoperti: {}, oggi: DateTime(2026, 10, 5)), [
        'JP',
      ]);
    });

    test('i paesi nell\'ordine in cui sono arrivati: «il tuo 2° paese»', () {
      final visite = [
        (paese: 'JP', fine: DateTime(2026, 10, 2)),
        (paese: 'PT', fine: DateTime(2025, 5, 17)),
        (paese: 'JP', fine: DateTime(2024, 1, 1)),
        (paese: 'GR', fine: DateTime(2026, 9, 10)),
      ];
      expect(paesiInOrdine(visite), ['JP', 'PT', 'GR']);
    });
  });
}
