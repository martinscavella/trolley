import 'dart:async';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../aspetto/elementi.dart';
import '../aspetto/formati.dart';
import '../aspetto/movimento.dart';
import '../aspetto/pagina.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../dati/database.dart';
import '../dati/errori.dart';
import '../dati/lettura.dart';
import '../dominio/itinerario.dart';
import '../servizi.dart';
import 'con_la_rete.dart';
import 'itinerario.dart';

/// Il titolo di una nota, da dove viene.
String titoloNota(Nota n) =>
    n.origine == 'incollata' ? 'Risposta incollata' : 'Nota';

/// Quando è nata, detto in breve: `3 ott, 18:40`.
String quandoNota(Nota n) {
  final il = (DateTime.tryParse(n.creatoIl) ?? DateTime.now()).toLocal();
  return '${dataBreve(il)}, '
      '${ora(Duration(hours: il.hour, minutes: il.minute))}';
}

/// Le note nella schermata del viaggio (tela, 28): per ora le risposte
/// incollate, salvate anche quando non si sono capite (04, regola 11). Si
/// leggono anche senza rete.
class SezioneNote extends StatelessWidget {
  const SezioneNote({super.key, required this.viaggio});

  final Viaggio viaggio;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Nota>>(
    stream: Servizi.of(context).archivio.osservaNote(viaggio.id),
    builder: (context, snapshot) {
      final note = snapshot.data ?? const <Nota>[];
      if (note.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TitoloSezione('Note'),
            for (final (i, n) in note.indexed) ...[
              if (i > 0) const SizedBox(height: 10),
              _RigaNota(nota: n, viaggio: viaggio),
            ],
          ],
        ),
      );
    },
  );
}

class _RigaNota extends StatelessWidget {
  const _RigaNota({required this.nota, required this.viaggio});

  final Nota nota;
  final Viaggio viaggio;

