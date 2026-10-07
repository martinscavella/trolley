import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dati/acquisizione.dart';
import 'package:trolley/dati/errori.dart';
import 'package:trolley/misurazione/misurazione.dart';
import 'package:trolley/schermate/i_tuoi_dati.dart';
import 'package:trolley/schermate/impostazioni.dart';

import '../aiuti.dart';

/// I tuoi dati e chiudere l'account (U.1; tela, 99–102): dal profilo, il
/// file dei dati consegnato e poi buttato, che cosa succede chiudendo con i
/// numeri veri, la chiusura confermata, senza rete.
void main() {
  late Ambiente ambiente;

  setUp(() => ambiente = Ambiente());
  tearDown(() => ambiente.chiudi());

  const marco = '22222222-2222-4222-8222-222222222222';

  /// Porto con Marco, di cui si è responsabili; Berlino da soli.
  Future<void> viaggi(WidgetTester tester) async {
    ambiente.server
      ..viaggi.addAll([
        rigaViaggio(
          'porto',
          stato: 'definito',
          inizio: '2099-10-10',
          fine: '2099-10-12',
        ),
        rigaViaggio(
          'berlino',
          stato: 'definito',
          citta: 'Berlino',
          paese: 'DE',
          inizio: '2099-11-02',
          fine: '2099-11-03',
        ),
      ])
      ..partecipazioni.addAll([
        rigaPartecipazione('porto'),
        rigaPartecipazione('porto', utente: marco, ruolo: 'partecipante'),
        rigaPartecipazione('berlino'),
      ])
      ..utenti.add({
        'id': marco,
        'nome': 'Marco',
        'versione': 1,
        'eliminato_il': null,
      });
    await ambiente.accedi(tester: tester);
    await tester.runAsync(ambiente.archivio.aggiornaCopia);
  }

  Future<void> unDocumento(WidgetTester tester) async {
    final file = File('${ambiente.cartella.path}/biglietto.pdf')
      ..writeAsStringSync('contenuto');
    await tester.runAsync(
      () => ambiente.documenti.aggiungi(
        viaggioId: 'porto',
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
  }

  /// Lascia arrivare le scritture: il database e il disco veri non avanzano
  /// nel tempo finto dei test. Dopo la chiusura il pulsante gira finché l'app
  /// non torna all'accesso, che qui non c'è: [quiete] falso non aspetta che
  /// si fermi.
  Future<void> aspetta(WidgetTester tester, {bool quiete = true}) async {
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
    if (quiete) await tester.pumpAndSettle();
  }

  /// I nomi degli eventi: quelli ancora sul telefono e quelli già partiti.
  Future<List<String>> eventi(WidgetTester tester) async => [
    for (final e in await ambiente.eventi(tester)) e.nome,
    for (final r in ambiente.server.chiamate('POST', '/rest/v1/evento'))
      for (final e in (jsonDecode(r.body) as List).cast<Map<String, dynamic>>())
        e['nome'] as String,
  ];

  Finder scritto(String testo) =>
      find.textContaining(testo, findRichText: true);

  testWidgets('dal profilo, sotto Privacy, «I tuoi dati» (tela, 99 e 100)', (
    tester,
  ) async {
    await ambiente.accedi(tester: tester);
    await ambiente.monta(tester, const SchermataImpostazioni());
    await aspetta(tester);

    await tester.scrollUntilVisible(find.text('I tuoi dati'), 200);
    expect(find.text("Scaricarli, o chiudere l'account"), findsOneWidget);
    await tester.tap(find.text('I tuoi dati'));
    await aspetta(tester);
    expect(find.byType(SchermataITuoiDati), findsOneWidget);
    expect(find.text('Scarica i tuoi dati'), findsOneWidget);
    expect(find.text("Chiudi l'account"), findsOneWidget);
  });

  testWidgets('scaricare consegna un file con i dati, lo misura e poi lo '
      'butta', (tester) async {
    await viaggi(tester);
    String? letto;
    String? percorso;
    await ambiente.monta(
      tester,
      SchermataITuoiDati(
        cartella: () async => ambiente.cartella,
        consegna: (file, _) async {
          percorso = file.path;
          letto = file.readAsStringSync();
          return true;
        },
      ),
    );
    await tester.tap(find.text('Scarica i tuoi dati'));
    await aspetta(tester);

    expect(letto, contains('"formato": "trolley.dati"'));
    expect(letto, contains('"nome": "Giulia"'));
    expect(File(percorso!).existsSync(), isFalse);
    expect(await eventi(tester), contains(Eventi.datiEsportati));
  });

  testWidgets('chiuso il foglio senza scegliere, non si misura', (
    tester,
  ) async {
    await viaggi(tester);
    await ambiente.monta(
      tester,
      SchermataITuoiDati(
        cartella: () async => ambiente.cartella,
        consegna: (_, _) async => false,
      ),
    );
    await tester.tap(find.text('Scarica i tuoi dati'));
    await aspetta(tester);

    expect(await eventi(tester), isNot(contains(Eventi.datiEsportati)));
  });

  testWidgets('chiudere l\'account dice prima che cosa succede, con i numeri '
      'veri (tela, 101)', (tester) async {
    await viaggi(tester);
    await unDocumento(tester);
    await ambiente.monta(
      tester,
      SchermataChiudiAccount(
        cartella: () async => ambiente.cartella,
        consegna: (_, _) async => true,
      ),
    );
    await aspetta(tester);

    expect(find.text("Chiudere l'account?"), findsOneWidget);
    expect(scritto("Il tuo profilo e l'accesso si cancellano"), findsOneWidget);
    expect(
      scritto('Un viaggio in cui sei da solo si cancella'),
      findsOneWidget,
    );
    expect(scritto('Da Porto esci'), findsOneWidget);
    expect(scritto('Le spese restano nei saldi'), findsOneWidget);
    expect(
      scritto('A Porto eri responsabile: il ruolo passa a Marco.'),
      findsOneWidget,
    );
    expect(
      scritto('Il documento su questo telefono si cancella.'),
      findsOneWidget,
    );
    expect(scritto('fatta senza rete'), findsNothing);
  });

  testWidgets('confermato, l\'account si chiude: via i documenti, la copia e '
      'l\'accesso (tela, 102)', (tester) async {
    await viaggi(tester);
    await unDocumento(tester);
    await ambiente.monta(
      tester,
      SchermataChiudiAccount(
        cartella: () async => ambiente.cartella,
        consegna: (_, _) async => true,
      ),
    );
    await aspetta(tester);

    await tester.scrollUntilVisible(find.text("Chiudi l'account"), 200);
    await tester.tap(find.text("Chiudi l'account"));
    await tester.pumpAndSettle();
    expect(scritto('Non si può annullare'), findsOneWidget);
    await tester.tap(find.text('Chiudi'));
    await aspetta(tester, quiete: false);

    expect(ambiente.server.chiusoConMisurazione, isTrue);
    final db = ambiente.db;
    expect(await tester.runAsync(() => db.select(db.viaggi).get()), isEmpty);
    expect(await tester.runAsync(() => db.select(db.documenti).get()), isEmpty);
    expect(
      Directory('${ambiente.cartella.path}/app/documenti/porto')
          .listSync()
          .whereType<File>(),
      isEmpty,
    );
    expect(ambiente.server.supabase.auth.currentUser, isNull);
  });

  testWidgets('annullato, non succede niente', (tester) async {
    await viaggi(tester);
    await ambiente.monta(
      tester,
      SchermataChiudiAccount(
        cartella: () async => ambiente.cartella,
        consegna: (_, _) async => true,
      ),
    );
    await aspetta(tester);

    await tester.scrollUntilVisible(find.text("Chiudi l'account"), 200);
    await tester.tap(find.text("Chiudi l'account"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annulla'));
    await aspetta(tester);

    expect(ambiente.server.chiusoConMisurazione, isNull);
    expect(ambiente.server.supabase.auth.currentUser, isNotNull);
  });

  testWidgets('senza rete, scaricare e chiudere si spengono e dicono '
      'perché', (tester) async {
    await viaggi(tester);
    ambiente.rete.disponibile = false;
    await ambiente.monta(
      tester,
      SchermataITuoiDati(
        cartella: () async => ambiente.cartella,
        consegna: (_, _) async => true,
      ),
    );
    expect(find.text(motivoSenzaRete), findsOneWidget);
    await tester.tap(find.text('Scarica i tuoi dati'));
    await aspetta(tester);
    expect(
      ambiente.server.chiamate('POST', '/rest/v1/rpc/i_miei_dati'),
      isEmpty,
    );

    await tester.ensureVisible(find.text("Chiudi l'account"));
    await tester.pump();
    await tester.tap(find.text("Chiudi l'account"));
    await aspetta(tester);
    await tester.scrollUntilVisible(find.text("Chiudi l'account"), 200);
    expect(find.text(motivoSenzaRete), findsOneWidget);
    await tester.tap(find.text("Chiudi l'account"));
    await aspetta(tester);
    expect(scritto('Non si può annullare'), findsNothing);
  });
}
