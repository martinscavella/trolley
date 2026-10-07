/// I tuoi dati e chiudere l'account (U.1, prima dell'ondata 1; 06, «Diritti
/// delle persone»), dal telefono: l'ordine in cui si fanno le cose. Che cosa
/// succede ai viaggi lo decide il server (chiusura_account.sql) e lo dice
/// prima il dominio (chiusura_account.dart). Tutte e due richiedono la rete.
///
/// I documenti non passano di qui: stanno solo sul telefono, e chi parla con
/// il server non li tocca (03). Li toglie la schermata, dopo la chiusura.
library;

import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../dominio/calendario.dart';
import '../misurazione/misurazione.dart';
import 'archivio.dart';

/// Scarica dal server i propri dati e li scrive in [cartella], in un file
/// JSON leggibile da una persona e da una macchina:
/// `trolley-dati-2026-10-06.json`. Il file lo consegna chi chiama, con il
/// foglio di condivisione, e poi lo butta.
Future<File> scriviIMieiDati(
  Archivio archivio, {
  required Directory cartella,
  required DateTime oggi,
}) async {
  final dati = await archivio.iMieiDati();
  final file = File('${cartella.path}/trolley-dati-${scriviData(oggi)}.json');
  await file.writeAsString(
    const JsonEncoder.withIndent('  ').convert(dati),
    flush: true,
  );
  return file;
}

/// Chiude l'account sul server. Prima parte quello che aspetta: i gesti in
/// coda, perché arrivino nei viaggi degli altri, e gli eventi, che sul server
/// cambiano id con gli altri. Senza rete non cambia niente, e lo dice con un
/// `ErroreTrolley`.
Future<void> chiudiLAccountSulServer({
  required Archivio archivio,
  required Misurazione misurazione,
}) async {
  final misura = await misurazione.attiva;
  await archivio.coda.svuota();
  if (misura) await misurazione.invia();
  await archivio.chiudiAccount(misurazione: misura);
}

/// Dopo la chiusura sul server, e tolti i propri documenti: la copia si
/// svuota e si esce. Si torna all'accesso.
Future<void> lasciaIlTelefono({
  required Archivio archivio,
  required GoTrueClient accesso,
}) async {
  await archivio.svuotaLaCopia();
  try {
    await accesso.signOut();
  } on Object {
    // La sessione sul telefono è già tolta; sul server l'utente non c'è più.
  }
}
