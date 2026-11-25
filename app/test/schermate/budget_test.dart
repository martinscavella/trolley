import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/aspetto/elementi.dart';
import 'package:trolley/aspetto/pagina.dart';
import 'package:trolley/dominio/calendario.dart';
import 'package:trolley/schermate/spese.dart';
import 'package:trolley/schermate/viaggio.dart';

import '../aiuti.dart';

/// Il budget (06, regole 12–17; tela, 134–136): quello del viaggio sul
/// server, quello di ciascuno solo sul telefono.
void main() {
  late Ambiente ambiente;

  setUp(() => ambiente = Ambiente());
  tearDown(() => ambiente.chiudi());

  final oggi = soloData(DateTime.now());
  String fra(int giorni) => scriviData(oggi.add(Duration(days: giorni)));

  Finder pulsante(String etichetta) => find.descendant(
    of: find.byType(PulsanteGrande),
    matching: find.text(etichetta),
  );

  Future<void> aspetta(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> scrivi(WidgetTester tester, String importo) async {
    await tester.enterText(
      find.descendant(
        of: find.byType(Foglio),
        matching: find.byType(TextField),
      ),
      importo,
    );
    await tester.pump();
  }

  /// Un viaggio di tre giorni cominciato ieri, con [spese] di oggi.
  Future<void> inCorso(
    WidgetTester tester, {
    List<Map<String, Object?>> spese = const [],
    bool conMarco = false,
  }) async {
    ambiente.server
      ..viaggi.add(
        rigaViaggio('v', stato: 'definito', inizio: fra(-1), fine: fra(1)),
      )
      ..partecipazioni.addAll([
        rigaPartecipazione('v'),
        if (conMarco)
          rigaPartecipazione('v', utente: 'marco', ruolo: 'partecipante'),
      ])
      ..giorni.addAll([
        rigaGiorno('v', fra(-1), '10:00:00', '24:00:00', id: 'g1'),
        rigaGiorno('v', fra(0), '00:00:00', '24:00:00', id: 'g2'),
        rigaGiorno('v', fra(1), '00:00:00', '18:00:00', id: 'g3'),
      ])
      ..spese.addAll(spese);
    if (conMarco) {
      ambiente.server.utenti.add({
        'id': 'marco',
        'nome': 'Marco',
        'versione': 1,
        'eliminato_il': null,
      });
    }
    await ambiente.accedi(tester: tester);
    await tester.runAsync(ambiente.archivio.aggiornaCopia);
    await ambiente.monta(tester, const SchermataSpese(viaggioId: 'v'));
    await aspetta(tester);
  }

  testWidgets('il budget del viaggio si mette, va sul server, e dice a che '
      'punto siete', (tester) async {
    await inCorso(
      tester,
      spese: [rigaDiSpesa('s1', viaggio: 'v', data: fra(0), importo: '120.00')],
    );
    expect(find.text('Metti un budget'), findsOneWidget);
    await tester.tap(find.text('Metti un budget'));
    await tester.pumpAndSettle();
    await scrivi(tester, '900');
    await tester.tap(pulsante('Salva'));
    await aspetta(tester);

    final viaggio = ambiente.server.viaggi.single;
    expect(viaggio['budget_importo'], '900.00');
    expect(viaggio['budget_valuta'], 'EUR');
    expect(find.text('di 900,00\u00a0€'), findsOneWidget);
    // 900 per tre giorni: oggi e domani restano 390 l'uno.
    expect(
      find.textContaining(
        'Restano 780,00\u00a0€: 390,00\u00a0€ al giorno per oggi e '
        'domani.',
      ),
      findsOneWidget,
    );
    // Due giorni cominciati, 600 di ritmo: 480 sotto.
    expect(
      find.textContaining('sotto il ritmo di 480,00\u00a0€'),
      findsOneWidget,
    );
    final evento = (await ambiente.eventi(tester))
        .where((e) => e.nome == 'budget_impostato')
        .single;
    expect(jsonDecode(evento.proprieta), {
      'di': 'viaggio',
      'stato': 'inCorso',
      'tolto': false,
    });
  });

  testWidgets('oltre il budget, lo si dice in rosso', (tester) async {
    ambiente.server.viaggi.add(
      rigaViaggio('altro', stato: 'definito', inizio: fra(5), fine: fra(6)),
    );
    await inCorso(
      tester,
      spese: [rigaDiSpesa('s1', viaggio: 'v', data: fra(0), importo: '120.00')],
    );
    await tester.tap(find.text('Metti un budget'));
    await tester.pumpAndSettle();
    await scrivi(tester, '100');
    await tester.tap(pulsante('Salva'));
    await aspetta(tester);
    expect(
      find.textContaining('Oltre il budget di 20,00\u00a0€.'),
      findsOneWidget,
    );
  });

  testWidgets('il proprio budget si mette anche senza rete, resta sul '
      'telefono, e si confronta con la propria parte', (tester) async {
    await inCorso(
      tester,
      conMarco: true,
      spese: [rigaDiSpesa('s1', viaggio: 'v', data: fra(0), importo: '120.00')],
    );
    ambiente.rete.disponibile = false;
    await tester.pumpAndSettle();
    await tester.tap(find.text('Il tuo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Metti un budget'));
    await tester.pumpAndSettle();
    await scrivi(tester, '300');
    await tester.tap(pulsante('Salva'));
    await aspetta(tester);

    expect(ambiente.server.viaggi.single['budget_importo'], isNull);
    // La metà dei 120, la propria parte.
    expect(find.text('60,00\u00a0€'), findsWidgets);
    expect(find.text('di 300,00\u00a0€'), findsOneWidget);
    final segno = await tester.runAsync(
      () => ambiente.archivio.osservaBudgetPersonale('v').first,
    );
    expect(segno?.centesimi, 30000);
  });

  testWidgets('il budget del viaggio senza rete non si mette, e lo dice', (
    tester,
  ) async {
    await inCorso(tester);
    ambiente.rete.disponibile = false;
    await tester.pumpAndSettle();
    await tester.tap(find.text('Metti un budget'));
    await tester.pumpAndSettle();
    await scrivi(tester, '900');
    expect(
      find.descendant(
        of: find.byType(Foglio),
        matching: find.text('Serve la connessione'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('nell\'idea c\'è il budget di massima', (tester) async {
    ambiente.server
      ..viaggi.add(rigaViaggio('v', periodo: 'autunno'))
      ..partecipazioni.add(rigaPartecipazione('v'));
    await ambiente.accedi(tester: tester);
    await tester.runAsync(ambiente.archivio.aggiornaCopia);
    await ambiente.monta(tester, const SchermataViaggio(viaggioId: 'v'));
    await aspetta(tester);

    await tester.scrollUntilVisible(
      find.text('Aggiungi un budget di massima'),
      300,
    );
    await tester.tap(find.text('Aggiungi un budget di massima'));
    await tester.pumpAndSettle();
    expect(
      find.text('Quanto pensate di spendere, più o meno?'),
      findsOneWidget,
    );
    await scrivi(tester, '2500');
    await tester.tap(pulsante('Salva'));
    await aspetta(tester);

    expect(ambiente.server.viaggi.single['budget_importo'], '2500.00');
    expect(find.text('2.500,00\u00a0€'), findsOneWidget);
  });
}
