/// Se c'è la rete (00-architettura.md, regola 3): quello che la richiede lo dice
/// prima, spegnendo il controllo con il motivo, invece di fallire dopo.
///
/// Due fonti. Il telefono sa se c'è una connessione; l'esito delle chiamate al
/// server sa se funziona davvero, perché il wi-fi d'albergo c'è ma non porta da
/// nessuna parte (02-sincronizzazione-e-offline.md). Basta una delle due per
/// dire che manca.
library;

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

abstract interface class Rete {
  /// Se adesso si può contare sulla rete.
  bool get disponibile;

  /// Il nuovo valore di [disponibile], ogni volta che cambia.
  Stream<bool> get cambi;

  /// Come è andata una chiamata al server.
  void registraEsito({required bool raggiunto});
}

/// La rete vista dal telefono (connectivity_plus) e dalle chiamate.
class ReteDelTelefono implements Rete {
  ReteDelTelefono([Connectivity? connettivita])
    : _connettivita = connettivita ?? Connectivity() {
    _connettivita.checkConnectivity().then(_nuovaConnessione, onError: _nulla);
    _iscrizione = _connettivita.onConnectivityChanged.listen(
      _nuovaConnessione,
      onError: _nulla,
    );
  }

  final Connectivity _connettivita;
  late final StreamSubscription<List<ConnectivityResult>> _iscrizione;
  final _cambi = StreamController<bool>.broadcast();

  /// Finché il telefono non dice altro, si prova.
  bool _connesso = true;
  bool _serverIrraggiungibile = false;

  @override
  bool get disponibile => _connesso && !_serverIrraggiungibile;

  /// Sempre lo stesso flusso, così chi lo ascolta non si riscrive a ogni
  /// ricostruzione.
  @override
  late final Stream<bool> cambi = _cambi.stream;

  void _nuovaConnessione(List<ConnectivityResult> risultati) => _aggiorna(() {
    _connesso = risultati.any((r) => r != ConnectivityResult.none);
    // Una connessione nuova merita un'altra occasione.
    _serverIrraggiungibile = false;
  });

  @override
  void registraEsito({required bool raggiunto}) => _aggiorna(() {
    _serverIrraggiungibile = !raggiunto;
    // Se il server ha risposto, la rete c'è, qualunque cosa dica il telefono.
    if (raggiunto) _connesso = true;
  });

  void _aggiorna(void Function() cambia) {
    final prima = disponibile;
    cambia();
    if (disponibile != prima && !_cambi.isClosed) _cambi.add(disponibile);
  }

  static void _nulla(Object _) {}

  Future<void> chiudi() async {
    await _iscrizione.cancel();
    await _cambi.close();
  }
}
