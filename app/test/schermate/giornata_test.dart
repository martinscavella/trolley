import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/aspetto/elementi.dart';
import 'package:trolley/dati/database.dart';
import 'package:trolley/dati/errori.dart';
import 'package:trolley/dominio/calendario.dart';
import 'package:trolley/schermate/giornata.dart';

import '../aiuti.dart';

/// La giornata e le sue tappe (fase 1.2): leggere, aggiungere anche senza
/// rete, la capienza che rifiuta, segnare con un tocco.
void main() {
  late Ambiente ambiente;

  setUp(() => ambiente = Ambiente());
  tearDown(() => ambiente.chiudi());

  final oggi = soloData(DateTime.now());
  String fra(int giorni) => scriviData(oggi.add(Duration(days: giorni)));

  /// Un viaggio di tre giorni che comincia fra [inizio] giorni: g1 dalle
  /// 10:00, g2 intero, g3 fino alle 18:00.
  Future<void> viaggio(
    WidgetTester tester, {
    int inizio = 30,
    List<Map<String, Object?>> tappe = const [],
  }) async {
    ambiente.server
      ..viaggi.add(
        rigaViaggio(
          'v',
          stato: 'definito',
          inizio: fra(inizio),
          fine: fra(inizio + 2),
        ),
      )
      ..partecipazioni.add(rigaPartecipazione('v'))
      ..giorni.addAll([
        rigaGiorno('v', fra(inizio), '10:00:00', '24:00:00', id: 'g1'),
        rigaGiorno('v', fra(inizio + 1), '00:00:00', '24:00:00', id: 'g2'),
        rigaGiorno('v', fra(inizio + 2), '00:00:00', '18:00:00', id: 'g3'),
      ])
      ..tappe.addAll(tappe);
    await tester.runAsync(ambiente.archivio.aggiornaCopia);
  }

  Finder pulsante(String etichetta) => find.descendant(
    of: find.byType(PulsanteGrande),
    matching: find.text(etichetta),
  );

  Future<void> apriNuovaTappa(WidgetTester tester) async {
    await tester.ensureVisible(pulsante('Aggiungi una tappa'));
    await tester.tap(pulsante('Aggiungi una tappa'));
    await tester.pumpAndSettle();
  }

  /// Lascia arrivare le scritture: il database vero non avanza nel tempo
  /// finto dei test.
  Future<void> aspetta(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<List<OperazioneInCoda>> inCoda(WidgetTester tester) async =>
      (await tester.runAsync(
        () => ambiente.db.select(ambiente.db.codaScrittura).get(),
      ))!;

  testWidgets('la giornata mostra le sue tappe in ordine, e quanto è piena', (
    tester,
  ) async {
    await viaggio(
      tester,
      tappe: [
        rigaDiTappa(
          'b',
          viaggio: 'v',
          giorno: 'g2',
          ordine: 2,
          titolo: 'Pranzo al Mercado do Bolhão',
          tipo: 'pasto',
        ),
        rigaDiTappa('a', viaggio: 'v', giorno: 'g2', titolo: 'Livraria Lello'),
      ],
    );
    await ambiente.monta(
      tester,
      const SchermataGiornata(viaggioId: 'v', giornoId: 'g2'),
    );

    expect(find.text('GIORNO 2 DI 3'), findsOneWidget);
    expect(find.text('3 h su 24 h'), findsOneWidget);
    expect(find.text('Restano 21 h liberi.'), findsOneWidget);
    final primo = tester.getTopLeft(find.text('Livraria Lello')).dy;
    final secondo = tester
        .getTopLeft(find.text('Pranzo al Mercado do Bolhão'))
        .dy;
    expect(primo, lessThan(secondo));
    expect(find.text('Pasto · 1 h 30'), findsOneWidget);
    // Prima della partenza non si segna niente, e lo si dice.
    expect(
      find.textContaining('si segnano dal primo giorno del viaggio'),
      findsOneWidget,
    );
  });

  testWidgets('senza rete una tappa si aggiunge lo stesso: compare subito, '
      'dice che partirà con la rete, e il gesto si misura', (tester) async {
    await viaggio(tester);
    ambiente.rete.disponibile = false;
    await ambiente.monta(
      tester,
      const SchermataGiornata(viaggioId: 'v', giornoId: 'g2'),
    );
    await apriNuovaTappa(tester);

    expect(find.text('Nuova tappa'), findsOneWidget);
    expect(
      find.text('Proposta per una visita: correggila se serve.'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField).first, 'Torre dei Clérigos');
    await tester.pump();
    await tester.tap(find.text('Museo'));
    await tester.pump();
    expect(find.text('2 h'), findsOneWidget);
    await tester.tap(pulsante('Aggiungi'));
    await aspetta(tester);

    expect(find.text('Nuova tappa'), findsNothing);
    expect(find.text('Torre dei Clérigos'), findsOneWidget);
    expect(find.textContaining('parte con la rete'), findsOneWidget);
    expect(ambiente.server.tappe, isEmpty);
    final op = (await inCoda(tester)).single;
    expect(op.gesto, GestoOffline.aggiungiTappa);
    final carico = jsonDecode(op.carico) as Map<String, dynamic>;
    expect(carico['titolo'], 'Torre dei Clérigos');
    expect(carico['tipo'], 'museo');
    expect(carico['durata_stimata_min'], 120);
    expect(carico['giorno_id'], 'g2');

    final eventi = await ambiente.eventi(tester);
    expect(eventi.map((e) => e.nome), [
      // Aprire la giornata senza rete si conta (H4).
      'apertura_senza_rete',
      'primo_elemento_aggiunto',
      'funzione_usata_nel_viaggio',
    ]);
    expect(jsonDecode(eventi.first.proprieta), {
      'schermata': 'giornata',
      'mancante': null,
    });
    // Azioni, mai contenuti: il titolo della tappa non c'è.
    for (final e in eventi) {
      expect(e.proprieta, isNot(contains('Torre')));
    }
    expect(jsonDecode(eventi[1].proprieta), containsPair('tipo', 'tappa'));
  });

  testWidgets('una tappa che non entra non si aggiunge: si dice quanto manca '
      'e si propone cosa fare', (tester) async {
    // L'ultimo giorno ha 18 ore, e ce ne sono già 17.
    await viaggio(
      tester,
      tappe: [
        rigaDiTappa(
          'lunga',
          viaggio: 'v',
          giorno: 'g3',
          titolo: 'Crociera sul Douro',
          tipo: 'escursione',
          durata: 17 * 60,
        ),
      ],
    );
    await ambiente.monta(
      tester,
      const SchermataGiornata(viaggioId: 'v', giornoId: 'g3'),
    );
    await apriNuovaTappa(tester);
    await tester.enterText(find.byType(TextField).first, 'Cena a Ribeira');
    await tester.pump();

    expect(find.textContaining('Non entra in'), findsOneWidget);
    expect(find.textContaining('ne mancano 30 min'), findsOneWidget);
    expect(find.text('Non entra nella giornata'), findsOneWidget);
    expect(find.text('Accorciala a 1 h'), findsOneWidget);
    expect(find.textContaining('Mettila '), findsOneWidget);

    await tester.ensureVisible(find.text('Accorciala a 1 h'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accorciala a 1 h'));
    await tester.pump();
    expect(find.text('Non entra nella giornata'), findsNothing);
    await tester.tap(pulsante('Aggiungi'));
    await aspetta(tester);

    expect(find.text('Cena a Ribeira'), findsOneWidget);
    expect(find.text('La giornata è piena.'), findsOneWidget);
  });

  testWidgets('durante il viaggio una tappa si segna con un tocco sul suo '
      'punto, e conta per la verifica', (tester) async {
    ambiente.server
      ..viaggi.add(
        rigaViaggio('v', stato: 'definito', inizio: fra(-1), fine: fra(1)),
      )
      ..partecipazioni.add(rigaPartecipazione('v'))
      ..giorni.addAll([
        rigaGiorno('v', fra(-1), '10:00:00', '24:00:00', id: 'g1'),
        rigaGiorno('v', fra(0), '00:00:00', '24:00:00', id: 'oggi'),
        rigaGiorno('v', fra(1), '00:00:00', '18:00:00', id: 'g3'),
      ])
      ..tappe.addAll([
        rigaDiTappa(
          'a',
          viaggio: 'v',
          giorno: 'oggi',
          titolo: 'Livraria Lello',
        ),
        rigaDiTappa(
          'b',
          viaggio: 'v',
          giorno: 'oggi',
          ordine: 2,
          titolo: 'Ponte Dom Luís I',
          tipo: 'passeggiata',
        ),
      ]);
    await tester.runAsync(ambiente.archivio.aggiornaCopia);
    await ambiente.monta(
      tester,
      const SchermataGiornata(viaggioId: 'v', giornoId: 'oggi'),
    );

    expect(find.text('OGGI · GIORNO 2 DI 3'), findsOneWidget);
    expect(find.text('Prossima'), findsOneWidget);

    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();

    expect(ambiente.server.tappe.first['stato'], 'completata');
    expect(ambiente.server.tappe.first['marcata_durante_il_viaggio'], isTrue);
    expect(find.text('Visita · 1 h 30 · fatta'), findsOneWidget);
    // La prossima adesso è la seconda.
    expect(find.text('Prossima'), findsOneWidget);
    final eventi = await ambiente.eventi(tester);
    expect(eventi.single.nome, 'tappa_marcata');
    expect(
      jsonDecode(eventi.single.proprieta),
      containsPair('durante_il_viaggio', true),
    );
  });

  testWidgets('prima della partenza toccare un punto apre la tappa', (
    tester,
  ) async {
    await viaggio(
      tester,
      tappe: [
        rigaDiTappa('a', viaggio: 'v', giorno: 'g2', titolo: 'Livraria Lello'),
      ],
    );
    await ambiente.monta(
      tester,
      const SchermataGiornata(viaggioId: 'v', giornoId: 'g2'),
    );

    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();

    expect(find.text('La tappa'), findsOneWidget);
    expect(find.text('Com\'è andata?'), findsNothing);
    expect(await inCoda(tester), isEmpty);
  });

  testWidgets('senza rete una tappa non si cambia né si toglie, e lo si dice '
      'prima', (tester) async {
    await viaggio(
      tester,
      tappe: [
        rigaDiTappa('a', viaggio: 'v', giorno: 'g2', titolo: 'Livraria Lello'),
      ],
    );
    ambiente.rete.disponibile = false;
    await ambiente.monta(
      tester,
      const SchermataGiornata(viaggioId: 'v', giornoId: 'g2'),
    );
    await tester.tap(find.text('Livraria Lello'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      'Livraria Lello, presto',
    );
    await tester.pump();

    // Sotto "Salva", e più in basso sotto "Togli la tappa".
    expect(find.text(motivoSenzaRete), findsOneWidget);
    await tester.tap(pulsante('Salva'));
    await tester.pumpAndSettle();
    expect(find.text('La tappa'), findsOneWidget);
    expect(ambiente.server.tappe.single['titolo'], 'Livraria Lello');
    await tester.scrollUntilVisible(
      pulsante('Togli la tappa'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text(motivoSenzaRete), findsNWidgets(2));
  });

  testWidgets('con la rete una tappa si cambia', (tester) async {
    await viaggio(
      tester,
      tappe: [
        rigaDiTappa('a', viaggio: 'v', giorno: 'g2', titolo: 'Livraria Lello'),
      ],
    );
    await ambiente.monta(
      tester,
      const SchermataGiornata(viaggioId: 'v', giornoId: 'g2'),
    );
    await tester.tap(find.text('Livraria Lello'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      'Livraria Lello, presto',
    );
    await tester.tap(find.bySemanticsLabel('Più lunga'));
    await tester.pump();
    await tester.tap(pulsante('Salva'));
    await tester.pumpAndSettle();

    expect(find.text('La tappa'), findsNothing);
    expect(ambiente.server.tappe.single['titolo'], 'Livraria Lello, presto');
    expect(ambiente.server.tappe.single['durata_stimata_min'], 105);
    expect(find.text('Livraria Lello, presto'), findsOneWidget);
  });

  testWidgets('in elenco le tappe hanno il loro segno, e senza rete non si '
      'riordinano', (tester) async {
    await viaggio(
      tester,
      tappe: [
        rigaDiTappa('a', viaggio: 'v', giorno: 'g2', titolo: 'Livraria Lello'),
        rigaDiTappa(
          'b',
          viaggio: 'v',
          giorno: 'g2',
          ordine: 2,
          titolo: 'Ponte Dom Luís I',
        ),
      ],
    );
    ambiente.rete.disponibile = false;
    await ambiente.monta(
      tester,
      const SchermataGiornata(viaggioId: 'v', giornoId: 'g2'),
    );

    await tester.tap(find.text('Elenco'));
    await tester.pumpAndSettle();

    expect(find.text('Livraria Lello'), findsOneWidget);
    expect(find.text('Ponte Dom Luís I'), findsOneWidget);
    expect(
      find.text('Per cambiare l\'ordine serve la connessione.'),
      findsOneWidget,
    );
  });
}
