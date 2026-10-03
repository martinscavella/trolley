import 'package:flutter/material.dart';

import '../aspetto/elementi.dart';
import '../aspetto/formati.dart';
import '../aspetto/movimento.dart';
import '../aspetto/pagina.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../dati/errori.dart';
import '../dominio/periodo.dart';
import 'con_la_rete.dart';

/// Il periodo di un'idea, fra i mesi e le stagioni che vengono: si sceglie,
/// non si scrive, così l'app sa quando è passato (02-il-viaggio.md, regola 5).
/// "Non lo so ancora" vale dodici mesi.
class ScegliPeriodo extends StatelessWidget {
  const ScegliPeriodo({
    super.key,
    required this.periodo,
    required this.onScelta,
    this.ammettiNessuno = true,
  });

  final Periodo? periodo;
  final ValueChanged<Periodo?> onScelta;

  /// Se si può restare senza periodo.
  final bool ammettiNessuno;

  @override
  Widget build(BuildContext context) {
    final t = Tavolozza.of(context);
    final oggi = DateTime.now();
    final mesi = Periodo.mesiDa(oggi);
    final stagioni = Periodo.stagioniDa(oggi);
    // Un periodo già scelto che non è fra le proposte (passato, o lontano)
    // resta visibile, e scelto.
    final fuoriElenco =
        periodo != null &&
            !mesi.contains(periodo) &&
            !stagioni.contains(periodo)
        ? periodo
        : null;

    Widget gruppo(String titolo, List<Periodo> periodi) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            titolo.toUpperCase(),
            style: Testi.etichetta.copyWith(color: t.testoSecondario),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in periodi)
              Gettone(
                etichetta: etichettaPeriodo(p, oggi),
                scelto: p == periodo,
                onTap: () => onScelta(p),
              ),
          ],
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (fuoriElenco != null) ...[
          gruppo('Scelto', [fuoriElenco]),
          const SizedBox(height: 18),
        ],
        gruppo('Un mese', mesi),
        const SizedBox(height: 18),
        gruppo('Una stagione', stagioni),
        if (ammettiNessuno) ...[
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: Gettone(
              etichetta: 'Non lo so ancora',
              scelto: periodo == null,
              onTap: () => onScelta(null),
            ),
          ),
        ],
      ],
    );
  }
}

/// Una schermata per scegliere il periodo e confermarlo: cambiare quello di
/// un'idea, tornare a idea, riprendere un'idea dall'archivio.
class SchermataPeriodo extends StatefulWidget {
  const SchermataPeriodo({
    super.key,
    required this.titolo,
    required this.spiegazione,
    required this.conferma,
    required this.onConferma,
    this.iniziale,
    this.ammettiNessuno = true,
    this.pericolo = false,
  });

  final String titolo;
  final String spiegazione;
  final String conferma;
  final Future<void> Function(Periodo? periodo) onConferma;
  final Periodo? iniziale;
  final bool ammettiNessuno;

  /// La conferma toglie qualcosa alla vista (tornare a idea): in rosso.
  final bool pericolo;

  @override
  State<SchermataPeriodo> createState() => _SchermataPeriodoState();
}

class _SchermataPeriodoState extends State<SchermataPeriodo> {
  late Periodo? _periodo = widget.iniziale;
  bool _inCorso = false;

  Future<void> _conferma() async {
    setState(() => _inCorso = true);
    try {
      await widget.onConferma(_periodo);
      if (mounted) Navigator.of(context).pop(true);
    } on ErroreTrolley catch (e) {
      if (mounted) mostraMessaggio(context, e.messaggio, errore: true);
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Tavolozza.of(context);
    final manca = !widget.ammettiNessuno && _periodo == null;
    return Foglio(
      titolo: widget.titolo,
      inBasso: ConLaRete(
        builder: (context, rete) {
          final motivo = !rete
              ? motivoSenzaRete
              : manca
              ? 'Scegli un periodo'
              : null;
          return AzioniFoglio(
            motivo: motivo,
            azione: PulsanteGrande(
              etichetta: widget.conferma,
              inCorso: _inCorso,
              pericolo: widget.pericolo,
              onPressed: motivo == null ? _conferma : null,
            ),
          );
        },
      ),
      children: [
        Text(
          widget.spiegazione,
          style: Testi.corpo.copyWith(color: t.testoSecondario),
        ).entra(context),
        const SizedBox(height: 20),
        ScegliPeriodo(
          periodo: _periodo,
          ammettiNessuno: widget.ammettiNessuno,
          onScelta: (p) => setState(() => _periodo = p),
        ).entra(context, ritardo: Ritmo.passo),
      ],
    );
  }
}
