import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dati/errori.dart';
import 'package:trolley/misurazione/misurazione.dart';
import 'package:trolley/schermate/community.dart';
import 'package:trolley/schermate/profilo_altrui.dart';
import 'package:trolley/schermate/profilo_pubblico.dart';
import 'package:trolley/schermate/scelta_destinazione.dart';
import 'package:trolley/schermate/viaggi.dart';
import 'package:trolley/schermate/viaggi_sul_profilo.dart';

import '../aiuti.dart';

/// Il profilo pubblico e la ricerca dal telefono (5.3; tela, 73–75 e
/// 108–110): Community nella barra solo quando la parte pubblica c'è; chi
/// guarda si fa guardare; si cerca per meta e gusti, mai per nome; il profilo
/// di un altro, con «…»; «Così ti vedono» e i viaggi sul profilo.
void main() {
  late Ambiente ambiente;

  setUp(() => ambiente = Ambiente());
  tearDown(() => ambiente.chiudi());

  const teresa = 'bbbbbbbb-2222-4222-8222-222222222222';
  const kyoto = 'cccccccc-3333-4333-8333-333333333333';
  const atene = 'dddddddd-4444-4444-8444-444444444444';

  Map<String, Object?> profiloDiTeresa() => {
    'id': teresa,
    'nome': 'Teresa',
    'dal': '${DateTime.now().year}-03-01',
    'gusti': ['cibo', 'panorami'],
    'traguardi': 5,
    'viaggi': [
      {
        'citta': 'Kyoto',
        'paese': 'JP',
        'mese': '2026-04-01',
        'periodo': null,
        'giorni': 9,
        'verificato': true,
        'importato': false,
      },
      {
        'citta': 'Porto',
        'paese': 'PT',
        'mese': null,
        'periodo': 'agosto 2019',
        'giorni': 5,
        'verificato': false,
        'importato': true,
      },
    ],
  };

  /// Lascia arrivare le risposte del server finto.
  Future<void> aspetta(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  /// La ricerca parte quando si smette di toccare.
  Future<void> dopoLaPausa(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 500));
    await aspetta(tester);
  }

  /// Dentro, con la parte pubblica aperta, il numero verificato e il
  /// profilo [acceso].
  Future<void> dentro(
    WidgetTester tester,
    Widget schermata, {
    bool acceso = true,
  }) async {
    ambiente.server.apriPartePubblica(telefono: '+393471234567');
    ambiente.server.partePubblica['attivo'] = acceso;
    await ambiente.accedi(tester: tester);
    await ambiente.monta(tester, schermata);
    await aspetta(tester);
  }

  Future<List<(String, Object?)>> registrati(WidgetTester tester) async => [
    for (final e in await ambiente.eventi(tester))
      (e.nome, jsonDecode(e.proprieta)),
    for (final r in ambiente.server.chiamate('POST', '/rest/v1/evento'))
      for (final e in (jsonDecode(r.body) as List).cast<Map<String, dynamic>>())
        (e['nome'] as String, e['proprieta']),
  ];

  /// Gli eventi come `nome {proprietà}`.
  Future<List<String>> eventi(WidgetTester tester) async => [
    for (final (nome, proprieta) in await registrati(tester))
      '$nome ${jsonEncode(proprieta)}',
  ];

  List<Map<String, dynamic>> ricerche() => [
    for (final r in ambiente.server.chiamate(
      'POST',
      '/rest/v1/rpc/cerca_viaggiatori',
    ))
      jsonDecode(r.body) as Map<String, dynamic>,
  ];

  group('Community nella barra', () {
    testWidgets('c\'è solo quando la parte pubblica c\'è, ed è maggiorenne', (
      tester,
    ) async {
      await ambiente.accedi(tester: tester);
      await ambiente.monta(tester, SchermataViaggi(onCodice: (_) {}));
      await aspetta(tester);
      expect(find.bySemanticsLabel('Community'), findsNothing);

      // All'apertura dell'app si chiede lo stato: il telefono lo ricorda.
      ambiente.server.apriPartePubblica();
      await tester.runAsync(ambiente.partePubblica.stato);
      await aspetta(tester);
      expect(find.bySemanticsLabel('Community'), findsOneWidget);

      ambiente.server.partePubblica['maggiorenne'] = false;
      await tester.runAsync(ambiente.partePubblica.stato);
      await aspetta(tester);
      expect(find.bySemanticsLabel('Community'), findsNothing);
    });
  });

  group('chi guarda si fa guardare', () {
    testWidgets('con il profilo spento non si vede nessuno: si dice come '
        'accenderlo', (tester) async {
      ambiente.server.profiliPubblici.add(profiloDiTeresa());
      await dentro(tester, const SchermataCommunity(), acceso: false);

      expect(find.text('Per vedere gli altri, fatti vedere'), findsOneWidget);
      expect(find.text('Teresa'), findsNothing);
      expect(ricerche(), isEmpty);

      await tester.tap(find.text('Accendi il profilo pubblico'));
      await tester.pumpAndSettle();
      expect(find.byType(SchermataProfiloPubblico), findsOneWidget);
    });
  });

  group('cercare', () {
    testWidgets('senza criteri non si vede nessuno', (tester) async {
      ambiente.server.profiliPubblici.add(profiloDiTeresa());
      await dentro(tester, const SchermataCommunity());

      expect(
        find.text(
          'Scegli una meta o cosa ti piace: trovi chi c\'è stato, o chi '
          'viaggia come te.',
        ),
        findsOneWidget,
      );
      expect(find.text('Teresa'), findsNothing);
      expect(ricerche(), isEmpty);
    });

    testWidgets('per gusti: i risultati dicono cosa avete in comune, e la '
        'ricerca si misura senza dire quali', (tester) async {
      ambiente.server
        ..gusti = ['cibo']
        ..profiliPubblici.add(profiloDiTeresa());
      await dentro(tester, const SchermataCommunity());

      await tester.tap(find.text('Cibo'));
      await tester.tap(find.text('Natura'));
      await dopoLaPausa(tester);

      // Due tocchi di fila sono una ricerca sola.
      expect(ricerche(), [
        {
          'p_paese': null,
          'p_citta': null,
          'p_gusti': ['cibo', 'natura'],
        },
      ]);
      expect(find.text('Teresa'), findsOneWidget);
      expect(find.text('ama il cibo'), findsOneWidget);
      expect(find.text('1 IN COMUNE'), findsOneWidget);
      expect(
        await eventi(tester),
        contains(
          '${Eventi.viaggiatoriCercati} {"criteri":"gusti","risultati":1}',
        ),
      );
    });

    testWidgets('per meta: si sceglie solo dall\'elenco, e si trova chi ci è '
        'stato', (tester) async {
      ambiente.server.profiliPubblici.add(profiloDiTeresa());
      await dentro(tester, const SchermataCommunity());

      await tester.tap(find.text('Una meta: un paese o una città'));
      await tester.pumpAndSettle();
      expect(find.byType(SchermataDestinazione), findsOneWidget);
      expect(find.text('Quale meta?'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Valle Segreta');
      await tester.pumpAndSettle();
      expect(find.textContaining('Usa «'), findsNothing);

      await tester.enterText(find.byType(TextField), 'Giappone');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Giappone').last);
      await dopoLaPausa(tester);

      expect(ricerche().single['p_paese'], 'JP');
      expect(find.text('Kyoto nel passaporto · 2 paesi'), findsOneWidget);

      // Togliendo la meta non si cerca più niente.
      await tester.tap(find.bySemanticsLabel('Togli la meta'));
      await dopoLaPausa(tester);
      expect(find.text('Teresa'), findsNothing);
      expect(ricerche(), hasLength(1));
    });

    testWidgets('per ora nessuno: la schermata lo regge', (tester) async {
      await dentro(tester, const SchermataCommunity());

      await tester.tap(find.text('Storia'));
      await dopoLaPausa(tester);
      expect(find.text('Per ora nessuno'), findsOneWidget);
      expect(
        find.text('Siamo ancora in pochi, capita spesso. Togli un gusto.'),
        findsOneWidget,
      );
    });

    testWidgets('senza rete non si cerca, e lo dice', (tester) async {
      await dentro(tester, const SchermataCommunity());
      ambiente.rete.disponibile = false;
      await tester.pumpAndSettle();

      expect(find.text(motivoSenzaRete), findsOneWidget);
      await tester.tap(find.text('Cibo'));
      await dopoLaPausa(tester);
      expect(ricerche(), isEmpty);
    });
  });

  group('il profilo di un altro', () {
    testWidgets('i numeri, cosa ama, cosa avete in comune, i viaggi chiusi', (
      tester,
    ) async {
      ambiente.server.profiliPubblici.add(profiloDiTeresa());
      await dentro(
        tester,
        const SchermataProfiloAltrui(
          utenteId: teresa,
          nome: 'Teresa',
          mieiGusti: {},
          mieMete: [(citta: 'Faro', paese: 'PT')],
        ),
      );

      expect(find.text('Teresa'), findsOneWidget);
      expect(find.text('su Trolley da marzo'), findsOneWidget);
      expect(find.text('VIAGGI'), findsOneWidget);
      expect(find.text('TRAGUARDI'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('CIBO'), findsOneWidget);
      expect(
        find.text('In comune: Portogallo', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Kyoto'), findsOneWidget);
      expect(find.text('aprile 2026 · 9 giorni'), findsOneWidget);
      expect(find.text('VERIFICATO'), findsOneWidget);
      expect(find.text('agosto 2019 · 5 giorni'), findsOneWidget);
      expect(find.text('IMPORTATO'), findsOneWidget);
    });

    testWidgets('da «…» si blocca: si torna indietro, e non lo si vede più', (
      tester,
    ) async {
      ambiente.server
        ..gusti = ['cibo']
        ..profiliPubblici.add(profiloDiTeresa())
        ..utenti.add({
          'id': teresa,
          'nome': 'Teresa',
          'versione': 1,
          'eliminato_il': null,
        });
      await dentro(tester, const SchermataCommunity());
      await tester.tap(find.text('Cibo'));
      await dopoLaPausa(tester);
      await tester.tap(find.text('Teresa'));
      await aspetta(tester);
      expect(find.byType(SchermataProfiloAltrui), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Segnala o blocca'));
      await tester.pumpAndSettle();
      expect(find.text('Segnala Teresa'), findsOneWidget);
      await tester.tap(find.text('Blocca Teresa'));
      await tester.pumpAndSettle();
      expect(find.text('Bloccare Teresa?'), findsOneWidget);
      await tester.tap(find.text('Blocca'));
      await aspetta(tester);

      expect(find.byType(SchermataProfiloAltrui), findsNothing);
      expect(find.text('Teresa'), findsNothing);
      expect(ambiente.server.bloccate.single['utente_id'], teresa);
      expect(
        await eventi(tester),
        contains('${Eventi.personaBloccata} {"da":"profilo"}'),
      );
    });

    testWidgets('un profilo che non si vede più lo dice', (tester) async {
      await dentro(
        tester,
        const SchermataProfiloAltrui(utenteId: teresa, nome: 'Teresa'),
      );
      expect(
        find.text('Questo profilo non è più nella parte pubblica.'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Segnala o blocca'), findsNothing);
    });
  });

  group('il proprio profilo pubblico', () {
    void dueViaggi() => ambiente.server.viaggiSulProfilo.addAll([
      {
        'viaggio_id': kyoto,
        'citta': 'Kyoto',
        'paese': 'JP',
        'mese': '2026-04-01',
        'periodo': null,
        'giorni': 9,
        'verificato': true,
        'importato': false,
        'sul_profilo': true,
      },
      {
        'viaggio_id': atene,
        'citta': 'Atene',
        'paese': 'GR',
        'mese': '2026-02-01',
        'periodo': null,
        'giorni': 3,
        'verificato': false,
        'importato': false,
        'sul_profilo': false,
      },
    ]);

    testWidgets('acceso è «Così ti vedono»: i gusti si scrivono a ogni tocco', (
      tester,
    ) async {
      dueViaggi();
      ambiente.server.gusti = ['cibo'];
      await dentro(tester, const SchermataProfiloPubblico());

      expect(find.text('Così ti vedono'), findsOneWidget);
      expect(find.text('1 viaggio · 1 paese · 0 traguardi'), findsOneWidget);
      expect(find.text('GIAPPONE'), findsOneWidget);
      expect(find.text('1 di 2 · scegli quali'), findsOneWidget);

      await tester.tap(find.text('Natura'));
      await aspetta(tester);
      expect(ambiente.server.gusti, ['cibo', 'natura']);
      // La versione del profilo è cambiata sul server: la copia la riprende.
      expect(
        ambiente.server.chiamate('POST', '/rest/v1/rpc/mio_profilo'),
        isNotEmpty,
      );
    });

    testWidgets('i viaggi sul profilo si scelgono uno per uno', (tester) async {
      dueViaggi();
      await dentro(tester, const SchermataProfiloPubblico());

      await tester.tap(find.text('Viaggi sul profilo'));
      await aspetta(tester);
      expect(find.byType(SchermataViaggiSulProfilo), findsOneWidget);
      expect(find.text('1 DI 2 SUL PROFILO'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Atene sul profilo'));
      await aspetta(tester);
      expect(ambiente.server.viaggiSulProfilo.last['sul_profilo'], isTrue);
      expect(find.text('2 DI 2 SUL PROFILO'), findsOneWidget);
    });

    testWidgets(
      'prima di accendere, si sceglie dalla schermata che lo accende',
      (tester) async {
        dueViaggi();
        await dentro(tester, const SchermataProfiloPubblico(), acceso: false);

        expect(find.text('I viaggi chiusi che scegli tu'), findsOneWidget);
        await tester.tap(find.text('1 · Scegli'));
        await aspetta(tester);
        expect(find.byType(SchermataViaggiSulProfilo), findsOneWidget);
      },
    );
  });
}
