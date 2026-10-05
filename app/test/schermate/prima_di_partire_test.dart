import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/aspetto/elementi.dart';
import 'package:trolley/aspetto/formati.dart';
import 'package:trolley/dati/errori.dart';
import 'package:trolley/dati/mappe.dart';
import 'package:trolley/dominio/calendario.dart';
import 'package:trolley/schermate/prima_di_partire.dart';
import 'package:trolley/schermate/viaggio.dart';

import '../aiuti.dart';

/// Prima di partire (fase 3.3; tela, 56, 57, 90–92).
void main() {
  late Ambiente ambiente;

  setUp(() => ambiente = Ambiente());
  tearDown(() => ambiente.chiudi());

  final oggi = soloData(DateTime.now());
  String fra(int giorni) => scriviData(oggi.add(Duration(days: giorni)));

  /// Un viaggio a Porto che comincia fra [inizio] giorni, con due tappe: una
  /// con il posto e una senza.
  Future<void> viaggio(WidgetTester tester, {int inizio = 2}) async {
    ambiente.server
      ..viaggi.add(
        rigaViaggio(
          'v',
          stato: 'definito',
          inizio: fra(inizio),
          fine: fra(inizio + 1),
        ),
      )
      ..partecipazioni.add(rigaPartecipazione('v'))
      ..giorni.addAll([
        rigaGiorno('v', fra(inizio), '10:00:00', '24:00:00', id: 'g1'),
        rigaGiorno('v', fra(inizio + 1), '00:00:00', '18:00:00', id: 'g2'),
      ])
      ..tappe.addAll([
        rigaDiTappa(
          't-lello',
          viaggio: 'v',
          giorno: 'g1',
          lat: 41.1469,
          lon: -8.6149,
        ),
        rigaDiTappa(
          't-cantinho',
          viaggio: 'v',
          giorno: 'g2',
          titolo: 'Pranzo da Cantinho',
          luogo: 'Rua das Flores',
        ),
      ])
      ..voci.addAll([
        rigaDiVoce('v1', viaggio: 'v', testo: 'Passaporto'),
        rigaDiVoce('v2', viaggio: 'v', testo: 'Spazzolino', spuntata: true),
        rigaDiVoce('v3', viaggio: 'v', testo: 'Adattatore', tipo: 'viaggio'),
      ])
      ..tassi.add(rigaTasso('USD', 1.1, fra(0)));
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

  Future<void> giro(WidgetTester tester) async {
    await ambiente.monta(tester, const SchermataPrimaDiPartire(viaggioId: 'v'));
    await aspetta(tester);
  }

  Finder pulsante(String etichetta) => find.descendant(
    of: find.byType(PulsanteGrande),
    matching: find.text(etichetta),
  );

  /// Porta in vista «Preparalo», in fondo al giro.
  Future<void> alPulsante(WidgetTester tester) async {
    final preparalo = pulsante('Preparalo per l\'uso senza rete');
    await tester.scrollUntilVisible(preparalo, 200);
    await tester.ensureVisible(preparalo);
    await tester.pumpAndSettle();
  }

  Future<List<(String, Map<String, dynamic>)>> eventi(
    WidgetTester tester,
  ) async => [
    for (final e in await ambiente.eventi(tester))
      (e.nome, jsonDecode(e.proprieta) as Map<String, dynamic>),
    for (final r in ambiente.server.chiamate('POST', '/rest/v1/evento'))
      for (final e in (jsonDecode(r.body) as List).cast<Map<String, dynamic>>())
        (e['nome'] as String, e['proprieta'] as Map<String, dynamic>),
  ];

  group('nel viaggio', () {
    testWidgets('da due giorni prima, sotto il biglietto, con quante cose '
        'chiedono uno sguardo', (tester) async {
      await viaggio(tester);
      await ambiente.monta(tester, const SchermataViaggio(viaggioId: 'v'));
      await aspetta(tester);

      expect(find.text('Prima di partire'), findsOneWidget);
      // Nessun documento, la valigia a metà, una tappa senza posto, non
      // ancora preparato.
      expect(
        find.text('Un giro di controllo: 4 cose da guardare.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Prima di partire'));
      await aspetta(tester);
      expect(
        find.text(
          'Si parte ${giornoDellaSettimana(oggi.add(const Duration(days: 2)))}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('tre giorni prima ancora no', (tester) async {
      await viaggio(tester, inizio: 3);
      await ambiente.monta(tester, const SchermataViaggio(viaggioId: 'v'));
      await aspetta(tester);

      expect(find.text('Prima di partire'), findsNothing);
    });
  });

  testWidgets('il giro di controllo dice cosa manca, riga per riga', (
    tester,
  ) async {
    await viaggio(tester, inizio: 1);
    await giro(tester);

    expect(find.text('Si parte domani'), findsOneWidget);
    expect(
      find.textContaining('Porto · domani, arrivi alle 10:00.'),
      findsOneWidget,
    );
    expect(find.textContaining('Nessuno sul telefono.'), findsOneWidget);
    expect(
      find.text(
        '1 di 2 in valigia. Manca Passaporto. Una voce della lista del '
        'viaggio non la porta nessuno.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Una tappa non si vedrà sulla mappa: aggiungi dov\'è.'),
      findsOneWidget,
    );
    await alPulsante(tester);
    expect(pulsante('Preparalo per l\'uso senza rete'), findsOneWidget);
  });

  testWidgets('prepararlo scarica il viaggio, si misura, e dice cosa c\'è sul '
      'telefono; tornando, la riga è a posto', (tester) async {
    await viaggio(tester);
    await giro(tester);
    final prima = ambiente.server.chiamate('GET', '/rest/v1/tappa').length;

    await alPulsante(tester);
    await tester.tap(pulsante('Preparalo per l\'uso senza rete'));
    await aspetta(tester);

    expect(
      ambiente.server.chiamate('GET', '/rest/v1/tappa'),
      hasLength(prima + 1),
    );
    expect(find.text('Pronto anche senza rete'), findsOneWidget);
    expect(
      find.textContaining(
        'Tutto il viaggio a Porto è su questo telefono, '
        'aggiornato oggi alle',
      ),
      findsOneWidget,
    );
    expect(find.text('Il programma di tutti e 2 i giorni'), findsOneWidget);
    expect(find.text('Gli indirizzi delle tappe'), findsOneWidget);
    // Nessun documento: non si dice che ci sono.
    expect(find.text('I documenti (sono già qui)'), findsNothing);
    expect(find.text('Le spese'), findsOneWidget);
    expect(find.text('I tassi di cambio di oggi'), findsOneWidget);
    expect(
      find.textContaining('La mappa e la navigazione restano dalla rete'),
      findsOneWidget,
    );
    final preparato = (await eventi(tester))
        .singleWhere((e) => e.$1 == 'viaggio_preparato')
        .$2;
    expect(preparato, {'viaggio_id': 'v', 'giorni_alla_partenza': 2});

    await tester.tap(find.bySemanticsLabel('Indietro').last);
    await aspetta(tester);
    expect(find.text('Pronto anche senza rete'), findsOneWidget);
    expect(find.textContaining('Aggiornato oggi alle'), findsOneWidget);
    expect(pulsante('Preparalo per l\'uso senza rete'), findsNothing);
  });

  testWidgets('senza rete il giro si legge, ma preparare e cercare i posti lo '
      'dicono prima', (tester) async {
    await viaggio(tester);
    ambiente.rete.disponibile = false;
    await giro(tester);

    await alPulsante(tester);
    expect(find.text(motivoSenzaRete), findsOneWidget);
    expect(
      find.textContaining('Per cercarlo serve la connessione.'),
      findsOneWidget,
    );
    await tester.tap(pulsante('Preparalo per l\'uso senza rete'));
    await aspetta(tester);
    expect(find.text('Pronto anche senza rete'), findsNothing);
    final aperture = [
      for (final e in await eventi(tester))
        if (e.$1 == 'apertura_senza_rete') e.$2['schermata'],
    ];
    expect(aperture, ['prima_di_partire']);
  });

  testWidgets('«Sistemale»: le tappe senza posto, e il posto cercato si '
      'salva subito', (tester) async {
    ambiente.mappe.luoghi.add(
      const Luogo(
        nome: 'Cantinho do Avillez',
        indirizzo: 'Rua Mouzinho da Silveira 166, Porto',
        posto: (lat: 41.1427, lon: -8.6131),
      ),
    );
    await viaggio(tester);
    await giro(tester);

    await tester.tap(find.text('Sistemale'));
    await aspetta(tester);
    expect(find.text('Tappe senza un posto'), findsWidgets);
    expect(find.text('Pranzo da Cantinho'), findsOneWidget);
    expect(find.text('Rua das Flores, scritto a mano'), findsOneWidget);
    // Quella col posto non c'è.
    expect(find.text('Livraria Lello'), findsNothing);

    await tester.tap(find.text('Pranzo da Cantinho'));
    await aspetta(tester);
    // «Dove?» cerca subito quello che c'era scritto.
    expect(ambiente.mappe.cercati, ['Rua das Flores']);
    await tester.enterText(find.byType(TextField).last, 'Cantinho');
    await tester.pump(const Duration(milliseconds: 500));
    await aspetta(tester);
    await tester.tap(find.text('Cantinho do Avillez'));
    await aspetta(tester);

    final tappa = ambiente.server.tappe.firstWhere(
      (t) => t['id'] == 't-cantinho',
    );
    expect((tappa['lat'], tappa['lon']), (41.1427, -8.6131));
    // Il posto ha un nome suo, diverso dal titolo: va nel «Dove».
    expect(
      tappa['luogo_nome'],
      'Cantinho do Avillez, Rua Mouzinho da Silveira 166, Porto',
    );
    expect(
      find.text('Adesso hanno tutte un posto sulla mappa.'),
      findsOneWidget,
    );
  });
}
