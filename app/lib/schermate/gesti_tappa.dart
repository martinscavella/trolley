/// I gesti sulle tappe che contano per la misurazione, in un posto solo: le
/// schermate li chiamano da qui così che nessuno dimentichi l'evento.
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../dati/database.dart';
import '../dati/lettura.dart';
import '../dominio/tappe.dart';
import '../misurazione/misurazione.dart';
import '../servizi.dart';

/// Segna una tappa, o la riporta da fare. Funziona anche senza rete: è uno
/// dei gesti della coda (02 §2). È il gesto da cui dipende la verifica del
/// viaggio, e si misura (07: `tappa_marcata`, durante il viaggio sì o no).
Future<void> segnaLaTappa(
  BuildContext context, {
  required Viaggio viaggio,
  required Tappa tappa,
  required StatoTappa stato,
}) async {
  final servizi = Servizi.of(context);
  final durante = segnataDuranteIlViaggio(viaggio.statoA(DateTime.now()));
  if (stato == StatoTappa.completata) {
    HapticFeedback.mediumImpact();
  } else {
    HapticFeedback.selectionClick();
  }
  await servizi.archivio.coda.segnaTappa(
    tappaId: tappa.id,
    viaggioId: viaggio.id,
    stato: stato,
    duranteIlViaggio: durante,
  );
  if (stato.segnata) {
    await servizi.misurazione.registra(Eventi.tappaMarcata, {
      'viaggio_id': viaggio.id,
      'durante_il_viaggio': durante,
    });
  }
}