  @override
  Widget build(BuildContext context) {
    final estratto = nota.testo.replaceAll(RegExp(r'\s+'), ' ').trim();
    return Premibile(
      onTap: () => apri<void>(
        context,
        SchermataNota(notaId: nota.id, viaggioId: viaggio.id),
      ),
      scala: 0.98,
      etichetta: '${titoloNota(nota)}, ${quandoNota(nota)}',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: Colori.bianco,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      titoloNota(nota),
                      style: Testi.evidenza.copyWith(
                        color: Colori.inchiostro,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Text(
                    quandoNota(nota),
                    style: Testi.didascalia.copyWith(color: Colori.grafite),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                estratto,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Testi.didascalia.copyWith(color: Colori.ardesia),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Una nota intera. Da una risposta incollata si può rileggere l'itinerario:
/// chi ha ottenuto una risposta non deve rifare il giro (04, regola 11).
/// Rileggere e aggiungere tappe funziona anche senza rete; eliminare la nota
/// la richiede.
class SchermataNota extends StatefulWidget {
  const SchermataNota({
    super.key,
    required this.notaId,
    required this.viaggioId,
  });

  final String notaId;
  final String viaggioId;

  @override
  State<SchermataNota> createState() => _SchermataNotaState();
}

class _SchermataNotaState extends State<SchermataNota> {
  late Stream<Nota?> _nota;
  late Stream<Viaggio?> _viaggio;
  bool _avviata = false;
  bool _inCorso = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_avviata) return;
    _avviata = true;
    final archivio = Servizi.of(context).archivio;
    _nota = archivio.osservaNota(widget.notaId);
    _viaggio = archivio.osservaViaggio(widget.viaggioId);
  }

  Future<void> _rileggi(Nota nota) async {
    final letto = leggiItinerario(nota.testo);
    if (letto.vuoto) {
      mostraMessaggio(
        context,
        'In questa nota non trovo tappe da aggiungere.',
        errore: true,
      );
      return;
    }
    final aggiunte = await apri<EsitoItinerario>(
      context,
      SchermataAnteprima(viaggioId: widget.viaggioId, letto: letto),
    );
    if (aggiunte != null && mounted) {
      mostraMessaggio(
        context,
        aggiunte == 1
            ? 'Aggiunta una tappa: la trovi nella sua giornata.'
            : 'Aggiunte $aggiunte tappe: le trovi nelle loro giornate.',
      );
    }
  }

  Future<void> _copia(Nota nota) async {
    await Clipboard.setData(ClipboardData(text: nota.testo));
    HapticFeedback.lightImpact();
    if (mounted) mostraMessaggio(context, 'Testo copiato.');
  }

  Future<void> _togli(Nota nota) async {
    var conferma = false;
    await AdaptiveAlertDialog.show(
      context: context,
      title: 'Eliminare questa nota?',
      message: 'Le tappe che ne sono nate restano nelle loro giornate.',
      actions: [
        AlertAction(
          title: 'Annulla',
          style: AlertActionStyle.cancel,
          onPressed: () {},
        ),
        AlertAction(
          title: 'Elimina',
          style: AlertActionStyle.destructive,
          onPressed: () => conferma = true,
        ),
      ],
    );
    if (!conferma || !mounted) return;
    setState(() => _inCorso = true);
    try {
      await Servizi.of(context).archivio.togliNota(nota);
      if (mounted) Navigator.of(context).pop();
    } on ErroreTrolley catch (e) {
      if (mounted) mostraMessaggio(context, e.messaggio, errore: true);
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<Viaggio?>(
    stream: _viaggio,
    builder: (context, viaggio) => StreamBuilder<Nota?>(
      stream: _nota,
      builder: (context, snapshot) {
        final nota = snapshot.data;
        final v = viaggio.data;
        if (nota == null || v == null) {
          return Pagina(
            corpo: Center(
              child: snapshot.connectionState == ConnectionState.waiting
                  ? const IndicatoreAttivita()
                  : Text(
                      'Questa nota non c\'è più.',
                      style: Testi.corpo.copyWith(color: Colori.grafite),
                    ),
            ),
          );
        }
        return ConLaRete(builder: (context, rete) => _pagina(nota, v, rete));
      },
    ),
  );

  Widget _pagina(Nota nota, Viaggio viaggio, bool rete) {
    final incollata = nota.origine == 'incollata';
    final rileggibile = incollata && viaggio.statoA(DateTime.now()).haGiorni;
    return Pagina(
      azioni: [
        PulsanteTondo(
          icona: icona(
            ios: CupertinoIcons.doc_on_doc,
            android: Icons.copy_rounded,
          ),
          etichetta: 'Copia il testo',
          onPressed: () => _copia(nota),
        ),
      ],
      inBasso: rileggibile
          ? PulsanteGrande(
              etichetta: 'Leggi di nuovo l\'itinerario',
              onPressed: () => _rileggi(nota),
            )
          : null,
      corpo: Builder(
        builder: (context) => ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.paddingOf(context).top + 8,
            20,
            MediaQuery.paddingOf(context).bottom + (rileggibile ? 110 : 32),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      titoloNota(nota),
                      style: Testi.titoloFoglio.copyWith(
                        color: Colori.inchiostro,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${titoloViaggio(viaggio)} · ${quandoNota(nota)}',
                    style: Testi.secondario.copyWith(color: Colori.grafite),
                  ),
                ],
              ),
            ).entra(context),
            const SizedBox(height: 16),
            Pannello(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                nota.testo,
                style: incollata
                    ? const TextStyle(
                        fontFamily: 'Menlo',
                        fontFamilyFallback: ['Courier', 'monospace'],
                        fontSize: 13,
                        height: 1.5,
                        color: Colori.inchiostro,
                      )
                    : Testi.corpo.copyWith(color: Colori.inchiostro),
              ),
            ).entra(context, ritardo: Ritmo.passo),
            const SizedBox(height: 20),
            PulsanteGrande(
              etichetta: 'Elimina la nota',
              secondario: true,
              pericolo: true,
              inCorso: _inCorso,
              motivo: rete ? null : motivoSenzaRete,
              onPressed: rete ? () => _togli(nota) : null,
            ),
          ],
        ),
      ),
    );
  }
}
