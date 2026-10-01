import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../aspetto/elementi.dart';
import '../aspetto/movimento.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../dati/destinazioni.dart';
import '../dati/errori.dart';
import '../dominio/periodo.dart';
import '../misurazione/misurazione.dart';
import '../servizi.dart';
import 'campi_date.dart';
import 'con_la_rete.dart';
import 'scelta_destinazione.dart';
import 'scelta_periodo.dart';
import 'viaggio.dart';

/// Un viaggio nuovo: dove, e poi le date **oppure** un periodo
/// (02-il-viaggio.md, "Nuovo viaggio"). Con le date nasce in programma, con i
/// suoi giorni; senza, nasce idea. Richiede la rete: senza, lo dice prima.
class SchermataNuovoViaggio extends StatefulWidget {
  const SchermataNuovoViaggio({super.key});

  @override
  State<SchermataNuovoViaggio> createState() => _SchermataNuovoViaggioState();
}

class _SchermataNuovoViaggioState extends State<SchermataNuovoViaggio> {
  Destinazione? _destinazione;
  bool _conDate = true;
  var _bozza = const BozzaProgramma();
  Periodo? _periodo;
  bool _inCorso = false;

  @override
  void initState() {
    super.initState();
    // L'elenco delle destinazioni si carica subito: quando si tocca "Dove?"
    // è già pronto.
    ElencoDestinazioni.carica();
  }

  Future<void> _scegliDestinazione() async {
    final scelta = await apri<Destinazione>(
      context,
      const SchermataDestinazione(),
    );
    if (scelta != null && mounted) setState(() => _destinazione = scelta);
  }

  String? get _cosaManca {
    if (_destinazione == null) return 'Scegli dove';
    if (_conDate) return _bozza.problema;
    return null;
  }

  Future<void> _crea() async {
    final destinazione = _destinazione!;
    final programma = _conDate ? _bozza.programma : null;
    final servizi = Servizi.of(context);
    final navigatore = Navigator.of(context);
    setState(() => _inCorso = true);
    try {
      final id = await servizi.archivio.creaViaggio(
        destinazione: destinazione,
        periodo: _conDate ? null : _periodo,
        programma: programma,
      );
      await servizi.misurazione.registra(Eventi.viaggioCreato, {
        'stato_iniziale': programma == null ? 'idea' : 'definito',
        'durata_prevista_giorni': programma?.durataGiorni,
      });
      HapticFeedback.mediumImpact();
      await navigatore.pushReplacement(
        rotta<void>(SchermataViaggio(viaggioId: id)),
      );
    } on ErroreTrolley catch (e) {
      if (mounted) mostraMessaggio(context, e.messaggio, errore: true);
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Tavolozza.of(context);
    final destinazione = _destinazione;
    return AdaptiveScaffold(
      appBar: const AdaptiveAppBar(
        title: 'Nuovo viaggio',
        leading: PulsanteChiudi(),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          MediaQuery.paddingOf(context).top + 12,
          16,
          MediaQuery.paddingOf(context).bottom + 32,
        ),
        children: [
          const TitoloSezione('Dove').entra(context),
          CampoScelta(
            simbolo: icona(
              ios: CupertinoIcons.location,
              android: Icons.place_outlined,
            ),
            segnaposto: 'Una città o un paese',
            valore: destinazione == null
                ? null
                : [
                    destinazione.nome,
                    if (destinazione.tipo != TipoDestinazione.paese)
                      ?destinazione.nomePaese,
                  ].join(', '),
            onTap: _scegliDestinazione,
          ).entra(context, ritardo: Ritmo.passo),
          if (destinazione != null &&
              destinazione.tipo == TipoDestinazione.aMano &&
              destinazione.paese == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Text(
                'Senza paese, questo viaggio non comparirà sul mappamondo.',
                style: Testi.didascalia.copyWith(color: t.testoSecondario),
              ),
            ),
          const SizedBox(height: 28),
          const TitoloSezione('Quando')
              .entra(context, ritardo: Ritmo.passo * 2),
          AdaptiveSegmentedControl(
            labels: const ['Ho le date', 'Non ancora'],
            selectedIndex: _conDate ? 0 : 1,
            onValueChanged: (i) => setState(() => _conDate = i == 0),
          ).entra(context, ritardo: Ritmo.passo * 2),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: Ritmo.medio,
            switchInCurve: Ritmo.curva,
            child: _conDate
                ? CampiDate(
                    key: const ValueKey('date'),
                    bozza: _bozza,
                    onCambio: (b) => setState(() => _bozza = b),
                  )
                : Column(
                    key: const ValueKey('periodo'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
                        child: Text(
                          'Nasce come idea: basta un periodo, anche vago. Quando '
                          'fissate le date diventa un viaggio in programma.',
                          style: Testi.secondario.copyWith(
                            color: t.testoSecondario,
                          ),
                        ),
                      ),
                      ScegliPeriodo(
                        periodo: _periodo,
                        onScelta: (p) => setState(() => _periodo = p),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 32),
          ConLaRete(
            builder: (context, rete) => PulsanteGrande(
              etichetta: _conDate ? 'Crea il viaggio' : 'Crea l\'idea',
              inCorso: _inCorso,
              motivo: rete ? _cosaManca : motivoSenzaRete,
              onPressed: _crea,
            ),
          ),
        ],
      ),
    );
  }
}
