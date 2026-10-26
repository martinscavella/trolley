/// Eliminare un viaggio (02, regola 13; tela, 132 e 133): solo chi ci è
/// rimasto da solo. Prima si dice, contato, che cosa si cancella; poi il
/// dialogo di sistema. Non si torna indietro.
library;

import 'dart:async';

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
import '../dati/database.dart';
import '../dati/errori.dart';
import '../dati/lettura.dart';
import '../dominio/calendario.dart';
import '../dominio/stato_viaggio.dart';
import '../misurazione/misurazione.dart';
import '../servizi.dart';
import 'con_la_rete.dart';
import 'sezioni.dart';

/// «Elimina il viaggio», in fondo al viaggio e in «Chi c'è». Con altri dentro
/// c'è, spento, e dice perché (tela, 133).
class PulsanteEliminaViaggio extends StatelessWidget {
  const PulsanteEliminaViaggio({super.key, required this.viaggio});

  final Viaggio viaggio;

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<List<(Partecipazione, Utente?)>>(
        stream: Servizi.of(context).archivio.osservaPartecipanti(viaggio.id),
        builder: (context, partecipanti) {
          final io = Servizi.of(context).archivio.io;
          final altri = [
            for (final (p, u)
                in partecipanti.data ?? const <(Partecipazione, Utente?)>[])
              if (p.utenteId != io) u?.nome ?? 'qualcuno',
          ];
          if (!partecipanti.hasData) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ConLaRete(
                  builder: (context, rete) => PulsanteGrande(
                    etichetta: 'Elimina il viaggio',
                    icona: Icons.delete_outline_rounded,
                    secondario: true,
                    pericolo: true,
                    motivo: altri.isNotEmpty
                        ? 'Ci sono altre persone'
                        : rete
                        ? null
                        : motivoSenzaRete,
                    onPressed: () => apri<void>(
                      context,
                      SchermataEliminaViaggio(viaggio: viaggio),
                    ),
                  ),
                ),
                if (altri.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Nel viaggio ci sono anche ${insieme(altri)}: per '
                    'eliminarlo devi restare solo tu. Puoi uscirne da «Chi '
                    'c\'è».',
                    textAlign: TextAlign.center,
                    style: Testi.didascalia.copyWith(color: Colori.grafite),
                  ),
                ],
              ],
            ),
          );
        },
      );
}

/// Quello che il telefono sa del viaggio, per dire che cosa si cancella.
typedef _Conto = ({
  int giorni,
  int tappe,
  int spese,
  List<String> usciti,
  int speseDegliUsciti,
  int voci,
  int note,
  int documenti,
  int nonArrivati,
});

class SchermataEliminaViaggio extends StatefulWidget {
  const SchermataEliminaViaggio({super.key, required this.viaggio});

  final Viaggio viaggio;

  @override
  State<SchermataEliminaViaggio> createState() =>
      _SchermataEliminaViaggioState();
}

