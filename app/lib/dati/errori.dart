/// Gli errori che arrivano alla persona, detti in modo che capisca cosa fare.
library;

import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'rete.dart';

class ErroreTrolley implements Exception {
  const ErroreTrolley(this.messaggio, {this.serveLaRete = false, this.codice});

  final String messaggio;

  /// Il gesto richiede la rete e non c'era: non è colpa di nessuno, si riprova.
  final bool serveLaRete;

  /// Il codice del server, se è stato lui a rifiutare ([CodiciServer]).
  final String? codice;

  @override
  String toString() => messaggio;
}

/// Codici d'errore del server (supabase/migrations).
abstract final class CodiciServer {
  static const accessoRichiesto = 'TR401';
  static const nonPermesso = 'TR403';
  static const nonTrovato = 'TR404';
  static const versioneSuperata = 'TR409';

  /// Chi è responsabile del viaggio esce solo dopo aver passato il ruolo.
  static const primaPassaIlRuolo = 'TR412';
}

/// Il motivo scritto sotto un controllo spento perché manca la rete.
const motivoSenzaRete = 'Serve la connessione';

/// Esegue una chiamata al server e traduce gli errori. Se c'è [rete], le dice
/// com'è andata: è così che il wi-fi che non funziona conta come assente.
Future<T> alServer<T>(
  Future<T> Function() chiamata, {
  Map<String, String> messaggi = const {},
  Rete? rete,
}) async {
  try {
    final risultato = await chiamata().timeout(const Duration(seconds: 12));
    rete?.registraEsito(raggiunto: true);
    return risultato;
  } on PostgrestException catch (e) {
    rete?.registraEsito(raggiunto: true);
    throw ErroreTrolley(
      messaggi[e.code] ?? _messaggiComuni[e.code] ?? _qualcosaNonVa,
      codice: e.code,
    );
  } on AuthRetryableFetchException catch (e) {
    // Senza codice, la richiesta non ha nemmeno raggiunto il server.
    final raggiunto = e.statusCode != null;
    rete?.registraEsito(raggiunto: raggiunto);
    throw raggiunto ? ErroreTrolley(_messaggioAccesso(e)) : _senzaRete;
  } on AuthException catch (e) {
    rete?.registraEsito(raggiunto: true);
    throw ErroreTrolley(_messaggioAccesso(e));
  } on SocketException {
    rete?.registraEsito(raggiunto: false);
    throw _senzaRete;
  } on TimeoutException {
    // Anche la rete che c'è ma non funziona (wi-fi d'albergo) conta come assenza.
    rete?.registraEsito(raggiunto: false);
    throw _senzaRete;
  } on ErroreTrolley {
    rethrow;
  } on Exception catch (e) {
    if (e.toString().contains('ClientException')) {
      rete?.registraEsito(raggiunto: false);
      throw _senzaRete;
    }
    rethrow;
  }
}

const _qualcosaNonVa = 'Qualcosa non ha funzionato. Riprova tra poco.';

const _messaggiComuni = {
  CodiciServer.versioneSuperata:
      'Qualcun altro ha appena cambiato questo viaggio. Ora vedi la versione '
      'aggiornata: controlla e riprova.',
};

const _senzaRete = ErroreTrolley(
  'Serve la connessione. Riprova quando sei online.',
  serveLaRete: true,
);

String _messaggioAccesso(AuthException e) => switch (e.code) {
  'invalid_credentials' => 'Email o password non corrette.',
  'email_not_confirmed' =>
    'Prima conferma l\'email: ti abbiamo mandato un link.',
  'user_already_exists' ||
  'email_exists' => 'Esiste già un account con questa email. Accedi.',
  'weak_password' => 'La password è troppo corta: servono almeno 6 caratteri.',
  _ => 'Accesso non riuscito. Riprova.',
};
