import 'dart:async';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../aspetto/elementi.dart';
import '../aspetto/movimento.dart';
import '../aspetto/pagina.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../dati/promemoria.dart';
import '../dominio/notifiche.dart';
import '../servizi.dart';
import 'giornata.dart';
import 'prima_di_partire.dart';
import 'riepilogo.dart';
import 'viaggio.dart';

/// Le righe di «Notifiche», nell'ordine della tela (83).
const _righe = [
  (
    TipoNotifica.primaDiPartire,
    'Prima di partire',
    'Due giorni prima, se manca qualcosa',
  ),
  (
    TipoNotifica.tappeDaSegnare,
    'Tappe da segnare',
    'La sera, se ne resta qualcuna',
  ),
  (
    TipoNotifica.ideaCheScade,
    'Idee che scadono',
    'Una volta per idea, al massimo una al giorno',
  ),
  (TipoNotifica.unAnnoFa, 'Un anno fa', '«Un anno fa eri a Lisbona»'),
];

const _notte =
    'Di notte non arriva niente: i promemoria partono fra le 10 e le 21. '
    'Mentre sei in viaggio arrivano solo quelli del viaggio.';

/// Le notifiche, una per una (tela, 83). Prima di accenderle (119), o
/// spente dalle Impostazioni del telefono (120), le righe restano visibili ma
/// ferme, e la scheda sopra dice come accenderle. Le scelte sono di questo
/// telefono, e valgono anche senza rete.
class SchermataNotifiche extends StatefulWidget {
  const SchermataNotifiche({super.key});

  @override
  State<SchermataNotifiche> createState() => _SchermataNotificheState();
}

class _SchermataNotificheState extends State<SchermataNotifiche>
    with WidgetsBindingObserver {
  PermessoNotifiche? _permesso;
  Set<TipoNotifica> _spente = const {};
  bool _primaVolta = true;
  bool _inCorso = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_primaVolta) {
      _primaVolta = false;
      unawaited(_leggi());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState stato) {
    // Tornando dalle Impostazioni il permesso può essere cambiato.
    if (stato == AppLifecycleState.resumed) unawaited(_leggi());
  }

  Future<void> _leggi() async {
    if (!mounted) return;
    final promemoria = Servizi.of(context).promemoria;
    final permesso = await promemoria.permesso();
    final spente = await promemoria.spente();
    if (mounted) {
      setState(() {
        _permesso = permesso;
        _spente = spente;
      });
    }
  }

  Future<void> _accendi() async {
    final promemoria = Servizi.of(context).promemoria;
    setState(() => _inCorso = true);
    final permesso = await promemoria.chiedi(da: 'impostazioni');
    if (mounted) {
      setState(() {
        _permesso = permesso;
        _inCorso = false;
      });
    }
  }

  Future<void> _imposta(TipoNotifica tipo, bool accesa) async {
    setState(
      () =>
          _spente = accesa ? (_spente.difference({tipo})) : {..._spente, tipo},
    );
    await Servizi.of(context).promemoria.imposta(tipo, accesa: accesa);
  }

  @override
  Widget build(BuildContext context) {
    final permesso = _permesso;
    return Pagina(
      corpo: Builder(
        builder: (context) => ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.paddingOf(context).top,
            20,
            MediaQuery.paddingOf(context).bottom + 32,
          ),
          children: [
            const TitoloPagina(
              'Notifiche',
              sottotitolo:
                  "Ognuna si spegne da sola. L'app funziona per intero anche "
                  'senza.',
            ).entra(context),
            if (permesso == null)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: IndicatoreAttivita(),
              )
            else ...[
              if (permesso == PermessoNotifiche.daChiedere) ...[
                _Stato(
                  icona: icona(
                    ios: CupertinoIcons.bell,
                    android: Icons.notifications_none_rounded,
                  ),
                  titolo: 'Per ora sono spente',
                  testo:
                      'Il telefono chiede il permesso una volta sola. Poi le '
                      'scegli qui, una per una.',
                  pulsante: PulsanteGrande(
                    etichetta: 'Accendile',
                    onPressed: _inCorso ? null : _accendi,
                  ),
                ).entra(context, ritardo: Ritmo.passo),
                const SizedBox(height: 16),
              ],
              if (permesso == PermessoNotifiche.negato) ...[
                _Stato(
                  icona: icona(
                    ios: CupertinoIcons.bell_slash,
                    android: Icons.notifications_off_outlined,
                  ),
                  titolo: 'Il telefono non le fa arrivare',
                  testo:
                      'Sono spente nelle Impostazioni del telefono. Le stesse '
                      "cose le trovi comunque dentro l'app.",
                  pulsante: PulsanteGrande(
                    etichetta: 'Apri Impostazioni',
                    secondario: true,
                    onPressed: () =>
                        Servizi.of(context).promemoria.apriImpostazioni(),
                  ),
                ).entra(context, ritardo: Ritmo.passo),
                const SizedBox(height: 16),
              ],
              _Tipi(
                spente: _spente,
                attive: permesso == PermessoNotifiche.concesso,
                onCambia: _imposta,
              ).entra(context, ritardo: Ritmo.passo * 2),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
                child: Text(
                  _notte,
                  textAlign: TextAlign.center,
                  style: Testi.didascalia.copyWith(color: Colori.grafite),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// La scheda sopra le righe quando le notifiche non arrivano (119, 120).
class _Stato extends StatelessWidget {
  const _Stato({
    required this.icona,
    required this.titolo,
    required this.testo,
    required this.pulsante,
  });

  final IconData icona;
  final String titolo;
  final String testo;
  final Widget pulsante;

  @override
  Widget build(BuildContext context) => Pannello(
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
    raggio: 20,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colori.foschia,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icona, size: 22, color: Colori.grafite),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  titolo,
                  style: Testi.titoli(
                    18,
                    altezza: 1.25,
                  ).copyWith(color: Colori.inchiostro),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          testo,
          style: Testi.secondario.copyWith(fontSize: 15, color: Colori.ardesia),
        ),
        const SizedBox(height: 14),
        pulsante,
      ],
    ),
  );
}

