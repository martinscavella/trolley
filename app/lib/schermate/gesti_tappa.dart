/// I gesti sulle tappe che contano per la misurazione, in un posto solo: le
/// schermate li chiamano da qui così che nessuno dimentichi l'evento.
library;

import 'dart:async';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../aspetto/elementi.dart';
import '../aspetto/formati.dart';
import '../aspetto/striscia.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/tipi.dart';
import '../dati/coda.dart';
import '../dati/database.dart';
import '../dati/errori.dart';
import '../dati/lettura.dart';
import '../dominio/calendario.dart';
import '../dominio/giornate.dart';
import '../dominio/orari.dart';
import '../dominio/tappe.dart';
import '../misurazione/misurazione.dart';
import '../servizi.dart';
import 'due_versioni.dart';

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

/// Svuota un giorno o tutto il viaggio (tela, 59 e 60): prima chiede, dicendo
/// quante tappe vanno via, poi le toglie in una scrittura sola. Richiede la
/// rete, come togliere una tappa: chi chiama lo dice prima, con il motivo.
/// Non ha un evento, come togliere una tappa: nessuna soglia lo chiede (07).
/// Restituisce quante ne sono uscite.
Future<int> svuotaLeTappe(
  BuildContext context, {
  required String viaggioId,
  required List<Tappa> tappe,
  required String titolo,
}) async {
  if (tappe.isEmpty) return 0;
  var conferma = false;
  final quante = tappe.length;
  await AdaptiveAlertDialog.show(
    context: context,
    title: titolo,
    message:
        'Spariscono per tutti quelli del viaggio. '
        '${tappe.any((t) => t.statoTappa.segnata) ? 'Anche quelle già segnate. ' : ''}'
        'Non si torna indietro.',
    actions: [
      AlertAction(
        title: 'Annulla',
        style: AlertActionStyle.cancel,
        onPressed: () {},
      ),
      AlertAction(
        title: quante == 1 ? 'Togli 1 tappa' : 'Togli $quante tappe',
        style: AlertActionStyle.destructive,
        onPressed: () => conferma = true,
      ),
    ],
  );
  if (!conferma || !context.mounted) return 0;
  try {
    final tolte = await Servizi.of(context).archivio
        .togliTappe(viaggioId, [for (final t in tappe) t.id]);
    HapticFeedback.mediumImpact();
    if (context.mounted) {
      mostraMessaggio(
        context,
        tolte == 1 ? 'Tolta 1 tappa.' : 'Tolte $tolte tappe.',
      );
    }
    return tolte;
  } on ErroreTrolley catch (e) {
    if (context.mounted) mostraMessaggio(context, e.messaggio, errore: true);
    return 0;
  }
}

/// I pezzi della striscia di un giorno, ai loro orari (tela, 127): fatte in
/// verde, le altre col colore del tipo, in rosso quelle fuori posto.
List<PezzoStriscia> pezziDelGiorno(
  FinestraGiorno finestra,
  List<Collocata<Tappa>> collocate,
) {
  final fuori = conflitti(finestra, collocate);
  return [
    for (final c in collocate)
      PezzoStriscia(
        c.durata,
        c.tappa.statoTappa == StatoTappa.completata
            ? Colori.verde
            : coloreTipo(c.tappa.tipoTappa),
        inizio: c.inizio,
        rosso: fuori.contains(c.tappa),
      ),
  ];
}

/// Perché una tappa non può stare a quell'ora, in poche parole: per la
/// linea del tempo mentre la si trascina (tela, 130).
String problemaInBreve(ProblemaOrario<Tappa> p) => switch (p) {
  Sovrapposta(:final con) when con.length == 1 =>
    'si sovrappone a «${con.single.chi.titolo}»',
  Sovrapposta() => 'si sovrappone a due tappe',
  PrimaDellInizio(:final inizio) => 'prima dell\'arrivo, alle ${ora(inizio)}',
  DopoLaFine(:final fine) when fine >= fineGiornata => 'oltre mezzanotte',
  DopoLaFine(:final fine) => 'dopo la partenza, alle ${ora(fine)}',
};

/// Sposta una tappa a un'altra ora, e se serve in un altro giorno: con la
/// sua versione, e se qualcuno l'ha cambiata intanto si sceglie fra le due
/// (02 §4). Richiede la rete.
Future<bool> spostaLaTappa(
  BuildContext context,
  Tappa tappa,
  Duration inizio, {
  String? giornoId,
}) async {
  final archivio = Servizi.of(context).archivio;
  try {
    final scelta = await salvaOScegli(
      context,
      () => archivio.modificaTappa(tappa, {
        'ora_inizio': scriviOra(inizio),
        if (giornoId != null && giornoId != tappa.giornoId)
          'giorno_id': giornoId,
      }),
    );
    return scelta != null;
  } on ErroreTrolley catch (e) {
    if (context.mounted) mostraMessaggio(context, e.messaggio, errore: true);
    return false;
  }
}
