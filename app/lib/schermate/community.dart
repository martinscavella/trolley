/// «Viaggiatori» (5.3; 11-community; tela, 74, 108 e 110): si cercano altri
/// viaggiatori per meta e per cosa piace, mai per nome (11, regola 7). Chi
/// guarda si fa guardare: con il profilo pubblico spento non si vede nessuno,
/// e la schermata dice come accenderlo (11, regola 6).
///
/// Con la 5.4 accanto a Cerca ci sono Collegamenti e Messaggi (tela, 77 e
/// 111), con il numero delle richieste ricevute e delle conversazioni da
/// leggere. Senza notifiche, si ricaricano ogni tanto mentre li si guarda.
/// Con la 5.5, durante un viaggio in corso, sotto la ricerca c'è «Chi c'è a
/// Porto» (tela, 74).
///
/// Dipende dalla rete: i profili degli altri si guardano com'erano adesso, e
/// non restano sul telefono. Si misura ogni ricerca (07,
/// `viaggiatori_cercati`): che criteri, mai quali, e quanti risultati.
library;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../aspetto/elementi.dart';
import '../aspetto/movimento.dart';
import '../aspetto/pagina.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../dati/database.dart';
import '../dati/destinazioni.dart';
import '../dati/errori.dart';
import '../dati/lettura.dart';
import '../dominio/collegamenti.dart';
import '../dominio/itinerario.dart';
import '../dominio/parte_pubblica.dart';
import '../dominio/profilo_pubblico.dart';
import '../dominio/ricordo.dart';
import '../misurazione/misurazione.dart';
import '../servizi.dart';
import 'collegamenti.dart';
import 'con_la_rete.dart';
import 'conversazione.dart';
import 'presenza.dart';
import 'profilo_altrui.dart';
import 'profilo_pubblico.dart';
import 'scelta_destinazione.dart';
import 'sezioni.dart';
import 'viaggiatori.dart';

class SchermataCommunity extends StatefulWidget {
  const SchermataCommunity({super.key});

  @override
  State<SchermataCommunity> createState() => _SchermataCommunityState();
}

/// Quello che serve per cercare: com'è la propria parte pubblica, e i
/// propri gusti, per dire che cosa si ha in comune. Le proprie mete le dice
/// la copia sul telefono, a parte.
typedef _Io = ({StatoPartePubblica stato, Set<Interesse> gusti});

/// Le tre schede in alto (tela, 74, 77 e 111).
enum _Scheda { cerca, collegamenti, messaggi }

class _SchermataCommunityState extends State<SchermataCommunity> {
  Future<_Io?>? _io;
  _Scheda _scheda = _Scheda.cerca;

  /// I collegamenti e le conversazioni (5.4): `null` finché non arrivano.
  Collegamenti? _collegamenti;
  List<RigaConversazione>? _conversazioni;
  ErroreTrolley? _erroreSociale;
  Timer? _orologio;

  /// Ogni quanto, guardando Collegamenti o Messaggi, si chiede se c'è
  /// qualcosa di nuovo: senza notifiche, arriva così.
  static const _ogni = Duration(seconds: 15);
  Ricerca _ricerca = const Ricerca();
  List<ProfiloPubblico>? _trovati;
  String? _errore;
  bool _cercando = false;
  Timer? _attesa;

  /// Quale ricerca è l'ultima: una risposta arrivata dopo un'altra domanda
  /// non vale più.
  int _giro = 0;