/// Le righe dei tipi, ciascuna col suo interruttore di sistema (83). Ferme
/// finché il telefono non le lascia arrivare.
class _Tipi extends StatelessWidget {
  const _Tipi({
    required this.spente,
    required this.attive,
    required this.onCambia,
  });

  final Set<TipoNotifica> spente;
  final bool attive;
  final void Function(TipoNotifica tipo, bool accesa) onCambia;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: attive ? 1 : 0.45,
    duration: Ritmo.breve,
    child: Pannello(
      padding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
      raggio: 20,
      child: Column(
        children: [
          for (final (i, (tipo, nome, sotto)) in _righe.indexed)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: i == 0
                    ? null
                    : const Border(
                        top: BorderSide(color: Color(0xFFEEF0F4), width: 1.5),
                      ),
              ),
              child: MergeSemantics(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nome,
                            style: Testi.evidenza.copyWith(
                              color: Colori.inchiostro,
                            ),
                          ),
                          Text(
                            sotto,
                            style: Testi.didascalia.copyWith(
                              fontSize: 13,
                              color: Colori.grafite,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    AdaptiveSwitch(
                      value: attive && !spente.contains(tipo),
                      onChanged: attive ? (v) => onCambia(tipo, v) : null,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// «Vuoi un promemoria?» (tela, 82): che cosa arriverà, prima che il
/// telefono chieda il permesso. Chiudendo restituisce `true` per «Sì,
/// avvisami».
class FoglioPermessoNotifiche extends StatelessWidget {
  const FoglioPermessoNotifiche({super.key, this.citta});

  /// La città del viaggio che ha appena preso le date.
  final String? citta;

  @override
  Widget build(BuildContext context) {
    final campanella = icona(
      ios: CupertinoIcons.bell,
      android: Icons.notifications_none_rounded,
    );
    return Foglio(
      titolo: 'Vuoi un promemoria?',
      inBasso: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PulsanteGrande(
            etichetta: 'Sì, avvisami',
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 10),
          PulsanteGrande(
            etichetta: 'Non ora',
            secondario: true,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          const SizedBox(height: 10),
          Text(
            "Dopo «Sì» il telefono chiede il permesso. Le stesse cose restano "
            "comunque dentro l'app.",
            textAlign: TextAlign.center,
            style: Testi.didascalia.copyWith(color: Colori.grafite),
          ),
        ],
      ),
      children: [
        Text(
          citta == null
              ? 'Hai appena fissato le date del viaggio.'
              : 'Hai appena fissato le date di $citta.',
          style: Testi.secondario.copyWith(color: Colori.grafite),
        ),
        const SizedBox(height: 16),
        Spiegazione(
          fondo: Colori.foschia,
          righe: [
            (
              campanella,
              'Due giorni prima di partire, se manca qualcosa: documenti, '
                  'valigia.',
            ),
            (campanella, 'La sera, se restano tappe da segnare.'),
            (
              campanella,
              "Quando un'idea sta per finire in archivio, e un anno dopo un "
                  'viaggio.',
            ),
            (
              icona(ios: CupertinoIcons.moon, android: Icons.bedtime_outlined),
              'Niente pubblicità, niente di notte.',
            ),
          ],
        ),
      ],
    );
  }
}

/// Dopo che un viaggio ha preso le date, il momento in cui i promemoria
/// servono davvero (14, regola 5): il foglio si propone da solo se il
/// telefono non ha mai chiesto il permesso, e dopo un «Non ora» non prima di
/// un mese. Chiudere il foglio vale come «Non ora».
Future<void> proponiLeNotifiche(
  NavigatorState navigatore, {
  String? citta,
}) async {
  final contesto = navigatore.overlay?.context;
  if (contesto == null) return;
  final promemoria = Servizi.of(contesto).promemoria;
  if (!await promemoria.daProporre() || !contesto.mounted) return;
  final si = await apriFoglio<bool>(
    contesto,
    FoglioPermessoNotifiche(citta: citta),
  );
  if (si == true) {
    await promemoria.chiedi(da: 'viaggio');
  } else {
    await promemoria.nonOra();
  }
}

/// Dove porta una notifica toccata (14, regola 7): Prima di partire, la
/// giornata con le tappe da segnare, l'idea, il riepilogo. Sopra l'elenco
/// dei viaggi, come un invito.
void apriDaNotifica(NavigatorState navigatore, DovePorta dove) {
  final id = dove.viaggioId;
  final giorno = dove.giornoId;
  final Widget pagina = switch (dove.tipo) {
    TipoNotifica.primaDiPartire => SchermataPrimaDiPartire(viaggioId: id),
    TipoNotifica.tappeDaSegnare when giorno != null => SchermataGiornata(
      viaggioId: id,
      giornoId: giorno,
    ),
    TipoNotifica.unAnnoFa => SchermataRiepilogo(viaggioId: id),
    _ => SchermataViaggio(viaggioId: id),
  };
  navigatore
    ..popUntil((r) => r.isFirst)
    ..push(rotta<void>(pagina));
}
