import 'dart:async';
import 'dart:math';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../aspetto/copertina.dart';
import '../aspetto/elementi.dart';
import '../aspetto/formati.dart';
import '../aspetto/movimento.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../dati/database.dart';
import '../dati/errori.dart';
import '../dati/lettura.dart';
import '../dominio/calendario.dart';
import '../dominio/codice_invito.dart';
import '../dominio/giornate.dart';
import '../dominio/stato_viaggio.dart';
import '../misurazione/misurazione.dart';
import '../servizi.dart';
import 'con_la_rete.dart';
import 'date_viaggio.dart';
import 'scelta_periodo.dart';

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
  final _scorrimento = ScrollController();
  final _origineInvito = GlobalKey();
  bool _titoloInBarra = false;
  bool _invitoInCorso = false;

  static const _altezzaTestata = 250.0;

  @override
  void initState() {
    super.initState();
    _scorrimento.addListener(() {
      final inBarra = _scorrimento.offset > _altezzaTestata - 40;
      if (inBarra != _titoloInBarra) setState(() => _titoloInBarra = inBarra);
    });
    // Aprire il viaggio aggiorna la copia (02 §1). Senza rete resta quella che
    // c'è, e va bene così.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(
          Servizi.of(context).archivio.aggiornaCopia().catchError((_) {}),
        );
      }
    });
  }

  @override
  void dispose() {
    _scorrimento.dispose();
    super.dispose();
  }

  Future<void> _invita() async {
    if (_invitoInCorso) return;
    final servizi = Servizi.of(context);
    if (!servizi.rete.disponibile) {
      mostraMessaggio(context, 'Per invitare qualcuno serve la connessione.');
      return;
    }
    // Il foglio di condivisione su iPad vuole sapere da dove parte.
    final box = _origineInvito.currentContext?.findRenderObject() as RenderBox?;
    setState(() => _invitoInCorso = true);
    try {
      final codice = await servizi.archivio.creaInvito(widget.viaggioId);
      await servizi.misurazione.registra(Eventi.invitoCreato);
      HapticFeedback.lightImpact();
      await SharePlus.instance.share(
        ShareParams(
          text: messaggioInvito(codice),
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
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
    // Lo spazio della barra di stato e della barra di vetro: la copertina ci
    // passa sotto, i testi no.
    final sopra = MediaQuery.paddingOf(context).top;
    return StreamBuilder<Viaggio?>(
      stream: archivio.osservaViaggio(widget.viaggioId),
      builder: (context, snapshot) {
        final viaggio = snapshot.data;
        if (viaggio == null) {
          return AdaptiveScaffold(
            appBar: const AdaptiveAppBar(),
            body: Center(
              child: snapshot.connectionState == ConnectionState.waiting
                  ? const IndicatoreAttivita()
                  : const Text('Questo viaggio non è sul telefono.'),
            ),
          );
        }
        final stato = viaggio.statoA(DateTime.now());
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: _titoloInBarra
              ? (Tavolozza.of(context).scuro
                    ? SystemUiOverlayStyle.light
                    : SystemUiOverlayStyle.dark)
              : SystemUiOverlayStyle.light,
          child: AdaptiveScaffold(
            appBar: AdaptiveAppBar(
              title: _titoloInBarra ? titoloViaggio(viaggio) : null,
              actions: [
                AdaptiveAppBarAction(
                  iosSymbol: 'person.badge.plus',
                  icon: Icons.person_add_alt_1_outlined,
                  label: 'Invita qualcuno',
                  onPressed: _invita,
                ),
              ],
            ),
            body: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: CustomScrollView(
                controller: _scorrimento,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child: _Testata(
                      viaggio: viaggio,
                      stato: stato,
                      altezza: sopra + _altezzaTestata,
                      scorrimento: _scorrimento,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Transform.translate(
                      offset: const Offset(0, -28),
                      child: _Foglio(
                        children: [
                          _Quando(
                            viaggio: viaggio,
                            stato: stato,
                          ).entra(context),
                          if (stato == StatoViaggio.idea)
                            _Sollecito(viaggio: viaggio),
                          if (stato.haGiorni) ...[
                            const SizedBox(height: 24),
                            const TitoloSezione('Giorni')
                                .entra(context, ritardo: Ritmo.passo),
                            _Giorni(viaggioId: viaggio.id)
                                .entra(context, ritardo: Ritmo.passo * 2),
                          ],
                          const SizedBox(height: 24),
                          const TitoloSezione('Chi c\'è')
                              .entra(context, ritardo: Ritmo.passo * 2),
                          _Partecipanti(viaggioId: widget.viaggioId)
                              .entra(context, ritardo: Ritmo.passo * 3),
                          const SizedBox(height: 24),
                          _Invito(
                            chiave: _origineInvito,
                            inCorso: _invitoInCorso,
                            onInvita: _invita,
                          ).entra(context, ritardo: Ritmo.passo * 4),
                          SizedBox(
                            height: MediaQuery.paddingOf(context).bottom + 24,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// La copertina a tutto schermo. Tirando giù si allunga, scorrendo su va più
/// piano del contenuto: la profondità che ci si aspetta da iOS.
class _Testata extends StatelessWidget {
  const _Testata({
    required this.viaggio,
    required this.stato,
    required this.altezza,
    required this.scorrimento,
  });

  final Viaggio viaggio;
  final StatoViaggio stato;
  final double altezza;
  final ScrollController scorrimento;

  @override
  Widget build(BuildContext context) {
    final segno = bandiera(viaggio.destinazionePaese);
    const bianco = Colors.white;
    return SizedBox(
      height: altezza,
      child: AnimatedBuilder(
        animation: scorrimento,
        builder: (context, testi) {
          final offset = scorrimento.hasClients ? scorrimento.offset : 0.0;
          final tirato = max(0.0, -offset);
          final parallasse = movimentoRidotto(context)
              ? 0.0
              : max(0.0, offset) * 0.45;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: -tirato + parallasse,
                left: 0,
                right: 0,
                height: altezza + tirato,
                child: CopertinaEroe(chiave: viaggio.id, raggio: 0),
              ),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.center,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0x66000000)],
                    ),
                  ),
                ),
              ),
              Positioned(left: 20, right: 20, bottom: 50, child: testi!),
            ],
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Pillola(descrizioneStato(stato), suCopertina: true),
                if (segno != null) ...[
                  const SizedBox(width: 8),
                  Text(segno, style: const TextStyle(fontSize: 22)),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Text(
              titoloViaggio(viaggio),
              style: Testi.titoloGrande.copyWith(
                color: bianco,
                fontSize: 38,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              quandoViaggio(viaggio),
              style: Testi.corpo.copyWith(color: bianco.withValues(alpha: 0.9)),
            ),
          ],
        ).entra(context, ritardo: Ritmo.passo * 2, da: 12),
      ),
    );
  }
}

/// Il foglio che sale sopra la copertina e porta i contenuti.
class _Foglio extends StatelessWidget {
  const _Foglio({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: ShapeDecoration(
      color: Tavolozza.of(context).sfondo,
      shape: const RoundedSuperellipseBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );
}

/// Quando: il periodo di un'idea, o le date di un viaggio. Si tocca per
/// cambiarli, e richiede la rete: senza, lo dice.
class _Quando extends StatelessWidget {
  const _Quando({required this.viaggio, required this.stato});

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
          conferma: 'Salva il periodo',
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
    final t = Tavolozza.of(context);
    final idea = stato == StatoViaggio.idea;
    final programma = viaggio.programma;
    return ConLaRete(
      builder: (context, rete) {
        final modificabile = stato.dateModificabili;
        return Pannello(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Premibile(
                onTap: modificabile && rete ? () => _cambia(context) : null,
                scala: 0.985,
                etichetta: idea ? 'Cambia il periodo' : 'Cambia le date',
                child: Row(
                  children: [
                    IconaTonda(
                      idea
                          ? icona(
                              ios: CupertinoIcons.lightbulb,
                              android: Icons.lightbulb_outline,
                            )
                          : icona(
                              ios: CupertinoIcons.calendar,
                              android: Icons.calendar_month_outlined,
                            ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            quandoViaggio(viaggio),
                            style: Testi.evidenza.copyWith(color: t.testo),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            idea || programma == null
                                ? 'È un\'idea: con le date diventa un viaggio '
                                      'in programma.'
                                : riassuntoProgramma(programma),
                            style: Testi.secondario.copyWith(
                              color: t.testoSecondario,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (modificabile && rete)
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
              if (modificabile && !rete)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    idea
                        ? 'Per cambiare il periodo o fissare le date serve la '
                              'connessione.'
                        : 'Per spostare le date serve la connessione.',
                    style: Testi.didascalia.copyWith(color: t.testoSecondario),
                  ),
                ),
              if (idea && rete) ...[
                const SizedBox(height: 16),
                PulsanteGrande(
                  etichetta: 'Fissa le date',
                  onPressed: () => apri<bool>(
                    context,
                    SchermataDate(viaggio: viaggio),
                    dalBasso: true,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
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
        colore: Tavolozza.of(context).pericolo,
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
class _Giorni extends StatelessWidget {
  const _Giorni({required this.viaggioId});

  final String viaggioId;

  @override
  Widget build(BuildContext context) {
    final t = Tavolozza.of(context);
    final oggi = soloData(DateTime.now());
    return StreamBuilder<List<Giorno>>(
      stream: Servizi.of(context).archivio.osservaGiorni(viaggioId),
      builder: (context, snapshot) {
        final giorni = [
          for (final g in snapshot.data ?? const <Giorno>[]) g.finestra,
        ];
        if (giorni.isEmpty) return const SizedBox.shrink();
        return Pannello(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            children: [
              for (final (i, g) in giorni.indexed) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    indent: 58,
                    color: t.separatore,
                  ),
                _RigaGiorno(giorno: g, oggi: g.data == oggi),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _RigaGiorno extends StatelessWidget {
  const _RigaGiorno({required this.giorno, required this.oggi});

  final FinestraGiorno giorno;
  final bool oggi;

  @override
  Widget build(BuildContext context) {
    final t = Tavolozza.of(context);
    final d = giorno.data;
    return Semantics(
      label:
          '${giornoDellaSettimana(d)} ${dataEstesa(d)}, '
          '${finestraDelGiorno(giorno)}, ${durata(giorno.capienza)}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: ShapeDecoration(
                color: oggi ? t.accento : t.accento.withValues(alpha: 0.12),
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${d.day}',
                    style: Testi.evidenza.copyWith(
                      color: oggi ? t.suAccento : t.accento,
                      height: 1.05,
                    ),
                  ),
                  Text(
                    meseBreve(d).toUpperCase(),
                    style: Testi.etichetta.copyWith(
                      fontSize: 10,
                      color: oggi ? t.suAccento : t.accento,
                    ),
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
                    style: Testi.evidenza.copyWith(color: t.testo),
                  ),
                  Text(
                    oggi
                        ? 'Oggi, ${finestraDelGiorno(giorno)}'
                        : conMaiuscola(finestraDelGiorno(giorno)),
                    style: Testi.didascalia.copyWith(color: t.testoSecondario),
                  ),
                ],
              ),
            ),
            Text(
              durata(giorno.capienza),
              style: Testi.secondario.copyWith(
                color: t.testoSecondario,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Partecipanti extends StatelessWidget {
  const _Partecipanti({required this.viaggioId});

  final String viaggioId;

  @override
  Widget build(BuildContext context) {
    final t = Tavolozza.of(context);
    return StreamBuilder<List<(Partecipazione, Utente?)>>(
      stream: Servizi.of(context).archivio.osservaPartecipanti(viaggioId),
      builder: (context, snapshot) {
        final persone = snapshot.data ?? const <(Partecipazione, Utente?)>[];
        return Pannello(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: Column(
            children: [
              for (final (i, (partecipazione, utente)) in persone.indexed) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    indent: 54,
                    color: t.separatore,
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Avatar(
                        nome: utente?.nome ?? '?',
                        dimensione: 40,
                      ).sboccia(context, ritardo: Ritmo.passo * (i + 2)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          utente?.nome ?? '…',
                          style: Testi.evidenza.copyWith(color: t.testo),
                        ),
                      ),
                      if (partecipazione.ruolo == 'creatore')
                        const Pillola('Organizza'),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Invito extends StatelessWidget {
  const _Invito({
    required this.chiave,
    required this.inCorso,
    required this.onInvita,
  });

  final Key chiave;
  final bool inCorso;
  final VoidCallback onInvita;

  @override
  Widget build(BuildContext context) {
    final t = Tavolozza.of(context);
    return Pannello(
      key: chiave,
      colore: Color.alphaBlend(t.accento.withValues(alpha: 0.10), t.superficie),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconaTonda(
                icona(
                  ios: CupertinoIcons.person_2_fill,
                  android: Icons.group_outlined,
                ),
                dimensione: 44,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Si viaggia meglio insieme',
                  style: Testi.evidenza.copyWith(color: t.testo),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Chi inviti vede tutto il viaggio e può aggiungere le sue spese, le '
            'sue tappe e le sue cose da portare.',
            style: Testi.secondario.copyWith(color: t.testoSecondario),
          ),
          const SizedBox(height: 16),
          ConLaRete(
            builder: (context, rete) => PulsanteGrande(
              etichetta: 'Invita qualcuno',
              inCorso: inCorso,
              motivo: rete ? null : motivoSenzaRete,
              onPressed: onInvita,
            ),
          ),
        ],
      ),
    );
  }
}