class _SchermataEliminaViaggioState extends State<SchermataEliminaViaggio> {
  Future<_Conto>? _conto;
  bool _inCorso = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _conto ??= _conta();
  }

  Future<_Conto> _conta() async {
    final servizi = Servizi.of(context);
    final archivio = servizi.archivio;
    final v = widget.viaggio.id;
    final (giorni, tappe, spese, usciti, voci, note, documenti, coda) = await (
      archivio.osservaGiorni(v).first,
      archivio.osservaTappe(v).first,
      archivio.osservaSpese(v).first,
      archivio.osservaUsciti(v).first,
      archivio.osservaVoci(v).first,
      archivio.osservaNote(v).first,
      servizi.documenti.osserva(v).first,
      archivio.coda.osserva(v).first,
    ).wait;
    final idUsciti = {for (final (p, _) in usciti) p.utenteId};
    return (
      giorni: giorni.length,
      tappe: tappe.length,
      spese: spese.length,
      usciti: [for (final (_, u) in usciti) u?.nome ?? 'qualcuno'],
      speseDegliUsciti: spese
          .where((s) => idUsciti.contains(s.paganteId))
          .length,
      voci: voci.length,
      note: note.length,
      documenti: documenti.length,
      nonArrivati: coda.where((op) => op.messaDaParte).length,
    );
  }

  String get _nome => titoloViaggio(widget.viaggio);

  List<(IconData, String)> _righe(_Conto c) {
    final stato = widget.viaggio.statoA(DateTime.now());
    return [
      if (c.giorni > 0)
        (
          icona(ios: CupertinoIcons.calendar, android: Icons.event_outlined),
          '${['**${quanti(c.giorni, 'giorno', 'giorni')}**', if (c.tappe > 0) c.tappe == 1 ? 'e la sua **tappa**' : 'e le **${c.tappe} tappe**'].join(' ')}.',
        ),
      if (c.spese > 0)
        (
          icona(
            ios: CupertinoIcons.creditcard,
            android: Icons.payments_outlined,
          ),
          c.speseDegliUsciti > 0
              ? '**${quanti(c.spese, 'spesa', 'spese')}**, anche '
                    '${c.speseDegliUsciti == 1 ? 'una' : c.speseDegliUsciti} '
                    'di ${insieme([for (final n in c.usciti) '**$n**'])}, '
                    'che ${c.usciti.length == 1 ? 'è uscito' : 'sono usciti'}: '
                    'il saldo sparisce.'
              : '**${quanti(c.spese, 'spesa', 'spese')}**.',
        ),
      if (c.voci > 0 || c.note > 0)
        (
          icona(ios: CupertinoIcons.list_bullet, android: Icons.checklist),
          '${conMaiuscola([if (c.voci > 0) 'le cose da portare', if (c.note == 1) 'la nota' else if (c.note > 1) 'le ${c.note} note'].join(' e '))}.',
        ),
      if (c.documenti > 0)
        (
          icona(
            ios: CupertinoIcons.doc,
            android: Icons.insert_drive_file_outlined,
          ),
          c.documenti == 1
              ? '**Il documento** di $_nome su questo telefono.'
              : '**I ${c.documenti} documenti** di $_nome su questo telefono.',
        ),
      if (stato == StatoViaggio.chiuso)
        (
          icona(ios: CupertinoIcons.book, android: Icons.menu_book_outlined),
          'Esce dal passaporto, e i traguardi che ti ha dato se ne vanno.',
        ),
      (
        icona(ios: CupertinoIcons.link, android: Icons.link_rounded),
        'Gli inviti che hai mandato non fanno più entrare nessuno.',
      ),
      if (c.nonArrivati > 0)
        (
          icona(
            ios: CupertinoIcons.wifi_slash,
            android: Icons.wifi_off_rounded,
          ),
          c.nonArrivati == 1
              ? '**Una cosa** fatta senza rete non è arrivata: si perde.'
              : '**${c.nonArrivati} cose** fatte senza rete non sono '
                    'arrivate: si perdono.',
        ),
    ];
  }

  Future<void> _conferma() => AdaptiveAlertDialog.show(
    context: context,
    title: 'Eliminare $_nome?',
    message: 'Il viaggio e tutto quello che contiene non si recuperano.',
    actions: [
      AlertAction(
        title: 'Annulla',
        style: AlertActionStyle.cancel,
        onPressed: () {},
      ),
      AlertAction(
        title: 'Elimina',
        style: AlertActionStyle.destructive,
        onPressed: _elimina,
      ),
    ],
  );

  /// Prima il server: se non elimina, il telefono resta com'è. Poi i propri
  /// documenti, che sono l'unica copia; con il suo evento (07).
  Future<void> _elimina() async {
    final servizi = Servizi.of(context);
    final viaggio = widget.viaggio;
    final stato = viaggio.statoA(DateTime.now());
    final navigatore = Navigator.of(context);
    setState(() => _inCorso = true);
    try {
      await servizi.archivio.eliminaViaggio(viaggio.id);
    } on ErroreTrolley catch (e) {
      if (!mounted) return;
      setState(() => _inCorso = false);
      mostraMessaggio(context, e.messaggio, errore: true);
      return;
    }
    try {
      await servizi.documenti.eliminaViaggio(viaggio.id);
    } on Object {
      // Il viaggio non c'è più: un file che non si cancella resta nella
      // cartella dell'app, e l'elenco dei documenti rimasti lo mostra.
    }
    unawaited(
      servizi.misurazione.registra(Eventi.viaggioEliminato, {
        'stato': stato.name,
        'giorni_dalla_creazione': soloData(DateTime.now())
            .difference(soloData(viaggio.creato))
            .inDays,
      }),
    );
    final contesto = navigatore.overlay?.context;
    if (SchermataSezioni.aperta case final sezioni?) {
      sezioni.tornaAiViaggi();
    } else {
      navigatore.popUntil((r) => r.isFirst);
    }
    if (contesto != null && contesto.mounted) {
      mostraMessaggio(contesto, '$_nome è stato eliminato.');
    }
  }

  @override
  Widget build(BuildContext context) => Pagina(
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
              ios: CupertinoIcons.trash,
              android: Icons.delete_outline,
            ),
            fondo: Colori.rosa,
            colore: Colori.pericolo,
          ).entra(context),
          const SizedBox(height: 18),
          TitoloPagina(
            'Eliminare $_nome?',
            sottotitolo:
                'Ci sei solo tu. Non si torna indietro: ecco cosa si cancella.',
          ).entra(context),
          FutureBuilder<_Conto>(
            future: _conto,
            builder: (context, conto) => conto.hasData
                ? Spiegazione(
                    righe: _righe(conto.data!),
                    colore: Colori.pericolo,
                  ).entra(context, ritardo: Ritmo.passo)
                : const SizedBox(height: 120),
          ),
          const SizedBox(height: 24),
          ConLaRete(
            builder: (context, rete) => PulsanteGrande(
              etichetta: 'Elimina il viaggio',
              icona: Icons.delete_outline_rounded,
              pericolo: true,
              inCorso: _inCorso,
              motivo: rete ? null : motivoSenzaRete,
              onPressed: rete && !_inCorso ? _conferma : null,
            ),
          ),
          const SizedBox(height: 10),
          PulsanteGrande(
            etichetta: 'Annulla',
            secondario: true,
            onPressed: _inCorso ? null : () => Navigator.of(context).pop(),
          ),
        ],
      ),
    ),
  );
}
