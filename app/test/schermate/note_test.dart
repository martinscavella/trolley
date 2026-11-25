import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/aspetto/elementi.dart';
import 'package:trolley/schermate/note.dart';
import 'package:trolley/schermate/viaggio.dart';

import '../aiuti.dart';

/// Le note scritte a mano (tela, 139–142): si scrivono dal viaggio, la prima
/// riga è il titolo, si cambiano, e se qualcuno le ha riscritte intanto si
/// sceglie fra due versioni. Senza rete si leggono e non si scrivono.
void main() {
  late Ambiente ambiente;
  const marco = 'marco';

  setUp(() => ambiente = Ambiente());
  tearDown(() => ambiente.chiudi());

  Future<void> viaggio(
    WidgetTester tester, {
    List<Map<String, Object?>> note = const [],
  }) async {
    ambiente.server
      ..viaggi.add(
        rigaViaggio(
          'v',
          citta: 'Lisbona',
          paese: 'PT',
          periodo: 'autunno 2099',
        ),
      )
      ..partecipazioni.addAll([
        rigaPartecipazione('v'),
        rigaPartecipazione('v', utente: marco, ruolo: 'partecipante'),
      ])
      ..utenti.add({
        'id': marco,
        'nome': 'Marco',
        'versione': 1,
        'eliminato_il': null,
      })
      ..note.addAll(note);
    await ambiente.accedi(tester: tester);
    await tester.runAsync(ambiente.archivio.aggiornaCopia);
  }

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

  Future<List<String>> eventi(WidgetTester tester) async => [
    for (final e in await ambiente.eventi(tester)) '${e.nome} ${e.proprieta}',
    for (final r in ambiente.server.chiamate('POST', '/rest/v1/evento'))
      for (final e in (jsonDecode(r.body) as List).cast<Map<String, dynamic>>())
        '${e['nome']} ${jsonEncode(e['proprieta'])}',
  ];

  Map<String, Object?> wifi({String testo = 'Wifi\nAlfama_5G'}) => rigaDiNota(
    'wifi',
    viaggio: 'v',
    origine: 'scritta',
    testo: testo,
    creatoDa: marco,
  );

  testWidgets('dal viaggio si scrive una nota: la prima riga è il titolo, e '
      'si conta', (tester) async {
    await viaggio(tester);
    await ambiente.monta(tester, const SchermataViaggio(viaggioId: 'v'));
    await tester.scrollUntilVisible(pulsante('Scrivi una nota'), 300);
    await tester.ensureVisible(pulsante('Scrivi una nota'));
    await tester.pumpAndSettle();
    await tester.tap(pulsante('Scrivi una nota'));
    await tester.pumpAndSettle();

    expect(find.text('Nuova nota'), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byType(FoglioNota),
        matching: find.byType(EditableText),
      ),
      'Treno per Sintra\n15:20 da Rossio, binario 3',
    );
    await tester.pump();
    await tester.tap(pulsante('Salva'));
    await aspetta(tester);

    expect(find.text('Nuova nota'), findsNothing);
    final riga = ambiente.server.note.single;
    expect(riga['origine'], 'scritta');
    expect(riga['testo'], 'Treno per Sintra\n15:20 da Rossio, binario 3');
    expect(find.text('Treno per Sintra'), findsOneWidget);
    expect(find.text('15:20 da Rossio, binario 3'), findsOneWidget);
    expect(
      await eventi(tester),
      contains('nota_scritta {"viaggio_id":"v","stato":"idea"}'),
    );
  });

  testWidgets('senza rete le note si leggono, e scriverne una dice perché '
      'non si può', (tester) async {
    await viaggio(tester, note: [wifi()]);
    ambiente.rete.disponibile = false;
    await ambiente.monta(tester, const SchermataViaggio(viaggioId: 'v'));
    await tester.scrollUntilVisible(pulsante('Scrivi una nota'), 300);
    await tester.ensureVisible(pulsante('Scrivi una nota'));
    await tester.pumpAndSettle();

    expect(find.text('Wifi'), findsOneWidget);
    expect(find.text('Serve la connessione'), findsWidgets);
    await tester.tap(pulsante('Scrivi una nota'));
    await tester.pumpAndSettle();
    expect(find.text('Nuova nota'), findsNothing);
  });

  testWidgets('una nota scritta si cambia, con il testo di prima nel campo', (
    tester,
  ) async {
    await viaggio(tester, note: [wifi()]);
    await ambiente.monta(
      tester,
      const SchermataNota(notaId: 'wifi', viaggioId: 'v'),
    );
    expect(find.textContaining('scritta da Marco'), findsOneWidget);

    await tester.tap(pulsante('Cambia la nota'));
    await tester.pumpAndSettle();
    final campo = find.descendant(
      of: find.byType(FoglioNota),
      matching: find.byType(EditableText),
    );
    expect(
      tester.widget<EditableText>(campo).controller.text,
      'Wifi\nAlfama_5G',
    );
    await tester.enterText(campo, 'Wifi\nAlfama_5G · casa-alfama-24');
    await tester.pump();
    await tester.tap(pulsante('Salva'));
    await aspetta(tester);

    expect(find.text('Cambia la nota'), findsOneWidget); // il pulsante
    expect(
      ambiente.server.note.single['testo'],
      'Wifi\nAlfama_5G · casa-alfama-24',
    );
    expect(find.textContaining('casa-alfama-24'), findsOneWidget);
  });

  testWidgets('una risposta incollata non si cambia', (tester) async {
    await viaggio(tester, note: [rigaDiNota('n', viaggio: 'v')]);
    await ambiente.monta(
      tester,
      const SchermataNota(notaId: 'n', viaggioId: 'v'),
    );
    expect(find.text('Risposta incollata'), findsOneWidget);
    expect(pulsante('Cambia la nota'), findsNothing);
    expect(pulsante('Elimina la nota'), findsOneWidget);
  });

  testWidgets('riscritta da Marco intanto: le due versioni, e «tienile tutte '
      'e due» fa una nota in più', (tester) async {
    await viaggio(tester, note: [wifi()]);
    await ambiente.monta(
      tester,
      const SchermataNota(notaId: 'wifi', viaggioId: 'v'),
    );
    ambiente.server.note.single
      ..['testo'] = 'Wifi\nIl router è dietro la tv'
      ..['versione'] = 2
      ..['modificato_da'] = marco;

    await tester.tap(pulsante('Cambia la nota'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(FoglioNota),
        matching: find.byType(EditableText),
      ),
      'Wifi\ncasa-alfama-24',
    );
    await tester.pump();
    await tester.tap(pulsante('Salva'));
    await aspetta(tester);
    await aspetta(tester);

    expect(find.text('Due versioni'), findsOneWidget);
    expect(find.text('DI MARCO'), findsOneWidget);
    expect(find.text('Wifi\ncasa-alfama-24'), findsOneWidget);
    expect(find.text('Wifi\nIl router è dietro la tv'), findsOneWidget);
    expect(
      find.text('Con «tutte e due» la tua diventa una nota in più.'),
      findsOneWidget,
    );

    await tester.tap(pulsante('Tienile tutte e due'));
    await aspetta(tester);

    expect(find.text('Due versioni'), findsNothing);
    expect(find.text('Cambia la nota'), findsOneWidget);
    expect(
      ambiente.server.note.map((n) => n['testo']),
      unorderedEquals([
        'Wifi\nIl router è dietro la tv',
        'Wifi\ncasa-alfama-24',
      ]),
    );
    expect(
      await eventi(tester),
      contains('conflitto_risolto {"tipo":"nota","scelta":"entrambe"}'),
    );
  });
}
