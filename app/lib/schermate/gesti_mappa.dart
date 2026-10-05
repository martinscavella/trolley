/// I gesti della mappa che più schermate condividono: dove centrarla, come
/// portare la persona a una tappa, come contare quello che costa (ADR-006).
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../aspetto/elementi.dart';
import '../aspetto/piattaforma.dart';
import '../dati/database.dart';
import '../dati/destinazioni.dart';
import '../dati/lettura.dart';
import '../dati/mappe.dart';
import '../dati/posizione.dart';
import '../dominio/mappa.dart';
import '../misurazione/misurazione.dart';
import '../servizi.dart';
import 'navigazione.dart';
import 'permesso_posizione.dart';

/// Dove guardare quando la mappa si apre o si cerca un posto: il centro delle
/// tappe che hanno un posto, altrimenti la meta del viaggio. `null` se non si
/// sa niente.
Future<({Coordinate centro, bool dalleTappe})?> centroDelViaggio(
  Viaggio viaggio,
  Iterable<Tappa> tappe,
) async {
  final riquadro = riquadroDi([for (final t in tappe) ?t.posto]);
  if (riquadro != null) {
    final (:sudOvest, :nordEst) = riquadro;
    return (
      centro: (
        lat: (sudOvest.lat + nordEst.lat) / 2,
        lon: (sudOvest.lon + nordEst.lon) / 2,
      ),
      dalleTappe: true,
    );
  }
  final ElencoDestinazioni elenco;
  try {
    elenco = await ElencoDestinazioni.carica();
  } on Object {
    return null;
  }
  final meta = elenco.trova(
    citta: viaggio.destinazioneCitta,
    paese: viaggio.destinazionePaese,
  );
  final posto = coordinate(meta?.lat, meta?.lon);
  return posto == null ? null : (centro: posto, dalleTappe: false);
}

/// Registra quanto si è chiesto al fornitore da [prima] a adesso, per il
/// viaggio (07: `consumo_mappe`). Niente se non si è chiesto niente.
Future<void> registraConsumo(
  Misurazione misurazione,
  Mappe mappe, {
  required String viaggioId,
  required ConsumoMappe prima,
}) async {
  final consumo = mappe.consumo - prima;
  if (consumo.nullo) return;
  await misurazione.registra(Eventi.consumoMappe, {
    'viaggio_id': viaggioId,
    ...consumo.proprieta,
  });
  unawaited(misurazione.invia());
}

/// «Portami»: la navigazione dentro Trolley se si può (rete, fornitore,
/// posizione), altrimenti le Mappe del telefono — chi sta viaggiando non
/// resta mai senza indicazioni (ADR-006). Il permesso di posizione si chiede
/// qui, la prima volta, dopo aver detto a cosa serve (tela, 58); dopo un no
/// non si insiste.
Future<void> portamiAllaTappa(
  BuildContext context, {
  required Viaggio viaggio,
  required Tappa tappa,
  required int numero,
}) async {
  final servizi = Servizi.of(context);
  final posto = tappa.posto;
  Future<void> alleMappe() async {
    final aperte = await servizi.mappeDelTelefono.portami(
      nome: tappa.titolo,
      posto: posto,
      indirizzo: tappa.luogoNome,
    );
    if (!aperte && context.mounted) {
      mostraMessaggio(context, 'Le Mappe non si sono aperte.', errore: true);
    }
  }

  if (posto == null ||
      !servizi.rete.disponibile ||
      !servizi.mappe.disponibili) {
    return alleMappe();
  }
  final permesso = await chiediLaPosizione(context, viaggio: viaggio);
  if (!context.mounted) return;
  if (permesso != PermessoPosizione.concesso) {
    mostraMessaggio(
      context,
      permesso == PermessoPosizione.spenta
          ? 'La localizzazione è spenta: ti portano le Mappe del telefono.'
          : 'Senza la posizione ti portano le Mappe del telefono.',
    );
    return alleMappe();
  }
  await apriAPienoSchermo<void>(
    context,
    SchermataNavigazione(viaggio: viaggio, tappa: tappa, numero: numero),
  );
}
