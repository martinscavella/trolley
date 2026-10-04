/// Le due forme di schermata della tela: la pagina, sul fondo grigio con i
/// pulsanti quadrati in alto; il foglio bianco che sale dal basso sopra la
/// schermata di prima, come "Nuova idea".
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'elementi.dart';
import 'movimento.dart';
import 'piattaforma.dart';
import 'tavolozza.dart';
import 'testi.dart';

/// Una pagina della tela. I contenuti scorrono sotto i pulsanti in alto:
/// [MediaQuery.paddingOf] in [corpo] dice già dove cominciare.
class Pagina extends StatelessWidget {
  const Pagina({
    super.key,
    required this.corpo,
    this.sinistra,
    this.azioni = const [],
    this.inBasso,
  });

  final Widget corpo;

  /// In alto a sinistra. Se manca e si può tornare indietro, c'è "Indietro".
  final Widget? sinistra;

  /// In alto a destra: pulsanti quadrati.
  final List<Widget> azioni;

  /// Quello che galleggia in basso: la barra principale.
  final Widget? inBasso;

  /// Quanto occupano i pulsanti in alto, sotto la barra di stato.
  static const altezzaBarra = 64.0;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final rotta = ModalRoute.of(context);
    final indietro = sinistra == null && (rotta?.canPop ?? false)
        ? PulsanteIndietro(chiudi: rotta is PageRoute && rotta.fullscreenDialog)
        : null;
    final inAlto = sinistra ?? indietro;
    final conBarra = inAlto != null || azioni.isNotEmpty;
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colori.nebbia,
          body: Stack(
            children: [
              Positioned.fill(
                child: MediaQuery(
                  data: mq.copyWith(
                    padding: mq.padding.copyWith(
                      top: mq.padding.top + (conBarra ? altezzaBarra : 8),
                    ),
                  ),
                  child: corpo,
                ),
              ),
              if (conBarra)
                Positioned(
                  top: mq.padding.top + 8,
                  left: 20,
                  right: 20,
                  child: Row(
                    children: [
                      ?inAlto,
                      const Spacer(),
                      for (final (i, a) in azioni.indexed) ...[
                        if (i > 0) const SizedBox(width: 8),
                        a,
                      ],
                    ],
                  ),
                ),
              if (inBasso != null)
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: mq.padding.bottom > 0 ? mq.padding.bottom - 6 : 20,
                  child: inBasso!,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Il pulsante d'inchiostro per tornare indietro, o per chiudere una
/// schermata salita dal basso.
class PulsanteIndietro extends StatelessWidget {
  const PulsanteIndietro({super.key, this.chiudi = false});

  final bool chiudi;

  @override
  Widget build(BuildContext context) => PulsanteTondo(
    icona: chiudi
        ? icona(ios: CupertinoIcons.xmark, android: Icons.close)
        : icona(ios: CupertinoIcons.chevron_back, android: Icons.arrow_back),
    etichetta: chiudi ? 'Chiudi' : 'Indietro',
    scuro: true,
    onPressed: () => Navigator.of(context).maybePop(),
  );
}

/// Apre [foglio] dal basso sopra la schermata di prima, che resta visibile
/// sotto un velo d'inchiostro. Si chiude trascinandolo giù o toccando fuori.
Future<T?> apriFoglio<T>(BuildContext context, Widget foglio) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0x00000000),
      barrierColor: Colori.inchiostro.withValues(alpha: 0.45),
      elevation: 0,
      sheetAnimationStyle: movimentoRidotto(context)
          ? AnimationStyle.noAnimation
          : AnimationStyle(
              duration: Ritmo.medio,
              reverseDuration: Ritmo.breve,
              curve: Ritmo.curva,
            ),
      builder: (_) => foglio,
    );

/// Il foglio bianco della tela: la maniglia, il titolo, i contenuti che
/// scorrono, e in fondo le azioni.
class Foglio extends StatelessWidget {
  const Foglio({
    super.key,
    required this.titolo,
    required this.children,
    this.inBasso,
  });

