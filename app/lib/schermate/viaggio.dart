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
import '../dominio/codice_invito.dart';
import '../misurazione/misurazione.dart';
import '../servizi.dart';

/// Un viaggio: quando, chi c'è, l'invito. Tappe, spese e liste arrivano con la
/// fase 1.
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
  }

  @override
  void dispose() {
    _scorrimento.dispose();
    super.dispose();
  }

  Future<void> _invita() async {
    if (_invitoInCorso) return;
    final servizi = Servizi.of(context);
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
                      altezza: sopra + _altezzaTestata,
                      scorrimento: _scorrimento,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Transform.translate(
                      offset: const Offset(0, -28),
                      child: _Foglio(
                        children: [
                          _Quando(viaggio: viaggio).entra(context),
                          const SizedBox(height: 24),
                          const TitoloSezione('Chi c\'è')
                              .entra(context, ritardo: Ritmo.passo),
                          _Partecipanti(viaggioId: widget.viaggioId)
                              .entra(context, ritardo: Ritmo.passo * 2),
                          const SizedBox(height: 24),
                          _Invito(
                            chiave: _origineInvito,
                            inCorso: _invitoInCorso,
                            onInvita: _invita,
                          ).entra(context, ritardo: Ritmo.passo * 3),
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
    required this.altezza,
    required this.scorrimento,
  });

  final Viaggio viaggio;
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
                Pillola(descrizioneStato(viaggio.stato), suCopertina: true),
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

class _Quando extends StatelessWidget {
  const _Quando({required this.viaggio});

  final Viaggio viaggio;

  @override
  Widget build(BuildContext context) {
    final t = Tavolozza.of(context);
    final inizio = DateTime.tryParse(viaggio.dataInizio ?? '');
    final fine = DateTime.tryParse(viaggio.dataFine ?? '');
    final conDate = inizio != null && fine != null;
    return Pannello(
      child: Row(
        children: [
          IconaTonda(
            icona(
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
                  conDate ? intervalloDate(inizio, fine) : 'Date da decidere',
                  style: Testi.evidenza.copyWith(color: t.testo),
                ),
                const SizedBox(height: 2),
                Text(
                  conDate
                      ? quanti(
                          giorniDiViaggio(inizio, fine),
                          'giorno',
                          'giorni',
                        )
                      : 'È ancora un\'idea: quando fissate le date, il viaggio '
                            'diventa definito.',
                  style: Testi.secondario.copyWith(color: t.testoSecondario),
                ),
              ],
            ),
          ),
        ],
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
          PulsanteGrande(
            etichetta: 'Invita qualcuno',
            inCorso: inCorso,
            onPressed: onInvita,
          ),
        ],
      ),
    );
  }
}
