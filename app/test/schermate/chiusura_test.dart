import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/aspetto/elementi.dart';
import 'package:trolley/dominio/calendario.dart';
import 'package:trolley/schermate/giornata.dart';
import 'package:trolley/schermate/impostazioni.dart';
import 'package:trolley/schermate/traguardi.dart';
import 'package:trolley/schermate/viaggi.dart';
import 'package:trolley/schermate/viaggio.dart';

import '../aiuti.dart';

/// La chiusura (fase 4.1; tela, 60–63, 93 e 94): da sola il giorno dopo la
/// fine, o prima a mano; il riepilogo, verificato o no; i traguardi.
void main() {
  late Ambiente ambiente;

  setUp(() => ambiente = Ambiente());
  tearDown(() => ambiente.chiudi());

  final oggi = soloData(DateTime.now());
  String fra(int giorni) => scriviData(oggi.add(Duration(days: giorni)));
  const marco = '22222222-2222-4222-8222-222222222222';

  /// Porto, due giorni, con una tappa fatta per giorno e Marco.
  Future<void> viaggio(
    WidgetTester tester, {
    int inizio = -2,
    int fine = -1,
    bool sulPosto = true,
    String ruolo = 'creatore',
  }) async {
    ambiente.server
      ..viaggi.add(
        rigaViaggio(
          'v',
          stato: 'definito',
          inizio: fra(inizio),
          fine: fra(fine),
        ),
      )
      ..partecipazioni.addAll([
        rigaPartecipazione('v', ruolo: ruolo)
          ..['sul_posto_il'] = sulPosto ? '${fra(inizio)}T12:00:00Z' : null,
        rigaPartecipazione(
          'v',
          utente: marco,
          ruolo: ruolo == 'creatore' ? 'partecipante' : 'creatore',
        ),
      ])
      ..utenti.add({
        'id': marco,
        'nome': 'Marco',
        'versione': 1,
        'eliminato_il': null,
      })
      ..giorni.addAll([
        rigaGiorno('v', fra(inizio), '10:00:00', '24:00:00', id: 'g1'),
        rigaGiorno('v', fra(fine), '00:00:00', '18:00:00', id: 'g2'),
      ])
      ..tappe.addAll([
        for (final (id, giorno) in [('t1', 'g1'), ('t2', 'g2')])
          rigaDiTappa(id, viaggio: 'v', giorno: giorno, stato: 'completata')
            ..['marcata_durante_il_viaggio'] = true,
      ])
      ..spese.add(
        rigaDiSpesa('s1', viaggio: 'v', data: fra(inizio), importo: '40.00'),
      )
      ..tassi.add(rigaTasso('EUR', 1, fra(0)));
    await ambiente.accedi(tester: tester);
    await tester.runAsync(ambiente.archivio.aggiornaCopia);
  }

  Future<void> aspetta(WidgetTester tester) async {
    for (var i = 0; i < 60; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Finder pulsante(String etichetta) => find.descendant(
    of: find.byType(PulsanteGrande),
    matching: find.text(etichetta),
  );

  testWidgets('il giorno dopo la fine, aprendo l\'app il viaggio si chiude e '
      'il riepilogo si apre: verificato, con i traguardi', (tester) async {
    await viaggio(tester);
    await ambiente.monta(tester, SchermataViaggi(onCodice: (_) {}));
    await aspetta(tester);

    expect(ambiente.server.viaggi.single['stato'], 'chiuso');
    expect(find.text('VERIFICATO'), findsOneWidget);
    expect(find.text('CONCLUSO'), findsOneWidget);
    expect(find.text('2 di 2'), findsOneWidget); // tappe fatte
    expect(find.text('SPESO IN TUTTO'), findsOneWidget);
    expect(find.textContaining('40,00'), findsWidgets);
    expect(find.text('Portogallo'), findsOneWidget); // di nuovo
    await tester.scrollUntilVisible(find.text('Traguardi presi'), 200);
    expect(find.text('Primo viaggio verificato'), findsOneWidget);
    expect(find.text('In compagnia'), findsOneWidget);
    expect(find.text('Organizzare'), findsOneWidget);

    final eventi = [
      for (final e in await ambiente.eventi(tester))
        if (e.nome == 'viaggio_chiuso')
          jsonDecode(e.proprieta) as Map<String, dynamic>,
      for (final r in ambiente.server.chiamate('POST', '/rest/v1/evento'))
        for (final e
            in (jsonDecode(r.body) as List).cast<Map<String, dynamic>>())
          if (e['nome'] == 'viaggio_chiuso')
            e['proprieta'] as Map<String, dynamic>,
    ];
    expect(eventi.single['verificato'], isTrue);

    // Il riepilogo si apre da solo una volta, e il viaggio non è più da
    // chiudere.
    expect(
      await tester.runAsync(() => ambiente.archivio.riepilogoVisto('v')),
      isTrue,
    );
  });

  testWidgets('non verificato: lo stesso riepilogo, senza timbro né '
      'traguardi, e senza dire che cosa è mancato', (tester) async {
    await viaggio(tester, sulPosto: false);
    await ambiente.monta(tester, SchermataViaggi(onCodice: (_) {}));
    await aspetta(tester);

    expect(find.text('CONCLUSO'), findsOneWidget);
    expect(find.text('VERIFICATO'), findsNothing);
    expect(find.text('Traguardi presi'), findsNothing);
    expect(
      find.textContaining('è nel tuo passaporto', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('posto'), findsNothing);
    expect(pulsante('Fatto'), findsOneWidget);
  });

  testWidgets('prima della fine chi è responsabile chiude a mano, dopo una '
      'conferma', (tester) async {
    await viaggio(tester, inizio: -1, fine: 1);
    await ambiente.monta(tester, const SchermataViaggio(viaggioId: 'v'));
    await aspetta(tester);

    await tester.scrollUntilVisible(pulsante('Chiudi il viaggio'), 300);
    await tester.ensureVisible(pulsante('Chiudi il viaggio'));
    await tester.pumpAndSettle();
    await tester.tap(pulsante('Chiudi il viaggio'));
    await aspetta(tester);
    expect(find.text('Chiudere il viaggio adesso?'), findsOneWidget);
    expect(find.textContaining('le spese e i saldi restano'), findsOneWidget);
    await tester.tap(find.text('Chiudi').last);
    await aspetta(tester);

    expect(ambiente.server.viaggi.single['stato'], 'chiuso');
    expect(find.text('CONCLUSO'), findsOneWidget);
  });

  testWidgets('chi partecipa non vede «Chiudi il viaggio»', (tester) async {
    await viaggio(tester, inizio: -1, fine: 1, ruolo: 'partecipante');
    await ambiente.monta(tester, const SchermataViaggio(viaggioId: 'v'));
    await aspetta(tester);

    await tester.scrollUntilVisible(find.text('Invita qualcuno'), 300);
    expect(find.text('Chiudi il viaggio'), findsNothing);
  });

  testWidgets('chiuso, il viaggio porta al riepilogo, e la giornata non '
      'aggiunge tappe', (tester) async {
    await viaggio(tester);
    await tester.runAsync(() => ambiente.archivio.chiudiViaggio('v'));
    await ambiente.monta(tester, const SchermataViaggio(viaggioId: 'v'));
    await aspetta(tester);

    expect(find.text('Il riepilogo del viaggio'), findsOneWidget);
    expect(find.text('2 giorni, 2 tappe fatte.'), findsOneWidget);

    await ambiente.monta(
      tester,
      const SchermataGiornata(viaggioId: 'v', giornoId: 'g1'),
    );
    await aspetta(tester);
    expect(find.text('Aggiungi una tappa'), findsNothing);
    expect(find.textContaining('Il viaggio è concluso'), findsOneWidget);
  });

  testWidgets('i traguardi: presi, e da prendere con quanto manca; dal '
      'profilo', (tester) async {
    await viaggio(tester);
    ambiente.server.traguardi.add({
      'id': 'tr1',
      'tipo': 'primo_viaggio_verificato',
      'viaggio_id': 'v',
      'preso_il': '${fra(-1)}T20:00:00Z',
    });
    ambiente.server.partecipazioni.first['verificato'] = true;
    await tester.runAsync(ambiente.archivio.aggiornaCopia);

    await ambiente.monta(tester, const SchermataImpostazioni());
    await aspetta(tester);
    expect(find.text('1 preso'), findsOneWidget);
    await tester.tap(find.text('Traguardi'));
    await aspetta(tester);

    expect(find.byType(SchermataTraguardi), findsOneWidget);
    expect(find.text('PRESI · 1'), findsOneWidget);
    expect(find.textContaining('Porto,'), findsOneWidget);
    expect(find.text('DA PRENDERE'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Quattro stagioni'), 200);
    expect(find.text('1 di 3'), findsOneWidget); // tre paesi
    expect(find.text('1 di 10'), findsOneWidget);
    expect(find.text('1 di 4'), findsOneWidget);
  });
}
