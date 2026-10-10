import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trolley/dati/errori.dart';
import 'package:trolley/dati/telefono.dart';

import '../aiuti.dart';

/// La verifica del telefono dietro la sua interfaccia (5.1, ADR-011): che
/// cosa si chiede alla funzione `telefono` del server, e come si dicono i suoi
/// no.
void main() {
  late ReteFinta rete;
  final richieste = <http.Request>[];

  setUp(() {
    rete = ReteFinta();
    richieste.clear();
  });
  tearDown(() => rete.chiudi());

  VerificaSulServer verifica(http.Response Function(http.Request) risponde) =>
      VerificaSulServer(
        indirizzo: 'https://progetto.supabase.co/functions/v1/telefono',
        chiavePubblica: 'chiave-pubblica',
        accesso: () => 'gettone',
        rete: rete,
        client: MockClient((r) async {
          richieste.add(r);
          return risponde(r);
        }),
      );

  http.Response no(int stato, String codice) =>
      http.Response(jsonEncode({'codice': codice}), stato);

  test('il numero va nel corpo, con l\'accesso di chi chiede', () async {
    final partito = await verifica(
      (_) => http.Response(jsonEncode({'esito': 'inviato'}), 200),
    ).mandaCodice('+393471234567');

    expect(partito, isTrue);
    final r = richieste.single;
    expect(
      r.url.toString(),
      'https://progetto.supabase.co/functions/v1/telefono/invia',
    );
    expect(r.method, 'POST');
    expect(r.headers['authorization'], 'Bearer gettone');
    expect(r.headers['apikey'], 'chiave-pubblica');
    expect(jsonDecode(r.body), {'numero': '+393471234567'});
    expect(r.url.query, isEmpty);
  });

  test('se è già il suo numero verificato, il codice non serve', () async {
    final partito = await verifica(
      (_) => http.Response(jsonEncode({'esito': 'gia'}), 200),
    ).mandaCodice('+393471234567');
    expect(partito, isFalse);
  });

  test('il codice si controlla per quel numero', () async {
    await verifica(
      (_) => http.Response(jsonEncode({'esito': 'verificato'}), 200),
    ).verifica('+393471234567', '123456');
    expect(richieste.single.url.path, '/functions/v1/telefono/verifica');
    expect(jsonDecode(richieste.single.body), {
      'numero': '+393471234567',
      'codice': '123456',
    });
  });

  group('i no, detti in modo che si capisca cosa fare', () {
    Future<ErroreTrolley> errore(Future<void> Function() chiamata) async {
      try {
        await chiamata();
      } on ErroreTrolley catch (e) {
        return e;
      }
      fail('nessun errore');
    }

    test('un numero di un altro account', () async {
      final e = await errore(
        () => verifica((_) => no(409, 'usato')).mandaCodice('+393471234567'),
      );
      expect(e.codice, CodiciTelefono.usato);
      expect(e.messaggio, contains('un numero vale per un account solo'));
    });

    test('il tetto: troppi codici chiesti, o troppi tentativi', () async {
      final codici = await errore(
        () => verifica((_) => no(429, 'tetto')).mandaCodice('+393471234567'),
      );
      expect(codici.messaggio, contains('troppi codici'));
      final tentativi = await errore(
        () =>
            verifica((_) => no(429, 'tetto'))
                .verifica('+393471234567', '000000'),
      );
      expect(tentativi.messaggio, contains('Troppi tentativi'));
    });

    test('il codice sbagliato e quello scaduto', () async {
      final sbagliato = await errore(
        () =>
            verifica((_) => no(422, 'sbagliato'))
                .verifica('+393471234567', '000000'),
      );
      expect(sbagliato.codice, CodiciTelefono.sbagliato);
      final scaduto = await errore(
        () =>
            verifica((_) => no(410, 'scaduto'))
                .verifica('+393471234567', '000000'),
      );
      expect(scaduto.messaggio, contains('scaduto'));
    });

    test('il fornitore che non risponde, o una risposta strana', () async {
      final fornitore = await errore(
        () =>
            verifica((_) => no(502, 'fornitore')).mandaCodice('+393471234567'),
      );
      expect(fornitore.messaggio, contains('L\'SMS non parte'));
      final strana = await errore(
        () =>
            verifica((_) => http.Response('<html>', 500))
                .mandaCodice('+393471234567'),
      );
      expect(strana.codice, CodiciTelefono.fornitore);
    });

    test('senza rete lo dice, e la rete risulta mancare', () async {
      final e = await errore(
        () =>
            verifica((_) => throw const SocketException('nessuna rete'))
                .mandaCodice('+393471234567'),
      );
      expect(e.serveLaRete, isTrue);
      expect(rete.disponibile, isFalse);
    });
  });
}
