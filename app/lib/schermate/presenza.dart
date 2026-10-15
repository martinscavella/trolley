/// «Chi c'è a Porto» (5.5; 11-community, regole 8–13; tela, 79–81, 117 e
/// 118): altri viaggiatori in città adesso, per conoscersi. Si accende per un
/// viaggio in corso, solo dopo che il telefono ha trovato la persona sul
/// posto (C1); prima lo dice, e senza il permesso di posizione anche.
/// Accesa, mostra chi altro l'ha accesa nella stessa città, in ordine di
/// nome, senza dire fino a quando resta (C2, C8); fino a quando si resta
/// visibili lo legge solo la persona.
///
/// Dipende dalla rete: chi c'è non resta sul telefono (C6), e si richiede
/// ogni tanto mentre la si guarda. Si misurano accenderla, con quanti altri
/// c'erano, e spegnerla (07: `presenza_attivata`, `presenza_spenta`): mai
/// la città, mai chi.
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
import '../dati/destinazioni.dart';
import '../dati/errori.dart';
import '../dati/lettura.dart';
import '../dati/posizione.dart';
import '../dominio/collegamenti.dart';
import '../dominio/itinerario.dart';
import '../dominio/presenza.dart';
import '../dominio/profilo_pubblico.dart';
import '../dominio/ricordo.dart';
import '../misurazione/misurazione.dart';
import '../servizi.dart';
import 'con_la_rete.dart';
import 'conversazione.dart';
import 'gesti_collegamenti.dart';
import 'permesso_posizione.dart';
import 'profilo_altrui.dart';

class SchermataPresenza extends StatefulWidget {
  const SchermataPresenza({
    super.key,
    required this.viaggioId,
    this.mieiGusti = const {},
    this.mieMete = const [],
  });

  final String viaggioId;

  /// Di chi guarda, per dire che cosa avete in comune.
  final Set<Interesse> mieiGusti;
  final List<Meta> mieMete;

  @override
  State<SchermataPresenza> createState() => _SchermataPresenzaState();
}

