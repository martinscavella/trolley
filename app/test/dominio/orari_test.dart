import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dominio/giornate.dart';
import 'package:trolley/dominio/orari.dart';

Duration h(int ore, [int minuti = 0]) => Duration(hours: ore, minutes: minuti);

Occupato<String> o(
  String chi,
  Duration inizio,
  Duration durata, {
  bool segnata = false,
}) => Occupato(chi, inizio: inizio, durata: durata, segnata: segnata);

void main() {
  final sabato = FinestraGiorno(
    data: DateTime.utc(2026, 10, 11),
    inizio: inizioGiornata,
    fine: fineGiornata,
  );
  // Il primo giorno si arriva alle 10, l'ultimo si riparte alle 18.
  final venerdi = FinestraGiorno(
    data: DateTime.utc(2026, 10, 10),
    inizio: h(10),
    fine: fineGiornata,
  );
  final domenica = FinestraGiorno(
    data: DateTime.utc(2026, 10, 12),
    inizio: inizioGiornata,
    fine: h(18),
  );

  group('sovrapporsi', () {
    test('toccarsi va bene, entrare l\'una nell\'altra no', () {
      final lello = o('lello', h(10), h(1));
      expect(lello.siSovrapponeA(h(11), h(1)), isFalse);
      expect(lello.siSovrapponeA(h(9), h(1)), isFalse);
      expect(lello.siSovrapponeA(h(10, 30), h(1)), isTrue);
      expect(lello.siSovrapponeA(h(10), h(1)), isTrue);
      expect(lello.siSovrapponeA(h(9), h(3)), isTrue);
    });

    test('gli orari vanno a passi di cinque minuti, arrotondati in su', () {
      expect(alPasso(h(10, 7)), h(10, 10));
      expect(alPasso(h(10, 10)), h(10, 10));
    });
  });

  group('l\'orario proposto', () {
    test('in una giornata vuota, alle 9; il primo giorno, all\'arrivo', () {
      expect(oraProposta<String>(sabato, const [], h(1)), h(9));
      expect(oraProposta<String>(venerdi, const [], h(1)), h(10));
    });

    test('subito dopo l\'ultima tappa', () {
      expect(
        oraProposta(sabato, [
          o('a', h(9), h(1)),
          o('b', h(13), h(1, 30)),
        ], h(1)),
        h(14, 30),
      );
    });

    test('se dopo l\'ultima non entra, il primo spazio libero dalle 9', () {
      expect(
        oraProposta(domenica, [
          o('a', h(9), h(1)),
          o('b', h(14), h(3, 30)),
        ], h(2)),
        h(10),
      );
    });

    test('se dalle 9 non entra più, anche prima', () {
      expect(oraProposta(domenica, [o('a', h(9), h(9))], h(2)), inizioGiornata);
    });

    test('nessuno spazio abbastanza lungo: nessun orario', () {
      expect(
        oraProposta(domenica, [o('a', h(0), h(9)), o('b', h(10), h(8))], h(2)),
        isNull,
      );
    });
  });

  group('che problema c\'è', () {
    final altre = [o('pranzo', h(13), h(1, 30)), o('ponte', h(15), h(1))];

    test('nessuno, se sta in un buco', () {
      expect(problemaOrario(sabato, altre, h(10), h(2)), isNull);
      expect(problemaOrario(sabato, altre, h(14, 30), h(0, 30)), isNull);
    });

    test('sovrapposta, con chi in ordine d\'orario', () {
      final p = problemaOrario(sabato, altre, h(14), h(2));
      expect(p, isA<Sovrapposta<String>>());
      expect(
        [for (final c in (p! as Sovrapposta<String>).con) c.chi],
        ['pranzo', 'ponte'],
      );
    });

    test('prima dell\'arrivo, il primo giorno', () {
      final p = problemaOrario<String>(venerdi, const [], h(9), h(1));
      expect((p! as PrimaDellInizio<String>).inizio, h(10));
    });

    test('dopo la partenza, o oltre mezzanotte: non attraversa la notte', () {
      expect(
        problemaOrario<String>(domenica, const [], h(17), h(2)),
        isA<DopoLaFine<String>>(),
      );
      expect(
        problemaOrario<String>(sabato, const [], h(23), h(2)),
        isA<DopoLaFine<String>>(),
      );
      expect(problemaOrario<String>(sabato, const [], h(22), h(2)), isNull);
    });
  });

  group('le proposte', () {
    final altre = [
      o('lello', h(9), h(1)),
      o('pranzo', h(13), h(1, 30)),
      o('ponte', h(15), h(1)),
    ];

    test('l\'orario libero più vicino a quello scelto, prima o dopo', () {
      // Alle 13 c'è il pranzo: un'ora sta alle 12 (prima) o alle 16 (dopo).
      final p = proposteOrario<String, String>(
        finestra: sabato,
        altre: altre,
        inizio: h(13),
        durata: h(1),
      );
      expect(p.orarioLibero, h(12));
      // Alle 14: il buco delle 14:30 è troppo corto; le 12 e le 16 sono a
      // due ore, e vince quella dopo.
      expect(
        proposteOrario<String, String>(
          finestra: sabato,
          altre: altre,
          inizio: h(14),
          durata: h(1),
        ).orarioLibero,
        h(16),
      );
    });

    test('a pari distanza, quello dopo', () {
      expect(
        proposteOrario<String, String>(
          finestra: sabato,
          altre: [o('a', h(10), h(2))],
          inizio: h(10, 30),
          durata: h(1),
        ).orarioLibero,
        h(12),
      );
    });

    test('tenere l\'orario e spostare in avanti le successive', () {
      // Alle 12:30 per un'ora e mezza: il pranzo va alle 14, e finendo alle
      // 15:30 spinge il ponte alle 15:30.
      final p = proposteOrario<String, String>(
        finestra: sabato,
        altre: altre,
        inizio: h(12, 30),
        durata: h(1, 30),
      );
      expect(p.spostaDopo, [
        (chi: 'pranzo', inizio: h(14)),
        (chi: 'ponte', inizio: h(15, 30)),
      ]);
    });

    test('lo spostamento si ferma alla prima tappa che non tocca più', () {
      final p = proposteOrario<String, String>(
        finestra: sabato,
        altre: altre,
        inizio: h(12, 45),
        durata: h(0, 30),
      );
      expect(p.spostaDopo, [(chi: 'pranzo', inizio: h(13, 15))]);
    });

    test('non si sposta una tappa già cominciata, né una segnata, né oltre '
        'la fine', () {
      // Alle 13:30 il pranzo è già cominciato.
      expect(
        proposteOrario<String, String>(
          finestra: sabato,
          altre: altre,
          inizio: h(13, 30),
          durata: h(1),
        ).spostaDopo,
        isNull,
      );
      expect(
        proposteOrario<String, String>(
          finestra: sabato,
          altre: [o('fatta', h(13), h(1), segnata: true)],
          inizio: h(12, 30),
          durata: h(1),
        ).spostaDopo,
        isNull,
      );
      expect(
        proposteOrario<String, String>(
          finestra: domenica,
          altre: [o('treno', h(16), h(2))],
          inizio: h(15),
          durata: h(2),
        ).spostaDopo,
        isNull,
      );
    });

    test('accorciarla a quel che resta fino alla tappa dopo', () {
      final p = proposteOrario<String, String>(
        finestra: sabato,
        altre: altre,
        inizio: h(12, 10),
        durata: h(1, 30),
      );
      expect(p.accorciaA, h(0, 50));
      // Meno di un quarto d'ora non è una tappa.
      expect(
        proposteOrario<String, String>(
          finestra: sabato,
          altre: altre,
          inizio: h(12, 50),
          durata: h(1),
        ).accorciaA,
        isNull,
      );
    });

    test('accorciarla fino alla partenza, l\'ultimo giorno', () {
      expect(
        proposteOrario<String, String>(
          finestra: domenica,
          altre: const [],
          inizio: h(16),
          durata: h(4),
        ).accorciaA,
        h(2),
      );
    });

    test('il giorno più vicino, alla stessa ora se lì è libera', () {
      final p = proposteOrario<String, String>(
        finestra: sabato,
        altre: [o('tutto', h(0), h(24))],
        inizio: h(15),
        durata: h(2),
        altriGiorni: [
          (giorno: 'ven', finestra: venerdi, occupati: [o('x', h(15), h(1))]),
          (giorno: 'dom', finestra: domenica, occupati: const []),
        ],
      );
      // Venerdì e domenica sono vicini uguali: si prende quello dopo, e
      // domenica alle 15 c'è posto.
      expect(p.altroGiorno?.giorno, 'dom');
      expect(p.altroGiorno?.ora, h(15));
      expect(p.orarioLibero, isNull);
      expect(p.libero, Duration.zero);
    });

    test('in un altro giorno, se l\'ora è presa, all\'orario proposto', () {
      final p = proposteOrario<String, String>(
        finestra: sabato,
        altre: [o('tutto', h(0), h(24))],
        inizio: h(15),
        durata: h(2),
        altriGiorni: [
          (giorno: 'dom', finestra: domenica, occupati: [o('x', h(15), h(1))]),
        ],
      );
      expect(p.altroGiorno?.ora, h(16));
    });
  });

  group('collocare le tappe senza orario', () {
    test('quelle con l\'orario stanno dove dicono, in ordine d\'orario', () {
      final c = colloca(sabato, [
        (tappa: 'b', ora: h(15), durata: h(1)),
        (tappa: 'a', ora: h(10), durata: h(1)),
      ]);
      expect([for (final x in c) x.tappa], ['a', 'b']);
      expect(c.first.proposto, isFalse);
    });

    test('quelle senza, in fila dalle 9, ciascuna dopo la precedente', () {
      final c = colloca(sabato, [
        (tappa: 'a', ora: null, durata: h(1)),
        (tappa: 'b', ora: null, durata: h(1, 30)),
        (tappa: 'c', ora: h(14), durata: h(1)),
        (tappa: 'd', ora: null, durata: h(1)),
      ]);
      expect(
        {for (final x in c) x.tappa: x.inizio},
        {'a': h(9), 'b': h(10), 'c': h(14), 'd': h(15)},
      );
      expect(c.firstWhere((x) => x.tappa == 'a').proposto, isTrue);
    });

    test('una senza orario salta il buco troppo corto', () {
      final c = colloca(sabato, [
        (tappa: 'a', ora: h(9, 30), durata: h(1)),
        (tappa: 'b', ora: null, durata: h(1)),
        (tappa: 'c', ora: h(11), durata: h(1)),
      ]);
      expect(c.firstWhere((x) => x.tappa == 'b').inizio, h(12));
    });

    test('il primo giorno partono dall\'arrivo', () {
      final c = colloca(venerdi, [(tappa: 'a', ora: null, durata: h(1))]);
      expect(c.single.inizio, h(10));
    });
  });

  group('le tappe fuori posto', () {
    test('quelle che si sovrappongono, e quelle fuori dalla giornata', () {
      final c = colloca(domenica, [
        (tappa: 'a', ora: h(10), durata: h(2)),
        (tappa: 'b', ora: h(11), durata: h(1)),
        (tappa: 'c', ora: h(13), durata: h(1)),
        (tappa: 'd', ora: h(17), durata: h(2)),
      ]);
      expect(conflitti(domenica, c), {'a', 'b', 'd'});
    });

    test('quelle senza orario che non trovano posto finiscono in fondo, '
        'fuori', () {
      final c = colloca(domenica, [
        (tappa: 'a', ora: null, durata: h(10)),
        (tappa: 'b', ora: null, durata: h(10)),
      ]);
      expect(conflitti(domenica, c), {'b'});
    });
  });

  group('le tappe nuove di un itinerario incollato', () {
    test('a un\'ora libera restano; a un\'ora presa vanno nel primo spazio '
        'dopo, e si dice; senza ora, dopo quella prima', () {
      final dove = collocaNuove(
        sabato,
        [o('pranzo', h(13), h(1, 30))],
        [
          (ora: h(10), durata: h(1)),
          (ora: h(14), durata: h(1)),
          (ora: null, durata: h(1)),
        ],
      );
      expect(dove, [
        (ora: h(10), spostata: false),
        (ora: h(14, 30), spostata: true),
        (ora: h(15, 30), spostata: false),
      ]);
    });

    test('senza ora in una giornata con tappe, dopo l\'ultima', () {
      expect(
        collocaNuove(sabato, [o('a', h(9), h(2))], [(ora: null, durata: h(1))]),
        [(ora: h(11), spostata: false)],
      );
    });

    test('due alla stessa ora: la seconda va dopo la prima', () {
      expect(
        collocaNuove<String>(sabato, const [], [
          (ora: h(10), durata: h(1)),
          (ora: h(10), durata: h(1)),
        ]),
        [(ora: h(10), spostata: false), (ora: h(11), spostata: true)],
      );
    });
  });
}
