import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dominio/notifiche.dart';
import 'package:trolley/dominio/stato_viaggio.dart';

void main() {
  // Venerdì 16 ottobre 2026, a mezzogiorno.
  final adesso = DateTime(2026, 10, 16, 12);

  ViaggioPerLeNotifiche porto({
    StatoViaggio stato = StatoViaggio.definito,
    int mancano = 3,
    int diNessuno = 0,
    int documenti = 1,
    String? citta = 'Porto',
    List<({String id, DateTime data, int daSegnare})> giorni = const [],
  }) => ViaggioPerLeNotifiche(
    id: 'porto',
    stato: stato,
    citta: citta,
    // Giovedì 22.
    inizio: DateTime.utc(2026, 10, 22),
    fine: DateTime.utc(2026, 10, 25),
    mancano: mancano,
    diNessuno: diNessuno,
    documenti: documenti,
    giorni: giorni,
  );

  group('prima di partire', () {
    test('due giorni prima alle 18, se manca qualcosa; porta a Prima di '
        'partire', () {
      final [n] = notificheDa([porto()], adesso: adesso);
      expect(n.tipo, TipoNotifica.primaDiPartire);
      expect(n.quando, DateTime(2026, 10, 20, 18));
      expect(n.titolo, 'Si parte giovedì per Porto');
      expect(n.testo, 'Mancano 3 cose da mettere in valigia.');
      expect(n.dovePorta, (
        tipo: TipoNotifica.primaDiPartire,
        viaggioId: 'porto',
        giornoId: null,
      ));
    });

    test('se non manca niente, non c\'è niente da dire (14, regola 4)', () {
      expect(
        notificheDa([porto(mancano: 0, documenti: 2)], adesso: adesso),
        isEmpty,
      );
    });

    test('passate le 18 di due giorni prima, il giorno prima; poi più', () {
      final [n] = notificheDa([porto()], adesso: DateTime(2026, 10, 20, 19));
      expect(n.quando, DateTime(2026, 10, 21, 18));
      expect(n.titolo, 'Si parte domani per Porto');
      expect(
        notificheDa([porto()], adesso: DateTime(2026, 10, 21, 19)),
        isEmpty,
      );
    });

    test('le cose che mancano, in una frase sola; senza città il posto non '
        'si nomina', () {
      final [n] = notificheDa([
        porto(mancano: 1, diNessuno: 2, documenti: 0, citta: null),
      ], adesso: adesso);
      expect(n.titolo, 'Si parte giovedì');
      expect(
        n.testo,
        'Manca una cosa da mettere in valigia, 2 cose del viaggio non le '
        'porta nessuno e sul telefono non c\'è ancora nessun documento.',
      );
    });

    test('un viaggio già in corso non chiede più di partire', () {
      expect(
        notificheDa([porto(stato: StatoViaggio.inCorso)], adesso: adesso),
        isEmpty,
      );
    });
  });

  group('le tappe da segnare', () {
    final giorni = [
      (id: 'g1', data: DateTime.utc(2026, 10, 16), daSegnare: 2),
      (id: 'g2', data: DateTime.utc(2026, 10, 17), daSegnare: 0),
      (id: 'g3', data: DateTime.utc(2026, 10, 18), daSegnare: 1),
    ];

    test('alle 21 dei giorni in cui ne resta qualcuna, una volta per giorno; '
        'portano alla giornata', () {
      final notifiche = notificheDa([
        porto(stato: StatoViaggio.inCorso, giorni: giorni),
      ], adesso: adesso);
      expect(
        [for (final n in notifiche) n.quando],
        [DateTime(2026, 10, 16, 21), DateTime(2026, 10, 18, 21)],
      );
      expect(notifiche.first.titolo, "Com'è andata oggi a Porto?");
      expect(
        notifiche.first.testo,
        'Restano 2 tappe da segnare: fatta o saltata, un tocco ciascuna.',
      );
      expect(
        notifiche.last.testo,
        'Resta una tappa da segnare: fatta o saltata, basta un tocco.',
      );
      expect(notifiche.first.dovePorta.giornoId, 'g1');
      expect(notifiche.first.dovePorta.tipo, TipoNotifica.tappeDaSegnare);
    });

    test('passate le 21, quella di oggi non c\'è più', () {
      final notifiche = notificheDa([
        porto(stato: StatoViaggio.inCorso, giorni: giorni),
      ], adesso: DateTime(2026, 10, 16, 21, 30));
      expect([for (final n in notifiche) n.dovePorta.giornoId], ['g3']);
    });
  });

  group('le idee che scadono', () {
    ViaggioPerLeNotifiche idea(String id, DateTime scadenza, {String? citta}) =>
        ViaggioPerLeNotifiche(
          id: id,
          stato: StatoViaggio.idea,
          citta: citta,
          scadenza: scadenza,
        );

    test(
      'alle 10 del giorno in cui compare il sollecito; portano all\'idea',
      () {
        final [n] = notificheDa([
          idea('valencia', DateTime.utc(2026, 10, 31), citta: 'Valencia'),
        ], adesso: adesso);
        expect(n.quando, DateTime(2026, 10, 17, 10));
        expect(n.titolo, "Valencia è ancora un'idea?");
        expect(n.testo, 'Completa le date per sbloccare il resto.');
        expect(n.dovePorta, (
          tipo: TipoNotifica.ideaCheScade,
          viaggioId: 'valencia',
          giornoId: null,
        ));
      },
    );

    test('al massimo una al giorno in tutto, la prima a scadere per prima', () {
      final notifiche = notificheDa([
        idea('b', DateTime.utc(2026, 10, 31)),
        idea('a', DateTime.utc(2026, 10, 31)),
        idea('c', DateTime.utc(2026, 10, 30)),
      ], adesso: adesso);
      expect(
        [for (final n in notifiche) (n.dovePorta.viaggioId, n.quando.day)],
        [('c', 17), ('a', 18), ('b', 19)],
      );
      expect(notifiche.first.titolo, "Questo viaggio è ancora un'idea?");
    });

    test('chi la apre dopo che il sollecito è comparso la riceve lo stesso, '
        'finché l\'idea è viva', () {
      final [n] = notificheDa([
        idea('a', DateTime.utc(2026, 10, 20)),
      ], adesso: adesso);
      expect(n.quando, DateTime(2026, 10, 17, 10));
      expect(
        notificheDa([idea('a', DateTime.utc(2026, 10, 15))], adesso: adesso),
        isEmpty,
      );
    });

    test('mentre si è in viaggio aspetta la fine (14, casi limite)', () {
      final notifiche = notificheDa([
        porto(
          stato: StatoViaggio.inCorso,
          mancano: 0,
        ).copiaConDate(DateTime.utc(2026, 10, 16), DateTime.utc(2026, 10, 20)),
        idea('a', DateTime.utc(2026, 10, 20)),
      ], adesso: adesso);
      expect(
        [
          for (final n in notifiche)
            if (n.tipo == TipoNotifica.ideaCheScade) n.quando,
        ],
        [DateTime(2026, 10, 21, 10)],
      );
    });

    test('un periodo cambiato è un\'idea nuova: la chiave cambia', () {
      final [prima] = notificheDa([
        idea('a', DateTime.utc(2026, 10, 31)),
      ], adesso: adesso);
      final [dopo] = notificheDa([
        idea('a', DateTime.utc(2026, 11, 30)),
      ], adesso: adesso);
      expect(prima.chiave, isNot(dopo.chiave));
    });
  });

  group('un anno fa', () {
    ViaggioPerLeNotifiche lisbona({bool importato = false}) =>
        ViaggioPerLeNotifiche(
          id: 'lisbona',
          stato: StatoViaggio.chiuso,
          citta: 'Lisbona',
          inizio: DateTime.utc(2025, 10, 6),
          fine: DateTime.utc(2025, 10, 17),
          importato: importato,
          traguardi: 3,
        );

    test('alle 10, un anno dopo l\'ultimo giorno; porta al riepilogo', () {
      final [n] = notificheDa([lisbona()], adesso: adesso);
      expect(n.quando, DateTime(2026, 10, 17, 10));
      expect(n.titolo, 'Un anno fa eri a Lisbona');
      expect(n.testo, '12 giorni, 3 traguardi.');
      expect(n.dovePorta.tipo, TipoNotifica.unAnnoFa);
    });

    test('arriva ancora per una settimana, se il telefono non ha potuto '
        'programmarla prima; poi più', () {
      final [n] = notificheDa([lisbona()], adesso: DateTime(2026, 10, 20, 12));
      expect(n.quando, DateTime(2026, 10, 21, 10));
      expect(
        notificheDa([lisbona()], adesso: DateTime(2026, 10, 25, 12)),
        isEmpty,
      );
    });

    test('non per un viaggio aggiunto a mano', () {
      expect(notificheDa([lisbona(importato: true)], adesso: adesso), isEmpty);
    });
  });

  group('per tutte', () {
    test('quelle spente non partono (14, regola 2)', () {
      final notifiche = notificheDa(
        [
          porto(
            giorni: [
              (id: 'g1', data: DateTime.utc(2026, 10, 22), daSegnare: 1),
            ],
          ),
        ],
        adesso: adesso,
        spente: {TipoNotifica.primaDiPartire},
      );
      expect(
        [for (final n in notifiche) n.tipo],
        [TipoNotifica.tappeDaSegnare],
      );
    });

    test('quelle già arrivate non ripartono: una volta sola', () {
      final [n] = notificheDa([porto()], adesso: adesso);
      expect(
        notificheDa([porto()], adesso: adesso, arrivate: {n.chiave}),
        isEmpty,
      );
    });

    test('mai di notte: fra le 10 e le 21', () {
      for (final t in TipoNotifica.values) {
        expect(t.ora.inHours, inInclusiveRange(10, 21));
      }
    });

    test('al massimo $massimoNotifiche, le più vicine, in ordine', () {
      final giorni = [
        for (var i = 0; i < 100; i++)
          (
            id: 'g$i',
            data: DateTime.utc(2026, 10, 17).add(Duration(days: i)),
            daSegnare: 1,
          ),
      ];
      final notifiche = notificheDa([
        porto(stato: StatoViaggio.inCorso, giorni: giorni),
      ], adesso: adesso);
      expect(notifiche, hasLength(massimoNotifiche));
      expect(notifiche.first.dovePorta.giornoId, 'g0');
      expect(notifiche.last.dovePorta.giornoId, 'g59');
    });
  });

  group('dove porta, dentro la notifica', () {
    test('va e torna', () {
      for (final d in <DovePorta>[
        (tipo: TipoNotifica.tappeDaSegnare, viaggioId: 'v', giornoId: 'g'),
        (tipo: TipoNotifica.unAnnoFa, viaggioId: 'v', giornoId: null),
      ]) {
        expect(leggiDovePorta(scriviDovePorta(d)), d);
      }
    });

    test('quello che non si riconosce non porta da nessuna parte', () {
      for (final testo in [null, '', 'altro|v', 'un_anno_fa', 'un_anno_fa|']) {
        expect(leggiDovePorta(testo), isNull, reason: testo);
      }
    });
  });
}

extension on ViaggioPerLeNotifiche {
  ViaggioPerLeNotifiche copiaConDate(DateTime inizio, DateTime fine) =>
      ViaggioPerLeNotifiche(
        id: id,
        stato: stato,
        citta: citta,
        inizio: inizio,
        fine: fine,
        mancano: mancano,
        documenti: documenti,
      );
}
