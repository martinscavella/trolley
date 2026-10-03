/// I gesti sulle cose da portare che contano per la misurazione, in un posto
/// solo, come per tappe, documenti e spese: così nessuno dimentica l'evento.
///
/// Gli eventi dicono che una voce è stata aggiunta o spuntata, mai quale:
/// niente testi (07-misurazione.md, regola 1).
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../dati/database.dart';
import '../dati/lettura.dart';
import '../misurazione/misurazione.dart';
import '../servizi.dart';

/// Aggiunge una voce alla propria lista. Richiede la rete (05, regola 5): chi
/// chiama ha già spento il campo senza. Con i suoi eventi (07): il primo
/// elemento del viaggio (H2), la funzione usata (H1), il primo contributo di
/// chi è stato invitato (H3).
Future<VoceLista> aggiungiLaVoce(
  BuildContext context, {
  required Viaggio viaggio,
  required String testo,
  int quantita = 1,
}) async {
  final servizi = Servizi.of(context);
  final archivio = servizi.archivio;
  final misurazione = servizi.misurazione;
  final v = viaggio.id;
  final io = archivio.io;
  final (tappe, spese, documenti, voci, ruolo) = await (
    archivio.osservaTappe(v).first,
    archivio.osservaSpese(v).first,
    servizi.documenti.osserva(v).first,
    archivio.osservaVoci(v).first,
    archivio.mioRuolo(v),
  ).wait;

  final voce = await archivio.aggiungiVoce(
    viaggioId: v,
    testo: testo,
    quantita: quantita,
  );
  HapticFeedback.lightImpact();

  if (tappe.isEmpty && spese.isEmpty && documenti.isEmpty && voci.isEmpty) {
    await misurazione.registraUnaVolta(
      'primo_elemento:$v',
      Eventi.primoElementoAggiunto,
      {
        'viaggio_id': v,
        'tipo': 'voce',
        'ore_dalla_creazione': DateTime.now()
            .toUtc()
            .difference(viaggio.creato.toUtc())
            .inHours,
      },
    );
  }
  await _funzioneUsata(misurazione, v);
  if (ruolo == 'partecipante' &&
      documenti.isEmpty &&
      !tappe.any((t) => t.creatoDa == io) &&
      !spese.any((s) => s.creatoDa == io) &&
      !voci.any((x) => x.creatoDa == io)) {
    await misurazione.registraUnaVolta(
      'primo_contributo:$v',
      Eventi.primoContributoInvitato,
      {'viaggio_id': v, 'tipo': 'voce'},
    );
  }
  unawaited(misurazione.invia());
  return voce;
}

/// Spunta una voce, o le toglie la spunta. Funziona anche senza rete: è uno
/// dei quattro gesti della coda (02 §2), quello che capita mentre si fa la
/// valigia. Usare la lista è usare la funzione (07, H1), anche senza averla
/// scritta.
Future<void> spuntaLaVoce(
  BuildContext context, {
  required VoceLista voce,
  required bool spuntata,
}) async {
  final servizi = Servizi.of(context);
  if (spuntata) {
    HapticFeedback.lightImpact();
  } else {
    HapticFeedback.selectionClick();
  }
  await servizi.archivio.coda.spuntaVoce(
    voceId: voce.id,
    viaggioId: voce.viaggioId,
    spuntata: spuntata,
    testo: voce.testo,
  );
  if (spuntata) await _funzioneUsata(servizi.misurazione, voce.viaggioId);
}

/// Rimette da mettere tutto quello che è in valigia: per rifare la valigia al
/// ritorno. Sono spunte, quindi funziona anche senza rete.
Future<void> rimettiTuttoDaMettere(
  BuildContext context, {
  required List<VoceLista> voci,
}) async {
  final coda = Servizi.of(context).archivio.coda;
  HapticFeedback.mediumImpact();
  for (final voce in voci.where((v) => v.spuntata)) {
    await coda.spuntaVoce(
      voceId: voce.id,
      viaggioId: voce.viaggioId,
      spuntata: false,
      testo: voce.testo,
    );
  }
}

Future<void> _funzioneUsata(Misurazione misurazione, String v) =>
    misurazione.registraUnaVolta(
      'funzione:liste:$v',
      Eventi.funzioneUsataNelViaggio,
      {'viaggio_id': v, 'funzione': 'liste'},
    );
