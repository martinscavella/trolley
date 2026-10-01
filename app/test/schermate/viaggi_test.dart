import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dati/database.dart';
import 'package:trolley/dominio/calendario.dart';
import 'package:trolley/dominio/periodo.dart';
import 'package:trolley/schermate/viaggi.dart';

import '../aiuti.dart';

void main() {
  late Ambiente ambiente;

  setUp(() => ambiente = Ambiente());
  tearDown(() => ambiente.chiudi());

  final oggi = soloData(DateTime.now());
  String fra(int giorni) => scriviData(oggi.add(Duration(days: giorni)));

  void sulServer(Map<String, Object?> viaggio) {
    ambiente.server.viaggi.add(viaggio);
    ambiente.server.partecipazioni.add(
      rigaPartecipazione(viaggio['id']! as String),
    );
  }

  testWidgets('i viaggi si dividono per stato, e l\'archivio sta a parte', (
    tester,
  ) async {
    sulServer(
      rigaViaggio('v', stato: 'definito', inizio: fra(20), fine: fra(22)),
    );
    sulServer(
      rigaViaggio('c', stato: 'definito', inizio: fra(-1), fine: fra(1)),
    );
    sulServer(rigaViaggio('i', periodo: 'agosto 2099', citta: 'Lisbona'));
    sulServer(
      rigaViaggio(
        'a',
        stato: 'archiviato',
        periodo: 'agosto 2020',
        citta: 'Oslo',
      ),
    );

    // L'elenco si aggiorna da sé appena compare.
    await ambiente.monta(tester, SchermataViaggi(onCodice: (_) {}));

    expect(find.text('In corso'), findsNWidgets(2)); // sezione ed etichetta
    expect(find.text('In programma'), findsNWidgets(2));
    expect(find.text('Idee'), findsOneWidget);
    expect(find.text('Lisbona'), findsOneWidget);
    expect(find.text('Oslo'), findsNothing);
    await tester.scrollUntilVisible(find.text('Archivio'), 300);
    expect(find.text('Archivio'), findsOneWidget);
    expect(find.text('1 idea'), findsOneWidget);
    expect(find.text('Nuovo viaggio'), findsOneWidget);
  });

  testWidgets('senza rete l\'elenco dice che è la copia, e quanto è vecchia', (
    tester,
  ) async {
    sulServer(rigaViaggio('i', periodo: 'agosto 2099'));
    await tester.runAsync(ambiente.archivio.aggiornaCopia);
    ambiente.rete.disponibile = false;

    await ambiente.monta(tester, SchermataViaggi(onCodice: (_) {}));

    expect(
      find.text(
        'Sei offline: stai vedendo la copia sul telefono, aggiornata poco fa.',
      ),
      findsOneWidget,
    );

    // Torna la rete: l'elenco si riaggiorna, e l'avviso se ne va.
    ambiente.rete.disponibile = true;
    await tester.pumpAndSettle();
    expect(find.textContaining('Sei offline'), findsNothing);
  });

  testWidgets('un\'idea sollecitata da due settimane col periodo passato va in '
      'archivio, e lo si dice', (tester) async {
    final passato = MeseDi.di(aggiungiMesi(oggi, -3));
    sulServer(rigaViaggio('i', periodo: passato.testo, citta: 'Lisbona'));
    await tester.runAsync(() async {
      await ambiente.archivio.aggiornaCopia();
      final idea = (await ambiente.archivio.osservaViaggio('i').first)!;
      await ambiente.archivio.segnaSollecitata(
        idea,
        oggi.subtract(const Duration(days: 15)),
      );
    });

    await ambiente.monta(tester, SchermataViaggi(onCodice: (_) {}));

    expect(ambiente.server.viaggi.single['stato'], 'archiviato');
    expect(
      find.textContaining('«Lisbona» è andata in archivio'),
      findsOneWidget,
    );
    expect(find.text('Idee'), findsNothing);
    await tester.scrollUntilVisible(find.text('1 idea'), 300);
    expect(find.text('1 idea'), findsOneWidget);
  });

  testWidgets(
    'un\'idea vicina alla scadenza lo mostra sulla scheda, e mostrarlo '
    'conta come sollecito',
    (tester) async {
      final finisce = MeseDi.di(oggi);
      final mancano = finisce.ultimoGiorno.difference(oggi).inDays;
      sulServer(rigaViaggio('i', periodo: finisce.testo, citta: 'Lisbona'));

      await ambiente.monta(tester, SchermataViaggi(onCodice: (_) {}));

      final attesa = mancano <= 14;
      expect(
        find.text('Ancora un\'idea?'),
        attesa ? findsOneWidget : findsNothing,
      );
      final sollecito = await tester.runAsync(
        () => (ambiente.db.select(
          ambiente.db.impostazioni,
        )..where((i) => i.chiave.equals('sollecito:i'))).getSingleOrNull(),
      );
      expect(sollecito != null, attesa);
    },
  );

  test('una riga della copia porta quando è stata scaricata', () {
    // Il tipo lo garantisce: senza scaricatoIl non si scrive nella copia.
    final riga = ViaggiCompanion.insert(
      id: 'v',
      versione: 1,
      scaricatoIl: DateTime.now(),
      stato: 'idea',
      creatoreId: idDiProva,
      importato: false,
      verificato: false,
      creatoIl: '2026-01-01T00:00:00Z',
      periodoApprossimativo: const Value(null),
    );
    expect(riga.scaricatoIl.present, isTrue);
  });
}
