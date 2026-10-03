import 'dart:async';
import 'dart:math';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../aspetto/barra.dart';
import '../aspetto/biglietto.dart';
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
import '../dati/lettura.dart';
import '../dominio/calendario.dart';
import '../dominio/codice_invito.dart';
import '../dominio/stato_viaggio.dart';
import '../servizi.dart';
import 'archivio_idee.dart';
import 'con_la_rete.dart';
import 'impostazioni.dart';
import 'nuovo_viaggio.dart';
import 'viaggio.dart';

/// I propri viaggi, divisi per stato: in corso, in programma, idee, conclusi.
/// L'archivio è una voce a parte (02-il-viaggio.md). Si legge dalla copia
/// locale: funziona anche senza rete.
class SchermataViaggi extends StatefulWidget {
  const SchermataViaggi({super.key, required this.onCodice});

  /// Un codice d'invito digitato a mano: lo gestisce l'app come quelli dei link.
  final ValueChanged<String> onCodice;

  @override
  State<SchermataViaggi> createState() => _SchermataViaggiState();
}

class _SchermataViaggiState extends State<SchermataViaggi>
    with WidgetsBindingObserver {
  final _scorrimento = ScrollController();
  StreamSubscription<bool>? _rete;

  /// Il titolo grande scorre via e ricompare piccolo nella barra, come su iOS.
  bool _titoloInBarra = false;
  bool _aggiornamentoInCorso = false;

  /// Le idee per cui questo elenco ha già segnato il sollecito.
  final _sollecitate = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scorrimento.addListener(() {
      final inBarra = _scorrimento.offset > 44;
      if (inBarra != _titoloInBarra) setState(() => _titoloInBarra = inBarra);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Quando la rete torna si aggiorna da sé: è il momento in cui la copia
      // può smettere di essere vecchia.
      _rete = Servizi.of(context).rete.cambi.listen((disponibile) {
        if (disponibile) _aggiorna();
      });
      _aggiorna();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState stato) {
    if (stato == AppLifecycleState.resumed) _aggiorna();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _rete?.cancel();
    _scorrimento.dispose();
    super.dispose();
  }

  /// Riscarica la copia e manda in archivio le idee scadute, dicendolo.
  /// All'apertura dell'app, quando torna la rete, tirando giù l'elenco.
  Future<void> _aggiorna() async {
    if (_aggiornamentoInCorso || !mounted) return;
    _aggiornamentoInCorso = true;
    final servizi = Servizi.of(context);
    try {
      await servizi.archivio.aggiornaCopia();
      unawaited(servizi.misurazione.invia());
      final archiviate = await servizi.archivio.archiviaIdeeScadute(
        DateTime.now(),
      );
      if (archiviate.isNotEmpty && mounted) {
        mostraMessaggio(
          context,
          archiviate.length == 1
              ? '«${titoloViaggio(archiviate.single)}» è andata in archivio: '
                    'il suo periodo è passato. La ritrovi in fondo all\'elenco.'
              : '${archiviate.length} idee sono andate in archivio: il loro '
                    'periodo è passato. Le ritrovi in fondo all\'elenco.',
        );
      }
    } on ErroreTrolley {
      // Senza rete si resta con la copia, e l'elenco lo dice.
    } finally {
      _aggiornamentoInCorso = false;
    }
  }

  Future<void> _nuovoViaggio() =>
      apri<void>(context, const SchermataNuovoViaggio(), dalBasso: true);

  Future<void> _inserisciCodice() async {
    if (!Servizi.of(context).rete.disponibile) {
      mostraMessaggio(
        context,
        'Per entrare con un codice serve la connessione.',
      );
      return;
    }
    final testo = await AdaptiveAlertDialog.inputShow(
      context: context,
      title: 'Codice d\'invito',
      message: 'Lo trovi nel messaggio con cui ti hanno invitato.',
      input: const AdaptiveAlertDialogInput(placeholder: 'ABCD-2345'),
      actions: [
        AlertAction(
          title: 'Annulla',
          style: AlertActionStyle.cancel,
          onPressed: () {},
        ),
        AlertAction(
          title: 'Entra',
          style: AlertActionStyle.primary,
          onPressed: () {},
        ),
      ],
    );
    if (testo == null || !mounted) return;
    final codice = normalizzaCodice(testo);
    if (codice == null) {
      await AdaptiveAlertDialog.show(
        context: context,
        title: 'Codice non valido',
        message: 'Il codice ha $lunghezzaCodice caratteri, come ABCD-2345.',
        actions: [AlertAction(title: 'OK', onPressed: () {})],
      );
      return;
    }
    widget.onCodice(codice);
  }

  /// Segna il sollecito delle idee che lo mostrano sulla scheda: vederlo
  /// nell'elenco conta come averlo visto (02, regola 6).
  void _segnaSollecitate(Iterable<Viaggio> idee) {
    final oggi = DateTime.now();
    final archivio = Servizi.of(context).archivio;
    for (final idea in idee) {
      if (_sollecitate.add('${idea.id}:${idea.scadenza}')) {
        unawaited(archivio.segnaSollecitata(idea, oggi));
      }
    }
  }

  /// "Altro": l'archivio delle idee e le impostazioni.
  Future<void> _altro() async {
    final archivio = Servizi.of(context).archivio;
    final archiviate =
        (await archivio.osservaViaggiInElenco(archiviati: true).first).length;
    if (!mounted) return;
    await scegliAzione(context, [
      AzioneMenu(
        archiviate == 0
            ? 'Archivio delle idee'
            : 'Archivio delle idee ($archiviate)',
        () => apri<void>(context, const SchermataArchivio()),
      ),
      AzioneMenu(
        'Impostazioni',
        () => apri<void>(context, const SchermataImpostazioni()),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final servizi = Servizi.of(context);
    final oggi = DateTime.now();
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
            onTap: () => _scorrimento.hasClients
                ? _scorrimento.animateTo(
                    0,
                    duration: movimentoRidotto(context)
                        ? Duration.zero
                        : Ritmo.medio,
                    curve: Ritmo.curva,
                  )
                : null,
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
        onAggiungi: _nuovoViaggio,
      ).entra(context, ritardo: Ritmo.lungo, da: 40),
      corpo: StreamBuilder<List<ViaggioInElenco>>(
        stream: servizi.archivio.osservaViaggiInElenco(),
        builder: (context, snapshot) {
          final viaggi = snapshot.data;
          final sezioni = viaggi == null ? null : _sezioni(viaggi, oggi);
          final daSollecitare = [
            for (final v
                in sezioni?[StatoViaggio.idea] ?? const <ViaggioInElenco>[])
              if (sollecitoDovuto(scadenza: v.viaggio.scadenza, oggi: oggi))
                v.viaggio,
          ];
          if (daSollecitare.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _segnaSollecitate(daSollecitare),
            );
          }

          var indice = 0;
          final elenco = CustomScrollView(
            controller: _scorrimento,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              if (suIOS) CupertinoSliverRefreshControl(onRefresh: _aggiorna),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  MediaQuery.paddingOf(context).top + 16,
                  20,
                  8,
                ),
                sliver: SliverToBoxAdapter(
                  child: _Intestazione(
                    onCodice: _inserisciCodice,
                    onAltro: _altro,
                  ),
                ),
              ),
              SliverToBoxAdapter(child: _SenzaRete(viaggi: viaggi ?? const [])),
              if (sezioni == null)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: IndicatoreAttivita()),
                )
              else if (sezioni.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _Vuoto(
                    onNuovoViaggio: _nuovoViaggio,
                    onCodice: _inserisciCodice,
                  ),
                )
              else ...[
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                for (final MapEntry(key: stato, value: dellaSezione)
                    in sezioni.entries) ...[
                  // Il biglietto di un viaggio in corso lo dice da sé.
                  if (stato != StatoViaggio.inCorso)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                      sliver: SliverToBoxAdapter(
                        child: TitoloSezione(
                          titoloSezione(stato),
                          sotto: stato == StatoViaggio.idea
                              ? 'Ancora senza date'
                              : null,
                        ).entra(context, ritardo: Ritmo.passo * min(indice, 6)),
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    sliver: SliverList.separated(
                      itemCount: dellaSezione.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final v = dellaSezione[i];
                        return TieniVivo(
                          key: ValueKey(v.viaggio.id),
                          child:
                              SchedaViaggio(
                                dati: v,
                                stato: stato,
                                oggi: oggi,
                                sollecito: daSollecitare.contains(v.viaggio),
                                onTap: () => apri<void>(
                                  context,
                                  SchermataViaggio(viaggioId: v.viaggio.id),
                                ),
                              ).entra(
                                context,
                                ritardo: Ritmo.passo * min(indice++, 6),
                              ),
                        );
                      },
                    ),
                  ),
                ],
              ],
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  BarraPrincipale.ingombro +
                      MediaQuery.paddingOf(context).bottom,
                ),
                sliver: SliverToBoxAdapter(child: _VoceArchivio()),
              ),
            ],
          );

          return suIOS
              ? elenco
              : RefreshIndicator(onRefresh: _aggiorna, child: elenco);
        },
      ),
    );
  }

  /// I viaggi divisi per stato, nell'ordine in cui servono: quello in corso
  /// prima di tutto, poi i prossimi dal più vicino, poi le idee, poi i
  /// conclusi dal più recente. Le sezioni vuote non ci sono.
  static Map<StatoViaggio, List<ViaggioInElenco>> _sezioni(
    List<ViaggioInElenco> viaggi,
    DateTime oggi,
  ) {
    final perStato = <StatoViaggio, List<ViaggioInElenco>>{};
    for (final v in viaggi) {
      (perStato[v.viaggio.statoA(oggi)] ??= []).add(v);
    }
    int perInizio(ViaggioInElenco a, ViaggioInElenco b) =>
        (a.viaggio.dataInizio ?? '').compareTo(b.viaggio.dataInizio ?? '');
    perStato[StatoViaggio.inCorso]?.sort(perInizio);
    perStato[StatoViaggio.definito]?.sort(perInizio);
    perStato[StatoViaggio.chiuso]?.sort((a, b) => -perInizio(a, b));
    return {
      for (final stato in const [
        StatoViaggio.inCorso,
        StatoViaggio.definito,
        StatoViaggio.idea,
        StatoViaggio.chiuso,
      ])
        stato: ?perStato[stato],
    };
  }
}