class _SchermataPresenzaState extends State<SchermataPresenza>
    with WidgetsBindingObserver {
  ChiCeInCitta? _chi;
  ErroreTrolley? _errore;
  PermessoPosizione? _permesso;
  bool _inCorso = false;
  bool _primaVolta = true;
  bool _guardato = false;
  bool _inPrimoPiano = true;
  Timer? _orologio;

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
      unawaited(_carica());
      unawaited(_leggiIlPermesso());
      _orologio = Timer.periodic(intervalloPresenza, (_) => _aggiorna());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _orologio?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState stato) {
    _inPrimoPiano = stato == AppLifecycleState.resumed;
    if (_inPrimoPiano) {
      // Tornando dalle Impostazioni il permesso può essere cambiato.
      unawaited(_leggiIlPermesso());
      _aggiorna();
    }
  }

  Future<void> _carica() async {
    if (!mounted) return;
    try {
      final chi = await Servizi.of(context).partePubblica.chiCeInCitta();
      if (mounted) {
        setState(() {
          _chi = chi;
          _errore = null;
        });
      }
    } on ErroreTrolley catch (e) {
      if (mounted) setState(() => _errore = e);
    }
  }

  Future<void> _leggiIlPermesso() async {
    if (!mounted) return;
    final permesso = await Servizi.of(context).posizione.permesso();
    if (mounted) setState(() => _permesso = permesso);
  }

  /// Ogni tanto, accesa, mentre la si guarda: chi arriva compare.
  void _aggiorna() {
    if (!mounted ||
        !_inPrimoPiano ||
        !(_chi?.accesaPer(widget.viaggioId) ?? false) ||
        !Servizi.of(context).rete.disponibile ||
        !(ModalRoute.of(context)?.isCurrent ?? false)) {
      return;
    }
    unawaited(_carica());
  }

  /// Prima del «sul posto», aprendo la schermata il telefono guarda dov'è
  /// (3.4): se la persona è a Porto, la presenza si può accendere subito.
  void _guardaIlPosto(Viaggio viaggio) {
    if (_guardato) return;
    _guardato = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await guardaIlPosto(context, viaggio: viaggio);
      await _leggiIlPermesso();
    });
  }

  Future<void> _accendi() async {
    final servizi = Servizi.of(context);
    setState(() => _inCorso = true);
    try {
      await servizi.partePubblica.accendiPresenza(widget.viaggioId);
      final chi = await servizi.partePubblica.chiCeInCitta();
      await servizi.misurazione.registra(Eventi.presenzaAttivata, {
        'presenti': chi.altri.length,
      });
      unawaited(servizi.misurazione.invia());
      if (!mounted) return;
      setState(() {
        _chi = chi;
        _inCorso = false;
      });
    } on ErroreTrolley catch (e) {
      if (!mounted) return;
      setState(() => _inCorso = false);
      mostraMessaggio(context, e.messaggio, errore: true);
    }
  }

  Future<void> _spegni() async {
    final servizi = Servizi.of(context);
    setState(() => _inCorso = true);
    try {
      await servizi.partePubblica.spegniPresenza();
      await servizi.misurazione.registra(Eventi.presenzaSpenta, {});
      unawaited(servizi.misurazione.invia());
      await _carica();
    } on ErroreTrolley catch (e) {
      if (mounted) mostraMessaggio(context, e.messaggio, errore: true);
    }
    if (mounted) setState(() => _inCorso = false);
  }

  Future<void> _apriProfilo(ProfiloPubblico p) async {
    await apri<bool>(
      context,
      SchermataProfiloAltrui(
        utenteId: p.id,
        nome: p.nome,
        mieiGusti: widget.mieiGusti,
        mieMete: widget.mieMete,
      ),
    );
    if (mounted) unawaited(_carica());
  }

  Future<void> _collegati(ProfiloPubblico p) async {
    final esito = await chiediDiCollegarvi(
      context,
      utenteId: p.id,
      nome: p.nome,
    );
    if (esito != null && mounted) unawaited(_carica());
  }

  Future<void> _scrivi(ProfiloPubblico p) async {
    await apri<bool>(
      context,
      SchermataConversazione(utenteId: p.id, nome: p.nome),
    );
    if (mounted) unawaited(_carica());
  }

  @override
  Widget build(BuildContext context) => Pagina(
    corpo: Builder(
      builder: (context) => StreamBuilder<List<(Partecipazione, Viaggio)>>(
        stream: Servizi.of(context).archivio.osservaMieiViaggi(),
        builder: (context, letti) {
          final padding = EdgeInsets.fromLTRB(
            20,
            MediaQuery.paddingOf(context).top,
            20,
            MediaQuery.paddingOf(context).bottom + 32,
          );
          final mio = letti.data
              ?.where((x) => x.$2.id == widget.viaggioId)
              .firstOrNull;
          if (mio == null) {
            return Center(
              child: letti.hasData
                  ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: Avviso(
                        icona: icona(
                          ios: CupertinoIcons.briefcase,
                          android: Icons.luggage_outlined,
                        ),
                        testo: 'Questo viaggio non è più sul telefono.',
                      ),
                    )
                  : const IndicatoreAttivita(),
            );
          }
          final (partecipazione, viaggio) = mio;
          final citta = viaggio.destinazioneCitta ?? '';
          final fine = viaggio.fine ?? DateTime.now();
          final sulPosto = partecipazione.sulPostoIl != null;
          if (!sulPosto) _guardaIlPosto(viaggio);
          return ListView(
            padding: padding,
            children: [
              ..._contenuto(citta: citta, fine: fine, sulPosto: sulPosto),
            ],
          );
        },
      ),
    ),
  );

  List<Widget> _contenuto({
    required String citta,
    required DateTime fine,
    required bool sulPosto,
  }) {
    final chi = _chi;
    final errore = _errore;
    if (chi == null && errore != null) {
      return [
        TitoloPagina('Chi c\'è a $citta'),
        Avviso(
          icona: icona(
            ios: CupertinoIcons.wifi_slash,
            android: Icons.wifi_off_rounded,
          ),
          errore: true,
          testo: errore.messaggio,
        ).entra(context),
        const SizedBox(height: 16),
        ConLaRete(
          builder: (context, rete) => PulsanteGrande(
            etichetta: 'Riprova',
            secondario: true,
            motivo: rete ? null : motivoSenzaRete,
            onPressed: () {
              setState(() => _errore = null);
              unawaited(_carica());
            },
          ),
        ),
      ];
    }
    if (chi == null || _permesso == null) {
      return [
        TitoloPagina('Chi c\'è a $citta'),
        const Padding(
          padding: EdgeInsets.only(top: 24),
          child: Center(child: IndicatoreAttivita()),
        ),
      ];
    }
    final oggi = DateTime.now();
    final stato = statoPresenza(
      accesaQui: chi.accesaPer(widget.viaggioId),
      sulPosto: sulPosto,
      posizioneNegata:
          _permesso == PermessoPosizione.negato ||
          _permesso == PermessoPosizione.spenta,
    );
    if (stato == StatoPresenza.accesa) {
      return _accesa(chi, citta: citta, fine: chi.mia?.fino ?? fine);
    }
    return [
      TitoloPagina(
        'Chi c\'è a $citta',
        sottotitolo:
            'Altri viaggiatori a $citta adesso, per conoscersi. La accendi '
            'tu, solo per questo viaggio.',
      ).entra(context),
      _Promesse(
        citta: citta,
        fine: fineInParole(fine, oggi),
      ).entra(context, ritardo: Ritmo.passo),
      const SizedBox(height: 14),
      ...switch (stato) {
        StatoPresenza.accendibile => [
          ConLaRete(
            builder: (context, rete) => _Interruttore(
              etichetta: 'Mostrami a $citta ${finoA(fine, oggi)}',
              onAccendi: rete && !_inCorso ? _accendi : null,
            ),
          ).entra(context, ritardo: Ritmo.passo * 2),
          _Didascalia(
            'Si accende perché il telefono ti ha trovato a $citta. Se cambi la '
            'meta o le date del viaggio, si spegne.',
          ),
          ConLaRete(
            builder: (context, rete) => _Didascalia(
              rete
                  ? 'Serve il profilo pubblico acceso. Spenta, da qui non si '
                        'vede nessuno.'
                  : motivoSenzaRete,
            ),
          ),
          // Accesa per un altro viaggio: accenderla qui spegne quella (C7).
          if (chi.mia case final altra?)
            _Didascalia(
              'Adesso sei visibile a ${altra.citta}: accendendola qui, lì '
              'si spegne.',
            ),
        ],
        StatoPresenza.senzaPosizione => [
          _QuandoSarai(
            senzaPosizione: true,
            citta: citta,
            onImpostazioni: () =>
                Servizi.of(context).posizione.apriImpostazioni(),
          ).entra(context, ritardo: Ritmo.passo * 2),
          const _Didascalia(
            'La posizione la guarda il telefono, solo mentre usi l\'app.',
          ),
        ],
        _ => [
          _QuandoSarai(
            senzaPosizione: false,
            citta: citta,
          ).entra(context, ritardo: Ritmo.passo * 2),
          const _Didascalia(
            'Il confronto lo fa il telefono, con la meta del viaggio. A noi '
            'arriva solo «sì», mai dove sei.',
          ),
        ],
      },
    ];
  }

  /// Accesa (tela, 80 e 81).
  List<Widget> _accesa(
    ChiCeInCitta chi, {
    required String citta,
    required DateTime fine,
  }) {
    final altri = chi.altri;
    return [
      TitoloPagina(
        'Chi c\'è a $citta',
        sottotitolo: altri.isEmpty ? null : oltreATe(altri.length),
      ).entra(context),
      ConLaRete(
        builder: (context, rete) => _Visibile(
          citta: citta,
          fine: fineInParole(fine, DateTime.now()),
          onSpegni: rete && !_inCorso ? _spegni : null,
        ),
      ).entra(context, ritardo: Ritmo.passo),
      const SizedBox(height: 14),
      if (altri.isEmpty)
        const _SoloTu().entra(context, ritardo: Ritmo.passo * 2)
      else ...[
        for (final (i, p) in altri.indexed) ...[
          _InCitta(
            profilo: p,
            sotto: _sotto(p),
            onTap: () => _apriProfilo(p),
            onCollegati: () => _collegati(p),
            onRispondi: () => _apriProfilo(p),
            onScrivi: () => _scrivi(p),
          ).entra(context, ritardo: Ritmo.passo * (i < 8 ? i + 2 : 10)),
          const SizedBox(height: 8),
        ],
        _Didascalia(
          'Solo chi ha acceso la presenza a $citta, in ordine di nome: '
          'nessuno sa chi è arrivato prima, né fino a quando resta.',
        ),
      ],
    ];
  }

  /// «14 paesi · Cibo in comune».
  String _sotto(ProfiloPubblico p) {
    final comune = inComune(
      mieMete: widget.mieMete,
      mieiGusti: widget.mieiGusti,
      altro: p,
    );
    final cosa = comune.gusti.isNotEmpty
        ? comune.gusti.first.nome
        : comune.paesi.isNotEmpty
        ? nomeDelPaese(comune.paesi.first) ?? comune.paesi.first
        : null;
    return [
      quanti(p.paesi.length, 'paese', 'paesi'),
      if (p.collegamento?.stato == StatoCollegamento.collegati)
        'già nei tuoi collegamenti'
      else if (cosa != null)
        '$cosa in comune',
    ].join(' · ');
  }
}

