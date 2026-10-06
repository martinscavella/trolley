import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dominio/traguardi.dart';

void main() {
  ViaggioVerificato viaggio({
    String id = 'v',
    required DateTime inizio,
    required DateTime fine,
    String? paese = 'PT',
    String? citta = 'Porto',
    int persone = 1,
    bool responsabile = true,
    List<int> fattePerGiorno = const [1],
  }) => (
    id: id,
    inizio: inizio,
    fine: fine,
    paese: paese,
    citta: citta,
    persone: persone,
    responsabile: responsabile,
    fattePerGiorno: fattePerGiorno,
  );

  test('il primo viaggio verificato, da soli, in giornata', () {
    final gita = viaggio(
      inizio: DateTime.utc(2026, 10, 14),
      fine: DateTime.utc(2026, 10, 14),
    );
    expect(traguardiNuovi(questo: gita, verificati: [gita], presi: {}), {
      Traguardo.primoViaggioVerificato,
      Traguardo.ogniGiornoUnaTappa,
    });
  });

  test('in tre, un weekend lungo da venerdì a domenica, organizzato da te', () {
    final porto = viaggio(
      // Venerdì 9 – domenica 11 ottobre 2026.
      inizio: DateTime.utc(2026, 10, 9),
      fine: DateTime.utc(2026, 10, 11),
      persone: 3,
      fattePerGiorno: [2, 0, 3],
    );
    final nuovi = traguardiNuovi(
      questo: porto,
      verificati: [porto],
      presi: {Traguardo.primoViaggioVerificato},
    );
    expect(nuovi, {
      Traguardo.inCompagnia,
      Traguardo.weekendLungo,
      Traguardo.organizzare,
    });
  });

  test('un giorno feriale non è un weekend; una settimana sì', () {
    final feriale = viaggio(
      inizio: DateTime.utc(2026, 10, 13),
      fine: DateTime.utc(2026, 10, 15),
    );
    expect(loDa(Traguardo.weekendLungo, feriale), isFalse);
    final settimana = viaggio(
      inizio: DateTime.utc(2026, 10, 10),
      fine: DateTime.utc(2026, 10, 16),
    );
    expect(loDa(Traguardo.unaSettimana, settimana), isTrue);
    expect(loDa(Traguardo.weekendLungo, settimana), isFalse);
  });

  test('chi partecipa senza esserne responsabile non organizza', () {
    final v = viaggio(
      inizio: DateTime.utc(2026, 10, 14),
      fine: DateTime.utc(2026, 10, 14),
      persone: 2,
      responsabile: false,
    );
    expect(loDa(Traguardo.organizzare, v), isFalse);
    expect(loDa(Traguardo.inCompagnia, v), isTrue);
  });

  test('tre paesi, dieci città e quattro stagioni si contano su tutti i '
      'viaggi verificati', () {
    final verificati = [
      viaggio(
        id: 'a',
        inizio: DateTime.utc(2026, 1, 10),
        fine: DateTime.utc(2026, 1, 10),
        paese: 'ES',
        citta: 'Madrid',
      ),
      viaggio(
        id: 'b',
        inizio: DateTime.utc(2026, 4, 10),
        fine: DateTime.utc(2026, 4, 10),
        paese: 'FR',
        citta: 'Parigi',
      ),
      viaggio(
        id: 'c',
        inizio: DateTime.utc(2026, 7, 10),
        fine: DateTime.utc(2026, 7, 10),
        paese: 'FR',
        citta: 'Lione',
      ),
    ];
    expect(contati(Traguardo.trePaesi, verificati), 2);
    expect(contati(Traguardo.quattroStagioni, verificati), 3);

    final porto = viaggio(
      id: 'd',
      inizio: DateTime.utc(2026, 10, 14),
      fine: DateTime.utc(2026, 10, 14),
    );
    final tutti = [...verificati, porto];
    expect(contati(Traguardo.dieciCitta, tutti), 4);
    final nuovi = traguardiNuovi(
      questo: porto,
      verificati: tutti,
      presi: {Traguardo.primoViaggioVerificato, Traguardo.ogniGiornoUnaTappa},
    );
    expect(nuovi, {Traguardo.trePaesi, Traguardo.quattroStagioni});
  });

  test('un giorno senza tappe fatte (tutte saltate) non è «ogni giorno una '
      'tappa»', () {
    final v = viaggio(
      inizio: DateTime.utc(2026, 10, 14),
      fine: DateTime.utc(2026, 10, 15),
      fattePerGiorno: [1, 0],
    );
    expect(loDa(Traguardo.ogniGiornoUnaTappa, v), isFalse);
  });

  test('i nomi del server si rileggono', () {
    for (final t in Traguardo.values) {
      expect(Traguardo.leggi(t.codice), t);
    }
    expect(Traguardo.leggi('sconosciuto'), isNull);
  });
}
