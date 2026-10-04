import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/aspetto/elementi.dart';
import 'package:trolley/dominio/calendario.dart';
import 'package:trolley/schermate/divisione_spesa.dart';
import 'package:trolley/schermate/foglio_spesa.dart';
import 'package:trolley/schermate/saldi.dart';
import 'package:trolley/schermate/spese.dart';

import '../aiuti.dart';

/// Dividere le spese (fase 2.3; tela, 37–41 e 89): chi ha pagato e per chi
/// già scelti, gli importi diversi, la propria parte, i saldi con il giro più
/// corto, «Li ho ricevuti», la stessa spesa registrata da due persone.
void main() {
  late Ambiente ambiente;

  setUp(() => ambiente = Ambiente());
  tearDown(() => ambiente.chiudi());

  const marco = '22222222-2222-4222-8222-222222222222';
  const sara = '33333333-3333-4333-8333-333333333333';
  final oggi = soloData(DateTime.now());
  String fra(int giorni) => scriviData(oggi.add(Duration(days: giorni)));

  /// Porto in tre, in corso: Giulia (chi prova), Marco e Sara. Con [soli]
  /// Giulia viaggia da sola.
  Future<void> viaggio(WidgetTester tester, {bool soli = false}) async {
    ambiente.server
      ..viaggi.add(
        rigaViaggio('v', stato: 'definito', inizio: fra(-1), fine: fra(1)),
      )
      ..giorni.add(rigaGiorno('v', fra(0), '00:00:00', '24:00:00'))
      ..partecipazioni.add(rigaPartecipazione('v'))
      ..tassi.add(rigaTasso('EUR', 1, fra(0)));
    if (!soli) {
      for (final (id, nome) in [(marco, 'Marco'), (sara, 'Sara')]) {
        ambiente.server
          ..partecipazioni.add(
            rigaPartecipazione('v', utente: id, ruolo: 'partecipante'),
          )
          ..utenti.add({
            'id': id,
            'nome': nome,
            'versione': 1,
            'eliminato_il': null,
          });
      }
    }
    await ambiente.accedi(tester: tester);
    await tester.runAsync(ambiente.archivio.aggiornaCopia);
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

  Finder pulsante(String etichetta) => find.descendant(
    of: find.byType(PulsanteGrande),
    matching: find.text(etichetta),
  );

  /// Un gettone della sezione: in «Ha pagato» il primo, in «Per chi» il
  /// secondo.
  Finder gettone(String nome, {bool perChi = false}) {
    final tutti = find.descendant(
      of: find.byType(Gettone),
      matching: find.text(nome),
    );
    return perChi ? tutti.last : tutti.first;
  }

  Future<void> nuovaSpesa(WidgetTester tester, String importo) async {
    await ambiente.monta(tester, const SchermataSpese(viaggioId: 'v'));
    await aspetta(tester);
    await tester.tap(pulsante('Registra una spesa'));
    await aspetta(tester);
    await tester.enterText(
      find
          .descendant(
            of: find.byType(FoglioSpesa),
            matching: find.byType(TextField),
          )
          .first,
      importo,
    );
    await tester.pump();
  }

  Map<String, num> quoteSulServer() => {
    for (final q in ambiente.server.quote)
      if (q['eliminato_il'] == null)
        q['utente_id']! as String: q['quota']! as num,
  };

  testWidgets('in tre: tu hai pagato, per tutti, in parti uguali, già '
      'scelto', (tester) async {
    await viaggio(tester);
    await nuovaSpesa(tester, '42');

    expect(
      find.textContaining('Chi ha pagato e per chi sono già scelti'),
      findsOneWidget,
    );
    expect(find.text('Ha pagato'), findsOneWidget);
    expect(find.text('Per chi'), findsOneWidget);
    expect(find.text('14,00 € a testa.'), findsOneWidget);

    await tester.ensureVisible(pulsante('Salva'));
    await tester.tap(pulsante('Salva'));
    await aspetta(tester);

    expect(ambiente.server.spese.single['pagante_id'], idDiProva);
    expect(quoteSulServer(), {idDiProva: 14, marco: 14, sara: 14});
  });

  testWidgets('si cambia chi ha pagato e per chi', (tester) async {
    await viaggio(tester);
    await nuovaSpesa(tester, '42');

    await tester.tap(gettone('Marco'));
    await tester.pump();
    await tester.ensureVisible(gettone('Sara', perChi: true));
    await tester.tap(gettone('Sara', perChi: true));
    await tester.pump();
    expect(find.text('21,00 € a testa.'), findsOneWidget);

    await tester.ensureVisible(pulsante('Salva'));
    await tester.tap(pulsante('Salva'));
    await aspetta(tester);

    expect(ambiente.server.spese.single['pagante_id'], marco);
    expect(quoteSulServer(), {idDiProva: 21, marco: 21});
  });

  testWidgets('importi diversi: si vede quanto manca, e si registra quando '
      'le parti tornano', (tester) async {
    await viaggio(tester);
    await nuovaSpesa(tester, '42');

    await tester.ensureVisible(find.text('Importi diversi'));
    await tester.tap(find.text('Importi diversi'));
    await aspetta(tester);
    final campi = find.descendant(
      of: find.byType(FoglioImportiDiversi),
      matching: find.byType(TextField),
    );
    expect(campi, findsNWidgets(3));
    await tester.enterText(campi.at(0), '20');
    await tester.enterText(campi.at(1), '12');
    await tester.enterText(campi.at(2), '6');
    await tester.pump();
    expect(find.text('Mancano 4,00 €'), findsNothing);
    expect(
      find.textContaining('Mancano 4,00', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.text('Le parti devono fare 42,00 €, l\'importo pagato.'),
      findsOneWidget,
    );

    await tester.enterText(campi.at(2), '10');
    await tester.pump();
    await tester.tap(pulsante('Registra'));
    await aspetta(tester);

    expect(find.byType(FoglioSpesa), findsNothing);
    expect(quoteSulServer(), {idDiProva: 20, marco: 12, sara: 10});
  });

  testWidgets('la tua parte, quanto hai pagato, i saldi; «Li ho ricevuti» '
      'chiude un saldo', (tester) async {
    ambiente.server
      ..spese.addAll([
        rigaDiSpesa(
          'cena',
          viaggio: 'v',
          importo: '84.00',
          data: fra(0),
          descrizione: 'Cena da Cantinho',
        ),
        rigaDiSpesa(
          'taxi',
          viaggio: 'v',
          importo: '36.00',
          data: fra(0),
          descrizione: 'Taxi',
          pagante: sara,
          creatoDa: sara,
        ),
      ])
      ..quote.addAll([
        for (final p in [idDiProva, marco, sara])
          rigaDiQuota('cena', viaggio: 'v', utente: p, quota: '28.00'),
        for (final p in [idDiProva, marco, sara])
          rigaDiQuota('taxi', viaggio: 'v', utente: p, quota: '12.00'),
      ]);
    await viaggio(tester);
    await ambiente.monta(tester, const SchermataSpese(viaggioId: 'v'));
    await aspetta(tester);

    expect(find.text('La tua parte'), findsOneWidget);
    expect(find.text('40,00 €'), findsOneWidget);
    expect(find.text('Hai pagato'), findsOneWidget);
    expect(find.text('84,00 €'), findsWidgets);
    expect(find.text('Ti devono 44,00 €'), findsOneWidget);
    expect(
      find.textContaining('Pagata da Sara · per tutti e 3'),
      findsOneWidget,
    );

    await tester.tap(find.text('Ti devono 44,00 €'));
    await aspetta(tester);
    expect(find.byType(SchermataSaldi), findsOneWidget);
    expect(
      find.text(
        'Il giro più corto per pareggiare: due passaggi invece di tre.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Marco dà a te', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Sara dà a te', findRichText: true),
      findsOneWidget,
    );

    await tester.tap(find.text('Li ho ricevuti').last);
    await tester.pumpAndSettle();
    expect(find.text('Hai ricevuto 4,00 € da Sara?'), findsOneWidget);
    await tester.tap(find.text('Li ho ricevuti').last);
    await aspetta(tester);

    final rimborso = ambiente.server.spese.singleWhere(
      (s) => s['rimborso'] == true,
    );
    expect(rimborso['pagante_id'], sara);
    expect(rimborso['importo'], 4);
    expect(
      find.textContaining('Sara dà a te', findRichText: true),
      findsNothing,
    );
    expect(
      find.textContaining('Marco dà a te', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('GIÀ DATI'), findsOneWidget);
    expect(find.textContaining('Sara a te'), findsOneWidget);
  });

  testWidgets('la stessa spesa registrata da due persone si segnala, e «Sono '
      'due spese» la fa sparire', (tester) async {
    final adesso = DateTime.now().toUtc();
    ambiente.server.spese.addAll([
      rigaDiSpesa(
        'sua',
        viaggio: 'v',
        importo: '36.00',
        data: fra(0),
        descrizione: 'Taxi',
        pagante: marco,
        creatoDa: marco,
        creatoIl: adesso.subtract(const Duration(minutes: 3)).toIso8601String(),
      ),
      rigaDiSpesa(
        'mia',
        viaggio: 'v',
        importo: '36.00',
        data: fra(0),
        descrizione: 'Taxi aeroporto',
        creatoIl: adesso.toIso8601String(),
      ),
    ]);
    await viaggio(tester);
    await ambiente.monta(tester, const SchermataSpese(viaggioId: 'v'));
    await aspetta(tester);

    expect(
      find.textContaining(
        'Sembra la stessa spesa di Marco:',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('3 minuti prima della tua', findRichText: true),
      findsOneWidget,
    );
    await tester.tap(find.text('Sono due spese'));
    await aspetta(tester);
    expect(
      find.textContaining(
        'Sembra la stessa spesa di Marco:',
        findRichText: true,
      ),
      findsNothing,
    );
  });

  testWidgets('da soli non si parla di dividere', (tester) async {
    await viaggio(tester, soli: true);
    await nuovaSpesa(tester, '12');
    expect(find.text('Ha pagato'), findsNothing);
    expect(find.text('Per chi'), findsNothing);
    await tester.ensureVisible(pulsante('Salva'));
    await tester.tap(pulsante('Salva'));
    await aspetta(tester);
    expect(ambiente.server.quote, isEmpty);
    expect(find.text('La tua parte'), findsNothing);
    expect(find.textContaining('Ti devono'), findsNothing);
  });
}