  final String titolo;
  final List<Widget> children;

  /// Le azioni in fondo, che restano visibili mentre i contenuti scorrono.
  final Widget? inBasso;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colori.bianco,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colori.cenere,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
              child: Semantics(
                header: true,
                child: Text(
                  titolo,
                  style: Testi.titoloFoglio.copyWith(color: Colori.inchiostro),
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                children: children,
              ),
            ),
            if (inBasso != null)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  4,
                  24,
                  (mq.viewInsets.bottom > 0 ? 0 : mq.padding.bottom) + 24,
                ),
                child: inBasso,
              ),
          ],
        ),
      ),
    );
  }
}

/// Due pulsanti affiancati in fondo a un foglio: "Annulla" e l'azione.
class AzioniFoglio extends StatelessWidget {
  const AzioniFoglio({super.key, required this.azione, this.motivo});

  /// Il pulsante principale, già con il suo stato.
  final Widget azione;

  /// Perché l'azione è spenta, scritto sotto tutti e due.
  final String? motivo;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(child: PulsanteAnnulla()),
          const SizedBox(width: 12),
          Expanded(child: azione),
        ],
      ),
      AnimatedSize(
        duration: Ritmo.medio,
        curve: Ritmo.curva,
        alignment: Alignment.topCenter,
        child: motivo == null
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  motivo!,
                  textAlign: TextAlign.center,
                  style: Testi.didascalia.copyWith(color: Colori.grafite),
                ),
              ),
      ),
    ],
  );
}

/// "Annulla", bianco con il bordo grigio, che chiude il foglio.
class PulsanteAnnulla extends StatelessWidget {
  const PulsanteAnnulla({super.key});

  @override
  Widget build(BuildContext context) => Premibile(
    onTap: () => Navigator.of(context).maybePop(),
    etichetta: 'Annulla',
    child: Container(
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colori.bianco,
        border: Border.all(color: Colori.cenere, width: 2),
      ),
      child: Text(
        'Annulla',
        style: Testi.pulsante.copyWith(color: Colori.inchiostro),
      ),
    ),
  );
}

/// Una voce di [scegliAzione].
class AzioneMenu {
  const AzioneMenu(this.etichetta, this.onTap, {this.pericolo = false});

  final String etichetta;
  final VoidCallback onTap;
  final bool pericolo;
}

/// Un menu di poche azioni, con il componente di sistema: il foglio di azioni
/// di iOS, un elenco dal basso su Android. Con [titolo] e [messaggio] sopra,
/// quando la scelta va spiegata.
Future<void> scegliAzione(
  BuildContext context,
  List<AzioneMenu> azioni, {
  String? titolo,
  String? messaggio,
}) async {
  final scelta = suIOS
      ? await showCupertinoModalPopup<AzioneMenu>(
          context: context,
          builder: (contesto) => CupertinoActionSheet(
            title: titolo == null ? null : Text(titolo),
            message: messaggio == null ? null : Text(messaggio),
            actions: [
              for (final a in azioni)
                CupertinoActionSheetAction(
                  isDestructiveAction: a.pericolo,
                  onPressed: () => Navigator.of(contesto).pop(a),
                  child: Text(a.etichetta),
                ),
            ],
            cancelButton: CupertinoActionSheetAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(contesto).pop(),
              child: const Text('Annulla'),
            ),
          ),
        )
      : await showModalBottomSheet<AzioneMenu>(
          context: context,
          builder: (contesto) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (titolo != null || messaggio != null)
                  ListTile(
                    title: titolo == null ? null : Text(titolo),
                    subtitle: messaggio == null ? null : Text(messaggio),
                  ),
                for (final a in azioni)
                  ListTile(
                    title: Text(
                      a.etichetta,
                      style: a.pericolo
                          ? const TextStyle(color: Colori.pericolo)
                          : null,
                    ),
                    onTap: () => Navigator.of(contesto).pop(a),
                  ),
              ],
            ),
          ),
        );
  scelta?.onTap();
}