  /// Quanto si aspetta dall'ultimo tocco prima di cercare: scegliere tre
  /// gusti di fila è una ricerca, non tre.
  static const _pausa = Duration(milliseconds: 450);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _io ??= _leggi();
  }

  @override
  void initState() {
    super.initState();
    _orologio = Timer.periodic(_ogni, (_) => _aggiornaSociale());
  }

  @override
  void dispose() {
    _attesa?.cancel();
    _orologio?.cancel();
    super.dispose();
  }

  Future<_Io?> _leggi() async {
    final servizi = Servizi.of(context);
    final stato = await servizi.partePubblica.stato();
    if (stato == null) return null;
    var gusti = const <Interesse>{};
    if (stato.attivo) {
      final mio = await servizi.partePubblica.ilMioProfilo();
      gusti = {...?mio?.gusti};
      // I numeri sulle schede, senza far aspettare la ricerca.
      unawaited(_caricaSociale());
    }
    return (stato: stato, gusti: gusti);
  }

  void _ricarica() => setState(() {
    _io = _leggi();
    _trovati = null;
    _errore = null;
    if (!_ricerca.vuota) _programma();
  });

  /// I collegamenti e le conversazioni, dal server.
  Future<void> _caricaSociale() async {
    if (!mounted) return;
    final parte = Servizi.of(context).partePubblica;
    try {
      final collegamenti = await parte.collegamenti();
      final conversazioni = await parte.conversazioni();
      if (!mounted) return;
      setState(() {
        _collegamenti = collegamenti;
        _conversazioni = conversazioni;
        _erroreSociale = null;
      });
    } on ErroreTrolley catch (e) {
      if (mounted) setState(() => _erroreSociale = e);
    }
  }

  /// Di tanto in tanto, mentre si guardano Collegamenti o Messaggi e la
  /// schermata è davanti.
  void _aggiornaSociale() {
    if (!mounted ||
        _scheda == _Scheda.cerca ||
        _collegamenti == null ||
        !Servizi.of(context).rete.disponibile ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
        !(ModalRoute.of(context)?.isCurrent ?? false)) {
      return;
    }
    unawaited(_caricaSociale());
  }

  void _cambiaScheda(_Scheda scheda) {
    if (scheda == _scheda) return;
    setState(() => _scheda = scheda);
    if (scheda != _Scheda.cerca) unawaited(_caricaSociale());
  }

  void _cambia(Ricerca ricerca) {
    setState(() {
      _ricerca = ricerca;
      _errore = null;
      if (ricerca.vuota) _trovati = null;
    });
    _attesa?.cancel();
    if (!ricerca.vuota) _programma();
  }

  /// Sceglie o toglie un gusto dalla ricerca com'è adesso: due tocchi di
  /// fila valgono tutti e due.
  void _scegliGusto(Interesse g) {
    final scelti = _ricerca.gusti;
    _cambia(
      _ricerca.conGusti(
        scelti.contains(g) ? ({...scelti}..remove(g)) : {...scelti, g},
      ),
    );
  }

  void _programma() {
    _attesa?.cancel();
    _attesa = Timer(_pausa, _cerca);
  }

  Future<void> _cerca() async {
    final ricerca = _ricerca;
    if (ricerca.vuota || !mounted) return;
    final servizi = Servizi.of(context);
    final giro = ++_giro;
    setState(() => _cercando = true);
    try {
      final trovati = await servizi.partePubblica.cerca(ricerca);
      await servizi.misurazione.registra(Eventi.viaggiatoriCercati, {
        'criteri': ricerca.criteri,
        'risultati': trovati.length,
      });
      if (!mounted || giro != _giro) return;
      setState(() {
        _trovati = trovati;
        _cercando = false;
      });
    } on ErroreTrolley catch (e) {
      if (!mounted || giro != _giro) return;
      setState(() {
        _errore = e.messaggio;
        _cercando = false;
      });
    }
  }

  Future<void> _scegliMeta() async {
    final scelta = await apri<Destinazione>(
      context,
      const SchermataDestinazione(soloElenco: true),
      dalBasso: true,
    );
    if (scelta == null || scelta.paese == null || !mounted) return;
    _cambia(
      _ricerca.conMeta(
        paese: scelta.paese,
        citta: scelta.citta,
        nome: scelta.nome,
      ),
    );
  }

  Future<void> _apriProfilo(
    String utenteId,
    String nome,
    _Io io,
    List<Meta> mieMete,
  ) async {
    final tolto = await apri<bool>(
      context,
      SchermataProfiloAltrui(
        utenteId: utenteId,
        nome: nome,
        mieiGusti: io.gusti,
        mieMete: mieMete,
      ),
    );
    if (!mounted) return;
    // Bloccato o segnalato con «Blocca anche»: non lo si vede più.
    if (tolto == true) {
      setState(
        () => _trovati = [...?_trovati]..removeWhere((x) => x.id == utenteId),
      );
    }
    // Dal profilo si chiede, si risponde, si scrive.
    unawaited(_caricaSociale());
  }

  Future<void> _apriConversazione(String utenteId, String? nome) async {
    await apri<bool>(
      context,
      SchermataConversazione(utenteId: utenteId, nome: nome),
    );
    if (mounted) unawaited(_caricaSociale());
  }

  Future<void> _apriIlMioProfilo() async {
    await apri<void>(context, const SchermataProfiloPubblico());
    if (mounted) _ricarica();
  }

  @override
  Widget build(BuildContext context) => Pagina(
    inBasso: BarraDelleSezioni(
      prima: [voceViaggi(context), voceMappa(context)],
      attiva: SezioneDopo.community,
    ),
    corpo: Builder(
      builder: (context) => FutureBuilder<_Io?>(
        future: _io,
        builder: (context, letto) {
          final padding = EdgeInsets.fromLTRB(
            20,
            MediaQuery.paddingOf(context).top,
            20,
            MediaQuery.paddingOf(context).bottom + 120,
          );
          if (letto.connectionState != ConnectionState.done) {
            return const Center(child: IndicatoreAttivita());
          }
          final dati = letto.data;
          return ListView(
            padding: padding,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              const TitoloPagina('Viaggiatori'),
              ...switch (dati) {
                null when letto.hasError => _senzaLettura(letto.error),
                null => _nonCe(),
                final io when io.stato.sospesoIl != null => _sospeso(),
                final io when !io.stato.visibile || !io.stato.maggiorenne =>
                  _nonCe(),
                final io when !io.stato.attivo => _spento(io.stato),
                final io => [
                  _Schede(
                    scelta: _scheda,
                    richieste: _collegamenti?.ricevute.length ?? 0,
                    daLeggere: conversazioniDaLeggere(
                      _conversazioni ?? const [],
                    ),
                    onScegli: _cambiaScheda,
                  ),
                  const SizedBox(height: 12),
                  ...switch (_scheda) {
                    _Scheda.cerca => _perCercare(io),
                    _Scheda.collegamenti => _deiCollegamenti(io),
                    _Scheda.messaggi => _deiMessaggi(),
                  },
                ],
              },
            ],
          );
        },
      ),
    ),
  );

  // ─── Senza poter cercare ─────────────────────────────────────────────────

  List<Widget> _senzaLettura(Object? errore) => [
    Avviso(
      icona: icona(
        ios: CupertinoIcons.wifi_slash,
        android: Icons.wifi_off_rounded,
      ),
      errore: true,
      testo: errore is ErroreTrolley
          ? errore.messaggio
          : 'La parte pubblica si guarda con la connessione.',
    ).entra(context),
    const SizedBox(height: 16),
    ConLaRete(
      builder: (context, rete) => PulsanteGrande(
        etichetta: 'Riprova',
        secondario: true,
        motivo: rete ? null : motivoSenzaRete,
        onPressed: _ricarica,
      ),
    ),
  ];

  List<Widget> _nonCe() => [
    Avviso(
      icona: icona(ios: CupertinoIcons.clock, android: Icons.schedule_rounded),
      testo:
          'Per ora la parte pubblica non c\'è. Il resto di Trolley è tutto '
          'tuo.',
    ).entra(context),
  ];

  List<Widget> _sospeso() => [
    Avviso(
      icona: icona(ios: CupertinoIcons.nosign, android: Icons.block),
      errore: true,
      testo:
          'Il tuo profilo pubblico è sospeso: non vedi gli altri, e gli '
          'altri non vedono te.',
    ).entra(context),
    const SizedBox(height: 16),
    PulsanteGrande(
      etichetta: 'Il tuo profilo pubblico',
      secondario: true,
      onPressed: _apriIlMioProfilo,
    ),
  ];

  /// Il profilo è spento (tela, 108): per vedere gli altri ci si fa vedere.
  List<Widget> _spento(StatoPartePubblica stato) => [
    Pannello(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      raggio: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colori.cobaltoChiaro,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                icona(
                  ios: CupertinoIcons.person_2,
                  android: Icons.group_outlined,
                ),
                size: 30,
                color: Colori.cobalto,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Semantics(
            header: true,
            child: Text(
              'Per vedere gli altri, fatti vedere',
              style: Testi.titoli(
                21,
                altezza: 1.25,
              ).copyWith(color: Colori.inchiostro),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Qui trovi altri viaggiatori per le mete che avete visto e per '
            'cosa vi piace. Chi guarda ha il profilo pubblico acceso: lo '
            'vedono anche gli altri.',
            style: Testi.secondario.copyWith(
              fontSize: 15,
              color: Colori.ardesia,
            ),
          ),
          const SizedBox(height: 18),
          ConLaRete(
            builder: (context, rete) => PulsanteGrande(
              etichetta: stato.accoglie
                  ? 'Accendi il profilo pubblico'
                  : 'Il tuo profilo pubblico',
              icona: icona(
                ios: CupertinoIcons.person_2,
                android: Icons.group_outlined,
              ),
              motivo: rete ? null : motivoSenzaRete,
              onPressed: _apriIlMioProfilo,
            ),
          ),
        ],
      ),
    ).entra(context),
    const SizedBox(height: 14),
    Text(
      stato.accoglie
          ? 'Sul profilo vanno solo i viaggi chiusi che scegli tu. Lo spegni '
                'quando vuoi.'
          : 'Per ora la parte pubblica non accoglie profili nuovi: riprova '
                'tra qualche giorno.',
      textAlign: TextAlign.center,
      style: Testi.didascalia.copyWith(color: Colori.grafite),
    ),
  ];

  // ─── Cercare ─────────────────────────────────────────────────────────────

  List<Widget> _perCercare(_Io io) {
    final ricerca = _ricerca;
    final trovati = _trovati;
    return [
      ConLaRete(
        builder: (context, rete) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CampoMeta(
              nome: ricerca.nomeMeta,
              onTap: rete ? _scegliMeta : null,
              onTogli: ricerca.paese == null
                  ? null
                  : () => _cambia(ricerca.conMeta()),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final g in gusti)
                  Gettone(
                    etichetta: g.nome,
                    scelto: ricerca.gusti.contains(g),
                    onTap: rete ? () => _scegliGusto(g) : null,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              rete
                  ? 'Si cerca per meta e per cosa piace, mai per nome.'
                  : motivoSenzaRete,
              style: Testi.didascalia.copyWith(color: Colori.grafite),
            ),
          ],
        ),
      ).entra(context),
      // Un viaggio in corso con una città, dalla copia sul telefono: la
      // presenza in città (5.5).
      StreamBuilder<List<(Partecipazione, Viaggio)>>(
        stream: Servizi.of(context).archivio.osservaMieiViaggi(),
        builder: (context, letti) {
          final miei = letti.data ?? const [];
          final adesso = DateTime.now();
          final perChi = perLaPresenza(miei, adesso);
          if (perChi == null) return const SizedBox.shrink();
          final viaggio = perChi.$2;
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _ChiCeInCitta(
              citta: viaggio.destinazioneCitta ?? '',
              onTap: () => apri<void>(
                context,
                SchermataPresenza(
                  viaggioId: viaggio.id,
                  mieiGusti: io.gusti,
                  mieMete: meteDi(delPassaporto(miei, adesso)),
                ),
              ),
            ),
          );
        },
      ),
      const SizedBox(height: 14),
      if (ricerca.vuota)
        Avviso(
          icona: icona(ios: CupertinoIcons.search, android: Icons.search),
          testo:
              'Scegli una meta o cosa ti piace: trovi chi c\'è stato, o '
              'chi viaggia come te.',
        ).entra(context, ritardo: Ritmo.passo)
      else if (_errore case final errore?)
        Avviso(
          icona: icona(
            ios: CupertinoIcons.exclamationmark_circle,
            android: Icons.error_outline,
          ),
          errore: true,
          testo: errore,
        )
      else if (trovati == null)
        const Padding(
          padding: EdgeInsets.only(top: 24),
          child: Center(child: IndicatoreAttivita()),
        )
      else if (trovati.isEmpty)
        _Nessuno(
          conCitta: ricerca.citta != null,
          conGusti: ricerca.gusti.isNotEmpty,
        ).entra(context)
      else
        // Le proprie mete dalla copia sul telefono: servono solo a dire che
        // cosa si ha in comune, e non fanno aspettare i risultati.
        StreamBuilder<List<Meta>>(
          stream: Servizi.of(context).archivio
              .osservaMieiViaggi()
              .map((miei) => meteDi(delPassaporto(miei, DateTime.now()))),
          builder: (context, mete) {
            final mieMete = mete.data ?? const <Meta>[];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EtichettaSezione(
                  trovati.length == 1
                      ? '1 viaggiatore'
                      : '${trovati.length} viaggiatori',
                ),
                for (final (i, p) in trovati.indexed) ...[
                  RigaViaggiatore(
                    nome: p.nome,
                    sotto: _perche(p, ricerca),
                    inComune: quantiInComune(
                      inComune(mieMete: mieMete, mieiGusti: io.gusti, altro: p),
                    ),
                    onTap: () => _apriProfilo(p.id, p.nome, io, mieMete),
                  ).entra(context, ritardo: Ritmo.passo * (i < 8 ? i : 8)),
                  const SizedBox(height: 8),
                ],
              ],
            );
          },
        ),
      if (_cercando && trovati != null)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Center(child: IndicatoreAttivita()),
        ),
    ];
  }

  // ─── Collegamenti e messaggi ─────────────────────────────────────────────

  /// Finché non arrivano: l'attesa, o perché non sono arrivati.
  List<Widget>? _inAttesa() {
    final errore = _erroreSociale;
    if (_collegamenti != null && _conversazioni != null) return null;
    if (errore == null) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 24),
          child: Center(child: IndicatoreAttivita()),
        ),
      ];
    }
    return [
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
            setState(() => _erroreSociale = null);
            unawaited(_caricaSociale());
          },
        ),
      ),
    ];
  }

  /// «Collegamenti» (tela, 77).
  List<Widget> _deiCollegamenti(_Io io) =>
      _inAttesa() ??
      [
        // Le proprie mete, come per la ricerca: per dire che cosa si ha in
        // comune con chi chiede.
        StreamBuilder<List<Meta>>(
          stream: Servizi.of(context).archivio
              .osservaMieiViaggi()
              .map((miei) => meteDi(delPassaporto(miei, DateTime.now()))),
          builder: (context, mete) {
            final mieMete = mete.data ?? const <Meta>[];
            return ElencoCollegamenti(
              collegamenti: _collegamenti!,
              mieMete: mieMete,
              mieiGusti: io.gusti,
              onCambiato: () => unawaited(_caricaSociale()),
              onProfilo: (id, nome) => _apriProfilo(id, nome, io, mieMete),
              onConversazione: _apriConversazione,
            );
          },
        ),
      ];

  /// «Messaggi» (tela, 111).
  List<Widget> _deiMessaggi() =>
      _inAttesa() ??
      [ElencoConversazioni(righe: _conversazioni!, onApri: _apriConversazione)];

  /// «Kyoto nel passaporto · ama il cibo», «Tokyo nel passaporto · 14 paesi».
  static String _perche(ProfiloPubblico p, Ricerca ricerca) {
    final viaggio = ricerca.viaggioNellaMeta(p);
    final gusto = ricerca.gustiTrovati(p).firstOrNull;
    final paesi = p.paesi.length;
    return [
      if (viaggio != null) '${metaPubblica(viaggio)} nel passaporto',
      if (gusto != null)
        'ama ${gustoConArticolo(gusto)}'
      else
        paesi == 1 ? '1 paese' : '$paesi paesi',
    ].join(' · ');
  }
}

