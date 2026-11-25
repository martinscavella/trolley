import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/aspetto/elementi.dart';
import 'package:trolley/dominio/calendario.dart';
import 'package:trolley/schermate/viaggio.dart';

import '../aiuti.dart';

/// Eliminare un viaggio (02, regola 13; tela, 132 e 133): solo se ci sei
/// soltanto tu, dicendo prima che cosa si cancella.
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

  /// Porto fra un mese, due giorni, una tappa e due spese, una di Marco che
  /// è uscito. Con [conSara], Sara è ancora dentro.
  Future<void> porto(WidgetTester tester, {bool conSara = false}) async {
    ambiente.server
      ..viaggi.add(
        rigaViaggio('v', stato: 'definito', inizio: fra(30), fine: fra(31)),
      )
      ..partecipazioni.addAll([
        rigaPartecipazione('v'),
        rigaPartecipazione(
          'v',
          utente: 'marco',
          ruolo: 'partecipante',
          stato: 'uscito',
        ),
        if (conSara)
          rigaPartecipazione('v', utente: 'sara', ruolo: 'partecipante'),
      ])
      ..giorni.addAll([
        rigaGiorno('v', fra(30), '10:00:00', '24:00:00', id: 'g1'),
        rigaGiorno('v', fra(31), '00:00:00', '18:00:00', id: 'g2'),
      ])
      ..tappe.add(rigaDiTappa('a', viaggio: 'v', giorno: 'g1'))
      ..spese.addAll([
        rigaDiSpesa('s1', viaggio: 'v', data: fra(30)),
        rigaDiSpesa('s2', viaggio: 'v', data: fra(30), pagante: 'marco'),
      ]);
    await ambiente.accedi(tester: tester);
    await tester.runAsync(ambiente.archivio.aggiornaCopia);
    await ambiente.monta(tester, const SchermataViaggio(viaggioId: 'v'));
    await tester.scrollUntilVisible(pulsante('Elimina il viaggio'), 300);
    await tester.pumpAndSettle();
  }

  testWidgets('da solo: si dice che cosa si cancella, si conferma, e del '
      'viaggio non resta niente', (tester) async {
    await porto(tester);
    await tester.tap(pulsante('Elimina il viaggio'));
    await aspetta(tester);

    expect(find.text('Eliminare Porto?'), findsOneWidget);
    expect(find.textContaining('2 giorni', findRichText: true), findsOneWidget);
    expect(find.textContaining('2 spese', findRichText: true), findsOneWidget);
    expect(
      find.textContaining('che è uscito', findRichText: true),
      findsOneWidget,
    );

    await tester.tap(pulsante('Elimina il viaggio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elimina').last);
    await aspetta(tester);

    expect(ambiente.server.viaggi, isEmpty);
    expect(ambiente.server.spese, isEmpty);
    final copia = await tester.runAsync(
      () => ambiente.archivio.osservaViaggio('v').first,
    );
    expect(copia, isNull);
    final evento = (await ambiente.eventi(tester))
        .where((e) => e.nome == 'viaggio_eliminato')
        .single;
    expect(jsonDecode(evento.proprieta), {
      'stato': 'definito',
      'giorni_dalla_creazione': isA<int>(),
    });
  });

  testWidgets('ripensandoci, non si elimina niente', (tester) async {
    await porto(tester);
    await tester.tap(pulsante('Elimina il viaggio'));
    await tester.pumpAndSettle();
    await tester.tap(pulsante('Elimina il viaggio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annulla').last);
    await tester.pumpAndSettle();
    expect(ambiente.server.viaggi, hasLength(1));
  });

  testWidgets('con altri dentro il pulsante è spento, e dice perché', (
    tester,
  ) async {
    ambiente.server.utenti.add({
      'id': 'sara',
      'nome': 'Sara',
      'versione': 1,
      'eliminato_il': null,
    });
    await porto(tester, conSara: true);
    expect(find.textContaining('ci sono anche Sara'), findsOneWidget);
    expect(find.text('Ci sono altre persone'), findsOneWidget);
    await tester.tap(pulsante('Elimina il viaggio'));
    await tester.pumpAndSettle();
    expect(find.text('Eliminare Porto?'), findsNothing);
  });

  testWidgets('senza rete non si elimina, e lo dice prima', (tester) async {
    await porto(tester);
    ambiente.rete.disponibile = false;
    await tester.pumpAndSettle();
    await tester.tap(pulsante('Elimina il viaggio'));
    await tester.pumpAndSettle();
    expect(find.text('Eliminare Porto?'), findsNothing);
  });
}