class _Intestazione extends StatelessWidget {
  const _Intestazione({required this.onCodice, required this.onAltro});

  final VoidCallback onCodice;
  final VoidCallback onAltro;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Semantics(
          header: true,
          child: Text(
            'I tuoi viaggi',
            style: Testi.titolo.copyWith(color: Colori.inchiostro),
          ),
        ),
      ),
      PulsanteTondo(
        icona: icona(
          ios: CupertinoIcons.tickets,
          android: Icons.vpn_key_outlined,
        ),
        etichetta: 'Ho un codice d\'invito',
        scuro: true,
        onPressed: onCodice,
      ),
      const SizedBox(width: 8),
      PulsanteTondo(
        icona: icona(
          ios: CupertinoIcons.ellipsis_vertical,
          android: Icons.more_vert,
        ),
        etichetta: 'Altro',
        onPressed: onAltro,
      ),
    ],
  ).entra(context, da: 8);
}

/// Senza rete si legge la copia, e si dice quanto è vecchia (02 §1: non si
/// finge che sia fresca).
class _SenzaRete extends StatelessWidget {
  const _SenzaRete({required this.viaggi});

  final List<ViaggioInElenco> viaggi;

  @override
  Widget build(BuildContext context) {
    final scaricata = viaggi.isEmpty
        ? null
        : viaggi
              .map((v) => v.viaggio.scaricatoIl)
              .reduce((a, b) => a.isBefore(b) ? a : b);
    return ConLaRete(
      builder: (context, rete) => AnimatedSize(
        duration: Ritmo.medio,
        curve: Ritmo.curva,
        child: rete
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Avviso(
                  icona: icona(
                    ios: CupertinoIcons.wifi_slash,
                    android: Icons.wifi_off,
                  ),
                  inizio: 'Sei offline.',
                  testo: scaricata == null
                      ? 'Quello che fai adesso parte appena torna la rete.'
                      : 'Stai vedendo la copia sul telefono, aggiornata '
                            '${quantoFa(scaricata, DateTime.now())}.',
                ),
              ),
      ),
    );
  }
}