/// Cerca, Collegamenti, Messaggi (tela, 74, 77 e 111): con il numero delle
/// richieste ricevute e delle conversazioni da leggere, quando ce ne sono.
class _Schede extends StatelessWidget {
  const _Schede({
    required this.scelta,
    required this.richieste,
    required this.daLeggere,
    required this.onScegli,
  });

  final _Scheda scelta;
  final int richieste;
  final int daLeggere;
  final ValueChanged<_Scheda> onScegli;

  @override
  Widget build(BuildContext context) {
    Widget scheda(_Scheda s, String nome, int quanti, String descrizione) {
      final attiva = s == scelta;
      final etichetta = quanti > 0 ? '$nome · $quanti' : nome;
      return Expanded(
        child: Semantics(
          selected: attiva,
          child: Premibile(
            onTap: () => onScegli(s),
            scala: 0.96,
            etichetta: quanti > 0 ? '$nome, $quanti $descrizione' : nome,
            child: AnimatedContainer(
              duration: Ritmo.breve,
              height: 40,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: attiva ? Colori.inchiostro : Colori.bianco,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ExcludeSemantics(
                child: Text(
                  etichetta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Testi.secondario.copyWith(
                    color: attiva ? Colori.bianco : Colori.ardesia,
                    fontWeight: attiva ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colori.bianco,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          scheda(_Scheda.cerca, 'Cerca', 0, ''),
          const SizedBox(width: 4),
          scheda(
            _Scheda.collegamenti,
            'Collegamenti',
            richieste,
            richieste == 1 ? 'richiesta ricevuta' : 'richieste ricevute',
          ),
          const SizedBox(width: 4),
          scheda(
            _Scheda.messaggi,
            'Messaggi',
            daLeggere,
            daLeggere == 1
                ? 'conversazione da leggere'
                : 'conversazioni da leggere',
          ),
        ],
      ),
    );
  }
}

/// «Chi c'è a Porto» (tela, 74): il viaggio è in corso, e si può guardare
/// chi altro c'è.
class _ChiCeInCitta extends StatelessWidget {
  const _ChiCeInCitta({required this.citta, required this.onTap});

  final String citta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Premibile(
    onTap: onTap,
    scala: 0.98,
    etichetta:
        'Chi c\'è a $citta. Il tuo viaggio è in corso: guarda chi altro è qui',
    child: ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
        decoration: BoxDecoration(
          color: Colori.cobaltoChiaro,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(
              icona(
                ios: CupertinoIcons.person_2,
                android: Icons.group_outlined,
              ),
              size: 24,
              color: Colori.cobalto,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chi c\'è a $citta',
                    style: Testi.evidenza.copyWith(color: Colori.inchiostro),
                  ),
                  Text(
                    'Il tuo viaggio è in corso: guarda chi altro è qui',
                    style: Testi.didascalia.copyWith(color: Colori.grafite),
                  ),
                ],
              ),
            ),
            Icon(
              icona(
                ios: CupertinoIcons.chevron_forward,
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

/// La meta della ricerca (tela, 74): vuota dice che cosa ci va; scelta ha il
/// bordo cobalto e la «x» per toglierla.
class _CampoMeta extends StatelessWidget {
  const _CampoMeta({required this.nome, required this.onTap, this.onTogli});

  final String? nome;
  final VoidCallback? onTap;
  final VoidCallback? onTogli;

  @override
  Widget build(BuildContext context) {
    final nome = this.nome;
    return Premibile(
      onTap: onTap,
      etichetta: nome == null ? 'Scegli una meta' : 'Meta: $nome. Cambiala',
      child: Container(
        height: 52,
        padding: EdgeInsets.only(left: 16, right: nome == null ? 16 : 6),
        decoration: BoxDecoration(
          color: Colori.bianco,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: nome == null ? Colori.bianco : Colori.cobalto,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icona(ios: CupertinoIcons.search, android: Icons.search),
              size: 20,
              color: Colori.grafite,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ExcludeSemantics(
                child: Text(
                  nome ?? 'Una meta: un paese o una città',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: nome == null
                      ? Testi.corpo.copyWith(color: Colori.grafite)
                      : Testi.evidenza.copyWith(color: Colori.inchiostro),
                ),
              ),
            ),
            if (nome != null && onTogli != null)
              PulsanteTondo(
                icona: icona(ios: CupertinoIcons.xmark, android: Icons.close),
                etichetta: 'Togli la meta',
                fondo: Colori.foschia,
                onPressed: onTogli,
              ),
          ],
        ),
      ),
    );
  }
}

/// Per ora nessuno (tela, 110): con pochi viaggiatori è il caso normale, e la
/// schermata non deve sembrare rotta (11, casi limite).
class _Nessuno extends StatelessWidget {
  const _Nessuno({required this.conCitta, required this.conGusti});

  final bool conCitta;
  final bool conGusti;

  @override
  Widget build(BuildContext context) {
    final consigli = [
      if (conCitta) 'prova il paese invece della città',
      if (conGusti) 'togli un gusto',
    ];
    return Pannello(
      padding: const EdgeInsets.all(22),
      raggio: 22,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colori.foschia,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icona(ios: CupertinoIcons.search, android: Icons.search),
              size: 24,
              color: Colori.grafite,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Per ora nessuno',
            style: Testi.titoli(18).copyWith(color: Colori.inchiostro),
          ),
          const SizedBox(height: 6),
          Text(
            consigli.isEmpty
                ? 'Siamo ancora in pochi, capita spesso.'
                : 'Siamo ancora in pochi, capita spesso. '
                      '${consigli.first[0].toUpperCase()}${consigli.join(', o ').substring(1)}.',
            textAlign: TextAlign.center,
            style: Testi.secondario.copyWith(color: Colori.ardesia),
          ),
        ],
      ),
    );
  }
}
