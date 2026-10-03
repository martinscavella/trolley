import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/aspetto/elementi.dart';
import 'package:trolley/dati/acquisizione.dart';
import 'package:trolley/dati/database.dart';
import 'package:trolley/dominio/calendario.dart';
import 'package:trolley/schermate/documenti.dart';
import 'package:trolley/schermate/documento.dart';
import 'package:trolley/schermate/viaggio.dart';

import '../aiuti.dart';

/// I documenti (fase 1.3): stanno solo sul telefono, si aprono con un tocco
/// dal viaggio in corso, l'elenco mette in cima quelli di oggi, e aggiungerli
/// si misura senza dire quali sono.
void main() {
  late Ambiente ambiente;

  setUp(() => ambiente = Ambiente());
  tearDown(() => ambiente.chiudi());

  final oggi = soloData(DateTime.now());
  String fra(int giorni) => scriviData(oggi.add(Duration(days: giorni)));

  /// Un viaggio di tre giorni che comincia fra [inizio] giorni: g1, g2, g3.
  Future<void> viaggio(WidgetTester tester, {int inizio = 30}) async {
    ambiente.server
      ..viaggi.add(
        rigaViaggio(
          'v',
          stato: 'definito',
          inizio: fra(inizio),
          fine: fra(inizio + 2),
        ),
      )
      ..partecipazioni.add(rigaPartecipazione('v'))
      ..giorni.addAll([
        rigaGiorno('v', fra(inizio), '10:00:00', '24:00:00', id: 'g1'),
        rigaGiorno('v', fra(inizio + 1), '00:00:00', '24:00:00', id: 'g2'),
        rigaGiorno('v', fra(inizio + 2), '00:00:00', '18:00:00', id: 'g3'),
      ]);
    await tester.runAsync(ambiente.archivio.aggiornaCopia);
  }

  /// Un documento già sul telefono, aggiunto per davvero dall'archivio.
  Future<Documento> documento(
    WidgetTester tester,
    String nome, {
    String? giorno,
    Duration? ora,
    String file = 'documento.pdf',
  }) async => (await tester.runAsync(() async {
    final arrivo = File('${ambiente.cartella.path}/$nome-$file')
      ..writeAsStringSync('contenuto');
    return ambiente.documenti.aggiungi(
      viaggioId: 'v',
      giornoId: giorno,
      ora: ora,
      nome: nome,
      sorgente: FileAcquisito(
        percorso: arrivo.path,
        sorgente: Sorgente.file,
        nome: file,
      ),
    );
  }))!;

  /// Lascia lavorare il disco: le scritture vere non avanzano nel tempo finto
  /// dei test.
  Future<void> aspettaIlDisco(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
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

  testWidgets('nel viaggio in corso, i documenti di oggi stanno nella '
      'schermata del viaggio e si aprono con un tocco', (tester) async {
    // Il viaggio è cominciato ieri: oggi è il secondo giorno, g2.
    await viaggio(tester, inizio: -1);
    await documento(tester, 'Passaporto');
    await documento(
      tester,
      'Biglietti della Livraria Lello',
      giorno: 'g2',
      ora: const Duration(hours: 10),
    );
    await documento(tester, 'Ritorno', giorno: 'g3');

    await ambiente.monta(tester, const SchermataViaggio(viaggioId: 'v'));

    expect(find.text('Documenti'), findsOneWidget);
    expect(find.text('Tutti · 3'), findsOneWidget);
    // Solo quelli di oggi.
    expect(find.text('Biglietti della Livraria Lello'), findsOneWidget);
    expect(find.text('10:00'), findsOneWidget);
    expect(find.text('Passaporto'), findsNothing);
    expect(find.text('Ritorno'), findsNothing);

    await tester.tap(find.text('Biglietti della Livraria Lello'));
    await aspettaIlDisco(tester);

    expect(find.byType(SchermataDocumento), findsOneWidget);
    expect(find.text('Oggi alle 10:00'), findsOneWidget);
    expect(
      find.text('Scorri per la pagina dopo, allarga con due dita.'),
      findsOneWidget,
    );
  });

  testWidgets('l\'elenco mette in cima oggi, poi domani, poi tutto il '
      'viaggio, poi gli altri giorni', (tester) async {
    await viaggio(tester, inizio: 0);
    await documento(tester, 'Treno', giorno: 'g3');
    await documento(tester, 'Passaporto');
    await documento(tester, 'Museo', giorno: 'g2');
    await documento(
      tester,
      'Carta d\'imbarco',
      giorno: 'g1',
      ora: const Duration(hours: 7, minutes: 5),
    );

    await ambiente.monta(tester, const SchermataDocumenti(viaggioId: 'v'));

    double y(String testo) => tester.getTopLeft(find.text(testo)).dy;
    expect(find.textContaining('OGGI · '), findsOneWidget);
    expect(find.textContaining('DOMANI · '), findsOneWidget);
    expect(find.text('PER TUTTO IL VIAGGIO'), findsOneWidget);
    expect(y('Carta d\'imbarco'), lessThan(y('Museo')));
    expect(y('Museo'), lessThan(y('Passaporto')));
    expect(y('Passaporto'), lessThan(y('Treno')));
    // Da soli, non c'è niente da dire sui compagni.
    expect(find.textContaining('Solo tuoi'), findsNothing);
  });

  testWidgets('in un viaggio con altri dice che i loro documenti restano sui '
      'loro telefoni', (tester) async {
    ambiente.server
      ..partecipazioni.add({
        ...rigaPartecipazione('v'),
        'id': 'p-marco',
        'utente_id': 'marco',
        'ruolo': 'partecipante',
      })
      ..utenti.add({
        'id': 'marco',
        'nome': 'Marco',
        'versione': 1,
        'eliminato_il': null,
      });
    await viaggio(tester);

    await ambiente.monta(tester, const SchermataDocumenti(viaggioId: 'v'));

    // Anche con l'elenco vuoto: non deve sembrare un errore.
    expect(find.textContaining('Biglietti, prenotazioni, passaporto'),
        findsOneWidget);
    expect(find.textContaining('Solo tuoi, solo su questo telefono.'),
        findsOneWidget);
    expect(
      find.textContaining('Marco non li vedono, e i loro restano'),
      findsOneWidget,
    );
  });

  testWidgets('aggiungere da una scansione: il nome, il giorno, l\'avviso la '
      'prima volta; e si misura senza dire quale', (tester) async {
    await viaggio(tester);
    await ambiente.monta(tester, const SchermataDocumenti(viaggioId: 'v'));

    await tester.tap(pulsante('Aggiungi un documento'));
    await tester.pumpAndSettle();
    expect(find.text('Nuovo documento'), findsOneWidget);

    await tester.tap(find.text('Scansiona'));
    await aspettaIlDisco(tester);

    // La scansione non ha un nome da proporre: si chiede.
    expect(find.text('Scansione · 2 pagine'), findsOneWidget);
    expect(find.text('Dagli un nome, per ritrovarlo'), findsOneWidget);
    expect(find.textContaining('Resta solo su questo telefono.',
        findRichText: true), findsOneWidget);
    // Per tutto il viaggio non serve l'ora.
    expect(find.text('A che ora?'), findsNothing);

    await tester.enterText(find.byType(TextField), 'Carta d\'identità');
    await tester.pump();
    await tester.tap(find.text(_giornoCorto(oggi.add(const Duration(days: 31)))));
    await tester.pumpAndSettle();
    expect(find.text('A che ora?'), findsOneWidget);

    await tester.ensureVisible(pulsante('Salva'));
    await tester.tap(pulsante('Salva'));
    await aspettaIlDisco(tester);

    expect(find.text('Nuovo documento'), findsNothing);
    expect(find.text('Carta d\'identità'), findsOneWidget);
    expect(ambiente.acquisizione.chieste, [Sorgente.scansione]);
    expect(ambiente.acquisizione.pulizie, 1);

    final salvato = (await tester.runAsync(
      () => ambiente.db.select(ambiente.db.documenti).get(),
    ))!.single;
    expect(salvato.giornoId, 'g2');
    expect(salvato.sorgente, 'scansione');
    expect(ambiente.telefono.protetti, hasLength(1));

    final eventi = await ambiente.eventi(tester);
    final primo = eventi.singleWhere((e) => e.nome == 'primo_elemento_aggiunto');
    expect(jsonDecode(primo.proprieta), containsPair('tipo', 'documento'));
    final funzione = eventi.singleWhere(
      (e) => e.nome == 'funzione_usata_nel_viaggio',
    );
    expect(jsonDecode(funzione.proprieta), {
      'viaggio_id': 'v',
      'funzione': 'documenti',
    });
    // Azioni, mai contenuti: il nome non va da nessuna parte.
    for (final e in eventi) {
      expect(e.proprieta, isNot(contains('identità')));
    }
  });

  testWidgets('l\'avviso del telefono si dice una volta sola', (tester) async {
    await viaggio(tester);
    await tester.runAsync(ambiente.documenti.segnaAvvisoDato);
    await ambiente.monta(tester, const SchermataDocumenti(viaggioId: 'v'));

    await tester.tap(pulsante('Aggiungi un documento'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dai file'));
    await aspettaIlDisco(tester);

    // Dal file arriva anche il nome.
    expect(find.text('Carta imbarco'), findsOneWidget);
    expect(find.textContaining('Resta solo su questo telefono.',
        findRichText: true), findsNothing);
  });

  testWidgets('senza rete tutto funziona lo stesso, e l\'apertura si conta', (
    tester,
  ) async {
    await viaggio(tester);
    await documento(tester, 'Passaporto');
    ambiente.rete.disponibile = false;

    await ambiente.monta(tester, const SchermataDocumenti(viaggioId: 'v'));
    expect(find.text('Passaporto'), findsOneWidget);
    expect(find.text('Serve la connessione'), findsNothing);

    await tester.tap(pulsante('Aggiungi un documento'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dai file'));
    await aspettaIlDisco(tester);
    await tester.ensureVisible(pulsante('Salva'));
    await tester.tap(pulsante('Salva'));
    await aspettaIlDisco(tester);
    expect(find.text('Carta imbarco'), findsOneWidget);

    final eventi = await ambiente.eventi(tester);
    final apertura = eventi.firstWhere((e) => e.nome == 'apertura_senza_rete');
    expect(jsonDecode(apertura.proprieta), {
      'schermata': 'documenti',
      'mancante': null,
    });
  });

  testWidgets('un\'idea non ha documenti: servono le date', (tester) async {
    ambiente.server
      ..viaggi.add(rigaViaggio('v'))
      ..partecipazioni.add(rigaPartecipazione('v'));
    await tester.runAsync(ambiente.archivio.aggiornaCopia);

    await ambiente.monta(tester, const SchermataViaggio(viaggioId: 'v'));

    expect(find.text('Documenti'), findsNothing);
    expect(find.text('Aggiungi un documento'), findsNothing);
  });

  testWidgets('eliminare chiede conferma, poi toglie il file e la riga', (
    tester,
  ) async {
    await viaggio(tester);
    final doc = await documento(tester, 'Passaporto');
    final file = (await tester.runAsync(() => ambiente.documenti.file(doc)))!;

    await ambiente.monta(tester, const SchermataDocumenti(viaggioId: 'v'));
    await tester.tap(find.text('Passaporto'));
    await aspettaIlDisco(tester);

    await tester.tap(find.bySemanticsLabel('Altro: cambia o elimina'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elimina').last);
    await tester.pumpAndSettle();
    expect(find.text('Eliminare «Passaporto»?'), findsOneWidget);
    await tester.tap(find.text('Elimina').last);
    await aspettaIlDisco(tester);

    expect(find.byType(SchermataDocumento), findsNothing);
    expect(find.text('Passaporto'), findsNothing);
    expect(file.existsSync(), isFalse);
  });

  test('i nomi dei compagni si dicono come si dicono', () {
    expect(elencoNomi(['Marco']), 'Marco');
    expect(elencoNomi(['Marco', 'Giulia']), 'Marco e Giulia');
    expect(elencoNomi(['Marco', 'Giulia', 'Luca']), 'Marco, Giulia e Luca');
    expect(elencoNomi(['A', 'B', 'C', 'D']), 'Gli altri del viaggio');
    expect(elencoNomi(['']), 'Gli altri del viaggio');
  });
}

/// Come la scrive la capsula del giorno: `Sab 11`.
String _giornoCorto(DateTime d) {
  const giorni = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];
  return '${giorni[d.weekday - 1]} ${d.day}';
}
