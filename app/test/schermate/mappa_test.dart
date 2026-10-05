import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/aspetto/elementi.dart';
import 'package:trolley/aspetto/segni_mappa.dart';
import 'package:trolley/dati/mappe.dart';
import 'package:trolley/dati/posizione.dart';
import 'package:trolley/dominio/calendario.dart';
import 'package:trolley/dominio/navigazione.dart';
import 'package:trolley/schermate/giornata.dart';
import 'package:trolley/schermate/mappa.dart';
import 'package:trolley/schermate/navigazione.dart';

import '../aiuti.dart';

/// La mappa (fase 3.2, 08-mappa.md; tela, 50–56): le tappe di oggi in
/// ordine, la prossima da segnare o da raggiungere, tutto il viaggio a
/// colori, gli indirizzi senza rete; la navigazione con l'arrivo; il posto
/// di una tappa cercato in «Dove?».
void main() {
  late Ambiente ambiente;

  setUp(() => ambiente = Ambiente());
  tearDown(() => ambiente.chiudi());

  final oggi = soloData(DateTime.now());
  String fra(int giorni) => scriviData(oggi.add(Duration(days: giorni)));
  DateTime alle(int ore, [int minuti = 0]) =>
      DateTime(oggi.year, oggi.month, oggi.day, ore, minuti);

  const lello = (lat: 41.14686, lon: -8.61479);
  const torre = (lat: 41.14573, lon: -8.61391);
  const ribeira = (lat: 41.14063, lon: -8.61307);

  /// Oggi: il Duomo già fatto, Lello alle 10:30, la torre alle 12, la cena
  /// senza un posto. Domani la Ribeira.
  final giornata = [
    rigaDiTappa(
      'duomo',
      viaggio: 'v',
      giorno: 'g2',
      titolo: 'Sé do Porto',
      durata: 60,
      stato: 'completata',
      lat: 41.1428,
      lon: -8.6113,
    ),
    rigaDiTappa(
      'lello',
      viaggio: 'v',
      giorno: 'g2',
      ordine: 2,
      titolo: 'Livraria Lello',
      durata: 60,
      ora: '10:30:00',
      luogo: 'Rua das Carmelitas 144, Porto',
      lat: lello.lat,
      lon: lello.lon,
    ),
    rigaDiTappa(
      'torre',
      viaggio: 'v',
      giorno: 'g2',
      ordine: 3,
      titolo: 'Torre dos Clérigos',
      ora: '12:00:00',
      luogo: 'Rua de São Filipe de Nery',
      lat: torre.lat,
      lon: torre.lon,
    ),
    rigaDiTappa(
      'cena',
      viaggio: 'v',
      giorno: 'g2',
      ordine: 4,
      titolo: 'Cena',
      tipo: 'pasto',
      durata: 90,
      luogo: 'Rua das Flores',
    ),
    rigaDiTappa(
      'ribeira',
      viaggio: 'v',
      giorno: 'g3',
      titolo: 'Cais da Ribeira',
      tipo: 'passeggiata',
      durata: 60,
      lat: ribeira.lat,
      lon: ribeira.lon,
    ),
  ];

  /// Porto, cominciato ieri: oggi è il giorno 2 di 3. O fra un mese.
  Future<void> viaggio(WidgetTester tester, {int inizio = -1}) async {
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
        rigaGiorno('v', fra(inizio + 1), '09:00:00', '24:00:00', id: 'g2'),
        rigaGiorno('v', fra(inizio + 2), '00:00:00', '18:00:00', id: 'g3'),
      ])
      // Copie: il server finto cambia le righe che riceve.
      ..tappe.addAll([
        for (final t in giornata) {...t},
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

  Future<void> mappa(WidgetTester tester, {String? giorno}) async {
    await ambiente.monta(
      tester,
      SchermataMappa(
        viaggioId: 'v',
        giornoId: giorno,
        orologio: () => alle(10),
      ),
    );
    await aspetta(tester);
  }

  Finder segno(String id) => find.byKey(ValueKey('segno-$id'));

  /// Gli eventi in attesa e quelli già partiti, per nome.
  Future<List<(String, Map<String, dynamic>)>> eventi(
    WidgetTester tester,
  ) async => [
    for (final e in await ambiente.eventi(tester))
      (e.nome, jsonDecode(e.proprieta) as Map<String, dynamic>),
    for (final r in ambiente.server.chiamate('POST', '/rest/v1/evento'))
      for (final e in (jsonDecode(r.body) as List).cast<Map<String, dynamic>>())
        (e['nome'] as String, e['proprieta'] as Map<String, dynamic>),
  ];

  Future<Map<String, dynamic>> evento(WidgetTester tester, String nome) async =>
      (await eventi(tester)).singleWhere((e) => e.$1 == nome).$2;

  Future<String?> statoDi(WidgetTester tester, String id) async =>
      (await tester.runAsync(
        () => (ambiente.db.select(
          ambiente.db.tappe,
        )..where((t) => t.id.equals(id))).getSingle(),
      ))!.stato;

  group('la mappa del giorno', () {
    testWidgets('le tappe di oggi sulla mappa, numerate; quella senza posto '
        'si dice; la prossima in basso con «Portami», «Fatta», «Salta»', (
      tester,
    ) async {
      await viaggio(tester);
      await mappa(tester);

      // Tre di oggi hanno un posto; la cena no, e domani non c'è.
      expect(find.byType(SegnoSullaMappa), findsNWidgets(3));
      expect(segno('cena'), findsNothing);
      expect(segno('ribeira'), findsNothing);
      expect(find.textContaining('4 tappe · 1 senza posto'), findsOneWidget);
      expect(find.text('Oggi'), findsOneWidget);

      expect(find.text('Livraria Lello'), findsOneWidget);
      expect(find.text('Prossima · 10:30 · Visita · 1 h'), findsOneWidget);
      expect(find.text('Portami'), findsOneWidget);
      expect(find.text('Fatta'), findsOneWidget);
      expect(find.text('Salta'), findsOneWidget);
      expect(find.textContaining('Mappe finte'), findsOneWidget);
    });

    testWidgets('«Fatta» dalla mappa segna la tappa in un tocco, e la '
        'prossima diventa quella dopo', (tester) async {
      await viaggio(tester);
      await mappa(tester);

      await tester.tap(find.text('Fatta'));
      await aspetta(tester);

      expect(await statoDi(tester, 'lello'), 'completata');
      expect(find.text('Torre dos Clérigos'), findsOneWidget);
      final segnata = (await ambiente.eventi(tester))
          .where((e) => e.nome == 'tappa_marcata')
          .single;
      expect(jsonDecode(segnata.proprieta), {
        'viaggio_id': 'v',
        'durante_il_viaggio': true,
      });
    });

    testWidgets('toccare una tappa apre la sua scheda: ora, durata, tipo, '
        'dove; e da lì la tappa intera', (tester) async {
      await viaggio(tester);
      await mappa(tester);

      await tester.tap(segno('torre'));
      await tester.pumpAndSettle();

      expect(find.text('Torre dos Clérigos'), findsOneWidget);
      expect(find.text('ORA'), findsOneWidget);
      expect(find.text('12:00'), findsOneWidget);
      expect(find.text('1 h 30'), findsOneWidget);
      expect(find.text('Visita'), findsOneWidget);
      expect(find.text('Rua de São Filipe de Nery'), findsOneWidget);

      await tester.tap(find.text('Apri la tappa'));
      await tester.pumpAndSettle();
      expect(find.text('La tappa'), findsOneWidget);
    });

    testWidgets('tutto il viaggio: un colore per giorno, e le tappe senza '
        'posto si dicono invece di sparire', (tester) async {
      await viaggio(tester);
      await mappa(tester);

      await tester.tap(find.text('Tutto il viaggio'));
      await tester.pumpAndSettle();

      expect(find.byType(SegnoSullaMappa), findsNWidgets(4));
      expect(segno('ribeira'), findsOneWidget);
      expect(
        find.text(
          'Una tappa non ha un posto riconoscibile: sta nell\'itinerario, '
          'non qui.',
        ),
        findsOneWidget,
      );
      // Toccare un giorno torna a quel giorno.
      final domani = oggi.add(const Duration(days: 1));
      await tester.tap(find.textContaining('${domani.day}').last);
      await tester.pumpAndSettle();
      expect(find.byType(SegnoSullaMappa), findsOneWidget);
      expect(segno('ribeira'), findsOneWidget);
    });

    testWidgets('la mappa vista con delle tappe è la funzione usata, e '
        'quello che è costato si registra uscendo', (tester) async {
      await viaggio(tester);
      await mappa(tester);
      ambiente.mappe.scaricaRiquadri(24);

      await tester.pumpWidget(const SizedBox());
      await aspetta(tester);

      expect(await evento(tester, 'funzione_usata_nel_viaggio'), {
        'viaggio_id': 'v',
        'funzione': 'mappa',
      });
      expect(await evento(tester, 'consumo_mappe'), {
        'viaggio_id': 'v',
        'riquadri': 24,
        'ricerche': 0,
        'percorsi': 0,
      });
    });
  });

  group('quale viaggio', () {
    testWidgets('la mappa dice quale viaggio mostra, e lo si cambia '
        'dall\'alto: in corso, in programma, conclusi; le idee no', (
      tester,
    ) async {
      ambiente.server
        ..viaggi.addAll([
          rigaViaggio(
            'l',
            stato: 'definito',
            citta: 'Londra',
            paese: 'GB',
            inizio: fra(40),
            fine: fra(42),
          ),
          rigaViaggio('idea', citta: 'Oslo', paese: 'NO'),
        ])
        ..partecipazioni.addAll([
          rigaPartecipazione('l'),
          rigaPartecipazione('idea'),
        ])
        ..giorni.add(rigaGiorno('l', fra(40), '00:00:00', '24:00:00', id: 'lg'))
        ..tappe.add(
          rigaDiTappa(
            'ben',
            viaggio: 'l',
            giorno: 'lg',
            titolo: 'Big Ben',
            lat: 51.5007,
            lon: -0.1246,
          ),
        );
      await viaggio(tester);
      await mappa(tester);

      expect(find.text('Porto'), findsOneWidget);
      expect(segno('lello'), findsOneWidget);
      await tester.tap(find.text('Porto'));
      await tester.pumpAndSettle();

      expect(find.text('Quale viaggio?'), findsOneWidget);
      expect(find.text('IN CORSO'), findsOneWidget);
      expect(find.text('IN PROGRAMMA'), findsOneWidget);
      expect(find.text('Oslo'), findsNothing);
      expect(find.textContaining('5 tappe, 4 sulla mappa'), findsOneWidget);
      await tester.tap(find.text('Londra'));
      await aspetta(tester);

      expect(find.text('Quale viaggio?'), findsNothing);
      expect(find.text('Londra'), findsOneWidget);
      expect(segno('ben'), findsOneWidget);
      expect(segno('lello'), findsNothing);
      // Un viaggio che deve ancora cominciare: niente «prossima» da segnare.
      expect(find.text('Fatta'), findsNothing);
    });
  });

  group('la posizione', () {
    testWidgets('mentre il viaggio è in corso il permesso si chiede, dopo '
        'aver detto a cosa serve, e il puntino compare', (tester) async {
      ambiente.posizione.stato = PermessoPosizione.daChiedere;
      await viaggio(tester);
      await mappa(tester);

      // Prima di iOS, a cosa serve (tela, 58).
      expect(ambiente.posizione.richieste, 0);
      expect(find.text('Sei davvero a Porto?'), findsOneWidget);
      await tester.tap(find.text('Continua'));
      await aspetta(tester);

      expect(ambiente.posizione.richieste, 1);
      expect(find.byType(PuntinoPosizione), findsNothing);
      ambiente.posizione.vai((lat: 41.1470, lon: -8.6160));
      await tester.pumpAndSettle();
      expect(find.byType(PuntinoPosizione), findsOneWidget);
    });

    testWidgets('con il permesso negato la mappa funziona lo stesso, senza '
        'puntino', (tester) async {
      ambiente.posizione.stato = PermessoPosizione.negato;
      await viaggio(tester);
      await mappa(tester);

      // Si dice una volta che il viaggio non sarà verificato (tela, 59).
      expect(find.text('Va bene anche così'), findsOneWidget);
      await tester.tap(find.text('Ho capito'));
      await aspetta(tester);

      expect(ambiente.posizione.seguita, isFalse);
      expect(find.byType(SegnoSullaMappa), findsNWidgets(3));
    });

    testWidgets('prima della partenza la posizione non si chiede', (
      tester,
    ) async {
      ambiente.posizione.stato = PermessoPosizione.daChiedere;
      await viaggio(tester, inizio: 30);
      await mappa(tester);

      expect(ambiente.posizione.richieste, 0);
      // Si apre sul primo giorno, e non c'è una prossima da segnare.
      expect(find.text('Fatta'), findsNothing);
    });
  });

  group('senza la mappa', () {
    testWidgets('senza rete restano gli indirizzi, da aprire nelle Mappe del '
        'telefono', (tester) async {
      await viaggio(tester);
      ambiente.rete.disponibile = false;
      await mappa(tester);

      expect(find.text('La mappa ha bisogno della rete'), findsOneWidget);
      expect(find.text('Sei offline'), findsOneWidget);
      expect(find.text('Rua das Carmelitas 144, Porto'), findsOneWidget);
      expect(find.byType(SegnoSullaMappa), findsNothing);

      await tester.tap(find.text('Mappe').first);
      await tester.pumpAndSettle();
      final aperta = ambiente.mappeDelTelefono.aperte.single;
      expect(aperta.nome, 'Sé do Porto');
      expect(aperta.posto, (lat: 41.1428, lon: -8.6113));

      final senza = (await ambiente.eventi(tester))
          .where((e) => e.nome == 'apertura_senza_rete')
          .single;
      expect(jsonDecode(senza.proprieta)['schermata'], 'mappa');
    });

    testWidgets('senza fornitore lo stesso, detto diversamente', (
      tester,
    ) async {
      await viaggio(tester);
      ambiente.mappe.disponibili = false;
      await mappa(tester);

      expect(find.text('La mappa non è disponibile'), findsOneWidget);
      expect(find.text('Sei offline'), findsNothing);
    });

    testWidgets('«Portami» senza il permesso di posizione: ti portano le '
        'Mappe del telefono', (tester) async {
      ambiente.posizione.stato = PermessoPosizione.negato;
      await viaggio(tester);
      await mappa(tester);
      await tester.tap(find.text('Ho capito'));
      await aspetta(tester);

      await tester.tap(find.text('Portami'));
      await tester.pumpAndSettle();

      final aperta = ambiente.mappeDelTelefono.aperte.single;
      expect(aperta.nome, 'Livraria Lello');
      expect(aperta.posto, lello);
      expect(find.byType(SchermataNavigazione), findsNothing);
    });
  });

  group('la navigazione', () {
    // Da qui si va a est per un centinaio di metri, poi a sud fino a Lello.
    const partenza = (lat: 41.1475, lon: -8.6160);
    const svolta = (lat: 41.1475, lon: -8.61479);

    Percorso strada() => Percorso(
      punti: const [partenza, svolta, lello],
      passi: const [
        Passo(
          istruzione: 'Cammina verso est.',
          manovra: Manovra.partenza,
          da: 0,
          a: 1,
          metri: 101,
        ),
        Passo(
          istruzione: 'Svolta a destra su Rua das Carmelitas.',
          manovra: Manovra.aDestra,
          da: 1,
          a: 2,
          metri: 71,
        ),
        Passo(
          istruzione: 'Sei arrivato.',
          manovra: Manovra.arrivo,
          da: 2,
          a: 2,
          metri: 0,
        ),
      ],
      metri: 172,
      durata: const Duration(minutes: 3),
    );

    Future<void> portami(WidgetTester tester) async {
      ambiente.mappe.percorso = strada();
      await viaggio(tester);
      await mappa(tester);
      await tester.tap(find.text('Portami'));
      await tester.pumpAndSettle();
    }

    testWidgets('«Portami»: la strada a piedi dentro Trolley, l\'indicazione '
        'grande in alto, quanto manca in basso', (tester) async {
      await portami(tester);

      expect(find.byType(SchermataNavigazione), findsOneWidget);
      expect(find.text('Cerco dove sei…'), findsOneWidget);
      expect(find.text('Apri in Mappe'), findsOneWidget);

      ambiente.posizione.vai(partenza);
      await aspetta(tester);

      // Al fornitore va solo dove si parte, e dove si arriva.
      expect(ambiente.mappe.chiesti.single, (da: partenza, a: lello));
      expect(
        find.text('Svolta a destra su Rua das Carmelitas.'),
        findsOneWidget,
      );
      expect(find.text('100 m'), findsOneWidget);
      expect(find.textContaining('3 min a piedi · 170 m'), findsOneWidget);
    });

    testWidgets('all\'arrivo «Sei qui» propone di segnarla: un tocco, e la '
        'navigazione si chiude', (tester) async {
      await portami(tester);
      ambiente.posizione.vai(partenza);
      await aspetta(tester);

      ambiente.posizione.vai((lat: 41.14695, lon: -8.61481));
      await aspetta(tester);
      expect(find.text('SEI QUI'), findsOneWidget);

      await tester.tap(find.text('Fatta').last);
      await aspetta(tester);

      expect(find.byType(SchermataNavigazione), findsNothing);
      expect(await statoDi(tester, 'lello'), 'completata');
    });

    testWidgets('fuori strada due volte di fila: una strada nuova da dove '
        'si è', (tester) async {
      await portami(tester);
      ambiente.posizione.vai(partenza);
      await aspetta(tester);

      const persi = (lat: 41.1490, lon: -8.6160);
      ambiente.posizione.vai(persi);
      await aspetta(tester);
      expect(ambiente.mappe.chiesti, hasLength(1));
      ambiente.posizione.vai(persi);
      await aspetta(tester);
      expect(ambiente.mappe.chiesti, hasLength(2));
      expect(ambiente.mappe.chiesti.last.da, persi);
    });

    testWidgets('«Apri in Mappe» c\'è sempre, e «Fine» torna alla mappa; '
        'il percorso chiesto si conta', (tester) async {
      await portami(tester);
      ambiente.posizione.vai(partenza);
      await aspetta(tester);

      await tester.tap(find.text('Apri in Mappe'));
      await tester.pumpAndSettle();
      expect(ambiente.mappeDelTelefono.aperte.single.posto, lello);

      await tester.tap(find.text('Fine'));
      await aspetta(tester);
      expect(find.byType(SchermataNavigazione), findsNothing);
      expect(find.byType(SchermataMappa), findsOneWidget);

      expect((await evento(tester, 'consumo_mappe'))['percorsi'], 1);
    });

    testWidgets('se il fornitore non trova la strada lo dice, e restano le '
        'Mappe', (tester) async {
      await portami(tester);
      ambiente.mappe.percorso = null;
      ambiente.posizione.vai(partenza);
      await aspetta(tester);

      expect(find.text('Niente strada'), findsOneWidget);
      expect(find.text('Apri in Mappe'), findsOneWidget);
    });
  });

  group('«Dove?»: il posto di una tappa', () {
    Finder pulsante(String etichetta) => find.descendant(
      of: find.byType(PulsanteGrande),
      matching: find.text(etichetta),
    );

    Future<void> nuovaTappa(WidgetTester tester) async {
      await viaggio(tester, inizio: 30);
      await ambiente.monta(
        tester,
        const SchermataGiornata(viaggioId: 'v', giornoId: 'g1'),
      );
      await tester.ensureVisible(pulsante('Aggiungi una tappa'));
      await tester.tap(pulsante('Aggiungi una tappa'));
      await tester.pumpAndSettle();
    }

    testWidgets('si cerca vicino alle tappe del viaggio, e il posto trovato '
        'dà nome, indirizzo e coordinate alla tappa', (tester) async {
      ambiente.mappe.luoghi.addAll(const [
        Luogo(
          nome: 'Café Majestic',
          indirizzo: 'Rua de Santa Catarina 112, Porto',
          posto: (lat: 41.1468, lon: -8.6067),
        ),
        Luogo(
          nome: 'Majestic Hotel',
          indirizzo: 'Avenida 5, Porto',
          posto: (lat: 41.15, lon: -8.6),
        ),
      ]);
      await nuovaTappa(tester);

      // Il campo, non la sua etichetta: «Facoltativo» è il segnaposto.
      await tester.tap(find.text('Facoltativo'));
      await tester.pumpAndSettle();
      expect(find.text('Vicino alle altre tappe del viaggio.'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, 'Majestic');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Una ricerca sola, quando si smette di scrivere.
      expect(ambiente.mappe.cercati, ['Majestic']);
      expect(ambiente.mappe.vicino.single, isNotNull);
      expect(find.text('Usa «Majestic» com\'è'), findsOneWidget);
      await tester.tap(find.text('Café Majestic'));
      await tester.pumpAndSettle();

      // Il titolo era vuoto: lo dà il posto; come «Dove» basta l'indirizzo.
      expect(find.text('Rua de Santa Catarina 112, Porto'), findsOneWidget);
      await tester.tap(pulsante('Aggiungi'));
      await aspetta(tester);

      final arrivata = ambiente.server.tappe.firstWhere(
        (t) => t['titolo'] == 'Café Majestic',
      );
      expect(arrivata['luogo_nome'], 'Rua de Santa Catarina 112, Porto');
      expect((arrivata['lat'], arrivata['lon']), (41.1468, -8.6067));
      expect((await evento(tester, 'consumo_mappe'))['ricerche'], 1);
    });

    testWidgets('senza rete il posto si scrive com\'è: la tappa c\'è, senza '
        'coordinate, e non si cerca niente', (tester) async {
      await nuovaTappa(tester);
      ambiente.rete.disponibile = false;
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Cena al porto');
      // Il campo, non la sua etichetta: «Facoltativo» è il segnaposto.
      await tester.tap(find.text('Facoltativo'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Senza rete scrivi il posto'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, 'Rua das Flores');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(ambiente.mappe.cercati, isEmpty);

      await tester.tap(find.text('Usa «Rua das Flores» com\'è'));
      await tester.pumpAndSettle();
      expect(find.text('Rua das Flores'), findsOneWidget);
      expect(
        find.text('Non è sulla mappa: tocca «Dove?» per cercare il posto.'),
        findsOneWidget,
      );
      await tester.tap(pulsante('Aggiungi'));
      await aspetta(tester);

      final tappa = (await tester.runAsync(
        () => (ambiente.db.select(
          ambiente.db.tappe,
        )..where((t) => t.titolo.equals('Cena al porto'))).getSingle(),
      ))!;
      expect(tappa.luogoNome, 'Rua das Flores');
      expect(tappa.lat, isNull);
    });
  });
}
