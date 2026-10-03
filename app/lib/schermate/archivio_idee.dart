import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../aspetto/elementi.dart';
import '../aspetto/formati.dart';
import '../aspetto/movimento.dart';
import '../aspetto/pagina.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../dati/archivio.dart';
import '../dati/database.dart';
import '../dati/errori.dart';
import '../servizi.dart';
import 'con_la_rete.dart';
import 'date_viaggio.dart';
import 'scelta_periodo.dart';
import 'viaggio.dart';

/// Le idee in archivio: il loro periodo è passato senza che diventassero
/// viaggi. Fuori dalla vista principale, mai cancellate (02-il-viaggio.md,
/// regola 5). Si leggono anche senza rete; riprenderle la richiede.
class SchermataArchivio extends StatelessWidget {
  const SchermataArchivio({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Tavolozza.of(context);
    return Pagina(
      corpo: StreamBuilder<List<ViaggioInElenco>>(
        stream: Servizi.of(context).archivio
            .osservaViaggiInElenco(archiviati: true),
        builder: (context, snapshot) {
          final idee = snapshot.data ?? const <ViaggioInElenco>[];
          return ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.paddingOf(context).top + 4,
              16,
              MediaQuery.paddingOf(context).bottom + 24,
            ),
            children: [
              const TitoloPagina(
                'Archivio delle idee',
                sottotitolo:
                    'Le idee il cui periodo è passato senza che diventassero '
                    'viaggi. Non si cancellano: si riprendono quando torna la '
                    'voglia.',
              ).entra(context),
              if (snapshot.hasData && idee.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 48),
                  child: Text(
                    'L\'archivio è vuoto.',
                    textAlign: TextAlign.center,
                    style: Testi.corpo.copyWith(color: t.testoTerziario),
                  ),
                ),
              for (final (i, idea) in idee.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _IdeaArchiviata(idea: idea.viaggio)
                      .entra(context, ritardo: Ritmo.passo * (i + 1)),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _IdeaArchiviata extends StatelessWidget {
  const _IdeaArchiviata({required this.idea});

  final Viaggio idea;

  /// Si riprende con un periodo nuovo, perché quello vecchio è passato, oppure
  /// direttamente con le date.
  Future<void> _riprendi(BuildContext context) async {
    final archivio = Servizi.of(context).archivio;
    Future<void> conPeriodo() => apri<bool>(
      context,
      SchermataPeriodo(
        titolo: 'Riprendi l\'idea',
        spiegazione: 'Torna fra le idee con un periodo nuovo: quello di prima è passato.',
        conferma: 'Riprendi',
        ammettiNessuno: false,
        onConferma: (periodo) => archivio.riprendi(idea, periodo),
      ),
      dalBasso: true,
    );
    Future<void> conDate() =>
        apri<bool>(context, SchermataDate(viaggio: idea), dalBasso: true);

    await AdaptiveAlertDialog.show(
      context: context,
      title: 'Riprendi «${titoloViaggio(idea)}»',
      message:
          'Con un periodo nuovo torna fra le idee; con le date diventa '
          'subito un viaggio in programma.',
      actions: [
        AlertAction(
          title: 'Con un periodo',
          style: AlertActionStyle.primary,
          onPressed: conPeriodo,
        ),
        AlertAction(title: 'Con le date', onPressed: conDate),
        AlertAction(
          title: 'Annulla',
          style: AlertActionStyle.cancel,
          onPressed: () {},
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Tavolozza.of(context);
    final segno = bandiera(idea.destinazionePaese);
    final periodo = idea.periodoApprossimativo;
    return Pannello(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Premibile(
            onTap: () =>
                apri<void>(context, SchermataViaggio(viaggioId: idea.id)),
            scala: 0.985,
            etichetta: titoloViaggio(idea),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: segno == null
                      ? Icon(
                          icona(
                            ios: CupertinoIcons.archivebox,
                            android: Icons.archive_outlined,
                          ),
                          color: t.testoSecondario,
                        )
                      : Text(segno, style: const TextStyle(fontSize: 28)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titoloViaggio(idea),
                        style: Testi.evidenza.copyWith(color: t.testo),
                      ),
                      Text(
                        periodo == null
                            ? 'Senza periodo'
                            : 'Era per ${periodo.toLowerCase()}',
                        style: Testi.secondario.copyWith(
                          color: t.testoSecondario,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ConLaRete(
            builder: (context, rete) => PulsanteGrande(
              etichetta: 'Riprendi',
              secondario: true,
              motivo: rete ? null : motivoSenzaRete,
              onPressed: () => _riprendi(context),
            ),
          ),
        ],
      ),
    );
  }
}
