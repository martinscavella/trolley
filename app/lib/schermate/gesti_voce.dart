/// I gesti sulle cose da portare che contano per la misurazione, in un posto
/// solo, come per tappe, documenti e spese: così nessuno dimentica l'evento.
///
/// Gli eventi dicono che una voce è stata aggiunta, spuntata o presa, mai
/// quale: niente testi (07-misurazione.md, regola 1).
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../dati/database.dart';
import '../dati/lettura.dart';
import '../dominio/liste.dart';
import '../misurazione/misurazione.dart';
import '../servizi.dart';

/// Aggiunge una voce a una delle due liste, la propria o quella del viaggio.
/// Richiede la rete (05, regola 5): chi chiama ha già spento il campo senza.
/// Con i suoi eventi (07): il primo elemento del viaggio (H2), la funzione
/// usata (H1), il primo contributo di chi è stato invitato (H3).
Future<VoceLista> aggiungiLaVoce(
  BuildContext context, {
  required Viaggio viaggio,
  required String testo,
  int quantita = 1,
  TipoLista lista = TipoLista.personale,
}) async {
  final servizi = Servizi.of(context);
  final archivio = servizi.archivio;
  final misurazione = servizi.misurazione;
  final v = viaggio.id;
  final (tappe, spese, documenti, voci) = await (
    archivio.osservaTappe(v).first,
    archivio.osservaSpese(v).first,
    servizi.documenti.osserva(v).first,
    archivio.osservaVoci(v).first,
  ).wait;
  final primoContributo = await _primoContributo(servizi, v);

  final voce = await archivio.aggiungiVoce(
    viaggioId: v,
    testo: testo,
    quantita: quantita,
    lista: lista,
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
  if (primoContributo) await _contributo(misurazione, v);
  unawaited(misurazione.invia());
  return voce;
}

/// Cambia una voce: che cosa, quante, chi la porta. Richiede la rete (05,
/// regola 5). Prendere una voce del viaggio («la porto io») è il contributo
/// più naturale di chi è appena entrato nella lista comune (03, regola 9):
/// conta come usare le liste (H1) e, per un invitato, come primo contributo
/// (H3), e chiude il benvenuto. Se qualcuno l'ha cambiata intanto arriva un
/// [Conflitto], e chi chiama fa scegliere.
Future<void> cambiaLaVoce(
  BuildContext context, {
  required VoceLista voce,
  required Map<String, Object?> cambiamenti,
}) async {
  final servizi = Servizi.of(context);
  final archivio = servizi.archivio;
  final v = voce.viaggioId;
  final presa =
      cambiamenti.containsKey('assegnato_a') &&
      cambiamenti['assegnato_a'] == archivio.io;
  final primoContributo = presa && await _primoContributo(servizi, v);
  await archivio.modificaVoce(voce, cambiamenti);
  if (!presa) return;
  await _funzioneUsata(servizi.misurazione, v);
  if (primoContributo) await _contributo(servizi.misurazione, v);
  await archivio.chiudiBenvenuto(v);
  unawaited(servizi.misurazione.invia());
}

/// Sposta una voce nell'altra lista (05, «Voce»). Richiede la rete. Non è un
/// gesto nuovo per la misurazione: la voce c'era già, e aggiungerla l'aveva
/// contata (07, regola 2).
Future<VoceLista> spostaLaVoce(BuildContext context, VoceLista voce) async {
  final voceNuova = await Servizi.of(context).archivio.spostaVoce(voce);
  HapticFeedback.lightImpact();
  return voceNuova;
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

/// Se la persona è stata invitata e non ha ancora aggiunto niente di suo al
/// viaggio: una tappa, una spesa, un documento, una cosa da portare (03,
/// regola 9). Una voce presa su questo telefono lo dice la chiave
/// dell'evento; chi la porta per averla assegnata da un altro non ha ancora
/// contribuito, e la copia non sa distinguere i due casi.
Future<bool> _primoContributo(Servizi servizi, String v) async {
  final archivio = servizi.archivio;
  final io = archivio.io;
  final (tappe, spese, documenti, voci, ruolo) = await (
    archivio.osservaTappe(v).first,
    archivio.osservaSpese(v).first,
    servizi.documenti.osserva(v).first,
    archivio.osservaVoci(v).first,
    archivio.mioRuolo(v),
  ).wait;
  return ruolo == 'partecipante' &&
      documenti.isEmpty &&
      !tappe.any((t) => t.creatoDa == io) &&
      !spese.any((s) => s.creatoDa == io) &&
      !voci.any((x) => x.creatoDa == io);
}

Future<void> _contributo(Misurazione misurazione, String v) =>
    misurazione.registraUnaVolta(
      'primo_contributo:$v',
      Eventi.primoContributoInvitato,
      {'viaggio_id': v, 'tipo': 'voce'},
    );

Future<void> _funzioneUsata(Misurazione misurazione, String v) =>
    misurazione.registraUnaVolta(
      'funzione:liste:$v',
      Eventi.funzioneUsataNelViaggio,
      {'viaggio_id': v, 'funzione': 'liste'},
    );
