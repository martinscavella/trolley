/// I gesti dell'itinerario con un assistente che contano per la misurazione,
/// in un posto solo (07: `prompt_esportato`, `incollato_riuscito`,
/// `incollato_non_interpretato`, per la regola asimmetrica). Azioni, mai
/// contenuti: né la richiesta né la risposta entrano in un evento.
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

import '../dati/database.dart';
import '../dominio/itinerario.dart';
import '../misurazione/misurazione.dart';
import '../servizi.dart';

/// Consegna la richiesta: negli appunti, o col foglio di condivisione verso
/// l'app dell'assistente. Funziona senza rete: la richiesta nasce sul telefono.
/// Conta come esportata solo se è uscita davvero.
Future<bool> esportaLaRichiesta(
  BuildContext context, {
  required Viaggio viaggio,
  required String richiesta,
  bool condividi = false,
  Rect? origine,
}) async {
  final misurazione = Servizi.of(context).misurazione;
  if (condividi) {
    final esito = await SharePlus.instance.share(
      ShareParams(text: richiesta, sharePositionOrigin: origine),
    );
    if (esito.status == ShareResultStatus.dismissed) return false;
  } else {
    await Clipboard.setData(ClipboardData(text: richiesta));
  }
  HapticFeedback.lightImpact();
  await misurazione.registra(Eventi.promptEsportato, {'viaggio_id': viaggio.id});
  unawaited(misurazione.invia());
  return true;
}

/// Salva la risposta incollata come nota del viaggio, e poi la legge: la nota
/// c'è anche se la lettura non trova niente (04, regola 11). Richiede la rete,
/// per la nota.
Future<(Nota, ItinerarioLetto)> leggiLaRisposta(
  BuildContext context, {
  required Viaggio viaggio,
  required String testo,
}) async {
  final servizi = Servizi.of(context);
  final nota = await servizi.archivio.salvaNota(
    viaggioId: viaggio.id,
    testo: testo,
    origine: 'incollata',
  );
  final letto = leggiItinerario(testo);
  await servizi.misurazione.registra(
    letto.vuoto ? Eventi.incollatoNonInterpretato : Eventi.incollatoRiuscito,
    {'viaggio_id': viaggio.id},
  );
  unawaited(servizi.misurazione.invia());
  return (nota, letto);
}
