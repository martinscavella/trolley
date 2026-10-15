import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dati/errori.dart';
import 'package:trolley/dati/posizione.dart';
import 'package:trolley/dominio/calendario.dart';
import 'package:trolley/misurazione/misurazione.dart';
import 'package:trolley/schermate/community.dart';
import 'package:trolley/schermate/presenza.dart';

import '../aiuti.dart';

/// Chi c'è in città dal telefono (5.5; tela, 74, 79–81, 117 e 118): la
/// scheda in Community durante un viaggio in corso; prima del «sul posto»
/// non si accende, e lo dice; sul posto si accende con l'interruttore; accesa
/// mostra chi c'è, in ordine di nome e senza fino a quando, e si spegne.
void main() {
  late Ambiente ambiente;

  setUp(() => ambiente = Ambiente());
  tearDown(() => ambiente.chiudi());

  final oggi = soloData(DateTime.now());
  String fra(int giorni) => scriviData(oggi.add(Duration(days: giorni)));

  const andrea = 'eeeeeeee-5555-4555-8555-555555555555';
  const teresa = 'bbbbbbbb-2222-4222-8222-222222222222';

  Map<String, Object?> profilo(String id, String nome, List<String> paesi) => {
    'id': id,
    'nome': nome,
    'dal': '${DateTime.now().year}-03-01',
    'gusti': ['cibo'],
    'traguardi': 1,
    'viaggi': [
      for (final p in paesi)
        {
          'citta': null,
          'paese': p,
          'mese': '2025-05-01',
          'periodo': null,
          'giorni': 4,
          'verificato': false,
          'importato': false,
        },
    ],
  };

  Future<void> aspetta(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  /// Porto, da ieri a dopodomani, con il profilo pubblico acceso; [sulPosto]
  /// se il telefono ha già trovato la persona lì.
  Future<void> aPorto(WidgetTester tester, {bool sulPosto = true}) async {
    ambiente.server
      ..apriPartePubblica(telefono: '+393471234567')
      ..viaggi.add(
        rigaViaggio('v', stato: 'definito', inizio: fra(-1), fine: fra(2)),
      )
      ..partecipazioni.add(
        rigaPartecipazione('v')
          ..['sul_posto_il'] = sulPosto
              ? DateTime.now().toUtc().toIso8601String()
              : null,
      )
      ..giorni.addAll([
        rigaGiorno('v', fra(-1), '10:00:00', '24:00:00', id: 'g1'),
        rigaGiorno('v', fra(0), '00:00:00', '24:00:00', id: 'g2'),
        rigaGiorno('v', fra(1), '00:00:00', '24:00:00', id: 'g3'),
        rigaGiorno('v', fra(2), '00:00:00', '18:00:00', id: 'g4'),
      ]);
    ambiente.server.partePubblica['attivo'] = true;
    await ambiente.accedi(tester: tester);
    await tester.runAsync(ambiente.archivio.aggiornaCopia);
  }

  /// Tocca [cosa] dopo averlo portato sullo schermo.
  Future<void> tocca(WidgetTester tester, Finder cosa) async {
    await tester.ensureVisible(cosa);
    await tester.pumpAndSettle();
    await tester.tap(cosa);
  }

  Future<void> apriLaPresenza(WidgetTester tester) async {
    await ambiente.monta(tester, const SchermataPresenza(viaggioId: 'v'));
    await aspetta(tester);
  }

  Future<List<String>> eventi(WidgetTester tester) async => [
    for (final e in await ambiente.eventi(tester)) '${e.nome} ${e.proprieta}',
    for (final r in ambiente.server.chiamate('POST', '/rest/v1/evento'))
      for (final e in (jsonDecode(r.body) as List).cast<Map<String, dynamic>>())
        '${e['nome']} ${jsonEncode(e['proprieta'])}',
  ];

  testWidgets('in Community, durante il viaggio, c\'è «Chi c\'è a Porto»', (
    tester,
  ) async {
    await aPorto(tester);
    await ambiente.monta(tester, const SchermataCommunity());
    await aspetta(tester);

    expect(find.text('Chi c\'è a Porto'), findsOneWidget);
    await tester.tap(find.text('Chi c\'è a Porto'));
    await aspetta(tester);
    expect(find.byType(SchermataPresenza), findsOneWidget);
  });

  testWidgets('senza un viaggio in corso la scheda non c\'è', (tester) async {
    ambiente.server
      ..apriPartePubblica(telefono: '+393471234567')
      ..partePubblica['attivo'] = true
      ..viaggi.add(
        rigaViaggio('v', stato: 'definito', inizio: fra(5), fine: fra(7)),
      )
      ..partecipazioni.add(rigaPartecipazione('v'));
    await ambiente.accedi(tester: tester);
    await tester.runAsync(ambiente.archivio.aggiornaCopia);
    await ambiente.monta(tester, const SchermataCommunity());
    await aspetta(tester);
    expect(find.textContaining('Chi c\'è a'), findsNothing);
  });

  testWidgets('prima del «sul posto» non si accende: «Quando sarai a Porto»', (
    tester,
  ) async {
    await aPorto(tester, sulPosto: false);
    await apriLaPresenza(tester);

    expect(
      find.text('Quando sarai a Porto', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.byType(Switch, skipOffstage: false), findsNothing);
    expect(
      find.textContaining('Gli altri vedono «a Porto adesso», non fino a'),
      findsOneWidget,
    );
    // Aprendo la schermata il telefono ha guardato dov'è.
    expect(ambiente.posizione.volteQui, 1);
    expect(ambiente.server.presenza, isNull);
  });

  testWidgets('aperta a Porto, il telefono trova la persona e si può '
      'accendere', (tester) async {
    ambiente.posizione.dove = (lat: 41.1470, lon: -8.6160);
    await aPorto(tester, sulPosto: false);
    await apriLaPresenza(tester);

    expect(
      find.text('Quando sarai a Porto', skipOffstage: false),
      findsNothing,
    );
    expect(
      find.textContaining('Mostrami a Porto', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('senza il permesso di posizione lo dice, e apre le '
      'Impostazioni', (tester) async {
    ambiente.posizione.stato = PermessoPosizione.negato;
    await tester.runAsync(ambiente.archivio.segnaPosizioneNegataDetta);
    await aPorto(tester, sulPosto: false);
    await apriLaPresenza(tester);

    expect(
      find.text('Senza la posizione non si accende', skipOffstage: false),
      findsOneWidget,
    );
    await tocca(tester, find.text('Apri Impostazioni'));
    await tester.pumpAndSettle();
    expect(ambiente.posizione.impostazioniAperte, 1);
  });

  testWidgets('sul posto si accende; accesa mostra chi c\'è, in ordine di '
      'nome e senza fino a quando, e si spegne', (tester) async {
    final persone = [
      profilo(andrea, 'Andrea', ['PT', 'ES', 'FR']),
      profilo(teresa, 'Teresa', ['JP']),
    ];
    ambiente.server
      ..inCitta.addAll(persone)
      ..profiliPubblici.addAll(persone);
    ambiente.server.collegamenti[teresa] = {
      'stato': 'accettato',
      'da_me': true,
      'messaggio': null,
      'chiesto_il': DateTime.now().toUtc().toIso8601String(),
      'risposto_il': DateTime.now().toUtc().toIso8601String(),
    };
    await aPorto(tester);
    await apriLaPresenza(tester);

    expect(
      find.textContaining(
        'il telefono ti ha trovato a Porto',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    await tocca(tester, find.byType(Switch));
    await aspetta(tester);

    expect(ambiente.server.presenza!['viaggio_id'], 'v');
    expect(
      await eventi(tester),
      contains('${Eventi.presenzaAttivata} {"presenti":2}'),
    );
    expect(find.text('2 viaggiatori, oltre a te'), findsOneWidget);
    expect(
      find.textContaining('Sei visibile a Porto', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('3 paesi', skipOffstage: false), findsOneWidget);
    expect(
      find.text('1 paese · già nei tuoi collegamenti', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('Collegati', skipOffstage: false), findsOneWidget);
    expect(find.text('Scrivi', skipOffstage: false), findsOneWidget);
    // Nessuna data degli altri.
    expect(find.textContaining('Fino al', skipOffstage: false), findsNothing);

    // Collegarsi da qui apre la richiesta (tela, 76).
    await tocca(tester, find.text('Collegati'));
    await tester.pumpAndSettle();
    expect(find.text('Collegarti con Andrea?'), findsOneWidget);
    await tester.tap(find.text('Invia la richiesta'));
    await aspetta(tester);
    expect(find.text('Richiesta inviata', skipOffstage: false), findsOneWidget);

    await tocca(tester, find.text('Spegni adesso'));
    await aspetta(tester);
    expect(ambiente.server.presenza, isNull);
    expect(await eventi(tester), contains('${Eventi.presenzaSpenta} {}'));
    expect(find.byType(Switch, skipOffstage: false), findsOneWidget);
  });

  testWidgets('da soli: «Per ora ci sei solo tu»', (tester) async {
    await aPorto(tester);
    await apriLaPresenza(tester);
    await tocca(tester, find.byType(Switch));
    await aspetta(tester);
    expect(
      find.text('Per ora ci sei solo tu', skipOffstage: false),
      findsOneWidget,
    );
    expect(
      await eventi(tester),
      contains('${Eventi.presenzaAttivata} {"presenti":0}'),
    );
  });

  testWidgets('senza rete non si accende, e lo dice', (tester) async {
    await aPorto(tester);
    await apriLaPresenza(tester);
    ambiente.rete.disponibile = false;
    await tester.pumpAndSettle();
    expect(find.text(motivoSenzaRete, skipOffstage: false), findsOneWidget);
    await tocca(tester, find.byType(Switch));
    await aspetta(tester);
    expect(ambiente.server.presenza, isNull);
  });
}
