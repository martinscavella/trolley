import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/aspetto/elementi.dart';
import 'package:trolley/aspetto/pagina.dart';
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

  /// Il cerchio che segna una tappa, a sinistra del suo titolo.
  Offset cerchioDi(WidgetTester tester, String titolo) =>
      tester.getTopLeft(find.text(titolo)) + const Offset(-22, 8);

  testWidgets('la giornata mette le tappe ai loro orari, in ordine d\'ora, e '
      'dice quanto è piena', (tester) async {
    await viaggio(
      tester,
      tappe: [
        // Prima nell'ordine, ma alle 15: viene dopo.
        rigaDiTappa(
          'b',
          viaggio: 'v',
          giorno: 'g2',
          titolo: 'Pranzo al Mercado do Bolhão',
          tipo: 'pasto',
          ora: '15:00:00',
        ),
        rigaDiTappa(
          'c',
          viaggio: 'v',
          giorno: 'g2',
          ordine: 2,
          titolo: 'Ponte Dom Luís I',
          tipo: 'passeggiata',
          durata: 60,
          ora: '09:00:00',
        ),
        // Senza orario: si mette nel primo spazio dopo quella che la
        // precede, il Ponte.
        rigaDiTappa(
          'a',
          viaggio: 'v',
          giorno: 'g2',
          ordine: 3,
          titolo: 'Livraria Lello',
        ),
      ],
    );
    await ambiente.monta(
      tester,
      const SchermataGiornata(viaggioId: 'v', giornoId: 'g2'),
    );

    expect(find.text('GIORNO 2 DI 3'), findsOneWidget);
    expect(find.text('4 h su 24 h'), findsOneWidget);
    expect(find.text('Restano 20 h liberi.'), findsOneWidget);
    final ponte = tester.getTopLeft(find.text('Ponte Dom Luís I')).dy;
    final lello = tester.getTopLeft(find.text('Livraria Lello')).dy;
    final pranzo = tester
        .getTopLeft(find.text('Pranzo al Mercado do Bolhão'))
        .dy;
    // Un'ora è alta 64 punti: Lello un'ora dopo il Ponte, il pranzo sei.
    expect(lello - ponte, closeTo(64, 3));
    expect(pranzo - ponte, closeTo(6 * 64, 3));
    expect(find.text('Visita · 10:00–11:30 · orario proposto'), findsOneWidget);
    expect(find.text('Pasto · 15:00–16:30'), findsOneWidget);
    // Prima della partenza non si segna niente, e lo si dice.
    expect(
      find.textContaining('si segnano dal primo giorno del viaggio'),
      findsOneWidget,
    );
  });

  testWidgets('il primo giorno, prima dell\'arrivo, la giornata è chiusa', (
    tester,
  ) async {
    await viaggio(tester);
    await ambiente.monta(
      tester,
      const SchermataGiornata(viaggioId: 'v', giornoId: 'g1'),
    );
    expect(find.text('Arrivi alle 10:00'), findsOneWidget);
  });

  testWidgets('senza rete una tappa si aggiunge lo stesso, all\'ora '
      'proposta: compare subito, dice che partirà con la rete, e il gesto si '
      'misura', (tester) async {
    await viaggio(
      tester,
      tappe: [
        rigaDiTappa(
          'a',
          viaggio: 'v',
          giorno: 'g2',
          titolo: 'Livraria Lello',
          ora: '09:00:00',
        ),
      ],
    );
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
    // Subito dopo l'ultima.
    expect(find.text('10:30'), findsOneWidget);
    expect(
      find.textContaining('Subito dopo «Livraria Lello»: finisce alle 12:00'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField).first, 'Torre dei Clérigos');
    await tester.pump();
    await tester.tap(find.text('Museo'));
    await tester.pump();
    expect(find.text('2 h'), findsOneWidget);
    expect(find.textContaining('finisce alle 12:30'), findsOneWidget);
    await tester.tap(pulsante('Aggiungi'));
    await aspetta(tester);

    expect(find.text('Nuova tappa'), findsNothing);
    expect(find.text('Torre dei Clérigos'), findsOneWidget);
    expect(find.textContaining('parte con la rete'), findsOneWidget);
    expect(ambiente.server.tappe, hasLength(1));
    final op = (await inCoda(tester)).single;
    expect(op.gesto, GestoOffline.aggiungiTappa);
    final carico = jsonDecode(op.carico) as Map<String, dynamic>;
    expect(carico['titolo'], 'Torre dei Clérigos');
    expect(carico['tipo'], 'museo');
    expect(carico['durata_stimata_min'], 120);
    expect(carico['ora_inizio'], '10:30:00');
    expect(carico['giorno_id'], 'g2');

    final eventi = await ambiente.eventi(tester);
    expect(eventi.map((e) => e.nome), [
      // Aprire la giornata senza rete si conta (H4).
      'apertura_senza_rete',
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
  });

  testWidgets('una tappa che si sovrappone non si aggiunge: si dice con chi, '
      'e si propone cosa fare', (tester) async {
    // L'ultimo giorno ha 18 ore, e la crociera ne prende 17 dalla
    // mezzanotte: non resta un buco per un'ora e mezza.
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
          ora: '00:00:00',
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

    expect(
      find.textContaining('Alle 00:00 c\'è già «Crociera sul Douro»'),
      findsOneWidget,
    );
    expect(find.textContaining('ne mancano 30 min'), findsOneWidget);
    expect(find.text('Si sovrappone a «Crociera sul Douro»'), findsOneWidget);
    // Il giorno prima è libero, alla stessa ora.
    final altroGiorno = find.textContaining('alle 00:00').last;
    await tester.ensureVisible(altroGiorno);
    await tester.pumpAndSettle();
    await tester.tap(altroGiorno);
    await tester.pump();
    expect(find.text('Si sovrappone a «Crociera sul Douro»'), findsNothing);
    await tester.tap(pulsante('Aggiungi'));
    await aspetta(tester);

    final aggiunta = ambiente.server.tappe.firstWhere(
      (t) => t['titolo'] == 'Cena a Ribeira',
    );
    expect(aggiunta['giorno_id'], 'g2');
    final evento = (await ambiente.eventi(tester))
        .where((e) => e.nome == 'tappa_non_entrata')
        .single;
    expect(jsonDecode(evento.proprieta), {
      'motivo': 'piena',
      'scelta': 'altro_giorno',
    });
  });

  testWidgets('durante il viaggio una tappa si segna con un tocco sul suo '
      'cerchio, e conta per la verifica', (tester) async {
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
          ora: '00:30:00',
        ),
        rigaDiTappa(
          'b',
          viaggio: 'v',
          giorno: 'oggi',
          ordine: 2,
          titolo: 'Ponte Dom Luís I',
          tipo: 'passeggiata',
          ora: '23:00:00',
        ),
      ]);
    await tester.runAsync(ambiente.archivio.aggiornaCopia);
    await ambiente.monta(
      tester,
      const SchermataGiornata(viaggioId: 'v', giornoId: 'oggi'),
    );

    expect(find.text('OGGI · GIORNO 2 DI 3'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Livraria Lello'),
      find.byType(Scrollable).first,
      const Offset(0, 300),
    );
    expect(find.textContaining('la prossima'), findsOneWidget);

    await tester.tapAt(cerchioDi(tester, 'Livraria Lello'));
    await tester.pumpAndSettle();

    expect(ambiente.server.tappe.first['stato'], 'completata');
    expect(ambiente.server.tappe.first['marcata_durante_il_viaggio'], isTrue);
    final eventi = await ambiente.eventi(tester);
    expect(eventi.single.nome, 'tappa_marcata');
    expect(
      jsonDecode(eventi.single.proprieta),
      containsPair('durante_il_viaggio', true),
    );
  });

  testWidgets('una tappa saltata si rimanda dal suo foglio: domani, '
      'all\'orario proposto, e torna da fare (04, regola 33)', (tester) async {
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
      ..tappe.add(
        rigaDiTappa(
          'a',
          viaggio: 'v',
          giorno: 'g1',
          titolo: 'Livraria Lello',
          ora: '11:00:00',
          stato: 'saltata',
        ),
      );
    await tester.runAsync(ambiente.archivio.aggiornaCopia);
    await ambiente.monta(
      tester,
      const SchermataGiornata(viaggioId: 'v', giornoId: 'g1'),
    );
    await tester.tap(find.text('Livraria Lello'));
    await tester.pumpAndSettle();

    expect(find.text('La tappa'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Rimandala'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.textContaining('Ci vuoi ancora andare?'), findsOneWidget);
    // Sopra i pulsanti in fondo al foglio, non sotto.
    await tester.drag(
      find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(Scrollable),
          )
          .first,
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rimandala'));
    await aspetta(tester);

    expect(find.text('Rimanda «Livraria Lello»'), findsOneWidget);
    // Da una tappa già saltata non c'è «Saltala e basta».
    expect(find.text('Saltala e basta'), findsNothing);
    await tester.tap(
      find.descendant(
        of: find.byType(Foglio).last,
        matching: find.text('Domani'),
      ),
    );
    await aspetta(tester);

    final lello = ambiente.server.tappe.single;
    expect(lello['giorno_id'], 'g3');
    expect(lello['ora_inizio'], '09:00:00');
    expect(lello['stato'], 'da_fare');
    expect(find.text('La tappa'), findsNothing);
    final rimandata = (await ambiente.eventi(tester))
        .singleWhere((e) => e.nome == 'tappa_rimandata');
    expect(jsonDecode(rimandata.proprieta), {
      'viaggio_id': 'v',
      'quando': 'domani',
      'da': 'tappa',
      'durante_il_viaggio': true,
    });
  });

  testWidgets('prima della partenza il cerchio non segna: la tappa si apre', (
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

    await tester.tapAt(cerchioDi(tester, 'Livraria Lello'));
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

    // Sotto "Salva", e più in basso sotto "Togli la tappa" (dietro il
    // foglio lo dice anche «Svuota la giornata»).
    expect(
      find.descendant(
        of: find.byType(Foglio),
        matching: find.text(motivoSenzaRete),
      ),
      findsOneWidget,
    );
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
    expect(
      find.descendant(
        of: find.byType(Foglio),
        matching: find.text(motivoSenzaRete),
      ),
      findsNWidgets(2),
    );
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

  /// Tiene premuto il titolo di una tappa e lo trascina di [ore].
  Future<void> trascina(WidgetTester tester, String titolo, double ore) async {
    final dito = await tester.startGesture(tester.getCenter(find.text(titolo)));
    await tester.pump(const Duration(milliseconds: 700));
    for (var i = 0; i < 8; i++) {
      await dito.moveBy(Offset(0, ore * 64 / 8));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await dito.up();
    await tester.pumpAndSettle();
  }

  testWidgets('una tappa si sposta trascinandola sulla linea del tempo', (
    tester,
  ) async {
    await viaggio(
      tester,
      tappe: [
        rigaDiTappa(
          'a',
          viaggio: 'v',
          giorno: 'g2',
          titolo: 'Livraria Lello',
          ora: '09:00:00',
        ),
      ],
    );
    await ambiente.monta(
      tester,
      const SchermataGiornata(viaggioId: 'v', giornoId: 'g2'),
    );

    await trascina(tester, 'Livraria Lello', 2);
    await aspetta(tester);

    expect(ambiente.server.tappe.single['ora_inizio'], '11:00:00');
    expect(find.text('Visita · 11:00–12:30'), findsOneWidget);
  });

  testWidgets('trascinata sopra un\'altra, torna al suo posto', (tester) async {
    await viaggio(
      tester,
      tappe: [
        rigaDiTappa(
          'a',
          viaggio: 'v',
          giorno: 'g2',
          titolo: 'Livraria Lello',
          ora: '09:00:00',
        ),
        rigaDiTappa(
          'b',
          viaggio: 'v',
          giorno: 'g2',
          ordine: 2,
          titolo: 'Pranzo',
          tipo: 'pasto',
          ora: '11:00:00',
        ),
      ],
    );
    await ambiente.monta(
      tester,
      const SchermataGiornata(viaggioId: 'v', giornoId: 'g2'),
    );

    await trascina(tester, 'Livraria Lello', 2);
    await aspetta(tester);

    expect(ambiente.server.tappe.first['ora_inizio'], '09:00:00');
    expect(find.text('Visita · 09:00–10:30'), findsOneWidget);
  });

  testWidgets('senza rete una tappa non si sposta, e lo si dice', (
    tester,
  ) async {
    await viaggio(
      tester,
      tappe: [
        rigaDiTappa(
          'a',
          viaggio: 'v',
          giorno: 'g2',
          titolo: 'Livraria Lello',
          ora: '09:00:00',
        ),
      ],
    );
    ambiente.rete.disponibile = false;
    await ambiente.monta(
      tester,
      const SchermataGiornata(viaggioId: 'v', giornoId: 'g2'),
    );

    await trascina(tester, 'Livraria Lello', 2);

    expect(
      find.text('Per spostare una tappa serve la connessione.'),
      findsOneWidget,
    );
    expect(ambiente.server.tappe.single['ora_inizio'], '09:00:00');
  });
}
