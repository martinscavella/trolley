import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/aspetto/elementi.dart';
import 'package:trolley/aspetto/pagina.dart';
import 'package:trolley/dati/errori.dart';
import 'package:trolley/dominio/calendario.dart';
import 'package:trolley/schermate/giornata.dart';
import 'package:trolley/schermate/tappa.dart';
import 'package:trolley/schermate/tragitto.dart';

import '../aiuti.dart';

/// I tragitti fra le tappe (CR-07; tela, 166 e 170): il mezzo e la stima
/// sulla giornata, da vedere; il mezzo si sceglie nel foglio della tappa,
/// «Come ci arrivi?».
void main() {
  late Ambiente ambiente;

  setUp(() => ambiente = Ambiente());
  tearDown(() => ambiente.chiudi());

  final oggi = soloData(DateTime.now());
  String fra(int giorni) => scriviData(oggi.add(Duration(days: giorni)));

  /// Una giornata a Porto, fra un mese: la Livraria Lello alle 9, la Torre
  /// a piedi alle 10:15, il pranzo senza mezzo alle 12:30, il ponte a piedi
  /// alle 14:10 (dieci minuti dopo il pranzo: a piedi non ci si sta).
  Future<void> porto(WidgetTester tester, {bool giornata = true}) async {
    ambiente.server
      ..viaggi.add(
        rigaViaggio('v', stato: 'definito', inizio: fra(30), fine: fra(30)),
      )
      ..partecipazioni.add(rigaPartecipazione('v'))
      ..giorni.add(rigaGiorno('v', fra(30), '00:00:00', '24:00:00', id: 'g'))
      ..tappe.addAll([
        rigaDiTappa(
          'lello',
          viaggio: 'v',
          giorno: 'g',
          titolo: 'Livraria Lello',
          durata: 60,
          ora: '09:00:00',
          lat: 41.14686,
          lon: -8.61479,
        ),
        rigaDiTappa(
          'torre',
          viaggio: 'v',
          giorno: 'g',
          ordine: 2,
          titolo: 'Torre dos Clérigos',
          durata: 60,
          ora: '10:15:00',
          lat: 41.14573,
          lon: -8.61398,
          mezzo: 'a_piedi',
        ),
        rigaDiTappa(
          'pranzo',
          viaggio: 'v',
          giorno: 'g',
          ordine: 3,
          titolo: 'Pranzo al Mercado do Bolhão',
          tipo: 'pasto',
          ora: '12:30:00',
          lat: 41.14904,
          lon: -8.60580,
        ),
        rigaDiTappa(
          'ponte',
          viaggio: 'v',
          giorno: 'g',
          ordine: 4,
          titolo: 'Ponte Dom Luís I',
          tipo: 'passeggiata',
          durata: 60,
          ora: '14:10:00',
          lat: 41.13996,
          lon: -8.60937,
          mezzo: 'a_piedi',
        ),
      ]);
    await tester.runAsync(ambiente.archivio.aggiornaCopia);
    if (!giornata) return;
    await ambiente.monta(
      tester,
      const SchermataGiornata(viaggioId: 'v', giornoId: 'g'),
    );
  }

  /// Il foglio della tappa [id], o di una nuova alle [alle].
  Future<void> foglio(WidgetTester tester, {String? id, Duration? alle}) async {
    await porto(tester, giornata: false);
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
                giornoId: 'g',
                tappa: id == null ? null : tappe.singleWhere((t) => t.id == id),
                ora: alle,
              ),
            ),
            child: const Text('Apri'),
          ),
        ),
      ),
    );
    // Uno schermo alto: il foglio intero si vede senza scorrere.
    tester.view.physicalSize = Size(
      tester.view.physicalSize.width,
      1600 * tester.view.devicePixelRatio,
    );
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apri'));
    await tester.pumpAndSettle();
  }

  /// Il foglio fa vedere solo quello che sta sullo schermo: si scorre fino
  /// a [f], o fino in fondo.
  Future<void> scorri(WidgetTester tester, Finder f) async {
    for (var i = 0; i < 10 && f.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -200));
      await tester.pumpAndSettle();
    }
  }

  Finder mezzo(String codice) => find.byKey(ValueKey('mezzo-$codice'));

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

  Future<void> tocca(WidgetTester tester, Finder f) async {
    await scorri(tester, f);
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Map<String, Object?> tappa(String id) =>
      ambiente.server.tappe.singleWhere((t) => t['id'] == id);

  Future<Map<String, dynamic>?> evento(WidgetTester tester) async {
    final eventi = (await ambiente.eventi(tester))
        .where((e) => e.nome == 'tragitto_sistemato')
        .toList();
    return eventi.isEmpty
        ? null
        : jsonDecode(eventi.single.proprieta) as Map<String, dynamic>;
  }

  testWidgets('fra due tappe il tragitto: il mezzo e quanto dura a stima, '
      '«Come ci vai?» senza mezzo, in rosso quando non ci si sta', (
    tester,
  ) async {
    await porto(tester);

    expect(find.text('A piedi · circa 5 min'), findsOneWidget);
    expect(find.text('Come ci vai?'), findsOneWidget);
    expect(find.text('A piedi · circa 20 min · non ci stai'), findsOneWidget);
    // Prima della prima tappa del giorno non c'è un tragitto.
    expect(find.textContaining('circa'), findsNWidgets(2));
    expect(
      find.bySemanticsLabel(
        'Fino a Ponte Dom Luís I a piedi, circa 20 min, non ci stai: fra le '
        'due tappe ci sono 10 min',
      ),
      findsOneWidget,
    );
  });

  testWidgets('la pillola si vede soltanto: toccata, non apre niente '
      '(tela, 166)', (tester) async {
    await porto(tester);
    await tester.tap(find.text('Come ci vai?'));
    await tester.pumpAndSettle();

    expect(find.byType(ComeCiArrivi), findsNothing);
    expect(find.byType(FoglioMezzoDellaGuida), findsNothing);
    expect(find.text('Come ci vai?'), findsOneWidget);
  });

  testWidgets('nel foglio della tappa, «Come ci arrivi?» dalla tappa prima: '
      'i sei mezzi con la stima, e salvando il mezzo va nella tappa '
      '(tela, 170)', (tester) async {
    await foglio(tester, id: 'pranzo');
    await scorri(tester, mezzo('taxi'));

    expect(find.text('Come ci arrivi?'), findsOneWidget);
    expect(
      find.text('Da Torre dos Clérigos, che finisce alle 11:15'),
      findsOneWidget,
    );
    for (final m in [
      'a_piedi',
      'bici',
      'mezzi',
      'monopattino',
      'auto',
      'taxi',
    ]) {
      expect(mezzo(m), findsOneWidget);
    }
    expect(
      find.descendant(of: mezzo('mezzi'), matching: find.text('Con i mezzi')),
      findsOneWidget,
    );

    await tocca(tester, mezzo('mezzi'));
    await tocca(tester, pulsante('Salva'));
    await aspetta(tester);

    expect(tappa('pranzo')['mezzo'], 'mezzi');
    expect(tappa('pranzo')['versione'], 2);
    expect(await evento(tester), {
      'viaggio_id': 'v',
      'mezzo': 'mezzi',
      'prima': 'nessuno',
      'da': 'tappa',
      'non_ci_stava': false,
    });
  });

  testWidgets('la prima tappa del giorno non ha «Come ci arrivi?»', (
    tester,
  ) async {
    await foglio(tester, id: 'lello');
    await scorri(tester, find.text('Giorno'));
    expect(find.byType(ComeCiArrivi), findsNothing);
  });

  testWidgets('quando non ci si sta lo dice, e un mezzo più veloce lo '
      'sistema; ritoccato quello scelto si toglie', (tester) async {
    await foglio(tester, id: 'ponte');
    await scorri(tester, mezzo('taxi'));

    expect(
      find.textContaining('Non ci stai: fra le due tappe ci sono 10 min'),
      findsOneWidget,
    );
    await tocca(tester, mezzo('a_piedi'));
    expect(find.textContaining('Non ci stai'), findsNothing);

    await tocca(tester, mezzo('bici'));
    expect(find.textContaining('Non ci stai'), findsNothing);
    await tocca(tester, pulsante('Salva'));
    await aspetta(tester);

    expect(tappa('ponte')['mezzo'], 'bici');
    expect(tappa('ponte')['ora_inizio'], '14:10:00');
    expect(await evento(tester), {
      'viaggio_id': 'v',
      'mezzo': 'bici',
      'prima': 'a_piedi',
      'da': 'tappa',
      'non_ci_stava': true,
    });
  });

  testWidgets('una tappa nuova nasce con il suo mezzo, anche senza rete', (
    tester,
  ) async {
    await foglio(tester, alle: const Duration(hours: 16));
    ambiente.rete.disponibile = false;
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Cais da Ribeira');
    await tester.pump();
    await scorri(tester, mezzo('taxi'));

    expect(
      find.text('Da Ponte Dom Luís I, che finisce alle 15:10'),
      findsOneWidget,
    );
    await tocca(tester, mezzo('auto'));
    // La copia si scrive nel database vero, che non avanza nel tempo finto.
    await tester.tap(pulsante('Aggiungi'));
    await aspetta(tester);

    final nuova = (await tester.runAsync(
      () => ambiente.archivio.osservaTappe('v').first,
    ))!.singleWhere((t) => t.titolo == 'Cais da Ribeira');
    expect(nuova.mezzo, 'auto');
  });

  testWidgets('senza rete il mezzo di una tappa che c\'è non si cambia, e lo '
      'si dice', (tester) async {
    await foglio(tester, id: 'pranzo');
    ambiente.rete.disponibile = false;
    await tester.pumpAndSettle();

    await tocca(tester, mezzo('bici'));
    final salva = tester.widget<PulsanteGrande>(
      find.ancestor(
        of: pulsante('Salva'),
        matching: find.byType(PulsanteGrande),
      ),
    );
    expect(salva.onPressed, isNull);
    expect(find.text(motivoSenzaRete), findsWidgets);
    expect(tappa('pranzo')['mezzo'], isNull);
  });
}
