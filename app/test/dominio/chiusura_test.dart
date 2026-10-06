import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dominio/chiusura.dart';
import 'package:trolley/dominio/stato_viaggio.dart';

void main() {
  final oggi = DateTime(2026, 10, 13, 9);

  test('si chiude da solo il giorno dopo la fine, se il server lo dice ancora '
      'definito', () {
    expect(
      daChiudereDaSolo(
        registrato: 'definito',
        fine: DateTime(2026, 10, 12),
        oggi: oggi,
      ),
      isTrue,
    );
    expect(
      daChiudereDaSolo(
        registrato: 'definito',
        fine: DateTime(2026, 10, 13),
        oggi: oggi,
      ),
      isFalse,
    );
    expect(
      daChiudereDaSolo(
        registrato: 'chiuso',
        fine: DateTime(2026, 10, 12),
        oggi: oggi,
      ),
      isFalse,
    );
    expect(
      daChiudereDaSolo(registrato: 'idea', fine: null, oggi: oggi),
      isFalse,
    );
  });

  test('prima della fine lo chiude a mano solo chi è responsabile, mentre è '
      'in corso', () {
    expect(
      siChiudeAMano(stato: StatoViaggio.inCorso, responsabile: true),
      isTrue,
    );
    expect(
      siChiudeAMano(stato: StatoViaggio.inCorso, responsabile: false),
      isFalse,
    );
    expect(
      siChiudeAMano(stato: StatoViaggio.definito, responsabile: true),
      isFalse,
    );
  });

  test('il riepilogo si apre da solo per un mese', () {
    expect(riepilogoDaSolo(fine: DateTime(2026, 10, 12), oggi: oggi), isTrue);
    expect(riepilogoDaSolo(fine: DateTime(2026, 8, 1), oggi: oggi), isFalse);
  });

  test('i punti viaggio: una gita 1, un weekend 1,1, una settimana 1,6, fino '
      'a 2', () {
    expect(puntiViaggio(1), 1.0);
    expect(puntiViaggio(2), 1.1);
    expect(puntiViaggio(7), 1.6);
    expect(puntiViaggio(30), 2.0);
  });

  group('che cosa c\'è di nuovo', () {
    MetaChiusa meta(String id, int mese, String? citta, String paese) =>
        (id: id, inizio: DateTime(2026, mese), paese: paese, citta: citta);

    test('il primo viaggio in un paese: paese e città nuovi', () {
      final n = novitaDelViaggio(meta('porto', 10, 'Porto', 'PT'), [
        meta('madrid', 5, 'Madrid', 'ES'),
      ]);
      expect((n.paeseNuovo, n.cittaNuova, n.volte), (true, true, 1));
    });

    test('un\'altra città dello stesso paese, e la stessa città un\'altra '
        'volta', () {
      final lisbona = meta('lisbona', 3, 'Lisbona', 'PT');
      final n = novitaDelViaggio(meta('porto', 10, 'Porto', 'PT'), [lisbona]);
      expect((n.paeseNuovo, n.cittaNuova), (false, true));

      final ancora = novitaDelViaggio(meta('porto2', 12, 'porto', 'PT'), [
        lisbona,
        meta('porto', 10, 'Porto', 'PT'),
      ]);
      expect(ancora.niente, isTrue);
      expect(ancora.volte, 2);
    });

    test('contano solo i viaggi di prima', () {
      final n = novitaDelViaggio(meta('porto', 3, 'Porto', 'PT'), [
        meta('porto-dopo', 10, 'Porto', 'PT'),
      ]);
      expect(n.cittaNuova, isTrue);
    });
  });

  test('dopo la chiusura non si aggiungono tappe', () {
    expect(tappeAggiungibili(StatoViaggio.inCorso), isTrue);
    expect(tappeAggiungibili(StatoViaggio.chiuso), isFalse);
  });
}