/// Un viaggio nell'elenco, come i biglietti della tela: una carta d'imbarco
/// con il codice di tre lettere, le date e quanti siete; un biglietto giallo
/// basso se è ancora un'idea.
class SchedaViaggio extends StatelessWidget {
  const SchedaViaggio({
    super.key,
    required this.dati,
    required this.stato,
    required this.oggi,
    required this.onTap,
    this.sollecito = false,
  });

  final ViaggioInElenco dati;
  final StatoViaggio stato;
  final DateTime oggi;
  final VoidCallback onTap;

  /// Un'idea vicina alla fine del suo periodo, o oltre: "è ancora un'idea?".
  final bool sollecito;

  @override
  Widget build(BuildContext context) {
    final v = dati.viaggio;
    if (stato == StatoViaggio.idea || stato == StatoViaggio.archiviato) {
      final periodo = v.periodo == null
          ? 'senza date'
          : etichettaPeriodo(v.periodo!, oggi).toLowerCase();
      return BigliettoIdea(
        codice: codiceViaggio(v),
        titolo: titoloViaggio(v),
        sottotitolo: sollecito
            ? 'Ancora un\'idea? · $periodo'
            : 'Idea · $periodo',
        onTap: onTap,
      );
    }
    final (inizio, fine) = (v.inizio, v.fine);
    final persone = dati.persone.length;
    final destra = switch (stato) {
      StatoViaggio.inCorso when inizio != null && fine != null =>
        'GIORNO ${giorniDiCalendario(inizio, oggi)} '
            'DI ${giorniDiCalendario(inizio, fine)}',
      StatoViaggio.definito when inizio != null => _traQuanto(inizio),
      StatoViaggio.chiuso when inizio != null => '${inizio.year}',
      _ => null,
    };
    return Biglietto(
      codice: codiceViaggio(v),
      nome: titoloViaggio(v),
      sinistra: descrizioneStato(stato).toUpperCase(),
      destra: destra,
      colore: stato == StatoViaggio.chiuso ? Colori.inchiostro : Colori.cobalto,
      campi: [
        if (inizio != null) CampoMatrice('Dal', dataBreve(inizio)),
        if (fine != null) CampoMatrice('Al', dataBreve(fine)),
        CampoMatrice('Persone', '$persone'),
      ],
      onTap: onTap,
      etichetta: [
        titoloViaggio(v),
        descrizioneStato(stato),
        quandoViaggio(v),
        ?destra?.toLowerCase(),
        quanti(persone, 'persona', 'persone'),
      ].join(', '),
    );
  }

