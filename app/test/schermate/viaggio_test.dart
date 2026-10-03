import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/aspetto/elementi.dart';
import 'package:trolley/aspetto/formati.dart';
import 'package:trolley/dati/errori.dart';
import 'package:trolley/dominio/calendario.dart';
import 'package:trolley/dominio/periodo.dart';
import 'package:trolley/schermate/viaggio.dart';

import '../aiuti.dart';

void main() {
  late Ambiente ambiente;

  setUp(() => ambiente = Ambiente());
  tearDown(() => ambiente.chiudi());

  final oggi = soloData(DateTime.now());
  String fra(int giorni) => scriviData(oggi.add(Duration(days: giorni)));

  Future<void> sulServer(
    WidgetTester tester,
    Map<String, Object?> viaggio, {
    List<Map<String, Object?>> giorni = const [],
  }) async {
    ambiente.server.viaggi.add(viaggio);
    ambiente.server.partecipazioni.add(
      rigaPartecipazione(viaggio['id']! as String),
    );
    ambiente.server.giorni.addAll(giorni);
    await tester.runAsync(ambiente.archivio.aggiornaCopia);
  }

  Finder pulsante(String etichetta) => find.descendant(
    of: find.byType(PulsanteGrande),
    matching: find.text(etichetta),
  );

  testWidgets('un viaggio in programma mostra i suoi giorni, ciascuno col suo '
      'tempo', (tester) async {
    await sulServer(
      tester,
      rigaViaggio('v', stato: 'definito', inizio: fra(30), fine: fra(32)),
      giorni: [
        rigaGiorno('v', fra(30), '10:00:00', '24:00:00'),
        rigaGiorno('v', fra(31), '00:00:00', '24:00:00'),
        rigaGiorno('v', fra(32), '00:00:00', '18:00:00'),
      ],
    );
    await ambiente.monta(tester, const SchermataViaggio(viaggioId: 'v'));

    expect(find.text('IN PROGRAMMA'), findsOneWidget);
    // Sulla matrice del biglietto, quando si arriva e quando si riparte.
    expect(
      find.text('${dataBreve(oggi.add(const Duration(days: 30)))} · 10:00'),
      findsOneWidget,
    );
    expect(
      find.text('${dataBreve(oggi.add(const Duration(days: 32)))} · 18:00'),
      findsOneWidget,
    );
    // I giorni vengono dopo documenti e spese.
    await tester.scrollUntilVisible(
      find.text('Nessuna tappa · 18 h libere'),
      300,
    );
    expect(find.text('Giorni'), findsOneWidget);
    expect(find.text('Dalle 10:00'), findsOneWidget);
    expect(find.text('Tutto il giorno'), findsOneWidget);
    expect(find.text('Fino alle 18:00'), findsOneWidget);
    expect(find.text('Nessuna tappa · 14 h libere'), findsOneWidget);
    expect(find.text('Nessuna tappa · 24 h libere'), findsOneWidget);
  });

  testWidgets('in corso, il giorno di oggi si riconosce', (tester) async {
    await sulServer(
      tester,
      rigaViaggio('v', stato: 'definito', inizio: fra(-1), fine: fra(1)),
      giorni: [
        rigaGiorno('v', fra(-1), '10:00:00', '24:00:00'),
        rigaGiorno('v', fra(0), '00:00:00', '24:00:00'),
        rigaGiorno('v', fra(1), '00:00:00', '18:00:00'),
      ],
    );
    await ambiente.monta(tester, const SchermataViaggio(viaggioId: 'v'));

    expect(find.text('IN CORSO'), findsOneWidget);
    expect(find.text('GIORNO 2 DI 3'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Oggi, tutto il giorno'), 300);
    expect(find.text('Oggi, tutto il giorno'), findsOneWidget);
  });

  testWidgets('un\'idea col periodo passato chiede se è ancora un\'idea, e '
      'segna di averlo chiesto', (tester) async {
    final passato = MeseDi.di(aggiungiMesi(oggi, -2));
    await sulServer(tester, rigaViaggio('i', periodo: passato.testo));
    await ambiente.monta(tester, const SchermataViaggio(viaggioId: 'i'));

    expect(
      find.textContaining('Il periodo di questa idea è passato'),
      findsOneWidget,
    );
    expect(find.textContaining('andrà in archivio'), findsOneWidget);
    final sollecito = await tester.runAsync(
      () => (ambiente.db.select(
        ambiente.db.impostazioni,
      )..where((i) => i.chiave.equals('sollecito:i'))).getSingleOrNull(),
    );
    expect(sollecito?.valore, endsWith(scriviData(oggi)));
  });

  testWidgets('senza rete le date non si toccano, e lo si dice', (
    tester,
  ) async {
    await sulServer(tester, rigaViaggio('i', periodo: 'agosto 2099'));
    ambiente.rete.disponibile = false;
    await ambiente.monta(tester, const SchermataViaggio(viaggioId: 'i'));

    expect(find.text('Fissa le date'), findsNothing);
    expect(find.textContaining('serve la connessione'), findsOneWidget);
    expect(find.text(motivoSenzaRete), findsOneWidget); // l'invito
  });

  testWidgets('fissare le date di un\'idea la fa diventare in programma, e '
      'il passaggio si misura', (tester) async {
    await sulServer(tester, rigaViaggio('i', periodo: 'agosto 2099'));
    await ambiente.monta(tester, const SchermataViaggio(viaggioId: 'i'));

    await tester.tap(pulsante('Fissa le date'));
    await tester.pumpAndSettle();

    /// Sceglie una data scrivendola, come si può fare nel selettore Material:
    /// così il test non dipende dal giorno in cui gira.
    Future<void> scegli(Finder campo, DateTime data) async {
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

    final inizio = oggi.add(const Duration(days: 40));
    await scegli(find.text('Primo giorno'), inizio);
    // L'ultimo giorno segue il primo: si sposta da lì.
    await scegli(
      find.text('Al ${dataEstesa(inizio)}'),
      inizio.add(const Duration(days: 2)),
    );
    expect(
      find.textContaining('3 giorni: il primo dalle 10:00'),
      findsOneWidget,
    );

    // Il foglio sale sopra il viaggio, che resta visibile sotto: il suo
    // pulsante è l'ultimo.
    await tester.tap(pulsante('Fissa le date').last);
    await tester.pumpAndSettle();

    final chiamata = ambiente.server
        .chiamate('POST', '/rest/v1/rpc/programma_viaggio')
        .single;
    expect(corpoDi(chiamata)['p_data_inizio'], scriviData(inizio));
    expect(corpoDi(chiamata)['p_giorni'], hasLength(3));

    // Di nuovo sul viaggio, che adesso ha i suoi giorni.
    expect(find.text('IN PROGRAMMA'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Giorni'), 300);
    expect(find.text('Giorni'), findsOneWidget);

    final eventi = await ambiente.eventi(tester);
    expect(eventi.single.nome, 'idea_definita');
    expect(
      jsonDecode(eventi.single.proprieta),
      containsPair('durata_prevista_giorni', 3),
    );
  });
}
