/// I gesti sulle tappe che contano per la misurazione, in un posto solo: le
/// schermate li chiamano da qui così che nessuno dimentichi l'evento.
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../dati/coda.dart';
import '../dati/database.dart';
import '../dati/lettura.dart';
import '../dominio/tappe.dart';
import '../misurazione/misurazione.dart';
import '../servizi.dart';

/// Aggiunge delle tappe al viaggio: nella copia subito, al server appena c'è
/// rete (02 §2). Una dal foglio della tappa, tante da un itinerario incollato:
/// gli eventi sono gli stessi (07): il primo elemento del viaggio (H2), la
/// funzione usata (H1), il primo contributo di chi è stato invitato (H3). La
/// capienza l'ha già controllata chi chiama.
Future<void> aggiungiLeTappe(
  BuildContext context, {
  required Viaggio viaggio,
  required List<NuovaTappa> tappe,
}) async {
  if (tappe.isEmpty) return;
  final servizi = Servizi.of(context);
  final archivio = servizi.archivio;
  final misurazione = servizi.misurazione;
  final v = viaggio.id;
  final io = archivio.io;
  final (giaQui, spese, voci, documenti, ruolo) = await (
    archivio.osservaTappe(v).first,
    archivio.osservaSpese(v).first,
    archivio.osservaVoci(v).first,
    servizi.documenti.osserva(v).first,
    archivio.mioRuolo(v),
  ).wait;
  final primaDelViaggio =
      giaQui.isEmpty && spese.isEmpty && voci.isEmpty && documenti.isEmpty;
  final miaGia =
      documenti.isNotEmpty ||
      giaQui.any((t) => t.creatoDa == io) ||
      spese.any((s) => s.creatoDa == io) ||
      voci.any((x) => x.creatoDa == io);

  for (final tappa in tappe) {
    await archivio.coda.aggiungiTappa(tappa);
  }
  HapticFeedback.lightImpact();

  if (primaDelViaggio) {
    await misurazione.registraUnaVolta(
      'primo_elemento:$v',
      Eventi.primoElementoAggiunto,
      {
        'viaggio_id': v,
        'tipo': 'tappa',
        'ore_dalla_creazione': DateTime.now()
            .toUtc()
            .difference(viaggio.creato.toUtc())
            .inHours,
      },
    );
  }
  await misurazione.registraUnaVolta(
    'funzione:itinerario:$v',
    Eventi.funzioneUsataNelViaggio,
    {'viaggio_id': v, 'funzione': 'itinerario'},
  );
  if (ruolo == 'partecipante' && !miaGia) {
    await misurazione.registraUnaVolta(
      'primo_contributo:$v',
      Eventi.primoContributoInvitato,
      {'viaggio_id': v, 'tipo': 'tappa'},
    );
  }
  unawaited(misurazione.invia());
}

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
