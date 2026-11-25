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
import '../dati/archivio.dart' show lunghezzaMassimaNota;
import '../dati/lettura.dart';
import '../dominio/itinerario.dart';
import '../misurazione/misurazione.dart';
import '../servizi.dart';
import 'con_la_rete.dart';
import 'due_versioni.dart';
import 'itinerario.dart';

/// Il titolo di una nota: per una scritta a mano la sua prima riga (tela,
/// 140), per una risposta incollata da dove viene.
String titoloNota(Nota n) {
  if (n.origine == 'incollata') return 'Risposta incollata';
  final prima = n.testo.trim().split('\n').first.trim();
  return prima.isEmpty ? 'Nota' : prima;
}

/// Sotto il titolo, nella riga: il resto del testo, su una riga sola. Per
/// una nota di una riga, niente.
String estrattoNota(Nota n) {
  final testo = n.testo.trim();
  final resto = n.origine == 'incollata'
      ? testo
      : testo.contains('\n')
      ? testo.substring(testo.indexOf('\n') + 1)
      : '';
  return resto.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Quando è nata, detto in breve: `3 ott, 18:40`.
String quandoNota(Nota n) {
  final il = (DateTime.tryParse(n.creatoIl) ?? DateTime.now()).toLocal();
  return '${dataBreve(il)}, '
      '${ora(Duration(hours: il.hour, minutes: il.minute))}';
}

/// Le note nella schermata del viaggio (tela, 28 e 139): quelle scritte a
/// mano — il codice del wifi, il treno delle 15:20 — e le risposte incollate,
/// salvate anche quando non si sono capite (04, regola 11). Si leggono anche
/// senza rete; scriverne una la richiede, e senza lo dice.
class SezioneNote extends StatelessWidget {
  const SezioneNote({super.key, required this.viaggio});

  final Viaggio viaggio;

  @override
  Widget build(BuildContext context) {
    final archivio = Servizi.of(context).archivio;
    return StreamBuilder<Map<String, String>>(
      stream: archivio.osservaNomi(viaggio.id),
      builder: (context, nomi) => StreamBuilder<List<Nota>>(
        stream: archivio.osservaNote(viaggio.id),
        builder: (context, snapshot) {
          final note = snapshot.data ?? const <Nota>[];
          return Padding(
            padding: const EdgeInsets.only(top: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const TitoloSezione(
                  'Note',
                  sotto:
                      'Quello che serve a tutti: lo vedono tutti quelli del '
                      'viaggio.',
                ),
                for (final n in note) ...[
                  _RigaNota(
                    nota: n,
                    viaggio: viaggio,
                    chi: n.origine == 'scritta'
                        ? chiHaScritto(n.creatoDa, archivio.io, nomi.data)
                        : null,
                  ),
                  const SizedBox(height: 10),
                ],
                if (note.isNotEmpty) const SizedBox(height: 2),
                ConLaRete(
                  builder: (context, rete) => PulsanteGrande(
                    etichetta: 'Scrivi una nota',
                    secondario: true,
                    icona: icona(
                      ios: CupertinoIcons.pencil,
                      android: Icons.edit_outlined,
                    ),
                    motivo: rete ? null : motivoSenzaRete,
                    onPressed: rete
                        ? () => apri<void>(
                            context,
                            FoglioNota(viaggio: viaggio),
                            dalBasso: true,
                          )
                        : null,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// «Tu», «Marco»: chi ha scritto una nota, dai nomi del viaggio.
String? chiHaScritto(String id, String? io, Map<String, String>? nomi) =>
    id == io ? 'Tu' : nomi?[id];

class _RigaNota extends StatelessWidget {
  const _RigaNota({required this.nota, required this.viaggio, this.chi});

  final Nota nota;
  final Viaggio viaggio;
  final String? chi;

  @override
  Widget build(BuildContext context) {
    final estratto = estrattoNota(nota);
    final quando = nota.origine == 'scritta'
        ? dataBreve(
            (DateTime.tryParse(nota.creatoIl) ?? DateTime.now()).toLocal(),
          )
        : quandoNota(nota);
    final sotto = [?chi, quando].join(' · ');
    return Premibile(
      onTap: () => apri<void>(
        context,
        SchermataNota(notaId: nota.id, viaggioId: viaggio.id),
      ),
      scala: 0.98,
      etichetta: '${titoloNota(nota)}, $sotto',
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Testi.evidenza.copyWith(
                        color: Colori.inchiostro,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    sotto,
                    style: Testi.didascalia.copyWith(color: Colori.grafite),
                  ),
                ],
              ),
              if (estratto.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  estratto,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Testi.didascalia.copyWith(color: Colori.ardesia),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Scrivere una nota, o cambiarne il testo (tela, 140–141). La prima riga è
/// il suo titolo. Salvare richiede la rete: senza, il pulsante si spegne e
/// dice perché, e il testo resta nel campo. Cambiandola, se qualcuno l'ha
/// riscritta nel frattempo si mostrano le due versioni (tela, 142).
class FoglioNota extends StatelessWidget {
  const FoglioNota({super.key, required this.viaggio, this.nota});

  final Viaggio viaggio;

  /// La nota da cambiare; `null` per una nuova.
  final Nota? nota;

  @override
  Widget build(BuildContext context) => ConLaRete(
    builder: (context, rete) =>
        _ScriviNota(viaggio: viaggio, nota: nota, rete: rete),
  );
}

class _ScriviNota extends StatefulWidget {
  const _ScriviNota({required this.viaggio, this.nota, required this.rete});

  final Viaggio viaggio;
  final Nota? nota;
  final bool rete;

  @override
  State<_ScriviNota> createState() => _ScriviNotaState();
}

class _ScriviNotaState extends State<_ScriviNota> {
  late final _testo = TextEditingController(text: widget.nota?.testo);
  final _fuoco = FocusNode();
  bool _inCorso = false;

  @override
  void initState() {
    super.initState();
    _testo.addListener(() => setState(() {}));
    _fuoco.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _testo.dispose();
    _fuoco.dispose();
    super.dispose();
  }

  String? get _motivo {
    final testo = _testo.text.trim();
    if (testo.isEmpty) return 'Scrivi qualcosa';
    if (testo.length > lunghezzaMassimaNota) {
      return 'È troppo lunga: dividila in due';
    }
    final nota = widget.nota;
    if (nota != null && testo == nota.testo.trim()) return 'Non è cambiata';
    if (!widget.rete) return motivoSenzaRete;
    return null;
  }

  Future<void> _salva() async {
    final servizi = Servizi.of(context);
    final nota = widget.nota;
    setState(() => _inCorso = true);
    try {
      if (nota == null) {
        await servizi.archivio.salvaNota(
          viaggioId: widget.viaggio.id,
          testo: _testo.text,
        );
        await servizi.misurazione.registra(Eventi.notaScritta, {
          'viaggio_id': widget.viaggio.id,
          'stato': widget.viaggio.statoA(DateTime.now()).name,
        });
        HapticFeedback.lightImpact();
        if (mounted) Navigator.of(context).pop();
        return;
      }
      final scelta = await salvaOScegli(
        context,
        () => servizi.archivio.cambiaNota(nota, _testo.text),
      );
      // Tornati dalle due versioni senza scegliere: il testo resta qui.
      if (scelta != null && mounted) Navigator.of(context).pop();
    } on ErroreTrolley catch (e) {
      if (mounted) mostraMessaggio(context, e.messaggio, errore: true);
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final motivo = _motivo;
    final stile = Testi.corpo.copyWith(color: Colori.inchiostro);
    final attivo = _fuoco.hasFocus;
    final forma = BoxDecoration(
      color: attivo ? Colori.bianco : Colori.foschia,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: attivo ? Colori.cobalto : Colori.foschia,
        width: 2,
      ),
    );
    const segnaposto =
        'Il codice del wifi, un indirizzo, il treno delle 15:20…';
    final segnapostoStile = Testi.campo.copyWith(
      color: Colori.grafite.withValues(alpha: 0.6),
    );
    final campo = suIOS
        ? CupertinoTextField(
            controller: _testo,
            focusNode: _fuoco,
            autofocus: widget.nota == null,
            minLines: 6,
            maxLines: 12,
            style: stile,
            placeholder: segnaposto,
            placeholderStyle: segnapostoStile,
            cursorColor: Colori.cobalto,
            padding: const EdgeInsets.all(14),
            decoration: forma,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
          )
        : DecoratedBox(
            decoration: forma,
            child: TextField(
              controller: _testo,
              focusNode: _fuoco,
              autofocus: widget.nota == null,
              minLines: 6,
              maxLines: 12,
              style: stile,
              cursorColor: Colori.cobalto,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: segnaposto,
                hintStyle: segnapostoStile,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
          );
    return Foglio(
      titolo: widget.nota == null ? 'Nuova nota' : 'Cambia la nota',
      inBasso: AzioniFoglio(
        motivo: motivo,
        azione: PulsanteGrande(
          etichetta: 'Salva',
          inCorso: _inCorso,
          onPressed: motivo == null ? _salva : null,
        ),
      ),
      children: [
        Text(
          'La vedono tutti quelli del viaggio, anche senza rete. La prima '
          'riga è il suo titolo.',
          style: Testi.secondario.copyWith(color: Colori.ardesia),
        ),
        const SizedBox(height: 12),
        Semantics(label: 'Il testo della nota', child: campo),
      ],
    );
  }
}

/// Una nota intera (tela, 141). Da una risposta incollata si può rileggere
/// l'itinerario: chi ha ottenuto una risposta non deve rifare il giro (04,
/// regola 11). Una nota scritta a mano si cambia; la risposta incollata resta
/// com'era. Rileggere e aggiungere tappe funziona anche senza rete; cambiare
/// ed eliminare la nota la richiedono.
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
  late Stream<Map<String, String>> _nomi;
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
    _nomi = archivio.osservaNomi(widget.viaggioId);
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
      final scelta = await salvaOScegli(
        context,
        () => Servizi.of(context).archivio.togliNota(nota),
      );
      // Tolta, o lasciata com'è dopo averla vista cambiata: si torna al
      // viaggio solo se non c'è più.
      if (scelta == SceltaVersione.tua && mounted) Navigator.of(context).pop();
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
        return StreamBuilder<Map<String, String>>(
          stream: _nomi,
          builder: (context, nomi) => ConLaRete(
            builder: (context, rete) => _pagina(nota, v, rete, nomi.data),
          ),
        );
      },
    ),
  );

  Widget _pagina(
    Nota nota,
    Viaggio viaggio,
    bool rete,
    Map<String, String>? nomi,
  ) {
    final incollata = nota.origine == 'incollata';
    final archivio = Servizi.of(context).archivio;
    final chi = incollata
        ? null
        : switch (chiHaScritto(nota.creatoDa, archivio.io, nomi)) {
            'Tu' => 'scritta da te',
            final nome? => 'scritta da $nome',
            null => null,
          };
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
                    [
                      titoloViaggio(viaggio),
                      ?chi,
                      quandoNota(nota),
                    ].join(' · '),
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
            if (!incollata) ...[
              PulsanteGrande(
                etichetta: 'Cambia la nota',
                icona: icona(
                  ios: CupertinoIcons.pencil,
                  android: Icons.edit_outlined,
                ),
                motivo: rete ? null : motivoSenzaRete,
                onPressed: rete
                    ? () => apri<void>(
                        context,
                        FoglioNota(viaggio: viaggio, nota: nota),
                        dalBasso: true,
                      )
                    : null,
              ),
              const SizedBox(height: 10),
            ],
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
