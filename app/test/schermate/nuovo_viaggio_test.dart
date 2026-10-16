import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/aspetto/elementi.dart';
import 'package:trolley/aspetto/formati.dart';
import 'package:trolley/dati/errori.dart';
import 'package:trolley/dominio/periodo.dart';
import 'package:trolley/schermate/nuovo_viaggio.dart';

import '../aiuti.dart';

void main() {
  late Ambiente ambiente;

  setUp(() => ambiente = Ambiente());
  tearDown(() => ambiente.chiudi());

  testWidgets('il pulsante dice cosa manca, e senza rete lo dice prima', (
    tester,
  ) async {
    await ambiente.monta(tester, const SchermataNuovoViaggio());
    expect(find.text('Scegli dove'), findsOneWidget);

    ambiente.rete.disponibile = false;
    await tester.pumpAndSettle();
    expect(find.text(motivoSenzaRete), findsOneWidget);
    expect(find.text('Scegli dove'), findsNothing);
  });

  testWidgets('si crea un\'idea scegliendo dove e un periodo, e la creazione '
      'si misura', (tester) async {
    await ambiente.monta(tester, const SchermataNuovoViaggio());

    await tester.tap(find.text('Non ancora'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Una città o un paese'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'lisb');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lisbona'));
    await tester.pumpAndSettle();
    expect(find.text('Lisbona, Portogallo'), findsOneWidget);

    final oggi = DateTime.now();
    final prossimo = Periodo.mesiDa(oggi)[1];
    final gettone = find.text(etichettaPeriodo(prossimo, oggi));
    await tester.ensureVisible(gettone);
    await tester.tap(gettone);
    await tester.pumpAndSettle();

    final crea = find.descendant(
      of: find.byType(PulsanteGrande),
      matching: find.text('Crea'),
    );
    await tester.tap(crea);
    await tester.pumpAndSettle();

    final chiamata = ambiente.server
        .chiamate('POST', '/rest/v1/rpc/crea_viaggio')
        .single;
    expect(corpoDi(chiamata), containsPair('p_periodo', prossimo.testo));
    expect(corpoDi(chiamata), containsPair('p_destinazione_citta', 'Lisbona'));
    expect(corpoDi(chiamata), containsPair('p_destinazione_paese', 'PT'));

    final eventi = await ambiente.eventi(tester);
    expect(eventi.single.nome, 'viaggio_creato');
    expect(jsonDecode(eventi.single.proprieta), {
      'stato_iniziale': 'idea',
      'durata_prevista_giorni': null,
    });

    // Si è già dentro l'idea, che invita a fissare le date.
    expect(find.text('Lisbona'), findsOneWidget);
    expect(find.text('Fissa le date'), findsOneWidget);
  });

  testWidgets('un viaggio che nasce con le date propone i promemoria '
      '(tela, 82)', (tester) async {
    await ambiente.monta(tester, const SchermataNuovoViaggio());

    await tester.tap(find.text('Ho le date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Una città o un paese'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'lisb');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lisbona'));
    await tester.pumpAndSettle();

    /// Sceglie una data scrivendola, come si può fare nel selettore Material.
    Future<void> scegli(Finder campo, DateTime data) async {
      await tester.ensureVisible(campo);
      await tester.pumpAndSettle();
      await tester.tap(campo);
      await tester.pumpAndSettle();
      final testi = MaterialLocalizations.of(
        tester.element(find.byType(DatePickerDialog)),
      );
      await tester.tap(find.byTooltip(testi.inputDateModeButtonLabel));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.byType(TextField),
        ),
        testi.formatCompactDate(data),
      );
      await tester.tap(find.text(testi.okButtonLabel));
      await tester.pumpAndSettle();
    }

    final inizio = DateTime.now().add(const Duration(days: 40));
    await scegli(find.text('Primo giorno'), inizio);
    await scegli(
      find.text('Al ${dataEstesa(inizio)}'),
      inizio.add(const Duration(days: 2)),
    );

    final crea = find.descendant(
      of: find.byType(PulsanteGrande),
      matching: find.text('Crea'),
    );
    await tester.tap(crea);
    await tester.pumpAndSettle();

    expect(find.text('Vuoi un promemoria?'), findsOneWidget);
    expect(find.text('Hai appena fissato le date di Lisbona.'), findsOneWidget);
    await tester.tap(find.text('Sì, avvisami'));
    await tester.pumpAndSettle();
    expect(ambiente.notifiche.richieste, 1);
    expect(find.text('Vuoi un promemoria?'), findsNothing);
  });
}
