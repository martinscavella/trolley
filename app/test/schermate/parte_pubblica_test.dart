import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dati/errori.dart';
import 'package:trolley/dati/pagine.dart';
import 'package:trolley/dati/telefono.dart';
import 'package:trolley/dominio/parte_pubblica.dart';
import 'package:trolley/misurazione/misurazione.dart';
import 'package:trolley/schermate/impostazioni.dart';
import 'package:trolley/schermate/persone_bloccate.dart';
import 'package:trolley/schermate/profilo_pubblico.dart';
import 'package:trolley/schermate/segnalazioni.dart';
import 'package:trolley/schermate/verifica_telefono.dart';

import '../aiuti.dart';

/// L'impianto di sicurezza dal telefono (5.1; tela, 68–72 e 103–107): la
/// parte pubblica nel profilo solo quando è aperta, il numero e il codice,
/// accendere e spegnere, la sospensione, segnalare, bloccare e sbloccare.
void main() {
  late Ambiente ambiente;

  setUp(() => ambiente = Ambiente());
  tearDown(() => ambiente.chiudi());

  const luca = 'aaaaaaaa-1111-4111-8111-111111111111';

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

  Future<void> dentro(WidgetTester tester, Widget schermata) async {
    ambiente.server.utenti.add({
      'id': luca,
      'nome': 'Luca',
      'versione': 1,
      'eliminato_il': null,
    });
    await ambiente.accedi(tester: tester);
    await ambiente.monta(tester, schermata);
    await aspetta(tester);
  }

  /// Gli eventi, quelli ancora sul telefono e quelli già partiti: il nome e
  /// le proprietà.
  Future<List<(String, Object?)>> registrati(WidgetTester tester) async => [
    for (final e in await ambiente.eventi(tester))
      (e.nome, jsonDecode(e.proprieta)),
    for (final r in ambiente.server.chiamate('POST', '/rest/v1/evento'))
      for (final e in (jsonDecode(r.body) as List).cast<Map<String, dynamic>>())
        (e['nome'] as String, e['proprieta']),
  ];

  Future<List<String>> eventi(WidgetTester tester) async => [
    for (final (nome, _) in await registrati(tester)) nome,
  ];

  group('nel profilo', () {
    testWidgets('con la parte pubblica chiusa non c\'è niente', (tester) async {
      await dentro(tester, const SchermataImpostazioni());
      expect(find.text('PARTE PUBBLICA'), findsNothing);
      expect(find.text('Profilo pubblico'), findsNothing);
    });

    testWidgets('aperta, ci sono il profilo pubblico, chi hai bloccato e le '
        'segnalazioni', (tester) async {
      ambiente.server.apriPartePubblica();
      ambiente.server.bloccate.add({
        'utente_id': luca,
        'nome': 'Luca',
        'dal': '2026-10-04T10:00:00+00:00',
      });
      await dentro(tester, const SchermataImpostazioni());

      expect(find.text('PARTE PUBBLICA'), findsOneWidget);
      expect(find.text('Profilo pubblico'), findsOneWidget);
      expect(find.text('Spento'), findsOneWidget);
      expect(find.text('Persone bloccate'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('Le tue segnalazioni'), findsOneWidget);
    });

    testWidgets('senza rete le righe si spengono e dicono perché', (
      tester,
    ) async {
      ambiente.server.apriPartePubblica();
      await dentro(tester, const SchermataImpostazioni());
      ambiente.rete.disponibile = false;
      await tester.pumpAndSettle();

      expect(find.text(motivoSenzaRete), findsNWidgets(3));
      await tester.tap(find.text('Profilo pubblico'));
      await tester.pumpAndSettle();
      expect(find.byType(SchermataProfiloPubblico), findsNothing);
    });
  });

  group('accendere il profilo pubblico', () {
    testWidgets('prima cosa vedono gli altri e cosa mai, poi il numero, il '
        'codice, e «Accendi»', (tester) async {
      ambiente.server.apriPartePubblica();
      await dentro(tester, const SchermataProfiloPubblico());

      expect(find.text('COSA VEDONO GLI ALTRI'), findsOneWidget);
      expect(find.text('COSA NON VEDONO MAI'), findsOneWidget);
      expect(
        find.text('I viaggi in programma o in corso, in nessuna forma'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(find.text('Verifica il telefono'), 200);
      await tester.tap(find.text('Verifica il telefono'));
      await tester.pumpAndSettle();

      // Il numero (tela, 104): senza prefisso è italiano.
      expect(find.text('Il tuo numero'), findsOneWidget);
      expect(find.text('+39'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '347 123 4567');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mandami il codice'));
      await aspetta(tester);
      expect(ambiente.verifica.mandati, ['+393471234567']);

      // Il codice (tela, 69): con l'ultima cifra si verifica.
      expect(find.text('Il codice'), findsOneWidget);
      expect(
        find.text('L\'abbiamo mandato per SMS al +39 347 ••• 4567.'),
        findsOneWidget,
      );
      expect(find.text('Si accende con tutte e sei le cifre.'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField),
        VerificaFinta.codiceGiusto,
      );
      await aspetta(tester);

      // Di nuovo il profilo pubblico (tela, 105).
      expect(find.text('Telefono verificato'), findsOneWidget);
      expect(find.textContaining('+39 347 ••• 4567'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Accendi il profilo pubblico'),
        200,
      );
      expect(
        find.textContaining('condizioni d\'uso', findRichText: true),
        findsOneWidget,
      );
      await tester.tap(find.text('Accendi il profilo pubblico'));
      await aspetta(tester);

      expect(ambiente.server.partePubblica['attivo'], isTrue);
      expect(ambiente.server.partePubblica['condizioni'], versioneCondizioni);
      expect(
        find.text('È acceso: altri viaggiatori ti possono trovare.'),
        findsOneWidget,
      );
      expect(await eventi(tester), [
        Eventi.telefonoVerificato,
        Eventi.profiloPubblicoAttivato,
      ]);
    });

    testWidgets('un codice sbagliato si cancella e lo dice', (tester) async {
      await dentro(tester, const SchermataIlCodice(numero: '+393471234567'));
      await tester.enterText(find.byType(TextField), '000000');
      await aspetta(tester);

      expect(find.text('Il codice'), findsOneWidget);
      expect(
        find.text('Il codice non è giusto. Controllalo, o chiedine un altro.'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(await eventi(tester), isEmpty);
      // Un altro codice si chiede dopo un po'.
      expect(find.textContaining('chiederne un altro tra'), findsOneWidget);
    });

    testWidgets('un numero di un altro account si rifiuta e lo dice', (
      tester,
    ) async {
      ambiente.verifica.rifiuto = const ErroreTrolley(
        'Questo numero è già di un altro account: un numero vale per un '
        'account solo.',
        codice: CodiciTelefono.usato,
      );
      await dentro(tester, const SchermataIlTuoNumero());
      await tester.enterText(find.byType(TextField), '+44 7911 123456');
      await tester.pumpAndSettle();
      // Con il prefisso scritto, la capsula «+39» non c'è.
      expect(find.text('+39'), findsNothing);
      await tester.tap(find.text('Mandami il codice'));
      await aspetta(tester);

      expect(
        find.textContaining('un numero vale per un account solo'),
        findsOneWidget,
      );
      expect(find.text('Il tuo numero'), findsOneWidget);
    });

    testWidgets('un numero che non è un numero non manda niente', (
      tester,
    ) async {
      await dentro(tester, const SchermataIlTuoNumero());
      await tester.enterText(find.byType(TextField), '347');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mandami il codice'));
      await aspetta(tester);
      expect(ambiente.verifica.mandati, isEmpty);
    });

    testWidgets('sotto i 18 anni non si accende', (tester) async {
      ambiente.server
        ..apriPartePubblica()
        ..partePubblica['maggiorenne'] = false;
      await dentro(tester, const SchermataProfiloPubblico());
      await tester.scrollUntilVisible(
        find.textContaining('solo dai 18 anni'),
        200,
      );
      expect(find.text('Verifica il telefono'), findsNothing);
      expect(find.text('Accendi il profilo pubblico'), findsNothing);
    });

    testWidgets('chiusa ai nuovi lo dice al posto del pulsante', (
      tester,
    ) async {
      ambiente.server
        ..apriPartePubblica(telefono: '+393471234567')
        ..partePubblica['accoglie'] = false;
      await dentro(tester, const SchermataProfiloPubblico());
      await tester.scrollUntilVisible(
        find.textContaining('non accoglie profili nuovi'),
        200,
      );
      expect(find.text('Accendi il profilo pubblico'), findsNothing);
    });

    testWidgets('acceso, si spegne con l\'interruttore', (tester) async {
      ambiente.server
        ..apriPartePubblica(telefono: '+393471234567')
        ..partePubblica['attivo'] = true;
      await dentro(tester, const SchermataProfiloPubblico());
      await tester.tap(find.byType(Switch));
      await aspetta(tester);

      expect(ambiente.server.partePubblica['attivo'], isFalse);
      await tester.scrollUntilVisible(
        find.text('Accendi il profilo pubblico'),
        200,
      );
      expect(await eventi(tester), [Eventi.profiloPubblicoSpento]);
    });

    testWidgets('sospeso, dice da quando, perché e a chi scrivere', (
      tester,
    ) async {
      ambiente.server
        ..apriPartePubblica(telefono: '+393471234567')
        ..partePubblica['sospeso_il'] = '2026-10-04T10:00:00+00:00'
        ..partePubblica['sospensione_motivo'] =
            'Condizioni d\'uso, regola 2: messaggi molesti.'
        ..configurazione.add({
          'chiave': 'contatto_moderazione',
          'valore': 'moderazione@trolley.prova',
        });
      await tester.runAsync(ambiente.archivio.aggiornaConfigurazione);
      await dentro(tester, const SchermataProfiloPubblico());

      expect(find.text('È sospeso'), findsOneWidget);
      expect(find.textContaining('Dal 4 ott'), findsOneWidget);
      expect(
        find.text('Condizioni d\'uso, regola 2: messaggi molesti.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('moderazione@trolley.prova', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Accendi il profilo pubblico'), findsNothing);
    });

    testWidgets('senza rete non si legge, e Riprova è spento', (tester) async {
      ambiente.server.apriPartePubblica();
      ambiente.server.utenti.add({
        'id': luca,
        'nome': 'Luca',
        'versione': 1,
        'eliminato_il': null,
      });
      await ambiente.accedi(tester: tester);
      ambiente.rete.disponibile = false;
      await ambiente.monta(tester, const SchermataProfiloPubblico());
      await aspetta(tester);

      expect(find.text('Riprova'), findsOneWidget);
      expect(find.text(motivoSenzaRete), findsOneWidget);
    });
  });

  group('segnalare', () {
    /// Una schermata con un pulsante che apre «Segnala Luca», come farà il
    /// «…» di un profilo (5.3).
    Widget conSegnala() => Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => segnala(
              context,
              tipo: TipoSegnalato.profilo,
              oggettoId: luca,
              utenteId: luca,
              nome: 'Luca',
            ),
            child: const Text('…'),
          ),
        ),
      ),
    );

    testWidgets('si sceglie il motivo, «Blocca anche» è già acceso, e poi '
        'si vede che è arrivata', (tester) async {
      await dentro(tester, conSegnala());
      await tester.tap(find.text('…'));
      await tester.pumpAndSettle();

      expect(find.text('Segnala Luca'), findsOneWidget);
      expect(
        find.text(
          'La legge solo chi modera. Luca non viene avvisato, e non saprà da '
          'chi arriva.',
        ),
        findsOneWidget,
      );
      expect(find.text('Scegli un motivo.'), findsOneWidget);
      await tester.tap(find.text('Profilo falso'));
      await tester.pumpAndSettle();
      expect(find.text('Scegli un motivo.'), findsNothing);
      await tester.enterText(
        find.byType(TextField),
        '  Usa le foto di un altro ',
      );
      await tester.tap(find.text('Invia la segnalazione'));
      await aspetta(tester);

      final mandata = ambiente.server.segnalate.single;
      expect(mandata['p_tipo'], 'profilo');
      expect(mandata['p_oggetto'], luca);
      expect(mandata['p_motivo'], 'falso');
      expect(mandata['p_nota'], 'Usa le foto di un altro');
      expect(mandata['p_blocca'], isTrue);
      expect(mandata['p_misurazione'], isTrue);

      expect(find.text('È arrivata'), findsOneWidget);
      expect(find.text('Luca · un profilo'), findsOneWidget);
      expect(find.text('RICEVUTA'), findsOneWidget);
      expect(
        find.textContaining('chiama il 112', findRichText: true),
        findsOneWidget,
      );
      final eventiMandati = await registrati(tester);
      expect(
        [for (final (nome, _) in eventiMandati) nome],
        [Eventi.personaBloccata],
      );
      expect(eventiMandati.single.$2, {'da': 'segnalazione'});
    });

    testWidgets('con la misurazione spenta lo dice al server, e senza blocco '
        'non blocca', (tester) async {
      await tester.runAsync(() => ambiente.misurazione.imposta(attiva: false));
      await dentro(tester, conSegnala());
      await tester.tap(find.text('…'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Messaggi molesti o minacce'));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Invia la segnalazione'));
      await aspetta(tester);

      final mandata = ambiente.server.segnalate.single;
      expect(mandata['p_misurazione'], isFalse);
      expect(mandata['p_blocca'], isFalse);
      expect(mandata['p_nota'], isNull);
      expect(ambiente.server.bloccate, isEmpty);
    });

    testWidgets('senza rete non parte, e lo dice', (tester) async {
      await dentro(tester, conSegnala());
      await tester.tap(find.text('…'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Altro'));
      ambiente.rete.disponibile = false;
      await tester.pumpAndSettle();

      expect(find.text(motivoSenzaRete), findsOneWidget);
      await tester.tap(find.text('Invia la segnalazione'));
      await aspetta(tester);
      expect(ambiente.server.segnalate, isEmpty);
    });

    testWidgets('le proprie segnalazioni, con l\'esito di quelle gestite', (
      tester,
    ) async {
      ambiente.server.mieSegnalazioni.addAll([
        {
          'id': 's1',
          'tipo_oggetto': 'profilo',
          'nome': 'Luca',
          'motivo': 'molestie',
          'stato': 'gestita',
          'esito': 'profilo_sospeso',
          'creata_il': '2026-10-01T10:00:00+00:00',
          'gestita_il': '2026-10-02T09:00:00+00:00',
        },
      ]);
      await dentro(tester, const SchermataSegnalazioni());

      expect(find.text('Le tue segnalazioni'), findsOneWidget);
      expect(find.text('GESTITA'), findsOneWidget);
      expect(
        find.text('Gestita il 2 ott: il profilo è stato sospeso'),
        findsOneWidget,
      );
    });

    testWidgets('senza segnalazioni lo dice', (tester) async {
      await dentro(tester, const SchermataSegnalazioni());
      expect(find.text('Non hai fatto segnalazioni.'), findsOneWidget);
    });
  });

  group('bloccare', () {
    testWidgets('si sblocca dopo la conferma, e la persona sparisce '
        'dall\'elenco', (tester) async {
      ambiente.server.bloccate.add({
        'utente_id': luca,
        'nome': 'Luca',
        'dal': '2026-10-04T10:00:00+00:00',
      });
      await dentro(tester, const SchermataPersoneBloccate());

      expect(find.text('Luca'), findsOneWidget);
      expect(find.text('Blocco dal 4 ott'), findsOneWidget);
      await tester.tap(find.text('Sblocca'));
      await tester.pumpAndSettle();
      expect(find.text('Sbloccare Luca?'), findsOneWidget);
      await tester.tap(find.text('Sblocca').last);
      await aspetta(tester);

      expect(ambiente.server.bloccate, isEmpty);
      expect(find.text('Non hai bloccato nessuno.'), findsOneWidget);
      expect(await eventi(tester), [Eventi.personaSbloccata]);
    });

    testWidgets('si blocca da un profilo dopo il dialogo, senza spiegazioni', (
      tester,
    ) async {
      await dentro(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => blocca(
                  context,
                  utenteId: luca,
                  nome: 'Luca',
                  da: DaDoveSiBlocca.profilo,
                ),
                child: const Text('…'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('…'));
      await tester.pumpAndSettle();
      expect(find.text('Bloccare Luca?'), findsOneWidget);
      expect(find.textContaining('Luca non lo saprà'), findsOneWidget);
      await tester.tap(find.text('Blocca'));
      await aspetta(tester);

      expect(ambiente.server.bloccate.single['utente_id'], luca);
      final eventiMandati = await registrati(tester);
      expect(
        [for (final (nome, _) in eventiMandati) nome],
        [Eventi.personaBloccata],
      );
      expect(eventiMandati.single.$2, {'da': 'profilo'});
    });
  });
}
