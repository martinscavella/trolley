import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dominio/mappa.dart';
import 'package:trolley/dominio/stato_viaggio.dart';
import 'package:trolley/dominio/tappe.dart';

typedef _T = ({String id, StatoTappa stato, Coordinate? posto});
typedef _V = ({String id, StatoViaggio stato, DateTime? inizio});

/// La mappa (fase 3.2, 08-mappa.md): i numeri della giornata, la prossima,
/// il tratto già percorso, quale giorno e quale viaggio si aprono.
void main() {
  const lello = (lat: 41.14686, lon: -8.61479);
  const torre = (lat: 41.14573, lon: -8.61391);
  const ribeira = (lat: 41.14063, lon: -8.61307);

  group('le distanze', () {
    test('fra due posti di Porto, in metri', () {
      // Dalla Livraria Lello alla Torre dos Clérigos: un isolato e mezzo.
      expect(distanzaInMetri(lello, torre), closeTo(146, 5));
      expect(distanzaInMetri(lello, lello), 0);
    });

    test('un grado di meridiano è un po\' più di centoundici chilometri', () {
      expect(
        distanzaInMetri((lat: 0, lon: 0), (lat: 1, lon: 0)),
        closeTo(111195, 50),
      );
    });

    test(
      'le coordinate valgono solo se ci sono tutte e due, e sulla Terra',
      () {
        expect(coordinate(41.1, -8.6), (lat: 41.1, lon: -8.6));
        expect(coordinate(null, -8.6), isNull);
        expect(coordinate(41.1, null), isNull);
        expect(coordinate(91, 0), isNull);
        expect(coordinate(0, 181), isNull);
      },
    );
  });

  group('le tappe di una giornata', () {
    final giornata = <_T>[
      (id: 'duomo', stato: StatoTappa.completata, posto: lello),
      (id: 'senza', stato: StatoTappa.saltata, posto: null),
      (id: 'torre', stato: StatoTappa.daFare, posto: torre),
      (id: 'ribeira', stato: StatoTappa.daFare, posto: ribeira),
    ];
    List<TappaSullaMappa<_T>> sulla({bool conProssima = false}) =>
        tappeSullaMappa(
          tappe: giornata,
          statoDi: (t) => t.stato,
          postoDi: (t) => t.posto,
          conProssima: conProssima,
        );

    test('numerate come nella giornata, anche quella senza posto', () {
      final s = sulla();
      expect([for (final t in s) t.numero], [1, 2, 3, 4]);
      expect(s[1].posto, isNull);
      expect(
        [for (final t in s) t.segno],
        [
          SegnoTappa.fatta,
          SegnoTappa.saltata,
          SegnoTappa.daFare,
          SegnoTappa.daFare,
        ],
      );
    });

    test('la prossima è la prima da fare, e solo quando si chiede', () {
      final s = sulla(conProssima: true);
      expect(
        [for (final t in s) t.segno],
        [
          SegnoTappa.fatta,
          SegnoTappa.saltata,
          SegnoTappa.prossima,
          SegnoTappa.daFare,
        ],
      );
    });

    test('la linea salta la tappa senza posto, ed è percorsa dove si è '
        'già passati', () {
      final tratti = trattiDellaGiornata(sulla(conProssima: true));
      expect(tratti, hasLength(2));
      expect(tratti[0], (da: lello, a: torre, percorso: true));
      expect(tratti[1], (da: torre, a: ribeira, percorso: false));
    });

    test('un posto solo non fa una linea', () {
      expect(
        trattiDellaGiornata(
          tappeSullaMappa(
            tappe: [giornata.first],
            statoDi: (t) => t.stato,
            postoDi: (t) => t.posto,
          ),
        ),
        isEmpty,
      );
    });
  });

  group('il giorno che si apre', () {
    final giorni = [
      DateTime.utc(2026, 10, 10),
      DateTime.utc(2026, 10, 11),
      DateTime.utc(2026, 10, 12),
    ];
    DateTime? apre(DateTime oggi) =>
        giornoDellaMappa(giorni: giorni, dataDi: (d) => d, oggi: oggi);

    test('oggi, se il viaggio lo comprende', () {
      expect(apre(DateTime(2026, 10, 11, 23, 30)), giorni[1]);
    });

    test('il primo, se deve ancora cominciare', () {
      expect(apre(DateTime(2026, 9, 1)), giorni.first);
    });

    test('l\'ultimo, se è finito', () {
      expect(apre(DateTime(2026, 11, 1)), giorni.last);
    });

    test('nessuno, se non ha giorni', () {
      expect(
        giornoDellaMappa<DateTime>(
          giorni: const [],
          dataDi: (d) => d,
          oggi: DateTime(2026, 10, 11),
        ),
        isNull,
      );
    });
  });

  group('il viaggio che apre «Mappa» dall\'elenco', () {
    String? apre(List<_V> viaggi, {String? scelto}) => viaggioPerLaMappa(
      viaggi: viaggi,
      idDi: (v) => v.id,
      statoDi: (v) => v.stato,
      inizioDi: (v) => v.inizio,
      sceltoOggi: scelto,
    );
    final idea = (id: 'idea', stato: StatoViaggio.idea, inizio: null);
    final finito = (
      id: 'finito',
      stato: StatoViaggio.chiuso,
      inizio: DateTime(2026, 5, 1),
    );
    final piuVecchio = (
      id: 'vecchio',
      stato: StatoViaggio.chiuso,
      inizio: DateTime(2025, 5, 1),
    );
    final dopo = (
      id: 'dopo',
      stato: StatoViaggio.definito,
      inizio: DateTime(2026, 12, 1),
    );
    final prima = (
      id: 'prima',
      stato: StatoViaggio.definito,
      inizio: DateTime(2026, 11, 1),
    );
    final porto = (
      id: 'porto',
      stato: StatoViaggio.inCorso,
      inizio: DateTime(2026, 10, 10),
    );
    final lione = (
      id: 'lione',
      stato: StatoViaggio.inCorso,
      inizio: DateTime(2026, 10, 9),
    );

    test('quello in corso prima di tutto', () {
      expect(apre([idea, dopo, porto, finito]), 'porto');
    });

    test('fra due in corso, quello scelto oggi', () {
      expect(apre([porto, lione], scelto: 'lione'), 'lione');
      // Senza una scelta, quello cominciato prima: non il primo a caso.
      expect(apre([porto, lione]), 'lione');
    });

    test('poi il prossimo in programma', () {
      expect(apre([idea, dopo, prima, finito]), 'prima');
    });

    test('poi l\'ultimo finito', () {
      expect(apre([idea, piuVecchio, finito]), 'finito');
    });

    test('la scelta in alto: in corso, poi in programma dal più vicino, poi '
        'conclusi dal più recente; le idee no', () {
      final v = viaggiDellaMappa(
        viaggi: [idea, piuVecchio, dopo, porto, finito, prima],
        statoDi: (v) => v.stato,
        inizioDi: (v) => v.inizio,
      );
      expect([for (final x in v.inCorso) x.id], ['porto']);
      expect([for (final x in v.inProgramma) x.id], ['prima', 'dopo']);
      expect([for (final x in v.conclusi) x.id], ['finito', 'vecchio']);
    });

    test('le idee no: non hanno tappe da mettere sulla mappa', () {
      expect(apre([idea]), isNull);
      expect(apre(const []), isNull);
    });
  });

  test('il riquadro di più punti, e nessuno senza punti', () {
    expect(riquadroDi([lello, torre, ribeira]), (
      sudOvest: (lat: ribeira.lat, lon: lello.lon),
      nordEst: (lat: lello.lat, lon: ribeira.lon),
    ));
    expect(riquadroDi(const []), isNull);
  });
}
