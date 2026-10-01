import 'dart:async';
import 'dart:math';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../aspetto/copertina.dart';
import '../aspetto/elementi.dart';
import '../aspetto/formati.dart';
import '../aspetto/movimento.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../dati/archivio.dart';
import '../dati/database.dart';
import '../dati/errori.dart';
import '../dati/lettura.dart';
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

  @override
  Widget build(BuildContext context) {
    final servizi = Servizi.of(context);
    final oggi = DateTime.now();
    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(
        title: _titoloInBarra ? 'Viaggi' : null,
        actions: [
          AdaptiveAppBarAction(
            iosSymbol: 'envelope.open',
            icon: Icons.drafts_outlined,
            label: 'Ho un codice d\'invito',
            onPressed: _inserisciCodice,
          ),
          AdaptiveAppBarAction(
            iosSymbol: 'gearshape',
            icon: Icons.settings_outlined,
            label: 'Impostazioni',
            onPressed: () => apri<void>(context, const SchermataImpostazioni()),
          ),
        ],
      ),
      body: StreamBuilder<List<ViaggioInElenco>>(
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
              SliverSafeArea(
                bottom: false,
                sliver: SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  sliver: SliverToBoxAdapter(
                    child: _Intestazione(numero: viaggi?.length ?? 0),
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
                for (final MapEntry(key: stato, value: dellaSezione)
                    in sezioni.entries) ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: TitoloSezione(
                        titoloSezione(stato),
                      ).entra(context, ritardo: Ritmo.passo * min(indice, 6)),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    sliver: SliverList.separated(
                      itemCount: dellaSezione.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 16),
                      itemBuilder: (context, i) {
                        final v = dellaSezione[i];
                        return TieniVivo(
                          key: ValueKey(v.viaggio.id),
                          child:
                              SchedaViaggio(
                                dati: v,
                                stato: stato,
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
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
                sliver: SliverToBoxAdapter(child: _VoceArchivio()),
              ),
            ],
          );

          return Stack(
            children: [
              if (suIOS)
                elenco
              else
                RefreshIndicator(onRefresh: _aggiorna, child: elenco),
              if (viaggi != null && viaggi.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    minimum: const EdgeInsets.only(bottom: 16),
                    child: Center(
                      child: _PulsanteNuovoViaggio(onPressed: _nuovoViaggio)
                          .entra(context, ritardo: Ritmo.lungo, da: 40),
                    ),
                  ),
                ),
            ],
          );
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
  const _Intestazione({required this.numero});

  final int numero;

  @override
  Widget build(BuildContext context) {
    final t = Tavolozza.of(context);
    return StreamBuilder<Utente?>(
      stream: Servizi.of(context).archivio.osservaProfilo(),
      builder: (context, snapshot) {
        final nome = snapshot.data?.nome;
        final saluto = [
          if (nome != null) 'Ciao $nome',
          if (numero > 0) quanti(numero, 'viaggio', 'viaggi'),
        ].join(' · ');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Viaggi', style: Testi.titoloGrande.copyWith(color: t.testo)),
            const SizedBox(height: 4),
            AnimatedSwitcher(
              duration: Ritmo.medio,
              child: Text(
                saluto,
                key: ValueKey(saluto),
                style: Testi.secondario.copyWith(color: t.testoSecondario),
              ),
            ),
          ],
        ).entra(context, da: 8);
      },
    );
  }
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
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Avviso(
                  icona: icona(
                    ios: CupertinoIcons.wifi_slash,
                    android: Icons.wifi_off,
                  ),
                  testo: scaricata == null
                      ? 'Sei offline.'
                      : 'Sei offline: stai vedendo la copia sul telefono, '
                            'aggiornata ${quantoFa(scaricata, DateTime.now())}.',
                  colore: Tavolozza.of(context).testoSecondario,
                ),
              ),
      ),
    );
  }
}

/// Un viaggio nell'elenco: la copertina, dove, quando, chi.
class SchedaViaggio extends StatelessWidget {
  const SchedaViaggio({
    super.key,
    required this.dati,
    required this.stato,
    required this.onTap,
    this.sollecito = false,
  });

  final ViaggioInElenco dati;
  final StatoViaggio stato;
  final VoidCallback onTap;

  /// Un'idea vicina alla fine del suo periodo, o oltre: "è ancora un'idea?".
  final bool sollecito;

