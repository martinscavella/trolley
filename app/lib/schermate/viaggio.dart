import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../aspetto/barra.dart';
import '../aspetto/biglietto.dart';
import '../aspetto/elementi.dart';
import '../aspetto/formati.dart';
import '../aspetto/movimento.dart';
import '../aspetto/pagina.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/striscia.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../aspetto/tipi.dart';
import '../dati/database.dart';
import '../dati/destinazioni.dart';
import '../dati/errori.dart';
import '../dati/lettura.dart';
import '../dominio/calendario.dart';
import '../dominio/giornate.dart';
import '../dominio/stato_viaggio.dart';
import '../dominio/tappe.dart';
import '../servizi.dart';
import 'con_la_rete.dart';
import 'cose.dart';
import 'date_viaggio.dart';
import 'documenti.dart';
import 'gesti_partecipanti.dart';
import 'giornata.dart';
import 'impostazioni.dart';
import 'itinerario.dart';
import 'note.dart';
import 'nuovo_viaggio.dart';
import 'partecipanti.dart';
import 'problemi_coda.dart';
import 'scelta_periodo.dart';
import 'spese.dart';
import 'tappa.dart';

/// Un viaggio. La schermata cambia forma con lo stato (02-il-viaggio.md): da
/// idea c'è il periodo e l'invito a fissare le date; da definito ci sono le
/// date e i giorni, ciascuno con il suo tempo. Si legge dalla copia locale,
/// anche senza rete.
class SchermataViaggio extends StatefulWidget {
  const SchermataViaggio({super.key, required this.viaggioId});

  final String viaggioId;

  @override
  State<SchermataViaggio> createState() => _SchermataViaggioState();
}

