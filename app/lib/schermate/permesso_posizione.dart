import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../aspetto/elementi.dart';
import '../aspetto/movimento.dart';
import '../aspetto/pagina.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../dati/database.dart';
import '../dati/destinazioni.dart';
import '../dati/posizione.dart';
import '../dati/sul_posto.dart';
import '../misurazione/misurazione.dart';
import '../servizi.dart';

/// Il permesso di posizione (02, regola 9; tela, 58 e 59). Prima di farlo
/// chiedere al telefono si dice a cosa serve: il puntino sulla mappa, e la
/// verifica del viaggio, con la posizione che non lascia il telefono. Se la
/// persona dice di no, si dice subito — una volta sola — che il viaggio non
/// potrà essere verificato, e che tutto il resto funziona.
///
/// [daSolo]: lo chiede l'app, aprendo «Adesso» o la mappa di un viaggio in
/// corso, e dopo un «Non ora» non lo richiede fino a domani. Altrimenti lo
/// chiede la persona, con «Portami».
///
/// Restituisce il permesso com'è alla fine. Si misura che cosa si risponde
/// (07: `permesso_posizione`).
Future<PermessoPosizione> chiediLaPosizione(
  BuildContext context, {
  required Viaggio viaggio,
  bool daSolo = false,
  DateTime Function() orologio = DateTime.now,
}) async {
  final servizi = Servizi.of(context);
  final archivio = servizi.archivio;
  final posizione = servizi.posizione;
  var permesso = await posizione.permesso();
  if (permesso == PermessoPosizione.daChiedere) {
    if (daSolo && await archivio.posizioneNonOraOggi(orologio())) {
      return permesso;
    }
    if (!context.mounted) return permesso;
    final continua = await apriAPienoSchermo<bool>(
      context,
      SchermataPercheLaPosizione(viaggio: viaggio),
    );
    if (continua != true) {
      if (daSolo) await archivio.posizioneNonOra(orologio());
      await servizi.misurazione.registra(Eventi.permessoPosizione, {
        'viaggio_id': viaggio.id,
        'esito': 'non_ora',
      });
      return permesso;
    }
    permesso = await posizione.chiedi();
    await servizi.misurazione.registra(Eventi.permessoPosizione, {
      'viaggio_id': viaggio.id,
      'esito': permesso == PermessoPosizione.concesso ? 'concesso' : 'negato',
    });
  }
  if (permesso == PermessoPosizione.negato &&
      !await archivio.posizioneNegataDetta()) {
    await archivio.segnaPosizioneNegataDetta();
    if (context.mounted) {
      await apriAPienoSchermo<void>(context, const SchermataPosizioneNegata());
    }
  }
  return permesso;
}

/// Mentre il viaggio è in corso: chiede la posizione se non si è mai
/// chiesta, e se c'è guarda se la persona è sul posto (dati/sul_posto.dart).
/// Lo fanno da sole «Adesso» e la mappa; non disturba mai due volte.
Future<void> guardaIlPosto(
  BuildContext context, {
  required Viaggio viaggio,
  bool chiedi = true,
  DateTime Function() orologio = DateTime.now,
}) async {
  final servizi = Servizi.of(context);
  try {
    if (chiedi) {
      await chiediLaPosizione(
        context,
        viaggio: viaggio,
        daSolo: true,
        orologio: orologio,
      );
    }
    await controllaSulPosto(
      viaggio: viaggio,
      archivio: servizi.archivio,
      posizione: servizi.posizione,
      elenco: ElencoDestinazioni.carica,
      orologio: orologio,
    );
  } on Object {
    // Non è una cosa che la persona ha chiesto: se non va, riproverà alla
    // prossima apertura, senza dire niente.
  }
}

/// «Sei davvero a Porto?» (tela, 58): a cosa serve la posizione, prima che
/// la chieda il telefono. Chiudendo restituisce `true` per «Continua».
class SchermataPercheLaPosizione extends StatelessWidget {
  const SchermataPercheLaPosizione({super.key, required this.viaggio});

  final Viaggio viaggio;

