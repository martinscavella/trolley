import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/aspetto/elementi.dart';
import 'package:trolley/schermate/cose.dart';
import 'package:trolley/schermate/partecipanti.dart';

import '../aiuti.dart';

/// La lista del viaggio (fase 2.4; tela, 42–44): con un compagno le liste
/// sono due, ogni voce del viaggio dice chi la porta, nella voce si sceglie
/// chi la porta e la si sposta, e chi lascia il viaggio libera le sue voci
/// con un avviso.
void main() {
  late Ambiente ambiente;

  const marco = '22222222-2222-4222-8222-222222222222';
  const luca = '33333333-3333-4333-8333-333333333333';

  setUp(() => ambiente = Ambiente());
  tearDown(() => ambiente.chiudi());

  /// Porto, con Marco; Luca c'era ed è uscito. Con [invitato] è Marco il
  /// responsabile, e chi è entrato partecipa.
  Future<void> viaggio(WidgetTester tester, {bool invitato = false}) async {
    Map<String, Object?> utente(String id, String nome) => {
      'id': id,
      'nome': nome,
      'versione': 1,
      'eliminato_il': null,
    };
    ambiente.server
      ..viaggi.add(rigaViaggio('v', citta: 'Porto', paese: 'PT'))
      ..partecipazioni.addAll([
        rigaPartecipazione('v', ruolo: invitato ? 'partecipante' : 'creatore'),
        rigaPartecipazione(
          'v',
          utente: marco,
          ruolo: invitato ? 'creatore' : 'partecipante',
        ),
        rigaPartecipazione(
          'v',
          utente: luca,
          ruolo: 'partecipante',
          stato: 'uscito',
        ),
      ])
      ..utenti.addAll([utente(marco, 'Marco'), utente(luca, 'Luca')])
      ..voci.addAll([
        rigaDiVoce(
          'adattatore',
          viaggio: 'v',
          testo: 'Adattatore tipo A',
          quantita: 2,
          tipo: 'viaggio',
          proprietario: marco,
          assegnatoA: marco,
          creatoDa: marco,
          creatoIl: '2026-10-04T09:00:00Z',
        ),
        rigaDiVoce(
          'ombrello',
          viaggio: 'v',
          testo: 'Ombrello',
          tipo: 'viaggio',
          proprietario: marco,
          creatoDa: marco,
          creatoIl: '2026-10-04T09:01:00Z',
        ),
        rigaDiVoce(
          'crema',
          viaggio: 'v',
          testo: 'Crema solare',
          tipo: 'viaggio',
          proprietario: luca,
          lasciataDa: luca,
          creatoDa: luca,
          creatoIl: '2026-10-04T09:03:00Z',
        ),
      ]);
    // Chi è appena entrato non ha ancora niente di suo.
    if (!invitato) {
      ambiente.server.voci.addAll([
        rigaDiVoce(
          'powerbank',
          viaggio: 'v',
          testo: 'Powerbank',
          tipo: 'viaggio',
          assegnatoA: idDiProva,
          creatoIl: '2026-10-04T09:02:00Z',
        ),
        rigaDiVoce(
          'spazzolino',
          viaggio: 'v',
          testo: 'Spazzolino',
          creatoIl: '2026-10-04T09:04:00Z',
        ),
      ]);
    }
    await ambiente.accedi(tester: tester);
    await tester.runAsync(ambiente.archivio.aggiornaCopia);
  }

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

  Finder pulsante(String etichetta) => find.descendant(
    of: find.byType(PulsanteGrande),
    matching: find.text(etichetta),
  );

  Map<String, Object?> sulServer(String id) =>
      ambiente.server.voci.singleWhere((v) => v['id'] == id);

  testWidgets('con un compagno le liste sono due; quella del viaggio dice chi '
      'porta cosa, e chi ha lasciato il viaggio', (tester) async {
    await viaggio(tester);
    await ambiente.monta(tester, const SchermataCose(viaggioId: 'v'));

    expect(find.text('Del viaggio · 4'), findsOneWidget);
    expect(find.text('Mie · 1'), findsOneWidget);
    expect(find.text('DA PORTARE · 4'), findsOneWidget);
    expect(find.text('Marco'), findsOneWidget);
    expect(find.text('Tu'), findsOneWidget);
    expect(find.text('LIBERA'), findsNWidgets(2));
    expect(find.text('Spazzolino'), findsNothing);
    expect(
      find.bySemanticsLabel(
        RegExp('^Cambia Adattatore tipo A × 2, la porta Marco'),
      ),
      findsOneWidget,
    );
    expect(find.text('Aggiungi alla lista del viaggio…'), findsOneWidget);

    // Luca è uscito: la crema che portava è tornata libera (tela, 44).
    expect(
      find.textContaining('Luca ha lasciato il viaggio:', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Crema solare, che portava, è tornata libera.',
        findRichText: true,
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Ho capito'));
    await aspetta(tester);
    expect(
      find.textContaining('Luca ha lasciato il viaggio:', findRichText: true),
      findsNothing,
    );

    await tester.tap(find.text('Mie · 1'));
    await tester.pumpAndSettle();
    expect(find.text('Spazzolino'), findsOneWidget);
    expect(find.text('Ombrello'), findsNothing);
    expect(find.text('0 di 1'), findsOneWidget);
    expect(find.text('Aggiungi alle tue cose…'), findsOneWidget);
  });

  testWidgets('la voce nuova va nella lista che si guarda', (tester) async {
    await viaggio(tester);
    await ambiente.monta(tester, const SchermataCose(viaggioId: 'v'));

    await tester.enterText(find.byType(TextField).last, 'Mazzo di carte');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await aspetta(tester);

    final nuova = ambiente.server.voci.last;
    expect(nuova['testo'], 'Mazzo di carte');
    expect(nuova['tipo'], 'viaggio');
    expect(nuova['assegnato_a'], isNull);
    expect(find.text('Del viaggio · 5'), findsOneWidget);

    await tester.tap(find.text('Mie · 1'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Medicine');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await aspetta(tester);
    expect(ambiente.server.voci.last['tipo'], 'personale');
    expect(find.text('Mie · 2'), findsOneWidget);
  });

  testWidgets('nella voce si dice chi la porta; prenderla è il primo '
      'contributo di chi è stato invitato', (tester) async {
    await viaggio(tester, invitato: true);
    await ambiente.monta(tester, const SchermataCose(viaggioId: 'v'));

    await tester.tap(find.bySemanticsLabel(RegExp('^Cambia Ombrello, libera')));
    await tester.pumpAndSettle();
    expect(find.text('Aggiunta da Marco'), findsOneWidget);
    expect(find.text('Chi la porta?'), findsOneWidget);
    expect(find.text('Nessuno'), findsOneWidget);
    // Luca non c'è più: non gli si dà niente.
    expect(find.text('Luca'), findsNothing);
    expect(
      find.text(
        'La vedono tutti nel viaggio. Le tue cose che non riguardano gli '
        'altri vanno in «Mie».',
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(of: find.byType(Gettone), matching: find.text('Tu')),
    );
    await tester.pump();
    await tester.tap(pulsante('Salva'));
    await aspetta(tester);

    expect(find.text('La voce'), findsNothing);
    expect(sulServer('ombrello')['assegnato_a'], idDiProva);
    expect(find.text('LIBERA'), findsOneWidget);
    final registrati = await eventi(tester);
    expect(
      registrati.singleWhere((e) => e.$1 == 'primo_contributo_invitato').$2,
      {'viaggio_id': 'v', 'tipo': 'voce'},
    );
    expect(
      registrati.singleWhere((e) => e.$1 == 'funzione_usata_nel_viaggio').$2,
      {'viaggio_id': 'v', 'funzione': 'liste'},
    );
  });

  testWidgets('una voce libera si sposta fra le proprie; quella che porta '
      'Marco no', (tester) async {
    await viaggio(tester);
    await ambiente.monta(tester, const SchermataCose(viaggioId: 'v'));

    await tester.tap(
      find.bySemanticsLabel(RegExp('^Cambia Adattatore tipo A × 2')),
    );
    await tester.pumpAndSettle();
    expect(pulsante('Spostala nella tua lista'), findsNothing);
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel(RegExp('^Cambia Ombrello, libera')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(pulsante('Spostala nella tua lista'));
    await tester.tap(pulsante('Spostala nella tua lista'));
    await aspetta(tester);

    expect(find.text('La voce'), findsNothing);
    expect(sulServer('ombrello')['eliminato_il'], isNotNull);
    final nuova = ambiente.server.voci.last;
    expect(nuova['testo'], 'Ombrello');
    expect(nuova['tipo'], 'personale');
    expect(find.text('Del viaggio · 3'), findsOneWidget);
    expect(find.text('Mie · 2'), findsOneWidget);
  });

  testWidgets('senza rete la voce si legge, ma chi la porta e lo spostamento '
      'lo dicono prima', (tester) async {
    await viaggio(tester);
    ambiente.rete.disponibile = false;
    await ambiente.monta(tester, const SchermataCose(viaggioId: 'v'));

    await tester.tap(find.bySemanticsLabel(RegExp('^Cambia Ombrello, libera')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(Gettone), matching: find.text('Tu')),
    );
    await tester.pump();
    expect(find.text('Niente da salvare'), findsNothing);
    expect(find.text('Serve la connessione'), findsWidgets);
    await tester.ensureVisible(pulsante('Spostala nella tua lista'));
    await tester.tap(pulsante('Spostala nella tua lista'));
    await aspetta(tester);
    expect(find.text('La voce'), findsOneWidget);
    expect(
      ambiente.server.chiamate('POST', '/rest/v1/rpc/sposta_voce'),
      isEmpty,
    );
  });

  testWidgets('togliere chi porta qualcosa lo dice prima, e le sue voci '
      'tornano libere', (tester) async {
    await viaggio(tester);
    await ambiente.monta(tester, const SchermataPartecipanti(viaggioId: 'v'));
    await aspetta(tester);

    await tester.tap(find.byTooltip('Cosa puoi fare con Marco'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Togli Marco dal viaggio'));
    await aspetta(tester);
    expect(
      find.textContaining(
        'Porta una cosa della lista del viaggio, che tornerà libera.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Togli').last);
    await aspetta(tester);

    expect(sulServer('adattatore')['assegnato_a'], isNull);
    expect(sulServer('adattatore')['lasciata_da'], marco);
  });
}
