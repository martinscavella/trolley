import 'dart:math';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
import '../dominio/codice_invito.dart';
import '../misurazione/misurazione.dart';
import '../servizi.dart';
import 'impostazioni.dart';
import 'viaggio.dart';

/// I propri viaggi. Si legge dalla copia locale: funziona anche senza rete.
class SchermataViaggi extends StatefulWidget {
  const SchermataViaggi({super.key, required this.onCodice});

  /// Un codice d'invito digitato a mano: lo gestisce l'app come quelli dei link.
  final ValueChanged<String> onCodice;

  @override
  State<SchermataViaggi> createState() => _SchermataViaggiState();
}

class _SchermataViaggiState extends State<SchermataViaggi> {
  final _scorrimento = ScrollController();

  /// Il titolo grande scorre via e ricompare piccolo nella barra, come su iOS.
  bool _titoloInBarra = false;
  bool _offline = false;
  bool _creazioneInCorso = false;

  @override
  void initState() {
    super.initState();
    _scorrimento.addListener(() {
      final inBarra = _scorrimento.offset > 44;
      if (inBarra != _titoloInBarra) setState(() => _titoloInBarra = inBarra);
    });
  }

  @override
  void dispose() {
    _scorrimento.dispose();
    super.dispose();
  }

  Future<void> _aggiorna() async {
    try {
      await Servizi.of(context).archivio.aggiornaCopia();
      if (mounted) setState(() => _offline = false);
    } on ErroreTrolley catch (e) {
      if (mounted) setState(() => _offline = e.serveLaRete);
    }
  }

  Future<void> _nuovaIdea() async {
    if (_creazioneInCorso) return;
    final servizi = Servizi.of(context);
    final citta = await AdaptiveAlertDialog.inputShow(
      context: context,
      title: 'Nuova idea',
      message: 'Dove? Anche vago: le date si aggiungono dopo.',
      input: const AdaptiveAlertDialogInput(placeholder: 'Lisbona, Dolomiti…'),
      actions: [
        AlertAction(
          title: 'Annulla',
          style: AlertActionStyle.cancel,
          onPressed: () {},
        ),
        AlertAction(
          title: 'Crea',
          style: AlertActionStyle.primary,
          onPressed: () {},
        ),
      ],
    );
    if (citta == null || !mounted) return;
    setState(() => _creazioneInCorso = true);
    try {
      final id = await servizi.archivio.creaIdea(citta: citta);
      await servizi.misurazione.registra(Eventi.viaggioCreato, {
        'stato_iniziale': 'idea',
        'durata_prevista_giorni': null,
      });
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      await apri<void>(context, SchermataViaggio(viaggioId: id));
    } on ErroreTrolley catch (e) {
      if (mounted) mostraMessaggio(context, e.messaggio, errore: true);
    } finally {
      if (mounted) setState(() => _creazioneInCorso = false);
    }
  }

  Future<void> _inserisciCodice() async {
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

  @override
  Widget build(BuildContext context) {
    final servizi = Servizi.of(context);
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
              SliverToBoxAdapter(
                child: AnimatedSize(
                  duration: Ritmo.medio,
                  curve: Ritmo.curva,
                  child: _offline
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Avviso(
                            icona: icona(
                              ios: CupertinoIcons.wifi_slash,
                              android: Icons.wifi_off,
                            ),
                            testo: 'Sei offline: stai vedendo la copia sul telefono.',
                            colore: Tavolozza.of(context).testoSecondario,
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ),
              if (viaggi == null)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: IndicatoreAttivita()),
                )
              else if (viaggi.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _Vuoto(
                    onNuovaIdea: _nuovaIdea,
                    onCodice: _inserisciCodice,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
                  sliver: SliverList.separated(
                    itemCount: viaggi.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (context, i) {
                      final v = viaggi[i];
                      return TieniVivo(
                        key: ValueKey(v.viaggio.id),
                        child: SchedaViaggio(
                          dati: v,
                          onTap: () => apri<void>(
                            context,
                            SchermataViaggio(viaggioId: v.viaggio.id),
                          ),
                        ).entra(context, ritardo: Ritmo.passo * min(i, 6)),
                      );
                    },
                  ),
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
                      child: _PulsanteNuovaIdea(
                        onPressed: _nuovaIdea,
                        inCorso: _creazioneInCorso,
                      ).entra(context, ritardo: Ritmo.lungo, da: 40),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
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

/// Un viaggio nell'elenco: la copertina, dove, quando, chi.
class SchedaViaggio extends StatelessWidget {
  const SchedaViaggio({super.key, required this.dati, required this.onTap});

  final ViaggioInElenco dati;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Tavolozza.of(context);
    final v = dati.viaggio;
    final sfumatura = copertinaPer(v.id);
    final segno = bandiera(v.destinazionePaese);
    const bianco = Colors.white;
    return Premibile(
      onTap: onTap,
      etichetta: '${titoloViaggio(v)}, ${descrizioneStato(v.stato)}',
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
                            descrizioneStato(v.stato),
                            suCopertina: true,
                            icona: v.stato == 'idea'
                                ? icona(
                                    ios: CupertinoIcons.lightbulb,
                                    android: Icons.lightbulb_outline,
                                  )
                                : null,
                          ),
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

/// Nessun viaggio ancora: un'illustrazione che respira e le due strade.
class _Vuoto extends StatelessWidget {
  const _Vuoto({required this.onNuovaIdea, required this.onCodice});

  final VoidCallback onNuovaIdea;
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
            'Basta un posto, anche vago. Le date, le tappe e chi viene con te '
            'si aggiungono dopo.',
            textAlign: TextAlign.center,
            style: Testi.corpo.copyWith(color: t.testoSecondario),
          ).entra(context, ritardo: Ritmo.passo * 3),
          const SizedBox(height: 28),
          PulsanteGrande(
            etichetta: 'Nuova idea',
            onPressed: onNuovaIdea,
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
class _PulsanteNuovaIdea extends StatelessWidget {
  const _PulsanteNuovaIdea({required this.onPressed, required this.inCorso});

  final VoidCallback onPressed;
  final bool inCorso;

  @override
  Widget build(BuildContext context) {
    final t = Tavolozza.of(context);
    return SizedBox(
      width: 200,
      child: AdaptiveButton.child(
        onPressed: inCorso ? null : onPressed,
        enabled: !inCorso,
        style: AdaptiveButtonStyle.prominentGlass,
        size: AdaptiveButtonSize.large,
        color: t.accento,
        useSmoothRectangleBorder: false,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sul vetro tinto dall'accento si scrive col colore pensato per
            // stare sopra l'accento: bianco in chiaro, scuro in scuro.
            if (inCorso)
              IndicatoreAttivita(colore: t.suAccento)
            else
              Icon(Icons.add_rounded, color: t.suAccento, size: 22),
            const SizedBox(width: 6),
            Text(
              inCorso ? 'Un attimo…' : 'Nuova idea',
              style: Testi.evidenza.copyWith(color: t.suAccento),
            ),
          ],
        ),
      ),
    );
  }
}
