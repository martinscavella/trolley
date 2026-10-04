import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/aspetto/elementi.dart';
import 'package:trolley/dati/database.dart';
import 'package:trolley/dati/errori.dart';
import 'package:trolley/dominio/calendario.dart';
import 'package:trolley/schermate/spese.dart';
import 'package:trolley/schermate/viaggio.dart';

import '../aiuti.dart';

/// Le spese (fase 1.4): si registrano con l'importo e un tocco, anche senza
/// rete; si vedono convertite nella propria valuta, dicendo di quando sono i
/// tassi; cambiarle richiede la rete.
void main() {
  late Ambiente ambiente;

  setUp(() => ambiente = Ambiente());
  tearDown(() => ambiente.chiudi());

  final oggi = soloData(DateTime.now());
  String fra(int giorni) => scriviData(oggi.add(Duration(days: giorni)));

  /// Un viaggio a Marrakech in corso: ieri, oggi, domani.
  Future<void> viaggio(WidgetTester tester, {String stato = 'definito'}) async {
    ambiente.server
      ..viaggi.add(
        rigaViaggio(
          'v',
          stato: stato,
          citta: 'Marrakech',
          paese: 'MA',
          inizio: stato == 'idea' ? null : fra(-1),
          fine: stato == 'idea' ? null : fra(1),
        ),
      )
      ..partecipazioni.add(rigaPartecipazione('v'))
      ..tassi.addAll([
        rigaTasso('EUR', 1, fra(0)),
        rigaTasso('MAD', 11.18, fra(0)),
      ]);
    if (stato != 'idea') {
      ambiente.server.giorni.addAll([
        rigaGiorno('v', fra(-1), '10:00:00', '24:00:00', id: 'g1'),
        rigaGiorno('v', fra(0), '00:00:00', '24:00:00', id: 'g2'),
        rigaGiorno('v', fra(1), '00:00:00', '18:00:00', id: 'g3'),
      ]);
    }
    await ambiente.accedi(tester: tester);
    await tester.runAsync(ambiente.archivio.aggiornaCopia);
  }

  Finder pulsante(String etichetta) => find.descendant(
    of: find.byType(PulsanteGrande),
    matching: find.text(etichetta),
  );

  Future<List<Spesa>> copia(WidgetTester tester) async => (await tester
      .runAsync(() => ambiente.db.select(ambiente.db.spese).get()))!;

  /// Gli eventi, nome e proprietà: quelli ancora in attesa e quelli già
  /// partiti, perché con l'accesso fatto partono subito.
  Future<List<(String, Map<String, dynamic>)>> eventi(
    WidgetTester tester,
  ) async => [
    for (final e in await ambiente.eventi(tester))
      (e.nome, jsonDecode(e.proprieta) as Map<String, dynamic>),
    for (final r in ambiente.server.chiamate('POST', '/rest/v1/evento'))
      for (final e in (jsonDecode(r.body) as List).cast<Map<String, dynamic>>())
        (e['nome'] as String, e['proprieta'] as Map<String, dynamic>),
  ];

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

  testWidgets('dal viaggio si registra una spesa con l\'importo e un tocco: '
      'la propria valuta, oggi', (tester) async {
    await viaggio(tester);
    await ambiente.monta(tester, const SchermataViaggio(viaggioId: 'v'));

    await tester.scrollUntilVisible(find.text('Registra una spesa'), 200);
    // Che non resti sotto la barra in basso.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registra una spesa'));
    await tester.pumpAndSettle();
    expect(find.text('Nuova spesa'), findsOneWidget);
    expect(find.text('Scrivi quanto hai speso'), findsOneWidget);
    // La propria valuta, e quella del posto a un tocco.
    expect(find.text('€ Euro · tua'), findsOneWidget);
    expect(find.text('MAD Dirham · del posto'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '12,40');
    await tester.pump();
    await tester.ensureVisible(pulsante('Salva'));
    await tester.tap(pulsante('Salva'));
    await aspetta(tester);

    expect(find.text('Nuova spesa'), findsNothing);
    final spesa = ambiente.server.spese.single;
    expect(spesa['importo'], 12.4);
    expect(spesa['valuta'], 'EUR');
    expect(spesa['data'], fra(0));
    expect(spesa['pagante_id'], idDiProva);
    expect(spesa['descrizione'], isNull);
    expect(spesa['tasso_usato'], '1');

    // La scheda del viaggio ha il totale, e il passaggio all'elenco.
    await tester.scrollUntilVisible(find.text('Tutte · 1'), -200);
    expect(find.text('12,40 €'), findsOneWidget);

    final registrati = await eventi(tester);
    final primo = registrati.singleWhere(
      (e) => e.$1 == 'primo_elemento_aggiunto',
    );
    expect(primo.$2, containsPair('tipo', 'spesa'));
    final funzione = registrati.singleWhere(
      (e) => e.$1 == 'funzione_usata_nel_viaggio',
    );
    expect(funzione.$2, {'viaggio_id': 'v', 'funzione': 'spese'});
    // Chi ha creato il viaggio non è un invitato.
    expect(
      registrati.where((e) => e.$1 == 'primo_contributo_invitato'),
      isEmpty,
    );
  });

  testWidgets('in dirham si vede la conversione, con il tasso e di quando è', (
    tester,
  ) async {
    await viaggio(tester);
    await ambiente.monta(tester, const SchermataSpese(viaggioId: 'v'));

    await tester.tap(pulsante('Registra una spesa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MAD Dirham · del posto'));
    await tester.enterText(find.byType(TextField).first, '170');
    await tester.pumpAndSettle();
    expect(find.text('≈ 15,21 €'), findsOneWidget);
    expect(find.text('1 € = 11,18 MAD · di oggi'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), 'Jardin Majorelle');
    await tester.pump();
    await tester.ensureVisible(pulsante('Salva'));
    await tester.tap(pulsante('Salva'));
    await aspetta(tester);

    expect(find.text('Jardin Majorelle'), findsOneWidget);
    expect(find.text('≈ 15,21 €'), findsOneWidget);
    expect(find.text('170,00 MAD'), findsOneWidget);
    expect(find.text('15,21 €'), findsOneWidget);
    expect(find.textContaining('Con i tassi di oggi.'), findsOneWidget);
    expect(find.textContaining('in dirham'), findsOneWidget);
    expect(ambiente.server.spese.single['tasso_usato'], '11.18');
    // Azioni, mai contenuti.
    for (final (_, proprieta) in await eventi(tester)) {
      expect(jsonEncode(proprieta), isNot(contains('Majorelle')));
    }
  });

  testWidgets('senza rete si registra lo stesso: la spesa c\'è e dice che '
      'parte con la rete', (tester) async {
    await viaggio(tester);
    ambiente.rete.disponibile = false;
    await ambiente.monta(tester, const SchermataSpese(viaggioId: 'v'));
    expect(find.text('Sei offline'), findsOneWidget);

    await tester.tap(pulsante('Registra una spesa'));
    await tester.pumpAndSettle();
    expect(find.textContaining('parte quando torna la rete'), findsOneWidget);
    await tester.tap(find.text('MAD Dirham · del posto'));
    await tester.enterText(find.byType(TextField).first, '80');
    await tester.pump();
    await tester.ensureVisible(pulsante('Salva'));
    await tester.tap(pulsante('Salva'));
    await aspetta(tester);

    expect(ambiente.server.spese, isEmpty);
    expect((await copia(tester)).single.versione, 0);
    expect(find.text('80,00 MAD · parte con la rete'), findsOneWidget);
    expect(
      find.textContaining('senza rete possono essere cambiati'),
      findsOneWidget,
    );

    expect(
      (await eventi(tester))
          .firstWhere((e) => e.$1 == 'apertura_senza_rete')
          .$2,
      {'schermata': 'spese', 'mancante': null},
    );

    // Toccata, si apre: ma per cambiarla deve prima partire.
    await tester.tap(find.text('Spesa'));
    await tester.pumpAndSettle();
    expect(find.text('La spesa'), findsOneWidget);
    expect(
      find.text('Parte con la rete: dopo si potrà cambiare'),
      findsOneWidget,
    );
  });

  testWidgets('senza un tasso la spesa resta nella sua valuta, e il totale lo '
      'dice', (tester) async {
    await viaggio(tester);
    ambiente.server.spese.add(
      rigaDiSpesa(
        'a',
        viaggio: 'v',
        importo: '50000',
        valuta: 'VND',
        data: fra(0),
        descrizione: 'Pho',
      ),
    );
    await tester.runAsync(ambiente.archivio.aggiornaCopia);
    await ambiente.monta(tester, const SchermataSpese(viaggioId: 'v'));

    expect(find.text('0,00 €'), findsOneWidget);
    expect(find.text('+ 50.000 VND, senza tasso'), findsOneWidget);
    expect(find.text('50.000 VND · senza tasso'), findsOneWidget);

    await tester.tap(find.text('Pho'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Conversione non disponibile.', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('cambiare una spesa richiede la rete, e lo dice prima', (
    tester,
  ) async {
    await viaggio(tester);
    ambiente.server.spese.add(
      rigaDiSpesa('a', viaggio: 'v', data: fra(0), descrizione: 'Pranzo'),
    );
    await tester.runAsync(ambiente.archivio.aggiornaCopia);
    await ambiente.monta(tester, const SchermataSpese(viaggioId: 'v'));

    ambiente.rete.disponibile = false;
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pranzo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '14');
    await tester.pumpAndSettle();
    expect(find.text(motivoSenzaRete), findsWidgets);

    ambiente.rete.disponibile = true;
    await tester.pumpAndSettle();
    await tester.ensureVisible(pulsante('Salva'));
    await tester.tap(pulsante('Salva'));
    await aspetta(tester);

    final chiamata = ambiente.server.chiamate('PATCH', '/rest/v1/spesa').single;
    expect(corpoDi(chiamata), {'importo': '14.00', 'versione': 1});
  });

  testWidgets('un\'idea non ha spese: servono le date', (tester) async {
    await viaggio(tester, stato: 'idea');
    await ambiente.monta(tester, const SchermataViaggio(viaggioId: 'v'));
    expect(find.text('Spese'), findsNothing);
    expect(find.text('Registra una spesa'), findsNothing);
  });
}
