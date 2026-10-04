import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dominio/valute.dart';

void main() {
  group('leggere un importo', () {
    test('con la virgola o col punto, e le migliaia', () {
      expect(leggiImporto('12,40'), 1240);
      expect(leggiImporto('12.40'), 1240);
      expect(leggiImporto('12,4'), 1240);
      expect(leggiImporto('300'), 30000);
      expect(leggiImporto('1.234,50'), 123450);
      expect(leggiImporto('1,234.50'), 123450);
      expect(leggiImporto('1.500'), 150000);
      expect(leggiImporto('1 500'), 150000);
      expect(leggiImporto(' 0,99 '), 99);
      expect(leggiImporto(',50'), 50);
    });

    test('non indovina quello che non è un importo', () {
      expect(leggiImporto(''), isNull);
      expect(leggiImporto('0'), isNull);
      expect(leggiImporto('0,00'), isNull);
      expect(leggiImporto('12,345'), isNull);
      expect(leggiImporto('1.2.3'), isNull);
      expect(leggiImporto('12,40,1'), isNull);
      expect(leggiImporto('1.23.456,00'), isNull);
      expect(leggiImporto('abc'), isNull);
      expect(leggiImporto('-5'), isNull);
      // Il server tiene dodici cifre, due dopo la virgola.
      expect(leggiImporto('100000000'), isNull);
      expect(leggiImporto('99999999,99'), 9999999999);
    });

    test('in una valuta senza centesimi, niente centesimi', () {
      expect(leggiImporto('1500', decimali: 0), 150000);
      expect(leggiImporto('1.500', decimali: 0), 150000);
      expect(leggiImporto('12,50', decimali: 0), isNull);
    });
  });

  test('l\'importo del server diventa centesimi, e torna com\'era', () {
    expect(centesimiDa('12.40'), 1240);
    expect(centesimiDa('12.4'), 1240);
    expect(centesimiDa('300'), 30000);
    expect(centesimiDa('0.05'), 5);
    expect(importoPerIlServer(1240), '12.40');
    expect(importoPerIlServer(5), '0.05');
    expect(importoPerIlServer(30000), '300.00');
  });

  test('scrivere un importo: l\'euro col simbolo, le altre col codice', () {
    expect(scriviImporto(1240, 'EUR'), '12,40 €');
    expect(scriviImporto(123450, 'MAD'), '1.234,50 MAD');
    expect(scriviImporto(150000, 'JPY'), '1.500 JPY');
    expect(scriviImporto(1234567890, 'EUR'), '12.345.678,90 €');
    expect(scriviImporto(0, 'EUR'), '0,00 €');
    // Un codice che l'app non conosce si scrive com'è.
    expect(scriviImporto(100, 'ZZZ'), '1,00 ZZZ');
  });

  test(
    'per cambiare una spesa, l\'importo si riscrive com\'è stato scritto',
    () {
      expect(importoDaModificare(1240), '12,40');
      expect(importoDaModificare(30000), '300');
    },
  );

  group('il tastierino della spesa veloce', () {
    String scrivi(List<String> tasti, {int decimali = 2}) => tasti.fold(
      '',
      (testo, tasto) => conIlTasto(testo, tasto, decimali: decimali),
    );

    test('cifre e virgola fanno un importo che si legge', () {
      final testo = scrivi(['1', '2', ',', '5', '0']);
      expect(testo, '12,50');
      expect(leggiImporto(testo), 1250);
    });

    test('la virgola per prima diventa «0,», e una seconda non entra', () {
      expect(scrivi([',', '5']), '0,5');
      expect(scrivi(['3', ',', ',', '2']), '3,2');
    });

    test('non più decimali di quanti ne ha la valuta', () {
      expect(scrivi(['1', ',', '2', '3', '4']), '1,23');
      expect(scrivi(['1', '5', ',', '0'], decimali: 0), '150');
    });

    test('niente zeri davanti, e non oltre le cifre del server', () {
      expect(scrivi(['0', '0', '7']), '7');
      expect(scrivi(List.filled(12, '9')), '9' * cifreMassime);
    });

    test('si cancella dall\'ultima', () {
      expect(scrivi(['1', '2', ',', tastoCancella, tastoCancella]), '1');
      expect(scrivi([tastoCancella]), '');
    });
  });

  group('convertire', () {
    const perEuro = {'MAD': 11.18, 'USD': 1.125, 'JPY': 176.99};

    test('passando per l\'euro', () {
      expect(converti(17000, da: 'MAD', a: 'EUR', perEuro: perEuro), 1521);
      expect(converti(1000, da: 'EUR', a: 'MAD', perEuro: perEuro), 11180);
      expect(converti(1000, da: 'USD', a: 'MAD', perEuro: perEuro), 9938);
      expect(converti(1000, da: 'MAD', a: 'MAD', perEuro: const {}), 1000);
    });

    test('senza il tasso non si inventa', () {
      expect(converti(1000, da: 'VND', a: 'EUR', perEuro: perEuro), isNull);
      expect(converti(1000, da: 'EUR', a: 'VND', perEuro: perEuro), isNull);
    });

    test('il tasso in parole, con la propria valuta a sinistra', () {
      expect(
        tassoInParole(mia: 'EUR', altra: 'MAD', perEuro: perEuro),
        '1 € = 11,18 MAD',
      );
      expect(
        tassoInParole(mia: 'EUR', altra: 'JPY', perEuro: perEuro),
        '1 € = 177 JPY',
      );
      expect(
        tassoInParole(mia: 'MAD', altra: 'EUR', perEuro: perEuro),
        '1 MAD = 0,0894 €',
      );
      expect(tassoInParole(mia: 'EUR', altra: 'VND', perEuro: perEuro), isNull);
    });
  });

  test('la valuta di un paese', () {
    expect(valutaDelPaese('MA'), 'MAD');
    expect(valutaDelPaese('pt'), 'EUR');
    expect(valutaDelPaese('US'), 'USD');
    expect(valutaDelPaese('SN'), 'XOF');
    expect(valutaDelPaese('GB'), 'GBP');
    expect(valutaDelPaese(null), isNull);
    expect(valutaDelPaese('XX'), isNull);
  });

  test('ogni valuta di un paese è nell\'elenco', () {
    for (final paese in ['MA', 'PT', 'US', 'JP', 'VN', 'TH', 'CH', 'SN']) {
      expect(valutaNota(valutaDelPaese(paese)!), isTrue, reason: paese);
    }
  });

  test('cercare una valuta, per codice o per nome', () {
    expect(cercaValute('mad').first.codice, 'MAD');
    expect(
      cercaValute('dirham').map((v) => v.codice),
      containsAll(['MAD', 'AED']),
    );
    expect(cercaValute('yen').first.codice, 'JPY');
    expect(cercaValute('zloty').single.codice, 'PLN');
    expect(cercaValute(''), valute);
    expect(cercaValute('qwerty'), isEmpty);
  });

  test('l\'elenco non ha codici doppi, e i codici sono di tre lettere', () {
    final codici = valute.map((v) => v.codice).toList();
    expect(codici.toSet(), hasLength(codici.length));
    for (final c in codici) {
      expect(RegExp(r'^[A-Z]{3}$').hasMatch(c), isTrue, reason: c);
    }
  });
}
