import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/aspetto/barra.dart';
import 'package:trolley/dominio/calendario.dart';
import 'package:trolley/schermate/impostazioni.dart';
import 'package:trolley/schermate/mappa.dart';
import 'package:trolley/schermate/passaporto.dart';
import 'package:trolley/schermate/sezioni.dart';
import 'package:trolley/schermate/viaggi.dart';
import 'package:trolley/schermate/viaggio.dart';

import '../aiuti.dart';

/// Le sezioni (ADR-013; tela, 122–126): una barra sola, che resta ferma;
/// ogni sezione con la sua pila, che ricorda dov'era; le pagine di lavoro
/// sopra la barra; «Mappa» dal viaggio apre quel viaggio.
void main() {
  late Ambiente ambiente;

  setUp(() => ambiente = Ambiente());
  tearDown(() => ambiente.chiudi());

  final oggi = soloData(DateTime.now());
  String fra(int giorni) => scriviData(oggi.add(Duration(days: giorni)));

  /// Porto fra dieci giorni, Oslo fra quaranta.
  Future<void> viaggi(WidgetTester tester) async {
    ambiente.server
      ..viaggi.addAll([
        rigaViaggio('porto', stato: 'definito', inizio: fra(10), fine: fra(12)),
        rigaViaggio(
          'oslo',
          stato: 'definito',
          citta: 'Oslo',
          paese: 'NO',
          inizio: fra(40),
          fine: fra(43),
        ),
      ])
      ..partecipazioni.addAll([
        rigaPartecipazione('porto'),
        rigaPartecipazione('oslo'),
      ]);
    await ambiente.accedi(tester: tester);
    await tester.runAsync(ambiente.archivio.aggiornaCopia);
  }

  /// Lascia arrivare le scritture: il database vero non avanza nel tempo
  /// finto dei test.
  Future<void> aspetta(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> sezioni(WidgetTester tester) async {
    await ambiente.monta(tester, SchermataSezioni(onCodice: (_) {}));
    await aspetta(tester);
  }

  /// Una voce della barra.
  Finder voce(String nome) => find.descendant(
    of: find.byType(BarraPrincipale),
    matching: find.bySemanticsLabel(nome),
  );

  Future<void> tocca(WidgetTester tester, Finder dove) async {
    await tester.tap(dove);
    await aspetta(tester);
  }

  /// La voce attiva della barra.
  String? attiva(WidgetTester tester) {
    final barra = tester.widget<BarraPrincipale>(find.byType(BarraPrincipale));
    return [
      ...barra.prima,
      ...barra.dopo,
    ].where((v) => v.attiva).firstOrNull?.etichetta;
  }

  testWidgets('la barra resta: cambiando sezione cambia solo il contenuto, e '
      'ogni sezione ricorda dov\'era', (tester) async {
    await viaggi(tester);
    await sezioni(tester);
    expect(attiva(tester), 'Viaggi');
    expect(
      tester
          .widget<BarraPrincipale>(find.byType(BarraPrincipale))
          .dopo
          .map((v) => v.etichetta),
      ['Passaporto'],
    );
    final barra = tester.state(find.byType(BarraPrincipale));

    await tocca(tester, voce('Passaporto'));
    expect(attiva(tester), 'Passaporto');
    expect(find.byType(SchermataPassaporto), findsOneWidget);
    expect(find.byType(SchermataViaggi), findsNothing);
    // È la stessa barra, non una nuova per ogni pagina: per questo la voce
    // bianca può scivolare.
    expect(tester.state(find.byType(BarraPrincipale)), same(barra));

    // In Viaggi si apre Oslo: la barra resta sul viaggio.
    await tocca(tester, voce('Viaggi'));
    await tocca(tester, find.text('Oslo'));
    expect(find.byType(SchermataViaggio), findsOneWidget);
    expect(attiva(tester), 'Viaggi');

    // Al passaporto e ritorno: Oslo è ancora lì.
    await tocca(tester, voce('Passaporto'));
    expect(find.byType(SchermataViaggio), findsNothing);
    await tocca(tester, voce('Viaggi'));
    expect(find.byType(SchermataViaggio), findsOneWidget);

    // Ritoccando Viaggi si torna all'elenco.
    await tocca(tester, voce('Viaggi'));
    expect(find.byType(SchermataViaggio), findsNothing);
    expect(find.byType(SchermataViaggi), findsOneWidget);
  });

  testWidgets('«Mappa» dall\'elenco apre il viaggio che conta; dal viaggio, '
      'quel viaggio', (tester) async {
    await viaggi(tester);
    await sezioni(tester);

    await tocca(tester, voce('Mappa'));
    expect(attiva(tester), 'Mappa');
    expect(
      tester.widget<SchermataMappa>(find.byType(SchermataMappa)).viaggioId,
      'porto',
    );

    await tocca(tester, voce('Viaggi'));
    await tocca(tester, find.text('Oslo'));
    await tocca(tester, voce('Mappa'));
    expect(
      tester.widget<SchermataMappa>(find.byType(SchermataMappa)).viaggioId,
      'oslo',
    );
    expect(
      find.descendant(
        of: find.byType(SchermataMappa),
        matching: find.text('Oslo'),
      ),
      findsWidgets,
    );
  });

  testWidgets('senza viaggi con le date, la Mappa lo dice (tela, 125)', (
    tester,
  ) async {
    ambiente.server
      ..viaggi.add(rigaViaggio('idea', periodo: 'agosto 2099'))
      ..partecipazioni.add(rigaPartecipazione('idea'));
    await ambiente.accedi(tester: tester);
    await tester.runAsync(ambiente.archivio.aggiornaCopia);
    await sezioni(tester);

    await tocca(tester, voce('Mappa'));
    expect(find.text('Ancora niente da mettere sulla mappa'), findsOneWidget);
    expect(find.byType(SchermataMappa), findsNothing);
  });

  testWidgets('il profilo si apre dall\'avatar e passa sopra la barra; '
      'tornando, la barra è dov\'era', (tester) async {
    await viaggi(tester);
    await sezioni(tester);
    await tocca(tester, voce('Passaporto'));

    await tocca(tester, find.bySemanticsLabel('Profilo e impostazioni'));
    expect(find.byType(SchermataImpostazioni), findsOneWidget);
    expect(find.byType(BarraPrincipale), findsNothing);

    await tocca(tester, find.byTooltip('Indietro'));
    expect(find.byType(SchermataImpostazioni), findsNothing);
    expect(attiva(tester), 'Passaporto');
  });

  testWidgets('un invito o una notifica aprono il viaggio nella sezione '
      'Viaggi, chiudendo quello che c\'era sopra', (tester) async {
    await viaggi(tester);
    await sezioni(tester);
    await tocca(tester, voce('Passaporto'));
    await tocca(tester, find.bySemanticsLabel('Profilo e impostazioni'));

    SchermataSezioni.aperta!.apriNeiViaggi(
      const SchermataViaggio(viaggioId: 'oslo'),
    );
    await aspetta(tester);
    expect(find.byType(SchermataImpostazioni), findsNothing);
    expect(find.byType(SchermataViaggio), findsOneWidget);
    expect(attiva(tester), 'Viaggi');
  });

  testWidgets('indietro su Android: dalla sezione si torna a Viaggi', (
    tester,
  ) async {
    await viaggi(tester);
    await sezioni(tester);
    await tocca(tester, voce('Passaporto'));

    await tester.binding.handlePopRoute();
    await aspetta(tester);
    expect(attiva(tester), 'Viaggi');
    expect(find.byType(SchermataViaggi), findsOneWidget);
  });
}