/// Le quattro promesse prima di accenderla (tela, 79, 117 e 118).
class _Promesse extends StatelessWidget {
  const _Promesse({required this.citta, required this.fine});

  final String citta;
  final String fine;

  @override
  Widget build(BuildContext context) {
    final righe = [
      'Vedi chi l\'ha accesa a $citta, e loro vedono te: chi guarda è anche '
          'visto.',
      'Solo la città. Mai dove sei, mai la distanza, nessun puntino su una '
          'mappa.',
      'Gli altri vedono «a $citta adesso», non fino a quando: la fine la vedi '
          'solo tu.',
      'Si spegne da sola ${fine == 'oggi' ? 'stasera' : fine}, alla fine del '
          'viaggio. Nessuno storico: nessuno può sapere dove eri ieri, nemmeno '
          'noi.',
    ];
    return Pannello(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
      raggio: 20,
      child: Column(
        children: [
          for (final (i, r) in righe.indexed)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: i == 0
                    ? null
                    : const Border(
                        top: BorderSide(color: Colori.foschia, width: 1.5),
                      ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(
                      icona(
                        ios: CupertinoIcons.checkmark_shield,
                        android: Icons.verified_user_outlined,
                      ),
                      size: 20,
                      color: Colori.cobalto,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      r,
                      style: Testi.secondario.copyWith(
                        fontSize: 15,
                        height: 1.4,
                        color: Colori.inchiostro,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// «Mostrami a Porto fino a domenica», con l'interruttore di sistema (79).
class _Interruttore extends StatelessWidget {
  const _Interruttore({required this.etichetta, required this.onAccendi});

  final String etichetta;
  final VoidCallback? onAccendi;

  @override
  Widget build(BuildContext context) => Pannello(
    padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
    raggio: 18,
    child: MergeSemantics(
      child: Row(
        children: [
          Expanded(
            child: Text(
              etichetta,
              style: Testi.evidenza.copyWith(color: Colori.inchiostro),
            ),
          ),
          const SizedBox(width: 12),
          AdaptiveSwitch(
            value: false,
            onChanged: onAccendi == null ? null : (_) => onAccendi!(),
          ),
        ],
      ),
    ),
  );
}

/// Prima del «sul posto» (117), o senza il permesso di posizione (118).
class _QuandoSarai extends StatelessWidget {
  const _QuandoSarai({
    required this.senzaPosizione,
    required this.citta,
    this.onImpostazioni,
  });

  final bool senzaPosizione;
  final String citta;
  final VoidCallback? onImpostazioni;

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
              child: Icon(
                senzaPosizione
                    ? icona(
                        ios: CupertinoIcons.location_slash,
                        android: Icons.location_off_outlined,
                      )
                    : icona(
                        ios: CupertinoIcons.location,
                        android: Icons.location_on_outlined,
                      ),
                size: 22,
                color: Colori.grafite,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  senzaPosizione
                      ? 'Senza la posizione non si accende'
                      : 'Quando sarai a $citta',
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
          senzaPosizione
              ? 'Il telefono non può dire che sei a $citta, e senza il «sì» '
                    'chi c\'è non si vede. Il resto di Trolley funziona lo '
                    'stesso.'
              : 'Si accende solo quando il telefono ti trova a $citta: così '
                    'chi guarda è davvero lì. Apri Trolley quando ci sei.',
          style: Testi.secondario.copyWith(fontSize: 15, color: Colori.ardesia),
        ),
        if (onImpostazioni != null) ...[
          const SizedBox(height: 14),
          PulsanteGrande(
            etichetta: 'Apri Impostazioni',
            secondario: true,
            onPressed: onImpostazioni,
          ),
        ],
      ],
    ),
  );
}

/// «Sei visibile a Porto fino a domenica 12», e Spegni adesso (80 e 81).
class _Visibile extends StatelessWidget {
  const _Visibile({
    required this.citta,
    required this.fine,
    required this.onSpegni,
  });

  final String citta;
  final String fine;
  final VoidCallback? onSpegni;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
    decoration: BoxDecoration(
      color: Colori.cobaltoChiaro,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            icona(ios: CupertinoIcons.person_2, android: Icons.group_outlined),
            size: 20,
            color: Colori.cobalto,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Sei visibile a $citta',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colori.inchiostro,
                      ),
                    ),
                    TextSpan(
                      text: fine == 'oggi'
                          ? ' fino a stasera. Gli altri non sanno fino a quando.'
                          : ' fino a $fine. Gli altri non sanno fino a quando.',
                    ),
                  ],
                ),
                style: Testi.secondario.copyWith(color: Colori.ardesia),
              ),
              const SizedBox(height: 10),
              _PulsanteRiga(
                etichetta: 'Spegni adesso',
                descrizione: 'Spegni la presenza a $citta',
                colore: Colori.pericolo,
                fondo: Colori.bianco,
                onPressed: onSpegni,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// «Per ora ci sei solo tu» (81): con pochi viaggiatori è il caso normale.
class _SoloTu extends StatelessWidget {
  const _SoloTu();

  @override
  Widget build(BuildContext context) => Pannello(
    padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
    raggio: 24,
    child: Column(
      children: [
        StreamBuilder<Utente?>(
          stream: Servizi.of(context).archivio.osservaProfilo(),
          builder: (context, io) =>
              Avatar(nome: io.data?.nome ?? '?', dimensione: 56),
        ),
        const SizedBox(height: 12),
        Text(
          'Per ora ci sei solo tu',
          textAlign: TextAlign.center,
          style: Testi.titoli(20).copyWith(color: Colori.inchiostro),
        ),
        const SizedBox(height: 8),
        Text(
          'Siamo ancora in pochi, capita spesso. Se arriva qualcuno, '
          'compare qui.',
          textAlign: TextAlign.center,
          style: Testi.secondario.copyWith(fontSize: 15, color: Colori.ardesia),
        ),
      ],
    ),
  );
}

/// Una persona in città (80): l'iniziale, il nome, i paesi e che cosa avete
/// in comune, e il gesto di quel momento.
class _InCitta extends StatelessWidget {
  const _InCitta({
    required this.profilo,
    required this.sotto,
    required this.onTap,
    required this.onCollegati,
    required this.onRispondi,
    required this.onScrivi,
  });

  final ProfiloPubblico profilo;
  final String sotto;
  final VoidCallback onTap;
  final VoidCallback onCollegati;
  final VoidCallback onRispondi;
  final VoidCallback onScrivi;

  @override
  Widget build(BuildContext context) {
    final p = profilo;
    final stato = p.collegamento?.stato;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colori.bianco,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Premibile(
              onTap: onTap,
              scala: 0.99,
              etichetta: '${p.nome}, $sotto. Apri il profilo',
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    Avatar(nome: p.nome, dimensione: 44),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.nome,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Testi.evidenza.copyWith(
                              color: Colori.inchiostro,
                            ),
                          ),
                          Text(
                            sotto,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Testi.didascalia.copyWith(
                              color: Colori.grafite,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          if (stato == StatoCollegamento.inviata)
            Text(
              'Richiesta inviata',
              style: Testi.didascalia.copyWith(
                color: Colori.grafite,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            ConLaRete(
              builder: (context, rete) => _PulsanteRiga(
                etichetta: switch (stato) {
                  StatoCollegamento.collegati => 'Scrivi',
                  StatoCollegamento.ricevuta => 'Rispondi',
                  _ => 'Collegati',
                },
                descrizione: switch (stato) {
                  StatoCollegamento.collegati => 'Scrivi a ${p.nome}',
                  StatoCollegamento.ricevuta =>
                    'Rispondi alla richiesta di ${p.nome}',
                  _ => 'Chiedi a ${p.nome} di collegarvi',
                },
                onPressed: !rete
                    ? null
                    : switch (stato) {
                        StatoCollegamento.collegati => onScrivi,
                        StatoCollegamento.ricevuta => onRispondi,
                        _ => onCollegati,
                      },
              ),
            ),
        ],
      ),
    );
  }
}

/// Un pulsante grigio alto 44 dentro una riga: «Collegati», «Scrivi»,
/// «Spegni adesso».
class _PulsanteRiga extends StatelessWidget {
  const _PulsanteRiga({
    required this.etichetta,
    required this.descrizione,
    required this.onPressed,
    this.colore = Colori.cobaltoScuro,
    this.fondo = Colori.foschia,
  });

  final String etichetta;
  final String descrizione;
  final VoidCallback? onPressed;
  final Color colore;
  final Color fondo;

  @override
  Widget build(BuildContext context) => Premibile(
    onTap: onPressed,
    scala: 0.95,
    etichetta: descrizione,
    child: AnimatedOpacity(
      duration: Ritmo.breve,
      opacity: onPressed == null ? 0.4 : 1,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          etichetta,
          style: Testi.secondario.copyWith(
            color: colore,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );
}

class _Didascalia extends StatelessWidget {
  const _Didascalia(this.testo);

  final String testo;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
    child: Text(
      testo,
      textAlign: TextAlign.center,
      style: Testi.didascalia.copyWith(color: Colori.grafite),
    ),
  );
}
