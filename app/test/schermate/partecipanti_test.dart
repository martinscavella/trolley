import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dati/acquisizione.dart';
import 'package:trolley/dominio/calendario.dart';
import 'package:trolley/schermate/partecipanti.dart';
import 'package:trolley/schermate/viaggi.dart';
import 'package:trolley/schermate/viaggio.dart';

import '../aiuti.dart';

/// Chi c'è (fase 2.1; tela, 29–33): la riga nel viaggio, l'elenco, i poteri
/// di chi è responsabile, uscire, il primo minuto di chi entra da un invito,
/// il viaggio lasciato nell'elenco.
void main() {
  late Ambiente ambiente;

  setUp(() => ambiente = Ambiente());
  tearDown(() => ambiente.chiudi());

  const marco = '22222222-2222-4222-8222-222222222222';
  final oggi = soloData(DateTime.now());
  String fra(int giorni) => scriviData(oggi.add(Duration(days: giorni)));

  /// Un viaggio a Porto fra un mese. Con [conMarco] c'è anche lui; con
  /// [invitato] è Marco il responsabile, e chi è entrato partecipa.
  Future<void> viaggio(
    WidgetTester tester, {
    bool conMarco = true,
    bool invitato = false,
  }) async {
    ambiente.server
      ..viaggi.add(
        rigaViaggio('v', stato: 'definito', inizio: fra(30), fine: fra(32)),
      )
      ..giorni.add(rigaGiorno('v', fra(30), '10:00:00', '24:00:00'))
      ..partecipazioni.add(
        rigaPartecipazione('v', ruolo: invitato ? 'partecipante' : 'creatore'),
      );
    if (conMarco) {
      ambiente.server
        ..partecipazioni.add(
          rigaPartecipazione(
            'v',
            utente: marco,
            ruolo: invitato ? 'creatore' : 'partecipante',
          ),
        )
        ..utenti.add({
          'id': marco,
          'nome': 'Marco',
          'versione': 1,
          'eliminato_il': null,
        });
    }
    await ambiente.accedi(tester: tester);
    await tester.runAsync(ambiente.archivio.aggiornaCopia);
  }

  /// Lascia arrivare le scritture: il database e il disco veri non avanzano
  /// nel tempo finto dei test.
  Future<void> aspetta(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Map<String, Object?> mia() => ambiente.server.partecipazioni.singleWhere(
    (p) => p['utente_id'] == idDiProva,
  );
  Map<String, Object?> diMarco() => ambiente.server.partecipazioni.singleWhere(
    (p) => p['utente_id'] == marco,
  );

  testWidgets('da soli, il viaggio dice «Solo tu, per ora»; l\'elenco non '
      'offre di uscire a chi resterebbe senza nessuno', (tester) async {
    await viaggio(tester, conMarco: false);
    await ambiente.monta(tester, const SchermataViaggio(viaggioId: 'v'));
    await aspetta(tester);

    expect(find.text('Chi c\'è'), findsOneWidget);
    expect(find.text('Solo tu, per ora'), findsOneWidget);
    expect(find.text('Invita chi viene con te'), findsOneWidget);

    await tester.tap(find.text('Solo tu, per ora'));
    await aspetta(tester);
    expect(find.byType(SchermataPartecipanti), findsOneWidget);
    expect(find.text('Responsabile del viaggio'), findsOneWidget);
    expect(find.text('Esci dal viaggio'), findsNothing);
  });

  testWidgets('chi è responsabile toglie qualcuno, dopo una conferma: passa '
      'fra chi non c\'è più', (tester) async {
    await viaggio(tester);
    await ambiente.monta(tester, const SchermataViaggio(viaggioId: 'v'));
    await aspetta(tester);
    expect(find.text('Marco e tu'), findsOneWidget);
    expect(find.text('2 persone · tu sei responsabile'), findsOneWidget);

    await tester.tap(find.text('Marco e tu'));
    await aspetta(tester);
    await tester.tap(find.byTooltip('Cosa puoi fare con Marco'));
    await tester.pumpAndSettle();
    expect(find.text('Rendi Marco responsabile'), findsOneWidget);
    await tester.tap(find.text('Togli Marco dal viaggio'));
    await tester.pumpAndSettle();
    expect(find.text('Togliere Marco dal viaggio?'), findsOneWidget);
    await tester.tap(find.text('Togli').last);
    await aspetta(tester);

    expect(diMarco()['stato'], 'rimosso');
    expect(find.text('NON CI SONO PIÙ'), findsOneWidget);
    expect(
      find.text('Quello che ha aggiunto resta nel viaggio'),
      findsOneWidget,
    );
  });

  testWidgets('chi è responsabile, per uscire, sceglie prima a chi passare il '
      'ruolo', (tester) async {
    await viaggio(tester);
    await ambiente.monta(tester, const SchermataPartecipanti(viaggioId: 'v'));
    await aspetta(tester);

    await tester.scrollUntilVisible(find.text('Esci dal viaggio'), 200);
    await tester.tap(find.text('Esci dal viaggio'));
    await tester.pumpAndSettle();
    expect(find.text('Chi sarà responsabile?'), findsOneWidget);
    await tester.tap(find.text('Marco').last);
    await aspetta(tester);
    expect(find.text('Uscire da «Porto»?'), findsOneWidget);
    expect(find.textContaining('Marco sarà responsabile'), findsOneWidget);
    await tester.tap(find.text('Esci').last);
    await aspetta(tester);

    expect(diMarco()['ruolo'], 'creatore');
    expect(mia()['stato'], 'uscito');
    expect(
      await tester.runAsync(() => ambiente.archivio.osservaViaggio('v').first),
      isNull,
    );
  });

  testWidgets('chi partecipa esce: la conferma dice che i suoi documenti si '
      'cancellano dal telefono, e dopo non ci sono più', (tester) async {
    await viaggio(tester, invitato: true);
    final file = File('${ambiente.cartella.path}/biglietto.pdf')
      ..writeAsStringSync('contenuto');
    await tester.runAsync(
      () => ambiente.documenti.aggiungi(
        viaggioId: 'v',
        giornoId: null,
        ora: null,
        nome: 'Biglietto',
        sorgente: FileAcquisito(
          percorso: file.path,
          sorgente: Sorgente.file,
          nome: 'biglietto.pdf',
        ),
      ),
    );
    await ambiente.monta(tester, const SchermataPartecipanti(viaggioId: 'v'));
    await aspetta(tester);
    // Chi partecipa non ha «…» sugli altri.
    expect(find.byTooltip('Cosa puoi fare con Marco'), findsNothing);

    await tester.scrollUntilVisible(find.text('Esci dal viaggio'), 200);
    await tester.tap(find.text('Esci dal viaggio'));
    await aspetta(tester);
    expect(
      find.textContaining(
        'Il tuo documento di questo viaggio si cancella da questo telefono.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Esci').last);
    await aspetta(tester);

    expect(mia()['stato'], 'uscito');
    expect(
      await tester.runAsync(() => ambiente.documenti.osserva('v').first),
      isEmpty,
    );
  });

  testWidgets('senza rete l\'elenco si legge, e i gesti che vogliono la rete '
      'lo dicono prima', (tester) async {
    await viaggio(tester, invitato: true);
    ambiente.rete.disponibile = false;
    await ambiente.monta(tester, const SchermataPartecipanti(viaggioId: 'v'));
    await aspetta(tester);

    expect(find.text('Marco'), findsOneWidget);
    expect(
      find.text('Gli inviti ancora in sospeso si vedono con la connessione.'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(find.text('Esci dal viaggio'), 200);
    expect(find.text('Serve la connessione'), findsNWidgets(2));
    await tester.tap(find.text('Esci dal viaggio'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Uscire da'), findsNothing);
  });

  testWidgets('gli inviti in sospeso si vedono e si ritirano', (tester) async {
    await viaggio(tester);
    await tester.runAsync(() => ambiente.archivio.creaInvito('v'));
    await ambiente.monta(tester, const SchermataPartecipanti(viaggioId: 'v'));
    await aspetta(tester);

    expect(
      find.textContaining(
        'Un link d\'invito ancora valido.',
        findRichText: true,
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Ritira il link'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ritira').last);
    await aspetta(tester);

    expect(ambiente.server.inviti.single['eliminato_il'], isNotNull);
    expect(
      find.textContaining('ancora valido', findRichText: true),
      findsNothing,
    );
  });

  testWidgets('chi entra da un invito trova il benvenuto con tre cose sue da '
      'fare, e la × lo chiude', (tester) async {
    await viaggio(tester, invitato: true);
    await tester.runAsync(() => ambiente.archivio.segnaBenvenuto('v'));
    await ambiente.monta(tester, const SchermataViaggio(viaggioId: 'v'));
    await aspetta(tester);

    expect(find.text('Sei dentro!'), findsOneWidget);
    expect(
      find.textContaining('Sei nel viaggio a Porto con Marco'),
      findsOneWidget,
    );
    expect(find.text('Il tuo biglietto'), findsOneWidget);
    expect(find.text('La tua prima spesa'), findsOneWidget);
    expect(find.text('Le tue cose da portare'), findsOneWidget);

    await tester.tap(find.byTooltip('Chiudi il benvenuto'));
    await aspetta(tester);
    expect(find.text('Sei dentro!'), findsNothing);
    expect(find.text('2 persone · Marco è responsabile'), findsOneWidget);
  });

  testWidgets('nell\'elenco, il viaggio da cui ti hanno tolto lo dice; «Ho '
      'capito» toglie l\'avviso', (tester) async {
    await viaggio(tester, invitato: true);
    mia()['stato'] = 'rimosso';
    await tester.runAsync(ambiente.archivio.aggiornaCopia);
    await ambiente.monta(tester, SchermataViaggi(onCodice: (_) {}));
    await aspetta(tester);

    expect(
      find.textContaining('Non fai più parte di «Porto».', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Chi ne è responsabile ti ha tolto',
        findRichText: true,
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Ho capito'));
    await aspetta(tester);
    expect(
      find.textContaining('Non fai più parte', findRichText: true),
      findsNothing,
    );
  });

  testWidgets('i propri documenti di un viaggio lasciato restano finché non '
      'li elimini, dopo una conferma', (tester) async {
    await viaggio(tester, invitato: true);
    final file = File('${ambiente.cartella.path}/biglietto.pdf')
      ..writeAsStringSync('contenuto');
    await tester.runAsync(
      () => ambiente.documenti.aggiungi(
        viaggioId: 'v',
        giornoId: null,
        ora: null,
        nome: 'Biglietto',
        sorgente: FileAcquisito(
          percorso: file.path,
          sorgente: Sorgente.file,
          nome: 'biglietto.pdf',
        ),
      ),
    );
    mia()['stato'] = 'rimosso';
    await tester.runAsync(ambiente.archivio.aggiornaCopia);
    await ambiente.monta(tester, SchermataViaggi(onCodice: (_) {}));
    await aspetta(tester);

    expect(
      find.textContaining(
        'Su questo telefono resta un tuo documento di quel viaggio.',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(find.text('Ho capito'), findsNothing);
    await tester.tap(find.text('Eliminalo'));
    await tester.pumpAndSettle();
    expect(find.text('Eliminare il documento di «Porto»?'), findsOneWidget);
    await tester.tap(find.text('Elimina').last);
    await aspetta(tester);

    expect(
      await tester.runAsync(() => ambiente.documenti.osserva('v').first),
      isEmpty,
    );
    expect(
      find.textContaining('Non fai più parte', findRichText: true),
      findsNothing,
    );
  });

  test('chi c\'è, in una riga', () {
    expect(chiCe([]), 'Solo tu, per ora');
    expect(chiCe(['Marco']), 'Marco e tu');
    expect(chiCe(['Giulia', 'Marco']), 'Giulia, Marco e tu');
    expect(
      chiCe(['Giulia', 'Marco', 'Sara', 'Luca']),
      'Giulia, Marco e altre 3 persone',
    );
  });
}
