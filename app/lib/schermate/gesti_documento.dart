/// I gesti sui documenti che contano per la misurazione, in un posto solo,
/// come per le tappe (gesti_tappa.dart): così nessuno dimentica l'evento.
///
/// Gli eventi dicono che un documento è stato aggiunto, mai quale: niente nomi,
/// niente contenuti (07-misurazione.md, regola 1).
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../dati/acquisizione.dart';
import '../dati/database.dart';
import '../dati/lettura.dart';
import '../misurazione/misurazione.dart';
import '../servizi.dart';

/// Aggiunge un documento al viaggio, e lo misura (07): il primo elemento del
/// viaggio (H2), la funzione usata (H1), il primo contributo di chi è stato
/// invitato (H3). Funziona senza rete: il documento resta sul telefono, e gli
/// eventi partono quando la rete torna.
Future<Documento> aggiungiIlDocumento(
  BuildContext context, {
  required Viaggio viaggio,
  required String? giornoId,
  required Duration? ora,
  required String nome,
  required FileAcquisito sorgente,
}) async {
  final servizi = Servizi.of(context);
  final misurazione = servizi.misurazione;
  final v = viaggio.id;
  final io = servizi.documenti.io;
  final (tappe, spese, voci, giaQui, ruolo) = await (
    servizi.archivio.osservaTappe(v).first,
    servizi.archivio.osservaSpese(v).first,
    servizi.archivio.osservaVoci(v).first,
    servizi.documenti.osserva(v).first,
    servizi.archivio.mioRuolo(v),
  ).wait;

  final documento = await servizi.documenti.aggiungi(
    viaggioId: v,
    giornoId: giornoId,
    ora: ora,
    nome: nome,
    sorgente: sorgente,
  );
  await servizi.documenti.segnaAvvisoDato();
  HapticFeedback.lightImpact();

  if (tappe.isEmpty && spese.isEmpty && voci.isEmpty && giaQui.isEmpty) {
    await misurazione.registraUnaVolta(
      'primo_elemento:$v',
      Eventi.primoElementoAggiunto,
      {
        'viaggio_id': v,
        'tipo': 'documento',
        'ore_dalla_creazione': DateTime.now()
            .toUtc()
            .difference(viaggio.creato.toUtc())
            .inHours,
      },
    );
  }
  await misurazione.registraUnaVolta(
    'funzione:documenti:$v',
    Eventi.funzioneUsataNelViaggio,
    {'viaggio_id': v, 'funzione': 'documenti'},
  );
  if (ruolo == 'partecipante' &&
      giaQui.isEmpty &&
      !tappe.any((t) => t.creatoDa == io) &&
      !spese.any((s) => s.creatoDa == io) &&
      !voci.any((x) => x.creatoDa == io)) {
    await misurazione.registraUnaVolta(
      'primo_contributo:$v',
      Eventi.primoContributoInvitato,
      {'viaggio_id': v, 'tipo': 'documento'},
    );
  }
  unawaited(misurazione.invia());
  return documento;
}
