import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/aspetto/pagina.dart';
import 'package:trolley/aspetto/piattaforma.dart';
import 'package:trolley/dati/database.dart';
import 'package:trolley/dati/errori.dart';
import 'package:trolley/misurazione/misurazione.dart';
import 'package:trolley/schermate/community.dart';
import 'package:trolley/schermate/conversazione.dart';
import 'package:trolley/schermate/profilo_altrui.dart';

import '../aiuti.dart';

/// I collegamenti e i messaggi dal telefono (5.4; tela, 76–78 e 111–116): sul
/// profilo di un altro il pulsante dice a che punto siete; si chiede con un
/// messaggio breve, si accetta o si rifiuta senza dirlo; Collegamenti e
/// Messaggi accanto a Cerca; la conversazione, con le righe di prudenza la
/// prima volta, il messaggio che non parte, quello tenuto premuto, la
/// conversazione finita che resta.
void main() {
  late Ambiente ambiente;

  setUp(() => ambiente = Ambiente());
  tearDown(() => ambiente.chiudi());

  const teresa = 'bbbbbbbb-2222-4222-8222-222222222222';
  const andrea = 'eeeeeeee-5555-4555-8555-555555555555';
  const luca = 'aaaaaaaa-1111-4111-8111-111111111111';
  const sara = 'cccccccc-3333-4333-8333-333333333333';
  const chiuso = 'ffffffff-6666-4666-8666-666666666666';

  Map<String, Object?> profilo(String id, String nome) => {
    'id': id,
    'nome': nome,
    'dal': '${DateTime.now().year}-03-01',
    'gusti': ['cibo'],
    'traguardi': 2,
    'viaggi': <Object?>[],
  };

  String fa(Duration quanto) =>
      DateTime.now().toUtc().subtract(quanto).toIso8601String();

  Map<String, Object?> collegati({Duration da = const Duration(days: 3)}) => {
    'stato': 'accettato',
    'da_me': true,
    'messaggio': null,
    'chiesto_il': fa(da + const Duration(hours: 1)),
    'risposto_il': fa(da),
  };

  Map<String, Object?> messaggio(
    String id,
    String con,
    String testo, {
    bool mio = false,
    bool letto = true,
    bool tolto = false,
    Duration fa_ = const Duration(hours: 1),
  }) => {
    'id': id,
    'con': con,
    'mio': mio,
    'testo': testo,
    'scritto_il': fa(fa_),
    'tolto': tolto,
    'letto': letto,
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

  /// Dentro, con la parte pubblica aperta e il profilo acceso.
  Future<void> dentro(WidgetTester tester, Widget schermata) async {
    ambiente.server.apriPartePubblica(telefono: '+393471234567');
    ambiente.server.partePubblica['attivo'] = true;
    await ambiente.accedi(tester: tester);
    await ambiente.monta(tester, schermata);
    await aspetta(tester);
  }

  /// Una schermata da cui si apre [schermata], per vederla chiudersi.
  Widget daQui(Widget schermata) => Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => apri<bool>(context, schermata),
          child: const Text('Apri'),
        ),
      ),
    ),
  );

  Future<void> apriDaQui(WidgetTester tester) async {
    await tester.tap(find.text('Apri'));
    await aspetta(tester);
  }

  Future<List<String>> eventi(WidgetTester tester) async => [
    for (final e in await ambiente.eventi(tester)) '${e.nome} ${e.proprieta}',
    for (final r in ambiente.server.chiamate('POST', '/rest/v1/evento'))
      for (final e in (jsonDecode(r.body) as List).cast<Map<String, dynamic>>())
        '${e['nome']} ${jsonEncode(e['proprieta'])}',
  ];

  group('il profilo di un altro', () {
    testWidgets('si chiede di collegarsi con un messaggio breve; la richiesta '
        'si vede, e si ritira', (tester) async {
      ambiente.server.profiliPubblici.add(profilo(teresa, 'Teresa'));
      await dentro(
        tester,
        const SchermataProfiloAltrui(utenteId: teresa, nome: 'Teresa'),
      );
      expect(
        find.text(
          'I viaggi in programma o in corso non si vedono mai, di nessuno.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Chiedi di collegarvi'));
      await tester.pumpAndSettle();
      expect(find.text('Collegarti con Teresa?'), findsOneWidget);
      expect(
        find.text(
          'Se accetta, potrete scrivervi. Fino ad allora passa solo questo '
          'messaggio, e nient\'altro.',
        ),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), '  Anche tu a Kyoto?  ');
      await tester.pumpAndSettle();
      expect(find.text('21 di 200'), findsOneWidget);
      await tester.tap(find.text('Invia la richiesta'));
      await aspetta(tester);

      expect(ambiente.server.collegamenti[teresa], {
        'stato': 'richiesto',
        'da_me': true,
        'messaggio': 'Anche tu a Kyoto?',
        'chiesto_il': isA<String>(),
        'risposto_il': null,
      });
      expect(
        await eventi(tester),
        contains('${Eventi.collegamentoRichiesto} {"compagni":false}'),
      );
      expect(find.text('Richiesta inviata'), findsOneWidget);
      expect(
        find.text('Se accetta, potrete scrivervi. Toccala per ritirarla.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Richiesta inviata'));
      await tester.pumpAndSettle();
      expect(find.text('Ritirare la richiesta a Teresa?'), findsOneWidget);
      await tester.tap(find.text('Ritira'));
      await aspetta(tester);
      expect(ambiente.server.collegamenti, isEmpty);
      expect(find.text('Chiedi di collegarvi'), findsOneWidget);
    });

    testWidgets('la sua richiesta: si accetta, diventa il primo messaggio, e '
        'si scrive', (tester) async {
      ambiente.server
        ..profiliPubblici.add(profilo(andrea, 'Andrea'))
        ..collegamenti[andrea] = {
          'stato': 'richiesto',
          'da_me': false,
          'messaggio': 'Anche io a Porto a ottobre!',
          'chiesto_il': fa(const Duration(days: 1)),
          'risposto_il': null,
        };
      await dentro(
        tester,
        const SchermataProfiloAltrui(utenteId: andrea, nome: 'Andrea'),
      );
      expect(find.text('Andrea ti ha chiesto di collegarvi'), findsOneWidget);
      expect(find.text('Anche io a Porto a ottobre!'), findsOneWidget);
      expect(
        find.text(
          'Rifiutare non glielo dice: vedrà solo che non è stata accettata.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Accetta'));
      await aspetta(tester);
      expect(ambiente.server.collegamenti[andrea]!['stato'], 'accettato');
      expect(
        ambiente.server.messaggi.single['testo'],
        'Anche io a Porto a ottobre!',
      );
      expect(
        await eventi(tester),
        contains('${Eventi.collegamentoAccettato} {"compagni":false}'),
      );
      expect(find.text('COLLEGATI'), findsOneWidget);
      expect(
        find.textContaining('Da «…» lo togli quando vuoi.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Scrivi a Andrea'));
      await aspetta(tester);
      expect(find.byType(SchermataConversazione), findsOneWidget);
      expect(find.text('Anche io a Porto a ottobre!'), findsOneWidget);
    });

    testWidgets('rifiutare chiede conferma, e non lo dice a chi ha chiesto', (
      tester,
    ) async {
      ambiente.server
        ..profiliPubblici.add(profilo(andrea, 'Andrea'))
        ..collegamenti[andrea] = {
          'stato': 'richiesto',
          'da_me': false,
          'messaggio': 'Ciao!',
          'chiesto_il': fa(const Duration(hours: 2)),
          'risposto_il': null,
        };
      await dentro(
        tester,
        const SchermataProfiloAltrui(utenteId: andrea, nome: 'Andrea'),
      );

      await tester.tap(find.text('Rifiuta'));
      await tester.pumpAndSettle();
      expect(find.text('Rifiutare la richiesta di Andrea?'), findsOneWidget);
      expect(
        find.text(
          'Non glielo diciamo: vedrà solo che la richiesta non è stata '
          'accettata.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Rifiuta').last);
      await aspetta(tester);

      expect(ambiente.server.collegamenti[andrea]!['stato'], 'rifiutato');
      expect(ambiente.server.collegamenti[andrea]!['messaggio'], isNull);
      // Per chi ha rifiutato non c'è più niente fra voi: può chiedere lui.
      expect(find.text('Chiedi di collegarvi'), findsOneWidget);
      expect(
        (await eventi(tester)).where((e) => e.startsWith('collegamento_')),
        isEmpty,
      );
    });

    testWidgets('due richieste incrociate sono un sì; fra compagni di viaggio '
        'l\'evento lo dice', (tester) async {
      ambiente.server.profiliPubblici.add(profilo(teresa, 'Teresa'));
      await dentro(
        tester,
        const SchermataProfiloAltrui(utenteId: teresa, nome: 'Teresa'),
      );
      await tester.runAsync(
        () => ambiente.db
            .into(ambiente.db.partecipazioni)
            .insert(
              PartecipazioniCompanion.insert(
                id: 'p-teresa',
                versione: 1,
                scaricatoIl: DateTime.now(),
                viaggioId: 'v-lisbona',
                utenteId: teresa,
                ruolo: 'partecipante',
                stato: 'uscito',
              ),
            ),
      );
      // Mentre si guarda il profilo, Teresa chiede a sua volta.
      ambiente.server.collegamenti[teresa] = {
        'stato': 'richiesto',
        'da_me': false,
        'messaggio': null,
        'chiesto_il': fa(const Duration(minutes: 1)),
        'risposto_il': null,
      };

      await tester.tap(find.text('Chiedi di collegarvi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Invia la richiesta'));
      await aspetta(tester);

      expect(ambiente.server.collegamenti[teresa]!['stato'], 'accettato');
      expect(
        await eventi(tester),
        contains('${Eventi.collegamentoAccettato} {"compagni":true}'),
      );
      expect(find.text('Scrivi a Teresa'), findsOneWidget);
    });

    testWidgets('collegati, da «…» si toglie il collegamento', (tester) async {
      ambiente.server
        ..profiliPubblici.add(profilo(teresa, 'Teresa'))
        ..collegamenti[teresa] = collegati();
      await dentro(
        tester,
        const SchermataProfiloAltrui(utenteId: teresa, nome: 'Teresa'),
      );

      await tester.tap(
        find.bySemanticsLabel('Segnala, blocca o togli il collegamento'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Togli il collegamento'));
      await tester.pumpAndSettle();
      expect(find.text('Togliere il collegamento con Teresa?'), findsOneWidget);
      await tester.tap(find.text('Togli'));
      await aspetta(tester);

      expect(ambiente.server.collegamenti, isEmpty);
      expect(find.text('Chiedi di collegarvi'), findsOneWidget);
      expect(find.text('COLLEGATI'), findsNothing);
    });

    testWidgets('senza rete il pulsante si spegne e dice perché', (
      tester,
    ) async {
      ambiente.server.profiliPubblici.add(profilo(teresa, 'Teresa'));
      await dentro(
        tester,
        const SchermataProfiloAltrui(utenteId: teresa, nome: 'Teresa'),
      );
      ambiente.rete.disponibile = false;
      await tester.pumpAndSettle();

      expect(find.text(motivoSenzaRete), findsOneWidget);
      await tester.tap(find.text('Chiedi di collegarvi'));
      await tester.pumpAndSettle();
      expect(find.text('Collegarti con Teresa?'), findsNothing);
    });
  });

  group('Viaggiatori: collegamenti e messaggi', () {
    void quattroPersone() => ambiente.server
      ..profiliPubblici.addAll([
        profilo(teresa, 'Teresa'),
        profilo(andrea, 'Andrea'),
        profilo(luca, 'Luca'),
        profilo(sara, 'Sara'),
      ])
      ..collegamenti.addAll({
        teresa: collegati(),
        andrea: {
          'stato': 'richiesto',
          'da_me': false,
          'messaggio': 'Ti va di scambiare due consigli?',
          'chiesto_il': fa(const Duration(days: 1)),
          'risposto_il': null,
        },
        luca: {
          'stato': 'richiesto',
          'da_me': true,
          'messaggio': null,
          'chiesto_il': fa(const Duration(minutes: 5)),
          'risposto_il': null,
        },
        sara: {
          'stato': 'rifiutato',
          'da_me': true,
          'messaggio': null,
          'chiesto_il': fa(const Duration(days: 4)),
          'risposto_il': fa(const Duration(days: 3)),
        },
      })
      ..messaggi.addAll([
        messaggio('m1', teresa, 'Nishiki Market la mattina presto.'),
        messaggio(
          'm2',
          teresa,
          'E gli okonomiyaki a Osaka, da non perdere.',
          letto: false,
          fa_: const Duration(minutes: 10),
        ),
      ]);

    testWidgets('le schede dicono quante richieste e quante conversazioni da '
        'leggere; si accetta e si ritira da lì', (tester) async {
      quattroPersone();
      await dentro(tester, const SchermataCommunity());
      expect(find.text('Collegamenti · 1'), findsOneWidget);
      expect(find.text('Messaggi · 1'), findsOneWidget);

      await tester.tap(find.text('Collegamenti · 1'));
      await aspetta(tester);
      expect(find.text('RICEVUTE · 1'), findsOneWidget);
      expect(find.text('Ti va di scambiare due consigli?'), findsOneWidget);
      expect(find.text('COLLEGATI · 1'), findsOneWidget);
      expect(find.text('INVIATE · 2'), findsOneWidget);
      expect(find.text('in attesa, da oggi'), findsOneWidget);
      expect(find.text('non accettata'), findsOneWidget);

      await tester.tap(find.text('Accetta'));
      await aspetta(tester);
      expect(find.text('COLLEGATI · 2'), findsOneWidget);
      expect(find.text('Collegamenti'), findsOneWidget);
      expect(
        await eventi(tester),
        contains('${Eventi.collegamentoAccettato} {"compagni":false}'),
      );

      await tester.tap(find.text('Ritira'));
      await aspetta(tester);
      expect(ambiente.server.collegamenti.containsKey(luca), isFalse);
      await tester.tap(find.text('Togli'));
      await aspetta(tester);
      expect(ambiente.server.collegamenti.containsKey(sara), isFalse);
      expect(find.text('INVIATE · 2'), findsNothing);
    });

    testWidgets('Messaggi: una riga per conversazione, anche quella finita; '
        'aperta, è letta', (tester) async {
      quattroPersone();
      ambiente.server
        ..accountChiusi.add(chiuso)
        ..messaggi.add(
          messaggio(
            'm3',
            chiuso,
            'Preferisco non dirlo, scusa.',
            mio: true,
            fa_: const Duration(days: 8),
          ),
        );
      await dentro(tester, const SchermataCommunity());

      await tester.tap(find.text('Messaggi · 1'));
      await aspetta(tester);
      expect(
        find.text('E gli okonomiyaki a Osaka, da non perdere.'),
        findsOneWidget,
      );
      expect(find.text('Account chiuso'), findsOneWidget);
      expect(find.text('Non siete più collegati'), findsOneWidget);

      await tester.tap(find.text('Teresa'));
      await aspetta(tester);
      expect(find.byType(SchermataConversazione), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Indietro'));
      await aspetta(tester);
      expect(find.text('Messaggi'), findsOneWidget);
      expect(find.text('Messaggi · 1'), findsNothing);
    });
  });

  group('una conversazione', () {
    void conTeresa() => ambiente.server
      ..profiliPubblici.add(profilo(teresa, 'Teresa'))
      ..utenti.add({
        'id': teresa,
        'nome': 'Teresa',
        'versione': 1,
        'eliminato_il': null,
      })
      ..collegamenti[teresa] = collegati();

    testWidgets('la prima volta, le righe di prudenza; poi mai più', (
      tester,
    ) async {
      conTeresa();
      await dentro(
        tester,
        const SchermataConversazione(utenteId: teresa, nome: 'Teresa'),
      );
      expect(find.text('Prima di incontrarvi'), findsOneWidget);
      expect(
        find.text('La prima volta vedetevi in un posto pubblico, di giorno.'),
        findsOneWidget,
      );
      expect(
        find.text('Siete collegati: scrivi tu per primo.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Ho capito'));
      await aspetta(tester);
      expect(find.text('Prima di incontrarvi'), findsNothing);

      await ambiente.monta(
        tester,
        daQui(const SchermataConversazione(utenteId: teresa, nome: 'Teresa')),
      );
      await apriDaQui(tester);
      expect(find.byType(SchermataConversazione), findsOneWidget);
      expect(find.text('Prima di incontrarvi'), findsNothing);
    });

    testWidgets('si scrive; un messaggio che non parte si riprova con lo '
        'stesso id', (tester) async {
      conTeresa();
      await tester.runAsync(ambiente.archivio.segnaPrudenzaVista);
      await dentro(
        tester,
        const SchermataConversazione(utenteId: teresa, nome: 'Teresa'),
      );

      ambiente.server.percorsi['POST /rest/v1/rpc/scrivi'] = (_) async =>
          risposta({'code': 'XX000', 'message': 'guasto'}, 500);
      await tester.enterText(find.byType(TextField), 'Ciao Teresa!');
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Invia'));
      await aspetta(tester);
      expect(find.text('Ciao Teresa!'), findsOneWidget);
      expect(find.text('Non inviato · Riprova'), findsOneWidget);
      expect(ambiente.server.messaggi, isEmpty);

      ambiente.server.percorsi.remove('POST /rest/v1/rpc/scrivi');
      await tester.tap(find.text('Non inviato · Riprova'));
      await aspetta(tester);
      expect(find.text('Non inviato · Riprova'), findsNothing);
      expect(ambiente.server.messaggi.single['testo'], 'Ciao Teresa!');
      final ids = {
        for (final r in ambiente.server.chiamate('POST', '/rest/v1/rpc/scrivi'))
          corpoDi(r)['p_id'],
      };
      expect(ids, hasLength(1));
    });

    testWidgets('senza rete non si scrive, e lo dice', (tester) async {
      conTeresa();
      await tester.runAsync(ambiente.archivio.segnaPrudenzaVista);
      await dentro(
        tester,
        const SchermataConversazione(utenteId: teresa, nome: 'Teresa'),
      );
      ambiente.rete.disponibile = false;
      await tester.pumpAndSettle();
      expect(find.text(motivoSenzaRete), findsOneWidget);
    });

    testWidgets('un messaggio ricevuto tenuto premuto si copia o si segnala; '
        'con «Blocca anche» la conversazione si chiude', (tester) async {
      conTeresa();
      ambiente.server.messaggi.addAll([
        messaggio('mio', teresa, 'Qualche consiglio sul cibo?', mio: true),
        messaggio(
          'suo',
          teresa,
          'Nishiki Market la mattina presto.',
          fa_: const Duration(minutes: 30),
        ),
      ]);
      await tester.runAsync(ambiente.archivio.segnaPrudenzaVista);
      await dentro(
        tester,
        daQui(const SchermataConversazione(utenteId: teresa, nome: 'Teresa')),
      );
      await apriDaQui(tester);

      // Il proprio si copia soltanto.
      await tester.longPress(find.text('Qualche consiglio sul cibo?'));
      await tester.pumpAndSettle();
      expect(find.text('Copia'), findsOneWidget);
      expect(find.text('Segnala il messaggio'), findsNothing);
      // Il menu si chiude toccando fuori.
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Nishiki Market la mattina presto.'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Messaggio di Teresa · '), findsOneWidget);
      await tester.tap(find.text('Segnala il messaggio'));
      await tester.pumpAndSettle();
      expect(find.text('Segnala Teresa'), findsOneWidget);
      await tester.tap(find.text('Messaggi molesti o minacce'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Invia la segnalazione'));
      await aspetta(tester);
      // «È arrivata», poi si torna indietro.
      expect(find.text('È arrivata'), findsOneWidget);
      await tester.tap(find.byType(PulsanteIndietro).last);
      await aspetta(tester);

      final mandata = ambiente.server.segnalate.single;
      expect(mandata['p_tipo'], 'messaggio');
      expect(mandata['p_oggetto'], 'suo');
      expect(mandata['p_blocca'], isTrue);
      expect(find.byType(SchermataConversazione), findsNothing);
      expect(find.text('Apri'), findsOneWidget);
    });

    testWidgets('una conversazione finita resta, senza scrivere, e si toglie', (
      tester,
    ) async {
      ambiente.server
        ..accountChiusi.add(chiuso)
        ..messaggi.addAll([
          messaggio(
            'c1',
            chiuso,
            'Ciao! Anche tu a Vienna a dicembre?',
            mio: true,
            fa_: const Duration(days: 16),
          ),
          messaggio(
            'c2',
            chiuso,
            'Tu dove dormi?',
            tolto: true,
            fa_: const Duration(days: 12),
          ),
        ]);
      await dentro(
        tester,
        daQui(const SchermataConversazione(utenteId: chiuso, nome: null)),
      );
      await apriDaQui(tester);

      expect(find.text('Account chiuso'), findsOneWidget);
      expect(find.text('Ciao! Anche tu a Vienna a dicembre?'), findsOneWidget);
      expect(find.text('Messaggio tolto da chi modera'), findsOneWidget);
      expect(find.text('Tu dove dormi?'), findsNothing);
      expect(
        find.textContaining('Non siete più collegati.', findRichText: true),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);
      // Chi chiude l'account non si segnala né si blocca: c'è solo togliere.
      await tester.tap(
        find.bySemanticsLabel('Segnala o togli la conversazione'),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Blocca'), findsNothing);
      // Il menu si chiude toccando fuori.
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Togli la conversazione'));
      await tester.pumpAndSettle();
      expect(find.text('Togliere la conversazione?'), findsOneWidget);
      await tester.tap(find.text('Togli'));
      await aspetta(tester);

      expect(ambiente.server.messaggi, isEmpty);
      expect(find.byType(SchermataConversazione), findsNothing);
    });

    testWidgets('da «…» si toglie il collegamento, e la conversazione si '
        'chiude', (tester) async {
      conTeresa();
      ambiente.server.messaggi.add(messaggio('m1', teresa, 'Ciao!'));
      await tester.runAsync(ambiente.archivio.segnaPrudenzaVista);
      await dentro(
        tester,
        daQui(const SchermataConversazione(utenteId: teresa, nome: 'Teresa')),
      );
      await apriDaQui(tester);

      await tester.tap(
        find.bySemanticsLabel('Segnala, blocca o togli il collegamento'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Togli il collegamento'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Togli'));
      await aspetta(tester);

      expect(ambiente.server.collegamenti, isEmpty);
      expect(find.byType(SchermataConversazione), findsNothing);
    });
  });
}
