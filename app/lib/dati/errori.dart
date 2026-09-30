/// Gli errori che arrivano alla persona, detti in modo che capisca cosa fare.
library;

import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

class ErroreTrolley implements Exception {
  const ErroreTrolley(this.messaggio, {this.serveLaRete = false});

  final String messaggio;

  /// Il gesto richiede la rete e non c'era: non è colpa di nessuno, si riprova.
  final bool serveLaRete;

  @override
  String toString() => messaggio;
}

/// Codici d'errore del server (supabase/migrations).
abstract final class CodiciServer {
  static const accessoRichiesto = 'TR401';
  static const nonPermesso = 'TR403';
  static const nonTrovato = 'TR404';
  static const versioneSuperata = 'TR409';
}

/// Esegue una chiamata al server e traduce gli errori.
Future<T> alServer<T>(
  Future<T> Function() chiamata, {
  Map<String, String> messaggi = const {},
}) async {
  try {
    return await chiamata().timeout(const Duration(seconds: 12));
  } on PostgrestException catch (e) {
    throw ErroreTrolley(
      messaggi[e.code] ?? 'Qualcosa non ha funzionato. Riprova tra poco.',
    );
  } on AuthException catch (e) {
    throw ErroreTrolley(_messaggioAccesso(e));
  } on SocketException {
    throw _senzaRete;
  } on TimeoutException {
    // Anche la rete che c'è ma non funziona (wi-fi d'albergo) conta come assenza.
    throw _senzaRete;
  } on ErroreTrolley {
    rethrow;
  } on Exception catch (e) {
    if (e.toString().contains('ClientException')) throw _senzaRete;
    rethrow;
  }
}

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
