import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dominio/mappa.dart';
import 'package:trolley/dominio/tragitti.dart';

Duration h(int ore, [int minuti = 0]) => Duration(hours: ore, minutes: minuti);

// A Porto: la Livraria Lello, la Torre dos Clérigos (circa 160 m), il
// Mercado do Bolhão (circa 900 m dalla torre), il Ponte Dom Luís I.
const lello = (lat: 41.14686, lon: -8.61479);
const torre = (lat: 41.14573, lon: -8.61398);
const bolhao = (lat: 41.14904, lon: -8.60580);
const ponte = (lat: 41.13996, lon: -8.60937);

TappaDelTragitto tappa(
  String id,
  Duration inizio,
  Duration durata, {
  Mezzo? mezzo,
  Coordinate? posto,
  bool saltata = false,
}) => (
  id: id,
  inizio: inizio,
  fine: inizio + durata,
  saltata: saltata,
  mezzo: mezzo,
  posto: posto,
);

void main() {
  group('la stima', () {
    test('a piedi, un chilometro in linea d\'aria: circa 20 minuti', () {
      // 1000 × 1,3 = 1,3 km a 4,5 km/h = 17,3 minuti, ai cinque in su.
      expect(Mezzo.aPiedi.stima(1000), const Duration(minutes: 20));
    });

    test('mai meno di cinque minuti', () {
      expect(Mezzo.aPiedi.stima(50), const Duration(minutes: 5));
      expect(Mezzo.bici.stima(0), const Duration(minutes: 5));
    });

    test('i mezzi contano l\'attesa e la strada fino alla fermata', () {
      // 3 km × 1,3 = 3,9 km a 15 km/h = 15,6 minuti, più 8.
      expect(Mezzo.mezzi.stima(3000), const Duration(minutes: 25));
    });

    test('auto e taxi contano partire e parcheggiare; il monopattino è la '
        'bici', () {
      expect(Mezzo.auto.stima(5000), Mezzo.taxi.stima(5000));
      expect(Mezzo.monopattino.stima(2500), Mezzo.bici.stima(2500));
      // 5 km × 1,3 = 6,5 km a 22 km/h = 17,7 minuti, più 3.
      expect(Mezzo.auto.stima(5000), const Duration(minutes: 25));
    });

    test('i codici sono quelli del server, e uno sconosciuto non è un '
        'mezzo', () {
      expect(
        [for (final m in Mezzo.values) m.codice],
        ['a_piedi', 'bici', 'mezzi', 'monopattino', 'auto', 'taxi'],
      );
      expect(Mezzo.leggi('mezzi'), Mezzo.mezzi);
      expect(Mezzo.leggi('elicottero'), isNull);
      expect(Mezzo.leggi(null), isNull);
    });
  });

  group('i tragitti della giornata', () {
    test('uno fra ogni tappa e quella dopo nel tempo, con il mezzo di quella '
        'a cui si arriva', () {
      final t = tragittiDelGiorno([
        tappa('pranzo', h(12, 30), h(1, 30), posto: bolhao),
        tappa('lello', h(9), h(1), posto: lello),
        tappa('torre', h(10, 15), h(1), mezzo: Mezzo.aPiedi, posto: torre),
      ]);
      expect(
        [for (final x in t) (x.daId, x.aId)],
        [('lello', 'torre'), ('torre', 'pranzo')],
      );
      expect(t.first.mezzo, Mezzo.aPiedi);
      expect(t.first.spazio, const Duration(minutes: 15));
      expect(t.first.stima(), const Duration(minutes: 5));
      expect(t.first.nonCiStai, isFalse);
      expect(t.last.mezzo, isNull);
      expect(t.last.stima(), isNull, reason: '«Come ci vai?»: senza stima');
      expect(t.last.stima(Mezzo.aPiedi), isNotNull);
    });

    test('una tappa saltata non ha tragitto: si va dalla tappa prima', () {
      final t = tragittiDelGiorno([
        tappa('lello', h(9), h(1)),
        tappa('torre', h(10, 15), h(1), saltata: true),
        tappa('pranzo', h(12, 30), h(1)),
      ]);
      expect([for (final x in t) (x.daId, x.aId)], [('lello', 'pranzo')]);
    });

    test('due tappe che si sovrappongono non hanno un tragitto fra loro', () {
      final t = tragittiDelGiorno([
        tappa('a', h(9), h(2)),
        tappa('b', h(10), h(1)),
        tappa('c', h(12), h(1)),
      ]);
      expect([for (final x in t) (x.daId, x.aId)], [('b', 'c')]);
    });

    test('senza il posto di una delle due, il mezzo senza tempo', () {
      final t = tragittiDelGiorno([
        tappa('a', h(9), h(1), posto: lello),
        tappa('b', h(10), h(1), mezzo: Mezzo.bici),
      ]).single;
      expect(t.metri, isNull);
      expect(t.stima(), isNull);
      expect(t.nonCiStai, isFalse);
      expect(t.piuVeloce, isNull);
      expect(t.arrivoPossibile, isNull);
    });
  });

  group('quando non ci si sta', () {
    // Dal pranzo al ponte: circa 1 km, 10 minuti liberi.
    final stretto = tragittiDelGiorno([
      tappa('pranzo', h(12, 30), h(1, 30), posto: bolhao),
      tappa('ponte', h(14, 10), h(1), mezzo: Mezzo.aPiedi, posto: ponte),
    ]).single;

    test('la stima è più lunga dello spazio libero', () {
      expect(stretto.spazio, const Duration(minutes: 10));
      expect(stretto.stima(), const Duration(minutes: 20));
      expect(stretto.nonCiStai, isTrue);
    });

    test('propone il mezzo più veloce che ci sta', () {
      expect(stretto.piuVeloce, Mezzo.bici);
      expect(stretto.stima(Mezzo.bici)! <= stretto.spazio, isTrue);
    });

    test('e l\'ora a cui la tappa dopo potrebbe cominciare', () {
      expect(stretto.arrivoPossibile, h(14, 20));
    });

    test('se ci si sta, niente da proporre', () {
      final largo = tragittiDelGiorno([
        tappa('pranzo', h(12, 30), h(1, 30), posto: bolhao),
        tappa('ponte', h(15), h(1), mezzo: Mezzo.aPiedi, posto: ponte),
      ]).single;
      expect(largo.nonCiStai, isFalse);
      expect(largo.arrivoPossibile, isNull);
    });

    test('se nessun mezzo ci sta, nessuno da proporre', () {
      final niente = tragittiDelGiorno([
        tappa('a', h(9), h(1), posto: lello),
        tappa(
          'b',
          h(10),
          h(1),
          mezzo: Mezzo.aPiedi,
          posto: (lat: 41.2, lon: -8.6),
        ),
      ]).single;
      expect(niente.nonCiStai, isTrue);
      expect(niente.piuVeloce, isNull);
      expect(niente.arrivoPossibile, isNotNull);
    });

    test('il mezzo già scelto, se è il più veloce, non si ripropone', () {
      final inBici = tragittiDelGiorno([
        tappa('pranzo', h(12, 30), h(1, 30), posto: bolhao),
        tappa('ponte', h(14, 10), h(1), mezzo: Mezzo.bici, posto: ponte),
      ]).single;
      expect(inBici.nonCiStai, isFalse);
      expect(inBici.piuVeloce, isNull);
    });
  });
}