  @override
  Widget build(BuildContext context) {
    final citta = viaggio.destinazioneCitta;
    return Pagina(
      sinistra: const SizedBox.shrink(),
      corpo: Builder(
        builder: (context) => ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.paddingOf(context).top,
            20,
            MediaQuery.paddingOf(context).bottom + 32,
          ),
          children: [
            IconaGrande(
              icona: icona(
                ios: CupertinoIcons.location,
                android: Icons.place_outlined,
              ),
              fondo: Colori.cobaltoChiaro,
              colore: Colori.cobalto,
            ).entra(context),
            const SizedBox(height: 18),
            TitoloPagina(
              citta == null
                  ? 'Sei davvero sul posto?'
                  : 'Sei davvero a $citta?',
              sottotitolo:
                  'Per verificare il viaggio Trolley controlla, mentre sei in '
                  'viaggio, che tu sia nella città o nel paese del viaggio. Un '
                  'viaggio verificato dà i traguardi.',
            ).entra(context),
            Spiegazione(
              righe: [
                (
                  icona(ios: CupertinoIcons.lock, android: Icons.lock_outline),
                  'La posizione non lascia il telefono: al server arriva solo '
                      '«sì» o «no».',
                ),
                (
                  icona(
                    ios: CupertinoIcons.globe,
                    android: Icons.public_rounded,
                  ),
                  'Si guarda la città o il paese, mai la via.',
                ),
                (
                  icona(ios: CupertinoIcons.map, android: Icons.map_outlined),
                  'La stessa posizione mostra il puntino sulla mappa.',
                ),
              ],
            ).entra(context, ritardo: Ritmo.passo),
            const SizedBox(height: 24),
            PulsanteGrande(
              etichetta: 'Continua',
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 10),
            PulsanteGrande(
              etichetta: 'Non ora',
              secondario: true,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            const SizedBox(height: 8),
            Text(
              'Dopo «Continua» il telefono ti chiede il permesso.',
              textAlign: TextAlign.center,
              style: Testi.didascalia.copyWith(color: Colori.grafite),
            ),
          ],
        ),
      ),
    );
  }
}

/// «Va bene anche così» (tela, 59): senza la posizione l'app funziona per
/// intero, ma il viaggio non potrà essere verificato. Si dice ora, una
/// volta, per non farlo scoprire alla fine (02, regola 9).
class SchermataPosizioneNegata extends StatelessWidget {
  const SchermataPosizioneNegata({super.key});

  @override
  Widget build(BuildContext context) => Pagina(
    sinistra: const SizedBox.shrink(),
    corpo: Builder(
      builder: (context) => ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          MediaQuery.paddingOf(context).top,
          20,
          MediaQuery.paddingOf(context).bottom + 32,
        ),
        children: [
          IconaGrande(
            icona: icona(
              ios: CupertinoIcons.location,
              android: Icons.place_outlined,
            ),
            fondo: Colori.foschia,
            colore: Colori.grafite,
          ).entra(context),
          const SizedBox(height: 18),
          const TitoloPagina(
            'Va bene anche così',
            sottotitolo:
                'Senza la posizione Trolley funziona per intero: programma, '
                'mappa, spese, documenti.',
          ).entra(context),
          Avviso(
            icona: icona(
              ios: CupertinoIcons.star,
              android: Icons.star_outline_rounded,
            ),
            inizio: 'Questo viaggio però non potrà essere verificato,',
            testo:
                'e non darà traguardi. Si chiude lo stesso, e finisce nel '
                'passaporto.',
          ).entra(context, ritardo: Ritmo.passo),
          const SizedBox(height: 24),
          PulsanteGrande(
            etichetta: 'Apri Impostazioni',
            secondario: true,
            onPressed: () async {
              final navigatore = Navigator.of(context);
              await Servizi.of(context).posizione.apriImpostazioni();
              navigatore.pop();
            },
          ),
          const SizedBox(height: 10),
          PulsanteGrande(
            etichetta: 'Ho capito',
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 8),
          Text(
            'Lo diciamo ora, una volta, per non fartelo scoprire alla fine del '
            'viaggio.',
            textAlign: TextAlign.center,
            style: Testi.didascalia.copyWith(color: Colori.grafite),
          ),
        ],
      ),
    ),
  );
}
