/// La verifica del numero di telefono (5.1; 04-integrazioni, ADR-011): un
/// codice SMS, mandato e controllato da Twilio Verify attraverso la funzione
/// `telefono` del nostro server, che tiene le chiavi e il tetto. L'app non
/// parla con Twilio, e il numero non sta sul telefono: lo tiene il server.
///
/// Richiede la rete. Serve solo alla parte pubblica: senza, il resto dell'app
/// funziona per intero.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'errori.dart';
import 'rete.dart';

/// I no della funzione `telefono`, nell'[ErroreTrolley.codice].
abstract final class CodiciTelefono {
  static const accesso = 'accesso';
  static const numero = 'numero';
  static const chiusa = 'chiusa';
  static const eta = 'eta';
  static const usato = 'usato';
  static const tetto = 'tetto';
  static const sbagliato = 'sbagliato';
  static const scaduto = 'scaduto';
  static const fornitore = 'fornitore';
}

abstract interface class VerificaDelTelefono {
  /// Manda un codice SMS a [numero] (`+393471234567`). `false` se non serve:
  /// è già il numero verificato di questa persona.
  Future<bool> mandaCodice(String numero);

  /// Controlla il [codice] arrivato a [numero]. Se è giusto il numero è
  /// verificato, sul server; altrimenti un [ErroreTrolley] che dice perché.
  Future<void> verifica(String numero, String codice);
}

/// La funzione `telefono` del server: `…/functions/v1/telefono`.
class VerificaSulServer implements VerificaDelTelefono {
  VerificaSulServer({
    required this.indirizzo,
    required this.chiavePubblica,
    required this.accesso,
    this.rete,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String indirizzo;
  final String chiavePubblica;

  /// Il gettone d'accesso di chi è dentro, letto a ogni richiesta.
  final String? Function() accesso;
  final Rete? rete;
  final http.Client _client;

  static const _messaggi = {
    CodiciTelefono.accesso: 'Non riusciamo a riconoscerti: esci e rientra.',
    CodiciTelefono.numero:
        'Questo non sembra un numero di cellulare. Controllalo, con il '
        'prefisso se non è italiano.',
    CodiciTelefono.chiusa:
        'Per ora la parte pubblica non accoglie profili nuovi.',
    CodiciTelefono.eta: 'La parte pubblica c\'è solo dai 18 anni.',
    CodiciTelefono.usato:
        'Questo numero è già di un altro account: un numero vale per un '
        'account solo.',
    CodiciTelefono.sbagliato:
        'Il codice non è giusto. Controllalo, o chiedine un altro.',
    CodiciTelefono.scaduto: 'Il codice è scaduto. Chiedine un altro.',
  };

  static const _nonParte = 'L\'SMS non parte, ora. Riprova tra poco.';

  @override
  Future<bool> mandaCodice(String numero) async {
    try {
      final esito = await _chiedi('invia', {'numero': numero});
      return esito != 'gia';
    } on ErroreTrolley catch (e) {
      if (e.codice != CodiciTelefono.tetto) rethrow;
      throw const ErroreTrolley(
        'Hai chiesto troppi codici per oggi. Riprova domani.',
        codice: CodiciTelefono.tetto,
      );
    }
  }

  @override
  Future<void> verifica(String numero, String codice) async {
    try {
      await _chiedi('verifica', {'numero': numero, 'codice': codice});
    } on ErroreTrolley catch (e) {
      if (e.codice != CodiciTelefono.tetto) rethrow;
      throw const ErroreTrolley(
        'Troppi tentativi per oggi. Riprova domani.',
        codice: CodiciTelefono.tetto,
      );
    }
  }

  /// Chiede [cosa] alla funzione. Restituisce l'`esito`; i no diventano un
  /// [ErroreTrolley] con il codice della funzione.
  Future<String?> _chiedi(String cosa, Map<String, String> corpo) async {
    final http.Response risposta;
    try {
      risposta = await _client
          .post(
            Uri.parse('$indirizzo/$cosa'),
            headers: {
              'apikey': chiavePubblica,
              if (accesso() case final gettone?)
                'authorization': 'Bearer $gettone',
              'content-type': 'application/json',
            },
            body: jsonEncode(corpo),
          )
          .timeout(const Duration(seconds: 15));
    } on SocketException {
      throw _senzaRete();
    } on TimeoutException {
      throw _senzaRete();
    } on http.ClientException {
      throw _senzaRete();
    }
    rete?.registraEsito(raggiunto: true);
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(risposta.bodyBytes));
    } on FormatException {
      throw const ErroreTrolley(_nonParte, codice: CodiciTelefono.fornitore);
    }
    final dati = json is Map<String, dynamic> ? json : const {};
    if (risposta.statusCode == 200) return dati['esito'] as String?;
    final codice = dati['codice'] as String? ?? CodiciTelefono.fornitore;
    throw ErroreTrolley(_messaggi[codice] ?? _nonParte, codice: codice);
  }

  ErroreTrolley _senzaRete() {
    rete?.registraEsito(raggiunto: false);
    return const ErroreTrolley(
      'Serve la connessione. Riprova quando sei online.',
      serveLaRete: true,
    );
  }
}
