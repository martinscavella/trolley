import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../aspetto/elementi.dart';
import '../aspetto/movimento.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../dati/database.dart';
import '../dati/errori.dart';
import '../dati/lettura.dart';
import '../dominio/calendario.dart';
import '../dominio/stato_viaggio.dart';
import '../misurazione/misurazione.dart';
import '../servizi.dart';
import 'campi_date.dart';
import 'con_la_rete.dart';
import 'scelta_periodo.dart';

/// Le date di un viaggio che esiste già: fissarle per un'idea, che così
/// diventa in programma (02-il-viaggio.md, regola 3), oppure spostarle. Da qui
/// si torna anche a idea. Tutto richiede la rete.
class SchermataDate extends StatefulWidget {
  const SchermataDate({super.key, required this.viaggio});

  final Viaggio viaggio;

  @override
  State<SchermataDate> createState() => _SchermataDateState();
}

class _SchermataDateState extends State<SchermataDate> {
  late var _bozza = switch (widget.viaggio.programma) {
    final programma? => BozzaProgramma.da(programma),
    null => const BozzaProgramma(),
  };
  bool _inCorso = false;

  StatoViaggio get _stato => widget.viaggio.statoA(DateTime.now());

  /// Un'idea, anche ripresa dall'archivio: fissare le date la fa diventare
  /// definita.
  bool get _eUnIdea =>
      _stato == StatoViaggio.idea || _stato == StatoViaggio.archiviato;

  Future<void> _salva() async {
    final programma = _bozza.programma!;
    final servizi = Servizi.of(context);
    final navigatore = Navigator.of(context);
    final eraIdea = _eUnIdea;
    setState(() => _inCorso = true);
    try {
      await servizi.archivio.programma(widget.viaggio, programma);
      if (eraIdea) {
        await servizi.misurazione.registra(Eventi.ideaDefinita, {
          'giorni_dalla_creazione':
              giorniDiCalendario(widget.viaggio.creato, DateTime.now()) - 1,
          'durata_prevista_giorni': programma.durataGiorni,
        });
      }
      HapticFeedback.mediumImpact();
      navigatore.pop(true);
    } on ErroreTrolley catch (e) {
      if (mounted) mostraMessaggio(context, e.messaggio, errore: true);
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  Future<void> _tornaIdea() async {
    final archivio = Servizi.of(context).archivio;
    final navigatore = Navigator.of(context);
    final tornata = await apri<bool>(
      context,
      SchermataPeriodo(
        titolo: 'Torna a idea',
        spiegazione:
            'Le date e i giorni spariscono dalla vista. Quello che vi è '
            'agganciato resta salvato, e torna se fissate di nuovo le stesse '
            'date. Intanto, quando pensate di partire?',
        conferma: 'Torna a idea',
        pericolo: true,
        onConferma: (periodo) =>
            archivio.tornaIdea(widget.viaggio, periodo: periodo),
      ),
    );
    if (tornata == true) navigatore.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final t = Tavolozza.of(context);
    final eUnIdea = _eUnIdea;
    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(
        title: eUnIdea ? 'Fissa le date' : 'Cambia le date',
        leading: const PulsanteChiudi(),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          MediaQuery.paddingOf(context).top + 16,
          16,
          MediaQuery.paddingOf(context).bottom + 32,
        ),
        children: [
          Text(
            eUnIdea
                ? 'Con le date l\'idea diventa un viaggio in programma: arrivano '
                      'i giorni, e con loro le tappe, le spese e i documenti.'
                : 'I giorni che escono dalle date non si perdono: tornano se '
                      'le date tornano a comprenderli.',
            style: Testi.corpo.copyWith(color: t.testoSecondario),
          ).entra(context),
          const SizedBox(height: 20),
          CampiDate(
            bozza: _bozza,
            onCambio: (b) => setState(() => _bozza = b),
          ).entra(context, ritardo: Ritmo.passo),
          const SizedBox(height: 32),
          ConLaRete(
            builder: (context, rete) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PulsanteGrande(
                  etichetta: eUnIdea ? 'Fissa le date' : 'Salva le date',
                  inCorso: _inCorso,
                  motivo: rete ? _bozza.problema : motivoSenzaRete,
                  onPressed: _salva,
                ),
                if (_stato.puoTornareIdea) ...[
                  const SizedBox(height: 8),
                  PulsanteGrande(
                    etichetta: 'Torna a idea',
                    secondario: true,
                    pericolo: true,
                    motivo: rete ? null : motivoSenzaRete,
                    onPressed: _inCorso ? null : _tornaIdea,
                  ),
                ],
              ],
            ),
          ).entra(context, ritardo: Ritmo.passo * 2),
        ],
      ),
    );
  }
}
