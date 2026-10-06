import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/aspetto/mappamondo.dart';
import 'package:trolley/dominio/calendario.dart';
import 'package:trolley/schermate/impostazioni.dart';
import 'package:trolley/schermate/mappamondo.dart';
import 'package:trolley/schermate/passaporto.dart';
import 'package:trolley/schermate/viaggio.dart';

import '../aiuti.dart';

/// Il ricordo (fase 4.2; tela, 64–66): il profilo con i suoi numeri, il
/// passaporto per anno, il mappamondo. Tutto dalla copia, anche senza rete.
void main() {
  late Ambiente ambiente;

  setUp(() => ambiente = Ambiente());
  tearDown(() => ambiente.chiudi());

  final oggi = soloData(DateTime.now());
  String fra(int giorni) => scriviData(oggi.add(Duration(days: giorni)));
  final anno = oggi.year;

  /// Porto quest'anno (verificato), Lisbona e Kyoto l'anno scorso; un viaggio
  /// che deve ancora venire e uno da cui si è usciti non ci sono.
  Future<void> viaggi(WidgetTester tester) async {
    ambiente.server
      ..viaggi.addAll([
        rigaViaggio(
          'porto',
          stato: 'chiuso',
          inizio: '$anno-01-10',
          fine: '$anno-01-12',
        ),
        rigaViaggio(
          'lisbona',
          stato: 'chiuso',
          citta: 'Lisbona',
          inizio: '${anno - 1}-05-12',
          fine: '${anno - 1}-05-17',
        ),
        rigaViaggio(
          'kyoto',
          stato: 'chiuso',
          citta: 'Kyoto',
          paese: 'JP',
          inizio: '${anno - 1}-04-03',
          fine: '${anno - 1}-04-10',
        ),
        rigaViaggio(
          'parigi',
          stato: 'definito',
          citta: 'Parigi',
          paese: 'FR',
          inizio: fra(10),
          fine: fra(12),
        ),
        rigaViaggio(
          'atene',
          stato: 'chiuso',
          citta: 'Atene',
          paese: 'GR',
          inizio: '${anno - 1}-08-01',
          fine: '${anno - 1}-08-05',
        ),
      ])
      ..partecipazioni.addAll([
        rigaPartecipazione('porto')..['verificato'] = true,
        rigaPartecipazione('lisbona')..['verificato'] = false,
        rigaPartecipazione('kyoto'),
        rigaPartecipazione('parigi'),
        rigaPartecipazione('atene', stato: 'uscito'),
      ]);
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

  Future<List<Map<String, dynamic>>> senzaRete(WidgetTester tester) async => [
    for (final e in await ambiente.eventi(tester))
      if (e.nome == 'apertura_senza_rete')
        jsonDecode(e.proprieta) as Map<String, dynamic>,
  ];

  testWidgets('il profilo conta i viaggi chiusi, i paesi e le città, e porta '
      'al passaporto e al mappamondo', (tester) async {
    await viaggi(tester);
    await ambiente.monta(tester, const SchermataImpostazioni());
    await aspetta(tester);

    expect(find.text('Giulia'), findsOneWidget);
    expect(find.bySemanticsLabel('Viaggi: 3'), findsOneWidget);
    expect(find.bySemanticsLabel('Paesi: 2'), findsOneWidget);
    expect(find.bySemanticsLabel('Città: 3'), findsOneWidget);
    expect(find.text('3 viaggi'), findsOneWidget);
    expect(find.text('2 paesi'), findsOneWidget);
    expect(find.text('nessuno'), findsOneWidget); // traguardi
    expect(find.text('Euro'), findsOneWidget);

    await tester.tap(find.text('Passaporto'));
    await aspetta(tester);
    expect(find.byType(SchermataPassaporto), findsOneWidget);
  });

  testWidgets('il passaporto: per anno, dal più recente, con il timbro dove '
      'è verificato; un biglietto apre il viaggio', (tester) async {
    await viaggi(tester);
    await ambiente.monta(tester, const SchermataPassaporto());
    await aspetta(tester);

    expect(find.textContaining('3 viaggi, dal più recente'), findsOneWidget);
    expect(find.text('$anno'), findsOneWidget);
    expect(find.text('${anno - 1}'), findsOneWidget);
    expect(find.text('Porto'), findsOneWidget);
    expect(find.text('10–12 gen · 3 giorni'), findsOneWidget);
    expect(find.text('12–17 mag · 6 giorni'), findsOneWidget);
    expect(find.text('POR'), findsOneWidget);
    expect(find.text('VERIFICATO'), findsOneWidget);
    expect(find.text('Parigi'), findsNothing);
    expect(find.text('Atene'), findsNothing);

    // Prima l'anno nuovo, e nell'anno vecchio Lisbona (maggio) prima di
    // Kyoto (aprile).
    final y = [
      for (final t in ['$anno', 'Porto', '${anno - 1}', 'Lisbona', 'Kyoto'])
        tester.getTopLeft(find.text(t)).dy,
    ];
    expect(y, [...y]..sort());

    await tester.tap(find.text('Kyoto'));
    await aspetta(tester);
    expect(find.byType(SchermataViaggio), findsOneWidget);
  });

  testWidgets('il mappamondo: i paesi in cobalto sul globo, l\'elenco e le '
      'città; un paese toccato gira il globo', (tester) async {
    await viaggi(tester);
    await ambiente.monta(tester, const SchermataMappamondo());
    await aspetta(tester);

    expect(
      find.text('2 paesi e 3 città: ogni viaggio chiuso, verificato o no.'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Mappamondo: 2 paesi visitati'), findsOne);
    final globo = tester.widget<Mappamondo>(find.byType(Mappamondo));
    expect(globo.grattati, {'PT', 'JP'});
    // Guarda il paese del viaggio più recente.
    expect(globo.centro.lon, closeTo(-8, 2));

    expect(find.text('PAESI · 2'), findsOneWidget);
    expect(find.text('Portogallo'), findsOneWidget);
    expect(find.text('Giappone'), findsOneWidget);
    expect(find.text('CITTÀ · 3'), findsOneWidget);
    expect(find.text('Porto, Lisbona, Kyoto'), findsOneWidget);

    await tester.tap(find.text('Giappone'));
    await aspetta(tester);
    expect(
      tester.widget<Mappamondo>(find.byType(Mappamondo)).centro.lon,
      closeTo(138, 3),
    );
  });

  testWidgets('senza viaggi chiusi si dice come si riempiono', (tester) async {
    await ambiente.accedi(tester: tester);
    await ambiente.monta(tester, const SchermataPassaporto());
    await aspetta(tester);
    expect(find.textContaining('Il primo arriva il giorno dopo'), findsOne);

    await ambiente.monta(tester, const SchermataMappamondo());
    await aspetta(tester);
    expect(find.textContaining('Si colora con i viaggi chiusi'), findsOne);
    expect(find.text('PAESI · 0'), findsNothing);
  });

  testWidgets('senza rete si leggono dalla copia, e si conta l\'apertura', (
    tester,
  ) async {
    await viaggi(tester);
    ambiente.rete.disponibile = false;
    await ambiente.monta(tester, const SchermataPassaporto());
    await aspetta(tester);
    expect(find.text('Porto'), findsOneWidget);

    await ambiente.monta(tester, const SchermataMappamondo());
    await aspetta(tester);
    expect(find.text('Portogallo'), findsOneWidget);

    expect(
      [for (final e in await senzaRete(tester)) e['schermata']],
      ['passaporto', 'mappamondo'],
    );
  });

  group('grattare un paese nuovo (tela, 95–97)', () {
    /// Porto l'anno scorso; Kyoto, il primo viaggio in Giappone, finito
    /// tre giorni fa.
    Future<void> nuovo(WidgetTester tester) async {
      ambiente.server
        ..viaggi.addAll([
          rigaViaggio(
            'porto',
            stato: 'chiuso',
            inizio: '${anno - 1}-01-10',
            fine: '${anno - 1}-01-12',
          ),
          rigaViaggio(
            'kyoto',
            stato: 'chiuso',
            citta: 'Kyoto',
            paese: 'JP',
            inizio: fra(-6),
            fine: fra(-3),
          ),
        ])
        ..partecipazioni.addAll([
          rigaPartecipazione('porto'),
          rigaPartecipazione('kyoto'),
        ]);
      await ambiente.accedi(tester: tester);
      await tester.runAsync(ambiente.archivio.aggiornaCopia);
    }

    Future<Set<String>> scoperti(WidgetTester tester) async => (await tester
        .runAsync(() => ambiente.archivio.osservaPaesiScoperti().first))!;

    testWidgets('il globo si avvicina al paese sotto la patina, e grattandolo '
        'col dito si scopre', (tester) async {
      await nuovo(tester);
      await ambiente.monta(tester, const SchermataMappamondo());
      await aspetta(tester);

      expect(
        find.textContaining('Un paese nuovo: grattalo col dito'),
        findsOne,
      );
      expect(find.text('Giappone: grattalo col dito'), findsOneWidget);
      expect(find.text('da grattare'), findsOneWidget);
      final globo = tester.widget<Mappamondo>(find.byType(Mappamondo));
      expect(globo.daGrattare, 'JP');
      expect(globo.grattati, {'PT'});

      // Il dito passa su tutto il globo, avanti e indietro.
      final riquadro = tester.getRect(find.byType(Mappamondo));
      final dito = await tester.startGesture(riquadro.topLeft);
      for (var y = riquadro.top; y < riquadro.bottom; y += 12) {
        await dito.moveTo(Offset(riquadro.right, y));
        await dito.moveTo(Offset(riquadro.left, y + 6));
      }
      await dito.up();
      await aspetta(tester);

      expect(await scoperti(tester), {'JP'});
      expect(find.text('Giappone: il tuo 2° paese'), findsOneWidget);
      expect(
        tester.widget<Mappamondo>(find.byType(Mappamondo)).daGrattare,
        isNull,
      );
      expect(find.text('da grattare'), findsNothing);
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('Giappone: il tuo 2° paese'), findsNothing);
    });

    testWidgets('un tocco qua e là non basta', (tester) async {
      await nuovo(tester);
      await ambiente.monta(tester, const SchermataMappamondo());
      await aspetta(tester);

      final centro = tester.getCenter(find.byType(Mappamondo));
      await tester.dragFrom(centro, const Offset(30, 0));
      await aspetta(tester);
      expect(await scoperti(tester), isEmpty);
      expect(find.text('Giappone: grattalo col dito'), findsOneWidget);
    });

    testWidgets('«Scopri» fa lo stesso senza grattare', (tester) async {
      await nuovo(tester);
      await ambiente.monta(tester, const SchermataMappamondo());
      await aspetta(tester);

      await tester.tap(find.text('Scopri'));
      await aspetta(tester);
      expect(await scoperti(tester), {'JP'});
      expect(find.text('Giappone: il tuo 2° paese'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('il profilo dice quanti paesi sono da grattare', (
      tester,
    ) async {
      await nuovo(tester);
      await ambiente.monta(tester, const SchermataImpostazioni());
      await aspetta(tester);
      expect(find.text('1 da grattare'), findsOneWidget);

      await tester.runAsync(() => ambiente.archivio.segnaPaeseScoperto('JP'));
      await aspetta(tester);
      expect(find.text('2 paesi'), findsOneWidget);
    });
  });
}
