import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dominio/stato_viaggio.dart';
import 'package:trolley/dominio/tappe.dart';

void main() {
  test('ogni tipo propone la sua durata, e si legge dal nome del server', () {
    expect(TipoTappa.visita.durataProposta, const Duration(minutes: 90));
    expect(TipoTappa.escursione.durataProposta, const Duration(hours: 4));
    expect(TipoTappa.pausa.durataProposta, const Duration(minutes: 30));
    expect(TipoTappa.leggi('passeggiata'), TipoTappa.passeggiata);
    expect(TipoTappa.leggi(null), isNull);
    expect(TipoTappa.leggi('shopping'), isNull);
  });

  test('gli stati si leggono dal server; segnata è completata o saltata', () {
    expect(StatoTappa.leggi('da_fare'), StatoTappa.daFare);
    expect(StatoTappa.leggi('saltata'), StatoTappa.saltata);
    expect(StatoTappa.daFare.segnata, isFalse);
    expect(StatoTappa.completata.segnata, isTrue);
    expect(StatoTappa.saltata.segnata, isTrue);
  });

  test('la durata cresce e cala di un quarto d\'ora, mai sotto il quarto', () {
    expect(
      durataPiuLunga(const Duration(minutes: 90)),
      const Duration(minutes: 105),
    );
    expect(
      durataPiuCorta(const Duration(minutes: 20)),
      const Duration(minutes: 15),
    );
    expect(
      durataPiuLunga(const Duration(hours: 24)),
      const Duration(hours: 24),
    );
  });

  test('il tempo libero è la capienza meno le tappe, e può sforare', () {
    expect(
      tempoLibero(capienza: const Duration(hours: 14), durateMinuti: [60, 90]),
      const Duration(hours: 11, minutes: 30),
    );
    expect(
      tempoLibero(capienza: const Duration(hours: 2), durateMinuti: [90, 60]),
      const Duration(minutes: -30),
    );
  });

  test('una tappa nuova va in fondo alla giornata', () {
    expect(ordineInFondo(const []), 1);
    expect(ordineInFondo([1, 4, 2]), 5);
  });

  group('quando una tappa non entra', () {
    final domenica = DateTime.utc(2026, 10, 12);

    test(
      'si dice quanto manca e si propone di accorciarla a quel che resta',
      () {
        final p = proposteSeNonEntra<String>(
          durata: const Duration(hours: 4),
          data: domenica,
          libero: const Duration(hours: 3, minutes: 20),
          altriGiorni: const [],
        );
        expect(p.manca, const Duration(minutes: 40));
        expect(p.accorciaA, const Duration(hours: 3, minutes: 20));
        expect(p.altroGiorno, isNull);
      },
    );

    test(
      'se non resta nemmeno un quarto d\'ora non si propone di accorciare',
      () {
        final p = proposteSeNonEntra<String>(
          durata: const Duration(hours: 1),
          data: domenica,
          libero: const Duration(minutes: 10),
          altriGiorni: const [],
        );
        expect(p.accorciaA, isNull);
        expect(p.manca, const Duration(minutes: 50));
      },
    );

    test('si propone il giorno più vicino in cui entra; a pari distanza, '
        'quello dopo', () {
      final p = proposteSeNonEntra<String>(
        durata: const Duration(hours: 4),
        data: DateTime.utc(2026, 10, 11),
        libero: const Duration(hours: 1),
        altriGiorni: [
          (
            giorno: 'venerdì',
            data: DateTime.utc(2026, 10, 10),
            libero: const Duration(hours: 9),
          ),
          (
            giorno: 'domenica',
            data: DateTime.utc(2026, 10, 12),
            libero: const Duration(hours: 5),
          ),
          (
            giorno: 'lunedì',
            data: DateTime.utc(2026, 10, 13),
            libero: const Duration(hours: 2),
          ),
        ],
      );
      expect(p.altroGiorno?.giorno, 'domenica');
    });

    test('un giorno che sfora già non dà tempo negativo da accorciare', () {
      final p = proposteSeNonEntra<String>(
        durata: const Duration(hours: 1),
        data: domenica,
        libero: const Duration(minutes: -30),
        altriGiorni: const [],
      );
      expect(p.manca, const Duration(hours: 1));
      expect(p.accorciaA, isNull);
    });
  });

  test(
    'si segna dal primo giorno del viaggio; conta solo mentre è in corso',
    () {
      expect(tappeSegnabili(StatoViaggio.definito), isFalse);
      expect(tappeSegnabili(StatoViaggio.inCorso), isTrue);
      expect(tappeSegnabili(StatoViaggio.chiuso), isTrue);
      expect(segnataDuranteIlViaggio(StatoViaggio.inCorso), isTrue);
      expect(segnataDuranteIlViaggio(StatoViaggio.chiuso), isFalse);
    },
  );
}
