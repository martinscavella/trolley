import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/aspetto/elementi.dart';
import 'package:trolley/aspetto/pagina.dart';
import 'package:trolley/dominio/calendario.dart';
import 'package:trolley/schermate/tappa.dart';

import '../aiuti.dart';

/// Il foglio della tappa con gli orari (04, «Gli orari»; tela, 128 e 129):
/// a un'ora presa non si salva, e le proposte la sistemano.
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

  /// Una tappa nuova alle 13:00, toccata sulla linea del tempo, in un giorno
  /// con il pranzo dalle 13 alle 14:30 e il ponte dalle 15 alle 16.
  Future<void> nuovaAlleTredici(WidgetTester tester) async {
    ambiente.server
      ..viaggi.add(
        rigaViaggio('v', stato: 'definito', inizio: fra(30), fine: fra(31)),
      )
      ..partecipazioni.add(rigaPartecipazione('v'))
      ..giorni.addAll([
        rigaGiorno('v', fra(30), '00:00:00', '24:00:00', id: 'g1'),
        rigaGiorno('v', fra(31), '00:00:00', '18:00:00', id: 'g2'),
      ])
      ..tappe.addAll([
        rigaDiTappa(
          'pranzo',
          viaggio: 'v',
          giorno: 'g1',
          titolo: 'Pranzo',
          tipo: 'pasto',
          ora: '13:00:00',
        ),
        rigaDiTappa(
          'ponte',
          viaggio: 'v',
          giorno: 'g1',
          ordine: 2,
          titolo: 'Ponte',
          tipo: 'passeggiata',
          durata: 60,
          ora: '15:00:00',
        ),
      ]);
    await tester.runAsync(ambiente.archivio.aggiornaCopia);
    final archivio = ambiente.archivio;
    final (viaggio, giorni, tappe) = (await tester.runAsync(
      () async => (
        (await archivio.osservaViaggio('v').first)!,
        await archivio.osservaGiorni('v').first,
        await archivio.osservaTappe('v').first,
      ),
    ))!;
    await ambiente.monta(
      tester,
      Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => apriFoglio<String>(
              context,
              SchermataTappa(
                viaggio: viaggio,
                giorni: giorni,
                tappe: tappe,
                giornoId: 'g1',
                ora: const Duration(hours: 13),
              ),
            ),
            child: const Text('Apri'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Apri'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Torre dei Clérigos');
    await tester.pump();
  }

  testWidgets('a un\'ora presa si dice con chi si scontra, e «Mettila alle» '
      'la porta all\'ora libera più vicina', (tester) async {
    await nuovaAlleTredici(tester);

    expect(find.textContaining('Alle 13:00 c\'è già «Pranzo»'), findsOneWidget);
    expect(find.text('Si sovrappone a «Pranzo»'), findsOneWidget);
    // Un'ora e mezza: prima del pranzo, dalle 11:30.
    await tester.ensureVisible(find.text('Mettila alle 11:30'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mettila alle 11:30'));
    await tester.pump();
    expect(find.text('Si sovrappone a «Pranzo»'), findsNothing);
    expect(find.text('11:30'), findsOneWidget);

    await tester.tap(pulsante('Aggiungi'));
    await aspetta(tester);
    final aggiunta = ambiente.server.tappe.firstWhere(
      (t) => t['titolo'] == 'Torre dei Clérigos',
    );
    expect(aggiunta['ora_inizio'], '11:30:00');
    final evento = (await ambiente.eventi(tester))
        .where((e) => e.nome == 'tappa_non_entrata')
        .single;
    expect(jsonDecode(evento.proprieta), {
      'motivo': 'sovrapposta',
      'scelta': 'orario_libero',
    });
  });

  testWidgets('tenerla all\'ora scelta sposta più tardi le tappe dopo, '
      'quanto serve', (tester) async {
    await nuovaAlleTredici(tester);

    final proposta = find.text(
      'Tienila alle 13:00 e sposta più tardi «Pranzo» e «Ponte»',
    );
    await tester.ensureVisible(proposta);
    await tester.pumpAndSettle();
    await tester.tap(proposta);
    await tester.pump();
    expect(
      find.textContaining('«Pranzo» alle 14:30, «Ponte» alle 16:00'),
      findsOneWidget,
    );

    await tester.tap(pulsante('Aggiungi'));
    await aspetta(tester);
    String alle(String id) =>
        ambiente.server.tappe.firstWhere((t) => t['id'] == id)['ora_inizio']!
            as String;
    expect(alle('pranzo'), '14:30:00');
    expect(alle('ponte'), '16:00:00');
    expect(
      ambiente.server.tappe.firstWhere(
        (t) => t['titolo'] == 'Torre dei Clérigos',
      )['ora_inizio'],
      '13:00:00',
    );
  });

  testWidgets('chiudendo senza sistemarla, si misura che la si è lasciata', (
    tester,
  ) async {
    await nuovaAlleTredici(tester);
    // Chiuso tirandolo giù, o con Indietro.
    Navigator.of(tester.element(find.text('Nuova tappa'))).pop();
    await aspetta(tester);
    final evento = (await ambiente.eventi(tester))
        .where((e) => e.nome == 'tappa_non_entrata')
        .single;
    expect(jsonDecode(evento.proprieta), {
      'motivo': 'sovrapposta',
      'scelta': 'lasciata',
    });
  });
}