  @override
  Widget build(BuildContext context) {
    final t = Tavolozza.of(context);
    final v = dati.viaggio;
    final sfumatura = copertinaPer(v.id);
    final segno = bandiera(v.destinazionePaese);
    const bianco = Colors.white;
    return Premibile(
      onTap: onTap,
      etichetta: [
        titoloViaggio(v),
        descrizioneStato(stato),
        if (sollecito) 'è ancora un\'idea?',
      ].join(', '),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(CopertinaEroe.raggioScheda),
          ),
          shadows: t.scuro
              ? null
              : [
                  BoxShadow(
                    color: sfumatura.inizio.withValues(alpha: 0.35),
                    blurRadius: 26,
                    spreadRadius: -8,
                    offset: const Offset(0, 14),
                  ),
                ],
        ),
        child: SizedBox(
          height: 184,
          child: ClipRSuperellipse(
            borderRadius: BorderRadius.circular(CopertinaEroe.raggioScheda),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CopertinaEroe(chiave: v.id, raggio: CopertinaEroe.raggioScheda),
                // Un velo in basso, perché il testo si legga su ogni colore.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.center,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0x59000000)],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Pillola(
                            descrizioneStato(stato),
                            suCopertina: true,
                            icona: stato == StatoViaggio.idea
                                ? icona(
                                    ios: CupertinoIcons.lightbulb,
                                    android: Icons.lightbulb_outline,
                                  )
                                : null,
                          ),
                          if (sollecito) ...[
                            const SizedBox(width: 6),
                            Pillola(
                              'Ancora un\'idea?',
                              suCopertina: true,
                              icona: icona(
                                ios: CupertinoIcons.hourglass,
                                android: Icons.hourglass_bottom,
                              ),
                            ),
                          ],
                          const Spacer(),
                          if (segno != null)
                            Text(segno, style: const TextStyle(fontSize: 26)),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        titoloViaggio(v),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Testi.titolo.copyWith(color: bianco),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              quandoViaggio(v),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Testi.secondario.copyWith(
                                color: bianco.withValues(alpha: 0.9),
                              ),
                            ),
                          ),
                          if (dati.persone.isNotEmpty)
                            PilaAvatar(
                              nomi: dati.persone,
                              bordo: bianco.withValues(alpha: 0.9),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
                  colore: t.testoSecondario,
                  dimensione: 36,
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

/// Nessun viaggio ancora: un'illustrazione che respira e le due strade.
class _Vuoto extends StatelessWidget {
  const _Vuoto({required this.onNuovoViaggio, required this.onCodice});

  final VoidCallback onNuovoViaggio;
  final VoidCallback onCodice;

  @override
  Widget build(BuildContext context) {
    final t = Tavolozza.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _Illustrazione(),
          const SizedBox(height: 32),
          Text(
            'Ogni viaggio comincia da un\'idea',
            textAlign: TextAlign.center,
            style: Testi.titoloSezione.copyWith(color: t.testo),
          ).entra(context, ritardo: Ritmo.passo * 2),
          const SizedBox(height: 8),
          Text(
            'Basta un posto e un periodo, anche vago. Le date, le tappe e chi '
            'viene con te si aggiungono dopo.',
            textAlign: TextAlign.center,
            style: Testi.corpo.copyWith(color: t.testoSecondario),
          ).entra(context, ritardo: Ritmo.passo * 3),
          const SizedBox(height: 28),
          PulsanteGrande(
            etichetta: 'Nuovo viaggio',
            onPressed: onNuovoViaggio,
          ).entra(context, ritardo: Ritmo.passo * 4),
          const SizedBox(height: 4),
          PulsanteGrande(
            etichetta: 'Ho un codice d\'invito',
            secondario: true,
            onPressed: onCodice,
          ).entra(context, ritardo: Ritmo.passo * 5),
        ],
      ),
    );
  }
}

class _Illustrazione extends StatelessWidget {
  const _Illustrazione();

  @override
  Widget build(BuildContext context) {
    final t = Tavolozza.of(context);
    Widget satellite(IconData simbolo, Color colore) => Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: t.superficie,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Icon(simbolo, color: colore, size: 22),
    );

    return SizedBox(
      width: 220,
      height: 190,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 148,
            height: 148,
            decoration: ShapeDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [t.accento, const Color(0xFF1D5FAE)],
              ),
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(48),
              ),
            ),
            child: const Icon(
              Icons.luggage_rounded,
              color: Colors.white,
              size: 72,
            ),
          ).sboccia(context).galleggia(context),
          Positioned(
            left: 8,
            top: 16,
            child:
                satellite(
                      icona(
                        ios: CupertinoIcons.airplane,
                        android: Icons.flight_rounded,
                      ),
                      const Color(0xFF339AF0),
                    )
                    .sboccia(context, ritardo: Ritmo.passo * 2)
                    .galleggia(context, ampiezza: 4),
          ),
          Positioned(
            right: 6,
            bottom: 20,
            child:
                satellite(
                      icona(
                        ios: CupertinoIcons.location_solid,
                        android: Icons.place_rounded,
                      ),
                      const Color(0xFFFF6B6B),
                    )
                    .sboccia(context, ritardo: Ritmo.passo * 3)
                    .galleggia(context, ampiezza: 5),
          ),
        ],
      ),
    );
  }
}

/// Il pulsante che galleggia in fondo all'elenco: vetro vero su iOS 26.
class _PulsanteNuovoViaggio extends StatelessWidget {
  const _PulsanteNuovoViaggio({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = Tavolozza.of(context);
    // Largo quanto il suo contenuto: con il testo ingrandito
    // dall'accessibilità cresce, e l'etichetta si accorcia solo se non ci sta.
    return AdaptiveButton.child(
      onPressed: onPressed,
      style: AdaptiveButtonStyle.prominentGlass,
      size: AdaptiveButtonSize.large,
      color: t.accento,
      useSmoothRectangleBorder: false,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sul vetro tinto dall'accento si scrive col colore pensato per
          // stare sopra l'accento: bianco in chiaro, scuro in scuro.
          Icon(Icons.add_rounded, color: t.suAccento, size: 22),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Nuovo viaggio',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Testi.evidenza.copyWith(color: t.suAccento),
            ),
          ),
        ],
      ),
    );
  }
}
