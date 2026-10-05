import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dati/posizione.dart';
import 'package:trolley/dominio/calendario.dart';
import 'package:trolley/schermate/adesso.dart';

import '../aiuti.dart';

/// La posizione per la verifica (fase 3.4; tela, 58 e 59): si dice a cosa
/// serve prima di chiederla, si dice una volta che senza il viaggio non sarà
/// verificato, e se si è sul posto al server va solo il sì.
void main() {
  late Ambiente ambiente;

  setUp(() => ambiente = Ambiente());
  tearDown(() => ambiente.chiudi());

  final oggi = soloData(DateTime.now());
  String fra(int giorni) => scriviData(oggi.add(Duration(days: giorni)));
  DateTime alle(int ore) => DateTime(oggi.year, oggi.month, oggi.day, ore);

  /// Porto, cominciato ieri.
  Future<void> viaggio(WidgetTester tester) async {
    ambiente.server
      ..viaggi.add(
        rigaViaggio('v', stato: 'definito', inizio: fra(-1), fine: fra(1)),
      )
      ..partecipazioni.add(rigaPartecipazione('v'))
      ..giorni.addAll([
        rigaGiorno('v', fra(-1), '10:00:00', '24:00:00', id: 'g1'),
        rigaGiorno('v', fra(0), '09:00:00', '24:00:00', id: 'g2'),
        rigaGiorno('v', fra(1), '00:00:00', '18:00:00', id: 'g3'),
      ]);
    await ambiente.accedi(tester: tester);
    await tester.runAsync(ambiente.archivio.aggiornaCopia);
  }

  Future<void> aspetta(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> adesso(WidgetTester tester) async {
    await ambiente.monta(
      tester,
      SchermataAdesso(viaggioId: 'v', orologio: () => alle(11)),
    );
    await aspetta(tester);
  }

  Future<List<Map<String, dynamic>>> permessi(WidgetTester tester) async => [
    for (final e in await ambiente.eventi(tester))
      if (e.nome == 'permesso_posizione')
        jsonDecode(e.proprieta) as Map<String, dynamic>,
    for (final r in ambiente.server.chiamate('POST', '/rest/v1/evento'))
      for (final e in (jsonDecode(r.body) as List).cast<Map<String, dynamic>>())
        if (e['nome'] == 'permesso_posizione')
          e['proprieta'] as Map<String, dynamic>,
  ];

  testWidgets('il primo giorno «Adesso» dice a cosa serve la posizione; con '
      '«Continua» la chiede il telefono, e a Porto si è sul posto', (
    tester,
  ) async {
    ambiente.posizione
      ..stato = PermessoPosizione.daChiedere
      ..dove = (lat: 41.1470, lon: -8.6160);
    await viaggio(tester);
    await adesso(tester);

    expect(find.text('Sei davvero a Porto?'), findsOneWidget);
    expect(
      find.textContaining('al server arriva solo «sì» o «no»'),
      findsOneWidget,
    );
    expect(ambiente.posizione.richieste, 0);

    await tester.tap(find.text('Continua'));
    await aspetta(tester);

    expect(ambiente.posizione.richieste, 1);
    expect(find.text('Sei davvero a Porto?'), findsNothing);
    final segnato = ambiente.server
        .chiamate('POST', '/rest/v1/rpc/segna_sul_posto')
        .single;
    // Solo il viaggio: mai dove.
    expect(corpoDi(segnato), {'p_viaggio': 'v'});
    expect(await permessi(tester), [
      {'viaggio_id': 'v', 'esito': 'concesso'},
    ]);
  });

  testWidgets('«Non ora»: niente richiesta, e fino a domani non si richiede '
      'da sola', (tester) async {
    ambiente.posizione.stato = PermessoPosizione.daChiedere;
    await viaggio(tester);
    await adesso(tester);

    await tester.tap(find.text('Non ora'));
    await aspetta(tester);
    expect(ambiente.posizione.richieste, 0);
    expect(await permessi(tester), [
      {'viaggio_id': 'v', 'esito': 'non_ora'},
    ]);

    await adesso(tester);
    expect(find.text('Sei davvero a Porto?'), findsNothing);
  });

  testWidgets('detto di no al telefono, si dice una volta che il viaggio non '
      'sarà verificato; dopo non si ripete', (tester) async {
    ambiente.posizione
      ..stato = PermessoPosizione.daChiedere
      ..risposta = PermessoPosizione.negato;
    await viaggio(tester);
    await adesso(tester);

    await tester.tap(find.text('Continua'));
    await aspetta(tester);

    expect(find.text('Va bene anche così'), findsOneWidget);
    expect(
      find.textContaining(
        'Questo viaggio però non potrà essere verificato,',
        findRichText: true,
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Apri Impostazioni'));
    await aspetta(tester);
    expect(ambiente.posizione.impostazioniAperte, 1);
    expect(find.text('Va bene anche così'), findsNothing);
    expect(await permessi(tester), [
      {'viaggio_id': 'v', 'esito': 'negato'},
    ]);

    await adesso(tester);
    expect(find.text('Va bene anche così'), findsNothing);
    expect(
      ambiente.server.chiamate('POST', '/rest/v1/rpc/segna_sul_posto'),
      isEmpty,
    );
  });

  testWidgets('con il permesso già dato non si chiede niente, e lontano dalla '
      'meta non si segna niente', (tester) async {
    ambiente.posizione.dove = (lat: 38.7223, lon: -9.1393); // Lisbona
    await viaggio(tester);
    await adesso(tester);

    expect(find.text('Sei davvero a Porto?'), findsNothing);
    expect(ambiente.posizione.volteQui, 1);
    expect(
      ambiente.server.chiamate('POST', '/rest/v1/rpc/segna_sul_posto'),
      isEmpty,
    );
  });
}
