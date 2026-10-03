import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../aspetto/elementi.dart';
import '../aspetto/piattaforma.dart';
import '../dati/coda.dart';
import '../dati/database.dart';
import '../servizi.dart';
import 'con_la_rete.dart';

/// I gesti fatti senza rete che il server ha rifiutato più volte: si dice
/// cosa è successo, e la persona può riprovare o scartarli. Non si cancellano
/// in silenzio (02-sincronizzazione-e-offline.md, casi limite).
class ProblemiDellaCoda extends StatelessWidget {
  const ProblemiDellaCoda({super.key, required this.operazioni});

  /// Le operazioni di un viaggio, come le dà [Coda.osserva].
  final List<OperazioneInCoda> operazioni;

  @override
  Widget build(BuildContext context) {
    final messeDaParte = [
      for (final op in operazioni)
        if (op.messaDaParte) op,
    ];
    if (messeDaParte.isEmpty) return const SizedBox.shrink();
    final archivio = Servizi.of(context).archivio;
    return ConLaRete(
      builder: (context, rete) => Column(
        children: [
          for (final op in messeDaParte)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Avviso(
                errore: true,
                icona: icona(
                  ios: CupertinoIcons.exclamationmark_circle,
                  android: Icons.error_outline_rounded,
                ),
                inizio: Coda.cosaNonEArrivato(op),
                testo: op.ultimoErrore ?? '',
                azioni: [
                  PulsantePiccolo(
                    etichetta: 'Riprova',
                    onPressed: rete ? () => archivio.coda.riprova(op.id) : null,
                  ),
                  PulsantePiccolo(
                    etichetta: 'Scarta',
                    pericolo: true,
                    onPressed: () async {
                      await archivio.coda.scarta(op.id);
                      if (rete) {
                        unawaited(archivio.aggiornaCopia().catchError((_) {}));
                      }
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
