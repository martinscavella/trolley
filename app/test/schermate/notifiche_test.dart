import 'dart:convert';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dominio/notifiche.dart';
import 'package:trolley/schermate/giornata.dart';
import 'package:trolley/schermate/impostazioni.dart';
import 'package:trolley/schermate/notifiche.dart';
import 'package:trolley/schermate/prima_di_partire.dart';
import 'package:trolley/schermate/riepilogo.dart';
import 'package:trolley/schermate/viaggio.dart';

import '../aiuti.dart';

/// Le notifiche (14; tela, 82, 83, 119, 120): il foglio del permesso quando
/// un viaggio prende le date, le righe una per una, dove porta una notifica
/// toccata.
void main() {
  late Ambiente ambiente;

  setUp(() => ambiente = Ambiente());
  tearDown(() => ambiente.chiudi());

  Future<List<Map<String, Object?>>> eventi(
    WidgetTester tester,
    String nome,
  ) async => [
    for (final e in await ambiente.eventi(tester))
      if (e.nome == nome) jsonDecode(e.proprieta) as Map<String, Object?>,
  ];

  AdaptiveSwitch interruttore(WidgetTester tester, String riga) =>
      tester.widget<AdaptiveSwitch>(
        find.descendant(
          of: find.ancestor(
            of: find.text(riga),
            matching: find.byType(MergeSemantics),
          ),
          matching: find.byType(AdaptiveSwitch),
        ),
      );

  group('Notifiche, nel profilo', () {
    testWidgets('dal profilo, sotto la valuta (tela, 64)', (tester) async {
      await ambiente.accedi(tester: tester);
      await ambiente.monta(tester, const SchermataImpostazioni());
      await tester.scrollUntilVisible(find.text('Notifiche'), 200);
      await tester.ensureVisible(find.text('Notifiche'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Notifiche'));
      await tester.pumpAndSettle();
      expect(find.byType(SchermataNotifiche), findsOneWidget);
    });

    testWidgets('prima di accenderle: le righe ferme, e «Accendile» chiede '
        'al telefono (119)', (tester) async {
      await ambiente.monta(tester, const SchermataNotifiche());
      expect(find.text('Per ora sono spente'), findsOneWidget);
      expect(interruttore(tester, 'Prima di partire').onChanged, isNull);

      await tester.tap(find.text('Accendile'));
      await tester.pumpAndSettle();
      expect(ambiente.notifiche.richieste, 1);
      expect(find.text('Per ora sono spente'), findsNothing);
      expect(interruttore(tester, 'Prima di partire').value, isTrue);
      expect(await eventi(tester, 'permesso_notifiche'), [
        {'esito': 'concesso', 'da': 'impostazioni'},
      ]);
    });

    testWidgets('ognuna si spegne da sola, e resta spenta (83)', (
      tester,
    ) async {
      ambiente.notifiche.attive = true;
      await ambiente.monta(tester, const SchermataNotifiche());
      for (final riga in [
        'Prima di partire',
        'Tappe da segnare',
        'Idee che scadono',
        'Un anno fa',
      ]) {
        expect(interruttore(tester, riga).value, isTrue, reason: riga);
      }

      interruttore(tester, 'Un anno fa').onChanged!(false);
      await tester.pumpAndSettle();
      expect(interruttore(tester, 'Un anno fa').value, isFalse);
      expect(interruttore(tester, 'Prima di partire').value, isTrue);
      expect(await tester.runAsync(() => ambiente.promemoria.spente()), {
        TipoNotifica.unAnnoFa,
      });
      expect(await eventi(tester, 'notifica_impostata'), [
        {'tipo': 'un_anno_fa', 'accesa': false},
      ]);
    });

    testWidgets('spente dal telefono: lo dice, con «Apri Impostazioni» '
        '(120)', (tester) async {
      ambiente.notifiche
        ..risposta = false
        ..attive = false;
      await tester.runAsync(
        () => ambiente.promemoria.chiedi(da: 'impostazioni'),
      );
      await ambiente.monta(tester, const SchermataNotifiche());
      expect(find.text('Il telefono non le fa arrivare'), findsOneWidget);
      expect(find.text('Accendile'), findsNothing);
      expect(interruttore(tester, 'Un anno fa').onChanged, isNull);

      await tester.tap(find.text('Apri Impostazioni'));
      await tester.pumpAndSettle();
      expect(ambiente.notifiche.impostazioniAperte, 1);
    });
  });

  group('il foglio del permesso (82)', () {
    Future<void> proponi(WidgetTester tester) async {
      await ambiente.monta(
        tester,
        Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () =>
                  proponiLeNotifiche(Navigator.of(context), citta: 'Porto'),
              child: const Text('Date fissate'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Date fissate'));
      await tester.pumpAndSettle();
    }

    testWidgets('dice cosa arriverà prima che chieda il telefono; «Sì» lo fa '
        'chiedere', (tester) async {
      await proponi(tester);
      expect(find.text('Vuoi un promemoria?'), findsOneWidget);
      expect(find.text('Hai appena fissato le date di Porto.'), findsOneWidget);
      expect(
        find.textContaining('Niente pubblicità, niente di notte.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Sì, avvisami'));
      await tester.pumpAndSettle();
      expect(find.text('Vuoi un promemoria?'), findsNothing);
      expect(ambiente.notifiche.richieste, 1);
      expect(await eventi(tester, 'permesso_notifiche'), [
        {'esito': 'concesso', 'da': 'viaggio'},
      ]);

      // Chiesto una volta, non si ripropone.
      await tester.tap(find.text('Date fissate'));
      await tester.pumpAndSettle();
      expect(find.text('Vuoi un promemoria?'), findsNothing);
    });

    testWidgets('«Non ora» non chiede niente, e per un mese non torna', (
      tester,
    ) async {
      await proponi(tester);
      await tester.tap(find.text('Non ora'));
      await tester.pumpAndSettle();
      expect(ambiente.notifiche.richieste, 0);
      expect(await eventi(tester, 'permesso_notifiche'), [
        {'esito': 'non_ora', 'da': 'viaggio'},
      ]);

      await tester.tap(find.text('Date fissate'));
      await tester.pumpAndSettle();
      expect(find.text('Vuoi un promemoria?'), findsNothing);
    });

    testWidgets('con le notifiche già accese non si propone', (tester) async {
      ambiente.notifiche.attive = true;
      await proponi(tester);
      expect(find.text('Vuoi un promemoria?'), findsNothing);
    });
  });

  group('dove porta una notifica toccata (14, regola 7)', () {
    Future<void> tocca(WidgetTester tester, DovePorta dove) async {
      await ambiente.monta(
        tester,
        Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => apriDaNotifica(Navigator.of(context), dove),
              child: const Text('Notifica'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Notifica'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('prima di partire', (tester) async {
      await tocca(tester, (
        tipo: TipoNotifica.primaDiPartire,
        viaggioId: 'v',
        giornoId: null,
      ));
      expect(find.byType(SchermataPrimaDiPartire), findsOneWidget);
    });

    testWidgets('le tappe da segnare: la giornata', (tester) async {
      await tocca(tester, (
        tipo: TipoNotifica.tappeDaSegnare,
        viaggioId: 'v',
        giornoId: 'g',
      ));
      final giornata = tester.widget<SchermataGiornata>(
        find.byType(SchermataGiornata),
      );
      expect((giornata.viaggioId, giornata.giornoId), ('v', 'g'));
    });

    testWidgets('un\'idea che scade: l\'idea', (tester) async {
      await tocca(tester, (
        tipo: TipoNotifica.ideaCheScade,
        viaggioId: 'v',
        giornoId: null,
      ));
      expect(find.byType(SchermataViaggio), findsOneWidget);
    });

    testWidgets('un anno fa: il riepilogo', (tester) async {
      await tocca(tester, (
        tipo: TipoNotifica.unAnnoFa,
        viaggioId: 'v',
        giornoId: null,
      ));
      expect(find.byType(SchermataRiepilogo), findsOneWidget);
    });
  });
}
