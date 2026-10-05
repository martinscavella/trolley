import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dati/destinazioni.dart';
import 'package:trolley/dominio/testo.dart';

void main() {
  test('normalizzare toglie maiuscole, accenti e punteggiatura', () {
    expect(normalizza('Sant\'Agata de\' Goti'), 'sant agata de goti');
    expect(normalizza('Sant’Agata'), 'sant agata');
    expect(normalizza('  Malmö  '), 'malmo');
    expect(normalizza('Reykjavík'), 'reykjavik');
    expect(normalizza('Łódź'), 'lodz');
    expect(normalizza('Straße'), 'strasse');
    expect(normalizza('Fær Øer'), 'faer oer');
    expect(normalizza('İstanbul'), 'istanbul');
    expect(normalizza('Saint-Barthélemy'), 'saint barthelemy');
    expect(normalizza('Αθήνα'), 'αθήνα');
    expect(normalizza('...'), '');
  });

  group('l\'elenco incorporato', () {
    late ElencoDestinazioni elenco;

    setUpAll(() {
      elenco = ElencoDestinazioni.daTesto(
        File('assets/destinazioni.tsv').readAsStringSync(),
      );
    });

    List<String> nomi(String testo, {int quante = 3}) => [
      for (final d in elenco.cerca(testo, quante: quante))
        '${d.nome}/${d.paese}',
    ];

    test('contiene i paesi, le città del mondo e i comuni italiani', () {
      expect(elenco.lunghezza, greaterThan(15000));
      expect(nomi('Matera', quante: 1), ['Matera/IT']);
      expect(nomi('positano', quante: 1), ['Positano/IT']);
    });

    test(
      'le città del mondo si trovano col nome italiano e con quello inglese',
      () {
        expect(nomi('lisbona', quante: 1), ['Lisbona/PT']);
        expect(nomi('Lisbon', quante: 1), ['Lisbona/PT']);
        expect(nomi('munich', quante: 1), ['Monaco di Baviera/DE']);
        expect(nomi('dubrovnik', quante: 1), ['Ragusa/HR']);
      },
    );

    test('conta come corrisponde, e quanto è grande e vicina', () {
      expect(nomi('roma', quante: 2), ['Roma/IT', 'Romania/RO']);
      expect(nomi('valencia', quante: 1), ['Valencia/ES']);
      expect(nomi('ragusa', quante: 2), ['Ragusa/IT', 'Ragusa/HR']);
      expect(nomi('florence', quante: 1), ['Firenze/IT']);
      expect(nomi('monaco', quante: 2), [
        'Principato di Monaco/MC',
        'Monaco di Baviera/DE',
      ]);
    });

    test('si trova anche dall\'inizio di una parola in mezzo', () {
      expect(nomi('baviera', quante: 1), ['Monaco di Baviera/DE']);
      expect(nomi('york'), ['York/GB', 'York/US', 'New York/US']);
    });

    test('i paesi si trovano anche coi nomi di tutti i giorni', () {
      expect(nomi('olanda', quante: 1), ['Paesi Bassi/NL']);
      expect(nomi('Scozia', quante: 1), ['Regno Unito/GB']);
      expect(elenco.cerca('stati', soloPaesi: true).first.nome, 'Stati Uniti');
    });

    test('un paese intero non ha città', () {
      final giappone = elenco.cerca('giappone', soloPaesi: true).single;
      expect(giappone.tipo, TipoDestinazione.paese);
      expect(giappone.citta, isNull);
      expect(giappone.nomePaese, 'Giappone');
    });

    test('i comuni omonimi si distinguono con la provincia', () {
      final samone = elenco.cerca('samone');
      expect(samone.map((d) => d.dettaglio).toSet(), {'TO', 'TN'});
    });

    test('la meta di un viaggio si ritrova con le sue coordinate, per la '
        'mappa', () {
      final porto = elenco.trova(citta: 'Porto', paese: 'PT')!;
      expect(porto.nome, 'Porto');
      expect((porto.lat, porto.lon), (41.152, -8.622));
      // La città con lo stesso nome in un altro paese non è lei.
      expect(elenco.trova(citta: 'Porto', paese: 'BR')?.paese, 'BR');
      expect(
        elenco.trova(citta: 'Porto', paese: 'BR')?.tipo,
        isNot(TipoDestinazione.citta),
      );
      // Scritta a mano: resta il paese.
      final isola = elenco.trova(citta: 'Isola che non c\'è', paese: 'PT')!;
      expect(isola.tipo, TipoDestinazione.paese);
      expect(elenco.trova(citta: 'Isola che non c\'è'), isNull);
      expect(elenco.trova(), isNull);
      // Scritta a mano, in inglese e senza paese: la si riconosce lo stesso.
      final copenaghen = elenco.trova(citta: 'Copenhagen')!;
      expect((copenaghen.nome, copenaghen.paese), ('Copenaghen', 'DK'));
      expect(elenco.trova(citta: 'københavn')?.nome, 'Copenaghen');
      // Senza paese vince la più probabile.
      expect(elenco.trova(citta: 'Londra')?.paese, 'GB');
    });

    test('ogni codice di paese ha il suo nome', () {
      for (final d in elenco.cerca('a', quante: 100000)) {
        expect(nomeDelPaese(d.paese), isNotNull, reason: d.toString());
      }
    });

    test('niente di vuoto, niente di strano', () {
      expect(elenco.cerca(''), isEmpty);
      expect(elenco.cerca('   '), isEmpty);
      expect(elenco.cerca('xqzwv'), isEmpty);
    });

    test('il paese di un punto è quello della città più vicina: per la '
        'verifica, non per tracciare confini', () {
      expect(elenco.paeseDi((lat: 41.1496, lon: -8.6110)), 'PT'); // Porto
      expect(elenco.paeseDi((lat: 55.6761, lon: 12.5683)), 'DK'); // Copenaghen
      expect(elenco.paeseDi((lat: 40.6280, lon: 14.4850)), 'IT'); // Positano
      expect(elenco.paeseDi((lat: 45.8150, lon: 15.9819)), 'HR'); // Zagabria
      // In mezzo all'Atlantico non si dice.
      expect(elenco.paeseDi((lat: 35.0, lon: -40.0)), isNull);
    });
  });

  test('un nome scritto a mano resta com\'è, col paese se c\'è', () {
    const dolomiti = Destinazione.aMano('Dolomiti', paese: 'IT');
    expect(dolomiti.citta, 'Dolomiti');
    expect(dolomiti.nomePaese, 'Italia');
    expect(const Destinazione.aMano('Da qualche parte').paese, isNull);
  });
}
