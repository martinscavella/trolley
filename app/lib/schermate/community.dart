/// «Viaggiatori» (5.3; 11-community; tela, 74, 108 e 110): si cercano altri
/// viaggiatori per meta e per cosa piace, mai per nome (11, regola 7). Chi
/// guarda si fa guardare: con il profilo pubblico spento non si vede nessuno,
/// e la schermata dice come accenderlo (11, regola 6).
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
import '../dati/destinazioni.dart';
import '../dati/errori.dart';
import '../dati/lettura.dart';
import '../dominio/itinerario.dart';
import '../dominio/parte_pubblica.dart';
import '../dominio/profilo_pubblico.dart';
import '../dominio/ricordo.dart';
import '../misurazione/misurazione.dart';
import '../servizi.dart';
import 'con_la_rete.dart';
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

class _SchermataCommunityState extends State<SchermataCommunity> {
  Future<_Io?>? _io;
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
  void dispose() {
    _attesa?.cancel();
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
    }
    return (stato: stato, gusti: gusti);
  }

  void _ricarica() => setState(() {
    _io = _leggi();
    _trovati = null;
    _errore = null;
    if (!_ricerca.vuota) _programma();
  });

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
    ProfiloPubblico p,
    _Io io,
    List<Meta> mieMete,
  ) async {
    final tolto = await apri<bool>(
      context,
      SchermataProfiloAltrui(
        utenteId: p.id,
        nome: p.nome,
        mieiGusti: io.gusti,
        mieMete: mieMete,
      ),
    );
    // Bloccato o segnalato con «Blocca anche»: non lo si vede più.
    if (tolto == true && mounted) {
      setState(
        () => _trovati = [...?_trovati]..removeWhere((x) => x.id == p.id),
      );
    }
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
                final io => _perCercare(io),
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
                    onTap: () => _apriProfilo(p, io, mieMete),
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