class _SchermataViaggioState extends State<SchermataViaggio> {
  bool _invitoInCorso = false;
  final _origineInvito = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Aprire il viaggio aggiorna la copia (02 §1). Senza rete resta quella che
    // c'è, e va bene così.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final archivio = Servizi.of(context).archivio;
      unawaited(archivio.aggiornaCopia().catchError((_) {}));
      // Senza rete, si conta l'apertura e se il viaggio mancava (07, H4).
      final c = context;
      final presente = await archivio.osservaViaggio(widget.viaggioId).first;
      if (c.mounted) {
        await segnaAperturaSenzaRete(
          c,
          'viaggio',
          mancante: presente == null ? 'viaggio' : null,
        );
      }
    });
  }

  Future<void> _invita() async {
    if (_invitoInCorso) return;
    setState(() => _invitoInCorso = true);
    try {
      await invitaQualcuno(
        context,
        widget.viaggioId,
        origine: posizioneDi(_origineInvito),
      );
    } on ErroreTrolley catch (e) {
      if (mounted) mostraMessaggio(context, e.messaggio, errore: true);
    } finally {
      if (mounted) setState(() => _invitoInCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final archivio = Servizi.of(context).archivio;
    return StreamBuilder<Viaggio?>(
      stream: archivio.osservaViaggio(widget.viaggioId),
      builder: (context, snapshot) {
        final viaggio = snapshot.data;
        if (viaggio == null) {
          return Pagina(
            corpo: Center(
              child: snapshot.connectionState == ConnectionState.waiting
                  ? const IndicatoreAttivita()
                  : Text(
                      'Questo viaggio non è sul telefono.',
                      style: Testi.corpo.copyWith(color: Colori.grafite),
                    ),
            ),
          );
        }
        final stato = viaggio.statoA(DateTime.now());
        return Pagina(
          inBasso: BarraPrincipale(
            prima: [
              VoceBarra(
                icona: icona(
                  ios: CupertinoIcons.briefcase,
                  android: Icons.luggage_outlined,
                ),
                etichetta: 'Viaggi',
                attiva: true,
                onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
              ),
            ],
            dopo: [
              VoceBarra(
                icona: icona(
                  ios: CupertinoIcons.person,
                  android: Icons.person_outline,
                ),
                etichetta: 'Profilo',
                onTap: () => apri<void>(context, const SchermataImpostazioni()),
              ),
            ],
            etichettaAggiungi: 'Nuovo viaggio',
            onAggiungi: () => apri<void>(
              context,
              const SchermataNuovoViaggio(),
              dalBasso: true,
            ),
          ),
          corpo: Builder(
            builder: (context) => ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.paddingOf(context).top + 12,
                20,
                BarraPrincipale.ingombro + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                _Testata(viaggio: viaggio, stato: stato).entra(context),
                if (stato == StatoViaggio.idea) _Sollecito(viaggio: viaggio),
                // Il primo minuto di chi è appena entrato da un invito (03,
                // regola 9; tela, 29), e chi c'è.
                BenvenutoInvitato(viaggio: viaggio, stato: stato),
                const SizedBox(height: 28),
                const TitoloSezione('Chi c\'è')
                    .entra(context, ritardo: Ritmo.passo),
                SezioneChiCe(viaggioId: viaggio.id)
                    .entra(context, ritardo: Ritmo.passo),
                if (!stato.haGiorni) _DocumentiInAttesa(viaggioId: viaggio.id),
                if (stato.haGiorni) ...[
                  const SizedBox(height: 28),
                  SezioneDocumenti(viaggio: viaggio)
                      .entra(context, ritardo: Ritmo.passo),
                ],
                if (stato.haGiorni) ...[
                  const SizedBox(height: 28),
                  SezioneSpese(viaggio: viaggio)
                      .entra(context, ritardo: Ritmo.passo),
                ],
                // Anche nelle idee: la lista non aspetta le date (05, regola 4).
                const SizedBox(height: 28),
                SezioneCose(viaggio: viaggio)
                    .entra(context, ritardo: Ritmo.passo),
                if (stato.haGiorni) ...[
                  const SizedBox(height: 28),
                  const TitoloSezione('Giorni')
                      .entra(context, ritardo: Ritmo.passo * 2),
                  _Giorni(viaggio: viaggio)
                      .entra(context, ritardo: Ritmo.passo * 2),
                ],
                // L'itinerario con un assistente ha bisogno dei giorni e di
                // un posto da chiedere (04, regola 1).
                if (stato.haGiorni &&
                    stato != StatoViaggio.chiuso &&
                    viaggio.destinazione != null) ...[
                  const SizedBox(height: 12),
                  IngressoItinerario(viaggio: viaggio)
                      .entra(context, ritardo: Ritmo.passo * 2),
                ],
                SezioneNote(viaggio: viaggio),
                const SizedBox(height: 28),
                ConLaRete(
                  builder: (context, rete) => PulsanteGrande(
                    key: _origineInvito,
                    etichetta: 'Invita qualcuno',
                    icona: icona(
                      ios: CupertinoIcons.person_badge_plus,
                      android: Icons.person_add_alt_1_outlined,
                    ),
                    inCorso: _invitoInCorso,
                    motivo: rete ? null : motivoSenzaRete,
                    onPressed: _invita,
                  ),
                ).entra(context, ritardo: Ritmo.passo * 4),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Il biglietto del viaggio in cima alla schermata: giallo per un'idea,
/// cobalto per un viaggio con le date. Nella matrice, quando e dove; "Quando"
/// si tocca per cambiare il periodo o le date, e richiede la rete: senza, lo
/// dice sotto.
class _Testata extends StatelessWidget {
  const _Testata({required this.viaggio, required this.stato});

  final Viaggio viaggio;
  final StatoViaggio stato;

  Future<void> _cambia(BuildContext context) async {
    if (stato == StatoViaggio.idea) {
      final archivio = Servizi.of(context).archivio;
      await apri<bool>(
        context,
        SchermataPeriodo(
          titolo: 'Il periodo',
          spiegazione:
              'Anche vago va bene: serve a ricordarvelo, e a non lasciare '
              'l\'idea in vista per sempre se il periodo passa.',
          conferma: 'Salva',
          iniziale: viaggio.periodo,
          onConferma: (periodo) => archivio.cambiaPeriodo(viaggio, periodo),
        ),
        dalBasso: true,
      );
    } else {
      await apri<bool>(
        context,
        SchermataDate(viaggio: viaggio),
        dalBasso: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final oggi = DateTime.now();
    final idea = stato == StatoViaggio.idea || stato == StatoViaggio.archiviato;
    final periodo = viaggio.periodo;
    final programma = viaggio.programma;
    final (inizio, fine) = (viaggio.inizio, viaggio.fine);
    final destinazione = viaggio.destinazione;
    final dove = destinazione == null
        ? null
        : [
            destinazione.nome,
            if (destinazione.tipo != TipoDestinazione.paese)
              ?destinazione.nomePaese,
          ].join(', ');
    final destra = switch (stato) {
      StatoViaggio.idea ||
      StatoViaggio.archiviato => periodo == null ? 'SENZA DATE' : null,
      StatoViaggio.inCorso when inizio != null && fine != null =>
        'GIORNO ${giorniDiCalendario(inizio, oggi)} '
            'DI ${giorniDiCalendario(inizio, fine)}',
      StatoViaggio.definito when inizio != null => switch (soloData(inizio)
          .difference(soloData(oggi))
          .inDays) {
        <= 1 => 'DOMANI',
        final giorni => 'TRA $giorni GIORNI',
      },
      _ => null,
    };
    return ConLaRete(
      builder: (context, rete) {
        final modificabile = stato.dateModificabili;
        final cambia = modificabile && rete ? () => _cambia(context) : null;
        String quando(DateTime giorno, Duration? alle) => alle == null
            ? dataBreve(giorno)
            : '${dataBreve(giorno)} · ${ora(alle)}';
        final campi = idea
            ? [
                CampoMatrice(
                  'Quando',
                  periodo == null
                      ? 'Da decidere'
                      : etichettaPeriodo(periodo, oggi),
                  sotto: cambia == null
                      ? null
                      : periodo == null
                      ? 'Scegli il periodo'
                      : 'Cambia il periodo',
                  onTap: cambia,
                ),
                // Il nome è già il titolo: per una città si dice il paese.
                if (destinazione?.citta != null &&
                    destinazione?.nomePaese != null)
                  CampoMatrice('Paese', destinazione!.nomePaese!)
                else
                  CampoMatrice(
                    'Dove',
                    destinazione?.nome ?? 'Da decidere',
                    sotto: 'Anche vago va bene',
                  ),
              ]
            : [
                if (inizio != null)
                  CampoMatrice(
                    programma == null ? 'Dal' : 'Arrivo',
                    quando(inizio, programma?.arrivo),
                    sotto: cambia == null ? null : 'Cambia le date',
                    onTap: cambia,
                  ),
                if (fine != null)
                  CampoMatrice(
                    programma == null ? 'Al' : 'Partenza',
                    quando(fine, programma?.partenza),
                    onTap: cambia,
                    azione: 'Cambia le date',
                  ),
              ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Biglietto(
              codice: codiceViaggio(viaggio),
              nome: idea
                  ? titoloViaggio(viaggio)
                  : (dove ?? titoloViaggio(viaggio)),
              nomeComeTitolo: true,
              grandezzaCodice: idea ? 64 : 72,
              sinistra: descrizioneStato(stato).toUpperCase(),
              destra: destra,
              colore: idea
                  ? Colori.sole
                  : stato == StatoViaggio.chiuso
                  ? Colori.inchiostro
                  : Colori.cobalto,
              campi: campi,
            ),
            if (modificabile && !rete)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
                child: Text(
                  stato == StatoViaggio.idea
                      ? 'Per cambiare il periodo o fissare le date serve la '
                            'connessione.'
                      : 'Per spostare le date serve la connessione.',
                  style: Testi.didascalia.copyWith(color: Colori.grafite),
                ),
              ),
            if (stato == StatoViaggio.idea && rete) ...[
              const SizedBox(height: 16),
              PulsanteGrande(
                etichetta: 'Fissa le date',
                secondario: true,
                onPressed: () => apri<bool>(
                  context,
                  SchermataDate(viaggio: viaggio),
                  dalBasso: true,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Un viaggio tornato idea con dei documenti: restano sul telefono, fuori
/// vista finché non ci sono di nuovo le date (02-il-viaggio.md, casi limite).
/// In un'idea non se ne aggiungono: hanno bisogno dei giorni (07, casi limite).
class _DocumentiInAttesa extends StatelessWidget {
  const _DocumentiInAttesa({required this.viaggioId});

  final String viaggioId;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Documento>>(
    stream: Servizi.of(context).documenti.osserva(viaggioId),
    builder: (context, documenti) {
      final n = documenti.data?.length ?? 0;
      if (n == 0) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Avviso(
          icona: icona(
            ios: CupertinoIcons.doc_text,
            android: Icons.description_outlined,
          ),
          testo: n == 1
              ? 'Un documento resta su questo telefono: torna in vista quando '
                    'fissate le date.'
              : '$n documenti restano su questo telefono: tornano in vista '
                    'quando fissate le date.',
        ),
      );
    },
  );
}

/// "È ancora un'idea?": nelle ultime due settimane del periodo, e dopo. È
/// l'avviso che precede l'archivio, e si mostra prima che l'idea ci vada
/// (02-il-viaggio.md, regola 6).
class _Sollecito extends StatefulWidget {
  const _Sollecito({required this.viaggio});

  final Viaggio viaggio;

  @override
  State<_Sollecito> createState() => _SollecitoState();
}

class _SollecitoState extends State<_Sollecito> {
  DateTime? _sollecitataIl;
  bool _letto = false;

  /// La scadenza per cui si è già letto: un periodo cambiato si rilegge.
  DateTime? _scadenzaLetta;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _leggi();
  }

  @override
  void didUpdateWidget(_Sollecito vecchio) {
    super.didUpdateWidget(vecchio);
    _leggi();
  }

  Future<void> _leggi() async {
    if (_scadenzaLetta == widget.viaggio.scadenza) return;
    _scadenzaLetta = widget.viaggio.scadenza;
    final oggi = DateTime.now();
    final viaggio = widget.viaggio;
    if (!sollecitoDovuto(scadenza: viaggio.scadenza, oggi: oggi)) {
      if (mounted) setState(() => _letto = true);
      return;
    }
    final archivio = Servizi.of(context).archivio;
    // Mostrarlo è il sollecito: da qui partono le due settimane.
    await archivio.segnaSollecitata(viaggio, oggi);
    final il = await archivio.sollecitataIl(viaggio);
    if (mounted) {
      setState(() {
        _sollecitataIl = il;
        _letto = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final il = _sollecitataIl;
    if (!_letto || il == null) return const SizedBox.shrink();
    final scadenza = widget.viaggio.scadenza;
    final passato = soloData(DateTime.now()).isAfter(scadenza);
    final archivio = giornoDellArchivio(scadenza: scadenza, sollecitataIl: il);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Avviso(
        icona: icona(
          ios: CupertinoIcons.hourglass,
          android: Icons.hourglass_bottom,
        ),
        colore: Colori.senape,
        testo: [
          passato
              ? 'Il periodo di questa idea è passato.'
              : 'È ancora un\'idea? Il periodo finisce il '
                    '${dataEstesa(scadenza)}.',
          'Fissate le date o sceglietene un altro: se no, il '
              '${dataEstesa(archivio)} andrà in archivio, da dove si può '
              'sempre riprendere.',
        ].join(' '),
      ).entra(context, da: 6),
    );
  }
}

/// I giorni del viaggio, ciascuno con il tempo che ha: dall'arrivo alla
/// ripartenza (01-modello-dati.md, capienza della giornata).
/// I giorni del viaggio, ciascuno con quanto è pieno (tela, 6): si toccano
/// per aprire la giornata. Sotto, le tappe rimaste senza giorno quando le date
/// si sono spostate, da ricollocare, e i gesti che il server non ha accettato.
class _Giorni extends StatefulWidget {
  const _Giorni({required this.viaggio});

  final Viaggio viaggio;

  @override
  State<_Giorni> createState() => _GiorniState();
}

class _GiorniState extends State<_Giorni> {
  late Stream<List<Giorno>> _giorni;
  late Stream<List<Tappa>> _tappe;
  late Stream<List<OperazioneInCoda>> _coda;
  bool _avviato = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_avviato) return;
    _avviato = true;
    final archivio = Servizi.of(context).archivio;
    _giorni = archivio.osservaGiorni(widget.viaggio.id);
    _tappe = archivio.osservaTappe(widget.viaggio.id);
    _coda = archivio.coda.osserva(widget.viaggio.id);
  }

  @override
  Widget build(BuildContext context) {
    final oggi = soloData(DateTime.now());
    return StreamBuilder<List<Giorno>>(
      stream: _giorni,
      builder: (context, giorni) => StreamBuilder<List<Tappa>>(
        stream: _tappe,
        builder: (context, tappe) => StreamBuilder<List<OperazioneInCoda>>(
          stream: _coda,
          builder: (context, coda) {
            final elenco = giorni.data ?? const <Giorno>[];
            final tutte = tappe.data ?? const <Tappa>[];
            if (elenco.isEmpty) return const SizedBox.shrink();
            final attivi = {for (final g in elenco) g.id};
            final daRicollocare = [
              for (final t in tutte)
                if (!attivi.contains(t.giornoId)) t,
            ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, g) in elenco.indexed) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _RigaGiorno(
                    giorno: g.finestra,
                    oggi: g.finestra.data == oggi,
                    tappe: [
                      for (final t in tutte)
                        if (t.giornoId == g.id) t,
                    ],
                    onTap: () => apri<void>(
                      context,
                      SchermataGiornata(
                        viaggioId: widget.viaggio.id,
                        giornoId: g.id,
                      ),
                    ),
                  ),
                ],
                if (daRicollocare.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const TitoloSezione(
                    'Da ricollocare',
                    sotto:
                        'Erano in giorni che non fanno più parte del '
                        'viaggio. Toccale per scegliere un giorno nuovo.',
                  ),
                  for (final t in daRicollocare)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _DaRicollocare(
                        tappa: t,
                        onTap: () => apriFoglio<String>(
                          context,
                          SchermataTappa(
                            viaggio: widget.viaggio,
                            giorni: elenco,
                            tappe: tutte,
                            tappa: t,
                          ),
                        ),
                      ),
                    ),
                ],
                ProblemiDellaCoda(operazioni: coda.data ?? const []),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Un giorno, come nella tela: la data grande a sinistra; il nome del giorno,
/// la sua finestra e la striscia delle tappe; quante sono e quanto resta.
/// Oggi ha il bordo cobalto.
class _RigaGiorno extends StatelessWidget {
  const _RigaGiorno({
    required this.giorno,
    required this.oggi,
    required this.tappe,
    required this.onTap,
  });

  final FinestraGiorno giorno;
  final bool oggi;
  final List<Tappa> tappe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = giorno.data;
    final libero = tempoLibero(
      capienza: giorno.capienza,
      durateMinuti: tappe.map((t) => t.durataStimataMin),
    );
    final quante = tappe.isEmpty
        ? 'Nessuna tappa · ${durataBreve(giorno.capienza)} libere'
        : [
            quanti(tappe.length, 'tappa', 'tappe'),
            libero.isNegative
                ? 'sfora di ${durataBreve(-libero)}'
                : 'restano ${durataBreve(libero)}',
          ].join(' · ');
    final finestra = oggi
        ? 'Oggi, ${finestraDelGiorno(giorno)}'
        : conMaiuscola(finestraDelGiorno(giorno));
    return Premibile(
      onTap: onTap,
      scala: 0.98,
      etichetta:
          '${giornoDellaSettimana(d)} ${dataEstesa(d)}, $finestra, $quante',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colori.bianco,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: oggi ? Colori.cobalto : Colori.bianco,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                child: Column(
                  children: [
                    Text(
                      '${d.day}',
                      style: Testi.titoli(22, spaziatura: 0, altezza: 1)
                          .copyWith(
                            color: oggi ? Colori.cobalto : Colori.inchiostro,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meseBreve(d).toUpperCase(),
                      style: Testi.sezione.copyWith(color: Colori.grafite),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conMaiuscola(giornoDellaSettimana(d)),
                      style: Testi.evidenza.copyWith(color: Colori.inchiostro),
                    ),
                    Text(
                      finestra,
                      style: Testi.didascalia.copyWith(color: Colori.grafite),
                    ),
                    const SizedBox(height: 8),
                    StrisciaGiornata(
                      capienza: giorno.capienza,
                      pezzi: [
                        for (final t in tappe)
                          PezzoStriscia(
                            t.durata,
                            t.statoTappa == StatoTappa.completata
                                ? Colori.verde
                                : coloreTipo(t.tipoTappa),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      quante,
                      style: Testi.didascalia.copyWith(
                        color: libero.isNegative
                            ? Colori.pericolo
                            : Colori.grafite,
                        fontWeight: libero.isNegative ? FontWeight.w600 : null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                icona(
                  ios: CupertinoIcons.chevron_right,
                  android: Icons.chevron_right,
                ),
                size: 16,
                color: Colori.grafite,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Una tappa rimasta senza giorno.
class _DaRicollocare extends StatelessWidget {
  const _DaRicollocare({required this.tappa, required this.onTap});

  final Tappa tappa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Premibile(
    onTap: onTap,
    scala: 0.98,
    etichetta: 'Ricolloca ${tappa.titolo}',
    child: ExcludeSemantics(
      child: Pannello(
        raggio: 16,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(
              iconaTipo(tappa.tipoTappa),
              size: 22,
              color: coloreIconaTipo(tappa.tipoTappa),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                tappa.titolo,
                style: Testi.evidenza.copyWith(color: Colori.inchiostro),
              ),
            ),
            Text(
              durataBreve(tappa.durata),
              style: Testi.secondario.copyWith(color: Colori.grafite),
            ),
          ],
        ),
      ),
    ),
  );
}
