import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dati/mappe.dart';
import 'package:trolley/dominio/apertura.dart';
import 'package:trolley/schermate/dettaglio_tappa.dart';

/// Gli orari di apertura di un posto, da Google (CR-06, passo 3).
void main() {
  Map<String, int> punto(int giorno, int ore, [int minuti = 0]) => {
    'day': giorno,
    'hour': ore,
    'minute': minuti,
  };

  group('gli orari di Google', () {
    // Rosenborg: da martedì a domenica 10–17, lunedì chiuso; il sabato
    // anche la sera, 19–22.
    final rosenborg = OrariDiApertura.daGoogle({
      'periods': [
        for (final g in [0, 2, 3, 4, 5, 6])
          {'open': punto(g, 10), 'close': punto(g, 17)},
        {'open': punto(6, 19), 'close': punto(6, 22)},
      ],
    })!;

    test('un giorno qualsiasi: le sue aperture, in ordine', () {
      // Sabato 28 novembre 2026.
      final sabato = rosenborg.del(DateTime(2026, 11, 28));
      expect(sabato, [
        (apre: const Duration(hours: 10), chiude: const Duration(hours: 17)),
        (apre: const Duration(hours: 19), chiude: const Duration(hours: 22)),
      ]);
      // Lunedì 30: chiuso.
      expect(rosenborg.del(DateTime(2026, 11, 30)), isEmpty);
      // Domenica 29: il giorno 0 di Google.
      expect(rosenborg.del(DateTime(2026, 11, 29)), hasLength(1));
    });

    test('un bar che chiude dopo mezzanotte: le ore vanno oltre le 24', () {
      final bar = OrariDiApertura.daGoogle({
        'periods': [
          {'open': punto(5, 18), 'close': punto(6, 2)},
        ],
      })!;
      expect(bar.del(DateTime(2026, 11, 27)).single, (
        apre: const Duration(hours: 18),
        chiude: const Duration(hours: 26),
      ));
    });

    test('aperto sempre: un\'apertura senza chiusura', () {
      final sempre = OrariDiApertura.daGoogle({
        'periods': [
          {'open': punto(0, 0)},
        ],
      })!;
      expect(sempre.sempre, isTrue);
      expect(sempre.del(DateTime(2026, 11, 30)).single.chiude.inHours, 24);
    });

    test('senza orari, niente', () {
      expect(OrariDiApertura.daGoogle(null), isNull);
      expect(OrariDiApertura.daGoogle({'periods': []}), isNull);
    });
  });

  group('la scheda di Google', () {
    test('indirizzo, aperto ora fino a quando nell\'ora del posto, orari, '
        'descrizione', () {
      final s = schedaDaGoogle({
        'id': 'ChIJ-rosenborg',
        'location': {'latitude': 55.6858, 'longitude': 12.577},
        'formattedAddress': 'Øster Voldgade 4A, 1350 København',
        'businessStatus': 'OPERATIONAL',
        'utcOffsetMinutes': 60,
        'currentOpeningHours': {
          'openNow': true,
          'nextCloseTime': '2026-11-28T16:00:00Z',
        },
        'regularOpeningHours': {
          'periods': [
            {'open': punto(6, 10), 'close': punto(6, 17)},
          ],
        },
        'editorialSummary': {'text': 'Castello rinascimentale del 1606.'},
      }, 'ChIJ-rosenborg');
      expect(s.indirizzo, startsWith('Øster Voldgade'));
      expect(s.apertoOra, isTrue);
      // Le 16 universali sono le 17 a Copenaghen.
      expect(s.cambiaAlle!.hour, 17);
      expect(s.orari!.del(DateTime(2026, 11, 28)), hasLength(1));
      expect(s.descrizione, 'Castello rinascimentale del 1606.');
      expect(s.chiusoPerSempre, isFalse);
    });

    test('chiuso per sempre', () {
      final s = schedaDaGoogle({'businessStatus': 'CLOSED_PERMANENTLY'}, 'x');
      expect(s.chiusoPerSempre, isTrue);
      expect(s.indirizzo, isNull);
    });
  });

  group('come si dice', () {
    final orari = OrariDiApertura.daGoogle({
      'periods': [
        {'open': punto(6, 10), 'close': punto(6, 17)},
      ],
    });
    final adesso = DateTime.utc(2026, 11, 28, 10);

    test('aperto ora, e gli orari del giorno in cui ci si va (tela, 161)', () {
      final d = descriviApertura(
        SchedaPosto(
          id: 'x',
          orari: orari,
          apertoOra: true,
          cambiaAlle: DateTime.utc(2026, 11, 28, 17),
          scarto: const Duration(hours: 1),
        ),
        giorno: DateTime(2026, 11, 28),
        adesso: adesso,
      )!;
      expect(d.titolo, 'Aperto · fino alle 17:00');
      expect(d.sotto, 'Sabato, quando ci vai: 10:00–17:00');
      expect(d.aperto, isTrue);
    });

    test('chiuso: apre oggi, o un altro giorno', () {
      String titolo(DateTime cambia) => descriviApertura(
        SchedaPosto(
          id: 'x',
          apertoOra: false,
          cambiaAlle: cambia,
          scarto: const Duration(hours: 1),
        ),
        adesso: DateTime.utc(2026, 11, 28, 7),
      )!.titolo;
      expect(
        titolo(DateTime.utc(2026, 11, 28, 10)),
        'Chiuso · apre alle 10:00',
      );
      expect(
        titolo(DateTime.utc(2026, 12, 1, 10)),
        'Chiuso · apre martedì alle 10:00',
      );
    });

    test('il giorno in cui ci si va è chiuso: lo dice', () {
      final d = descriviApertura(
        SchedaPosto(id: 'x', orari: orari),
        giorno: DateTime(2026, 11, 30),
        adesso: adesso,
      )!;
      expect(d.titolo, 'Lunedì, quando ci vai: chiuso');
    });

    test('chiuso per sempre vale più di tutto; senza orari, niente', () {
      expect(
        descriviApertura(
          const SchedaPosto(id: 'x', chiusoPerSempre: true, apertoOra: true),
          adesso: adesso,
        )!.titolo,
        'Chiuso per sempre',
      );
      expect(
        descriviApertura(const SchedaPosto(id: 'x'), adesso: adesso),
        isNull,
      );
    });
  });
}