  /// «TRA 8 GIORNI», «DOMANI».
  String _traQuanto(DateTime inizio) {
    final giorni = soloData(inizio).difference(soloData(oggi)).inDays;
    return giorni <= 1 ? 'DOMANI' : 'TRA $giorni GIORNI';
  }
}

/// La voce che porta all'archivio delle idee, se ce ne sono.
class _VoceArchivio extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = Tavolozza.of(context);
    return StreamBuilder<List<ViaggioInElenco>>(
      stream: Servizi.of(context).archivio
          .osservaViaggiInElenco(archiviati: true),
      builder: (context, snapshot) {
        final quante = snapshot.data?.length ?? 0;
        if (quante == 0) return const SizedBox.shrink();
        return Premibile(
          onTap: () => apri<void>(context, const SchermataArchivio()),
          scala: 0.985,
          etichetta: 'Archivio, ${quanti(quante, 'idea', 'idee')}',
          child: Pannello(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                IconaTonda(
                  icona(
                    ios: CupertinoIcons.archivebox,
                    android: Icons.archive_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Archivio',
                    style: Testi.evidenza.copyWith(color: t.testo),
                  ),
                ),
                Text(
                  quanti(quante, 'idea', 'idee'),
                  style: Testi.secondario.copyWith(color: t.testoSecondario),
                ),
                const SizedBox(width: 6),
                Icon(
                  icona(
                    ios: CupertinoIcons.chevron_right,
                    android: Icons.chevron_right,
                  ),
                  size: 16,
                  color: t.testoTerziario,
                ),
              ],
            ),
          ),
        ).entra(context, ritardo: Ritmo.passo * 4);
      },
    );
  }
}

/// Nessun viaggio ancora: una scheda bianca con le due strade.
class _Vuoto extends StatelessWidget {
  const _Vuoto({required this.onNuovoViaggio, required this.onCodice});

  final VoidCallback onNuovoViaggio;
  final VoidCallback onCodice;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      24,
      20,
      BarraPrincipale.ingombro + MediaQuery.paddingOf(context).bottom,
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Pannello(
          raggio: 24,
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Ogni viaggio comincia da un\'idea',
                style: Testi.titoloSezione.copyWith(color: Colori.inchiostro),
              ),
              const SizedBox(height: 8),
              Text(
                'Basta un posto e un periodo, anche vago. Le date, le tappe e '
                'chi viene con te si aggiungono dopo.',
                style: Testi.corpo.copyWith(color: Colori.grafite),
              ),
              const SizedBox(height: 20),
              PulsanteGrande(
                etichetta: 'Nuovo viaggio',
                onPressed: onNuovoViaggio,
              ),
              const SizedBox(height: 10),
              PulsanteGrande(
                etichetta: 'Ho un codice d\'invito',
                secondario: true,
                onPressed: onCodice,
              ),
            ],
          ),
        ).entra(context, ritardo: Ritmo.passo * 2, da: 30),
      ],
    ),
  );
}
