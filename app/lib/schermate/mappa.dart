import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../aspetto/barra.dart';
import '../aspetto/elementi.dart';
import '../aspetto/formati.dart';
import '../aspetto/movimento.dart';
import '../aspetto/pagina.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/segni_mappa.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../dati/archivio.dart';
import '../dati/database.dart';
import '../dati/lettura.dart';
import '../dati/mappe.dart';
import '../dati/posizione.dart';
import '../dominio/adesso.dart';
import '../dominio/calendario.dart';
import '../dominio/mappa.dart';
import '../dominio/stato_viaggio.dart';
import '../dominio/tappe.dart';
import '../misurazione/misurazione.dart';
import '../servizi.dart';
import 'con_la_rete.dart';
import 'gesti_mappa.dart';
import 'gesti_tappa.dart';
import 'impostazioni.dart';
import 'nuovo_viaggio.dart';
import 'permesso_posizione.dart';
import 'tappa.dart';

/// La mappa del viaggio (08-mappa.md; tela, 50–55): le tappe di un giorno
/// nell'ordine del programma, numerate come nella giornata, o quelle di
/// tutto il viaggio con un colore per giorno. Da qui si va a una tappa
/// («Portami») e la si segna in un tocco (09, regola 10).
///
/// La mappa ha bisogno della rete e del fornitore (ADR-006). Senza, restano
/// gli indirizzi delle tappe, da aprire nelle Mappe del telefono (regola 6).
/// La posizione della persona si vede solo mentre il viaggio è in corso, e
/// solo con il suo permesso (regola 3).
class SchermataMappa extends StatefulWidget {
  const SchermataMappa({
    super.key,
    required this.viaggioId,
    this.giornoId,
    this.orologio = DateTime.now,
  });

  final String viaggioId;

  /// Il giorno da mostrare; se manca, oggi o il più vicino.
  final String? giornoId;

  /// Che ora è: le prove la fissano.
  final DateTime Function() orologio;

  @override
  State<SchermataMappa> createState() => _SchermataMappaState();
}

LatLng _ll(Coordinate c) => LatLng(c.lat, c.lon);

/// Il fondo della carta mentre arrivano i riquadri, come nella tela.
const _fondoCarta = Color(0xFFE7EAF0);

class _SchermataMappaState extends State<SchermataMappa> {
  late Servizi _servizi;

  /// Il viaggio mostrato: si cambia dalla scelta in alto (tela, 57 e 58).
  late String _viaggioId = widget.viaggioId;
  late Stream<Viaggio?> _viaggio;
  late Stream<List<Giorno>> _giorni;
  late Stream<List<Tappa>> _tappe;

  /// Quanto si era chiesto al fornitore quando la mappa si è aperta.
  late ConsumoMappe _prima;
  bool _avviata = false;

  final _controllo = MapController();
  bool _pronta = false;

  /// Che cosa si sta inquadrando: quando cambia, si rifà l'inquadratura.
  String? _inquadrata;

  String? _giornoId;
  bool _tutto = false;
  bool _elenco = false;

  /// La tappa toccata: la sua scheda è aperta (tela, 53).
  String? _scelta;

  Coordinate? _qui;
  StreamSubscription<Coordinate>? _seguo;
  bool _posizioneAvviata = false;

  ({Coordinate centro, bool dalleTappe})? _centro;
  bool _centroCercato = false;
  bool _usoContato = false;

  @override
  void initState() {
    super.initState();
    _giornoId = widget.giornoId;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_avviata) return;
    _avviata = true;
    _servizi = Servizi.of(context);
    final archivio = _servizi.archivio;
    unawaited(segnaAperturaSenzaRete(context, 'mappa'));
    _viaggiDellaMappa = archivio.osservaViaggiInElenco();
    _conti = archivio.osservaTappeDeiViaggi();
    _mostra(_viaggioId);
  }

  late Stream<List<ViaggioInElenco>> _viaggiDellaMappa;
  late Stream<Map<String, ({int tappe, int conPosto})>> _conti;

  /// Mostra [viaggioId]: le sue tappe, dal suo giorno, inquadrate da capo.
  /// Quello che è costato il viaggio di prima si registra per quello (07).
  void _mostra(String viaggioId) {
    final archivio = _servizi.archivio;
    _viaggioId = viaggioId;
    _prima = _servizi.mappe.consumo;
    _viaggio = archivio.osservaViaggio(viaggioId);
    _giorni = archivio.osservaGiorni(viaggioId);
    _tappe = archivio.osservaTappe(viaggioId);
    _giornoId = viaggioId == widget.viaggioId ? widget.giornoId : null;
    _tutto = false;
    _scelta = null;
    _centro = null;
    _centroCercato = false;
    _inquadrata = null;
    _usoContato = false;
    // La mappa si rifà: è pronta quando lo dice lei.
    _pronta = false;
  }

  Future<void> _cambiaViaggio(String viaggioId) async {
    if (viaggioId == _viaggioId) return;
    unawaited(
      registraConsumo(
        _servizi.misurazione,
        _servizi.mappe,
        viaggioId: _viaggioId,
        prima: _prima,
      ),
    );
    setState(() => _mostra(viaggioId));
  }

  Future<void> _scegliViaggio() async {
    final scelto = await apriFoglio<String>(
      context,
      _FoglioViaggi(
        viaggi: _viaggiDellaMappa,
        conti: _conti,
        scelto: _viaggioId,
      ),
    );
    if (scelto != null && mounted) await _cambiaViaggio(scelto);
  }

  @override
  void dispose() {
    unawaited(_seguo?.cancel());
    _controllo.dispose();
    unawaited(
      registraConsumo(
        _servizi.misurazione,
        _servizi.mappe,
        viaggioId: _viaggioId,
        prima: _prima,
      ),
    );
    super.dispose();
  }

  /// Il puntino della persona, mentre il viaggio è in corso. La prima volta
  /// si dice a cosa serve la posizione, e poi la chiede iOS; dopo un no la
  /// mappa va avanti senza (08, casi limite).
  Future<void> _avviaPosizione(Viaggio viaggio) async {
    _posizioneAvviata = true;
    final posizione = _servizi.posizione;
    // Prima di chiederla si dice a cosa serve (tela, 58), e serve anche a
    // verificare il viaggio: già che c'è, guarda se si è sul posto.
    final permesso = await chiediLaPosizione(
      context,
      viaggio: viaggio,
      daSolo: true,
      orologio: widget.orologio,
    );
    if (!mounted || permesso != PermessoPosizione.concesso) return;
    unawaited(
      guardaIlPosto(
        context,
        viaggio: viaggio,
        chiedi: false,
        orologio: widget.orologio,
      ),
    );
    _seguo = posizione.segui().listen((p) {
      if (mounted) setState(() => _qui = p);
    }, onError: (Object _) {});
  }

  Future<void> _cercaCentro(Viaggio viaggio, List<Tappa> tappe) async {
    _centroCercato = true;
    final centro = await centroDelViaggio(viaggio, tappe);
    if (mounted) setState(() => _centro = centro);
  }

  /// Inquadra [punti]: tutti dentro, sopra la scheda in basso.
  void _inquadra(String chiave, List<Coordinate> punti) {
    if (!_pronta || chiave == _inquadrata) return;
    final mq = MediaQuery.of(context);
    final margini = EdgeInsets.fromLTRB(
      56,
      mq.padding.top + 8 + _InAlto.altezza + 60,
      56,
      mq.padding.bottom + 290,
    );
    if (punti.length >= 2) {
      _controllo.fitCamera(
        CameraFit.coordinates(
          coordinates: [for (final p in punti) _ll(p)],
          padding: margini,
          maxZoom: 16,
        ),
      );
    } else if (punti.length == 1) {
      _controllo.move(_ll(punti.single), 15.5);
    } else if (_centro != null) {
      _controllo.move(_ll(_centro!.centro), 13);
    } else {
      return;
    }
    _inquadrata = chiave;
  }

  // Un viaggio nuovo è una mappa nuova: niente dati di due viaggi insieme,
  // nemmeno per un attimo.
  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: ValueKey(_viaggioId), child: _costruisci(context));

  Widget _costruisci(BuildContext context) => StreamBuilder<Viaggio?>(
    stream: _viaggio,
    builder: (context, viaggio) => StreamBuilder<List<Giorno>>(
      stream: _giorni,
      builder: (context, giorni) => StreamBuilder<List<Tappa>>(
        stream: _tappe,
        builder: (context, tappe) {
          final (v, g, t) = (viaggio.data, giorni.data, tappe.data);
          if (v == null || g == null || t == null) {
            return const Pagina(corpo: Center(child: IndicatoreAttivita()));
          }
          return ConLaRete(builder: (context, rete) => _pagina(v, g, t, rete));
        },
      ),
    ),
  );

  Widget _pagina(
    Viaggio viaggio,
    List<Giorno> giorni,
    List<Tappa> tappe,
    bool rete,
  ) {
    final adesso = widget.orologio();
    final stato = viaggio.statoA(adesso);
    if (stato == StatoViaggio.inCorso && !_posizioneAvviata) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_posizioneAvviata) {
          unawaited(_avviaPosizione(viaggio));
        }
      });
    }
    if (!_centroCercato) unawaited(_cercaCentro(viaggio, tappe));

    final giorno =
        giorni.where((g) => g.id == _giornoId).firstOrNull ??
        giornoDellaMappa(
          giorni: giorni,
          dataDi: (g) => g.finestra.data,
          oggi: adesso,
        );
    final oggi =
        giorno != null &&
        stato == StatoViaggio.inCorso &&
        giorno.finestra.data == soloData(adesso);
    final vista = _Vista(
      viaggio: viaggio,
      stato: stato,
      giorni: giorni,
      giorno: giorno,
      oggi: oggi,
      tutto: _tutto,
      tappe: tappe,
      adesso: adesso,
    );

    if (!rete || !_servizi.mappe.disponibili) {
      return _comeElenco(vista, rete: rete, senzaMappa: true);
    }
    if (_elenco) return _comeElenco(vista, rete: true, senzaMappa: false);
    return _conLaMappa(vista);
  }

  // ─── La mappa ────────────────────────────────────────────────────────────

  Widget _conLaMappa(_Vista vista) {
    final mq = MediaQuery.of(context);
    final punti = vista.punti;
    final chiave =
        '${vista.tutto}|${vista.giorno?.id}|${punti.length}|'
        '${_centro != null}';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _inquadra(chiave, punti);
    });
    if (punti.isNotEmpty && !_usoContato) {
      _usoContato = true;
      // La mappa vista con delle tappe sopra è la funzione usata (07, H1).
      unawaited(
        _servizi.misurazione.registraUnaVolta(
          'funzione:mappa:${vista.viaggio.id}',
          Eventi.funzioneUsataNelViaggio,
          {'viaggio_id': vista.viaggio.id, 'funzione': 'mappa'},
        ),
      );
    }

    final scelta = vista.sullaMappa
        .where((s) => s.tappa.tappa.id == _scelta)
        .firstOrNull;
    final prossima = vista.oggi && !vista.tutto
        ? vista.delGiorno
              .where((s) => s.segno == SegnoTappa.prossima)
              .firstOrNull
        : null;
    final iniziale = _centro?.centro;

    final mappa = FlutterMap(
      mapController: _controllo,
      options: MapOptions(
        backgroundColor: _fondoCarta,
        initialCenter: _ll(
          punti.firstOrNull ?? iniziale ?? (lat: 41.9, lon: 12.5),
        ),
        initialZoom: switch (punti.length) {
          0 => iniziale != null ? 13 : 4,
          1 => 15.5,
          _ => 13,
        },
        initialCameraFit: punti.length >= 2
            ? CameraFit.coordinates(
                coordinates: [for (final p in punti) _ll(p)],
                padding: EdgeInsets.fromLTRB(
                  56,
                  mq.padding.top + 8 + _InAlto.altezza + 60,
                  56,
                  mq.padding.bottom + 290,
                ),
                maxZoom: 16,
              )
            : null,
        minZoom: 3,
        maxZoom: 19,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onMapReady: () {
          _pronta = true;
          // La mappa nasce già inquadrata: un salto nell'istante in cui è
          // pronta lasciava i riquadri nuovi fuori dal disegno, grigi finché
          // non la si muoveva.
          if (punti.isNotEmpty || iniziale != null) _inquadrata = chiave;
          _inquadra(chiave, punti);
        },
        onTap: (_, _) {
          if (_scelta != null) setState(() => _scelta = null);
        },
      ),
      children: [
        _servizi.mappe.riquadri(context, viaggioId: _viaggioId),
        if (!vista.tutto)
          PolylineLayer(
            polylines: [
              for (final t in trattiDellaGiornata(vista.delGiorno))
                Polyline(
                  points: [_ll(t.da), _ll(t.a)],
                  color: t.percorso ? Colori.verde : Colori.cobalto,
                  strokeWidth: 5,
                ),
            ],
          ),
        MarkerLayer(
          markers: [
            for (final s in vista.sullaMappa)
              if (s.tappa.posto case final posto?)
                Marker(
                  key: ValueKey('segno-${s.tappa.tappa.id}'),
                  point: _ll(posto),
                  width: latoSegno,
                  height: latoSegno,
                  child: SegnoSullaMappa(
                    numero: s.tappa.numero,
                    segno: s.tappa.segno,
                    colore: vista.tutto ? coloreGiorno(s.indiceGiorno) : null,
                    scelto: s.tappa.tappa.id == _scelta,
                    etichetta: _etichetta(vista, s),
                    onTap: () => setState(() => _scelta = s.tappa.tappa.id),
                  ),
                ),
            // La posizione solo mentre il viaggio è in corso (08, regola 3).
            if (_qui case final qui? when vista.stato == StatoViaggio.inCorso)
              Marker(
                point: _ll(qui),
                width: PuntinoPosizione.lato,
                height: PuntinoPosizione.lato,
                child: const PuntinoPosizione(),
              ),
          ],
        ),
      ],
    );

    final inBasso = mq.padding.bottom > 0 ? mq.padding.bottom - 6 : 20.0;
    return Scaffold(
      backgroundColor: _fondoCarta,
      body: Stack(
        children: [
          Positioned.fill(child: mappa),
          Positioned(
            top: mq.padding.top + 8,
            left: 20,
            right: 20,
            child: _InAlto(
              vista: vista,
              onViaggio: _scegliViaggio,
              onVista: (tutto) => _cambiaVista(vista, tutto),
              onElenco: () => setState(() {
                _elenco = true;
                _scelta = null;
              }),
            ),
          ),
          Positioned(
            top: mq.padding.top + 8 + _InAlto.altezza + 10,
            left: 20,
            right: 20,
            child: Row(
              children: [
                if (!vista.tutto && vista.giorno != null)
                  Flexible(
                    child: _CapsulaGiorno(
                      testo: _quandoIlGiorno(vista),
                      onTap: () => _scegliGiorno(vista),
                    ),
                  ),
              ],
            ),
          ),
          if (scelta == null) ...[
            Positioned(
              left: 20,
              right: 20,
              bottom: inBasso + 64 + 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Attribuzione(_servizi.mappe.attribuzione),
                  const SizedBox(height: 8),
                  AnimatedSwitcher(
                    duration: movimentoRidotto(context)
                        ? Duration.zero
                        : Ritmo.medio,
                    child: _schedaInBasso(vista, prossima),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: inBasso,
              child: _barra(vista),
            ),
          ] else
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _SchedaTappa(
                key: ValueKey(scelta.tappa.tappa.id),
                vista: vista,
                sulla: scelta,
                onChiudi: () => setState(() => _scelta = null),
                onSegna: (stato) => _segna(vista, scelta.tappa.tappa, stato),
                onPortami: () => _portami(vista, scelta.tappa),
                onApri: () => _apriTappa(vista, scelta.tappa.tappa),
              ),
            ),
        ],
      ),
    );
  }

  Widget _schedaInBasso(_Vista vista, TappaSullaMappa<Tappa>? prossima) {
    if (vista.tutto) {
      return _Legenda(
        key: const ValueKey('legenda'),
        vista: vista,
        onGiorno: (g) => setState(() {
          _tutto = false;
          _giornoId = g.id;
        }),
      );
    }
    if (prossima != null) {
      return _SchedaProssima(
        key: ValueKey('prossima-${prossima.tappa.id}'),
        sulla: prossima,
        dettaglio: _dettaglio(vista, prossima.tappa, prossima: true),
        segnabili: tappeSegnabili(vista.stato),
        onApri: () => setState(() => _scelta = prossima.tappa.id),
        onPortami: () => _portami(vista, prossima),
        onSegna: (stato) => _segna(vista, prossima.tappa, stato),
      );
    }
    final testo = _avvisoDelGiorno(vista);
    if (testo == null) return const SizedBox.shrink(key: ValueKey('niente'));
    return _Scheda(
      key: ValueKey(testo),
      child: Text(
        testo,
        style: Testi.secondario.copyWith(color: Colori.ardesia),
      ),
    );
  }

  /// Cosa dire in basso quando non c'è una prossima da mostrare.
  String? _avvisoDelGiorno(_Vista vista) {
    if (vista.giorno == null) {
      return 'Le tappe arrivano quando il viaggio ha le date.';
    }
    if (vista.delGiorno.isEmpty) return 'Nessuna tappa in questo giorno.';
    final senza = vista.senzaPosto;
    if (senza == vista.delGiorno.length) {
      return senza == 1
          ? 'La tappa di questo giorno non ha un posto sulla mappa: '
                'cercalo in «Dove?», nella tappa.'
          : 'Le tappe di questo giorno non hanno un posto sulla mappa: '
                'cercalo in «Dove?», nella tappa.';
    }
    if (senza > 0) return _senzaPostoInParole(senza);
    if (vista.oggi &&
        vista.delGiorno.every((s) => s.segno != SegnoTappa.prossima)) {
      return 'Per oggi è tutto: le tappe sono segnate.';
    }
    return null;
  }

  Widget _barra(_Vista vista) => BarraPrincipale(
    prima: [
      VoceBarra(
        icona: icona(
          ios: CupertinoIcons.briefcase,
          android: Icons.luggage_outlined,
        ),
        etichetta: 'Viaggi',
        onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
      ),
      VoceBarra(
        icona: icona(ios: CupertinoIcons.globe, android: Icons.public_rounded),
        etichetta: 'Mappa',
        attiva: true,
        onTap: () => setState(() {
          _inquadrata = null;
          _scelta = null;
        }),
      ),
    ],
    dopo: [
      VoceBarra(
        icona: icona(ios: CupertinoIcons.person, android: Icons.person_outline),
        etichetta: 'Profilo',
        onTap: () => apri<void>(context, const SchermataImpostazioni()),
      ),
    ],
    etichettaAggiungi: 'Nuovo viaggio',
    onAggiungi: () =>
        apri<void>(context, const SchermataNuovoViaggio(), dalBasso: true),
  );

  // ─── Senza la mappa: gli indirizzi ───────────────────────────────────────

  /// L'elenco delle tappe con i loro indirizzi: quando la mappa non c'è
  /// (tela, 55) o quando lo si chiede.
  Widget _comeElenco(
    _Vista vista, {
    required bool rete,
    required bool senzaMappa,
  }) {
    final mq = MediaQuery.of(context);
    final gruppi = [
      for (final (i, g) in vista.giorni.indexed)
        if (vista.tutto ? true : g.id == vista.giorno?.id)
          (
            indice: i,
            giorno: g,
            tappe: [
              for (final s in vista.sullaMappa)
                if (s.giorno.id == g.id) s.tappa,
            ],
          ),
    ];
    return Pagina(
      sinistra: Navigator.of(context).canPop() ? null : const SizedBox.shrink(),
      azioni: [
        if (!senzaMappa)
          PulsanteTondo(
            icona: icona(ios: CupertinoIcons.map, android: Icons.map_outlined),
            etichetta: 'Mostra la mappa',
            onPressed: () => setState(() {
              _elenco = false;
              _inquadrata = null;
            }),
          )
        else if (!rete)
          const SeiOffline(),
      ],
      inBasso: _barra(vista),
      corpo: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          mq.padding.top,
          20,
          BarraPrincipale.ingombro + mq.padding.bottom,
        ),
        children: [
          const TitoloPagina('Mappa'),
          if (senzaMappa) ...[
            _MappaAssente(rete: rete),
            const SizedBox(height: 12),
          ],
          _SceltaViaggio(
            viaggio: vista.viaggio,
            stato: vista.stato,
            onTap: _scegliViaggio,
            ombra: false,
          ),
          const SizedBox(height: 10),
          _SceltaVista(
            vista: vista,
            onVista: (tutto) => _cambiaVista(vista, tutto),
            ombra: false,
          ),
          for (final gruppo in gruppi) ...[
            _Etichetta(_titoloGruppo(vista, gruppo.giorno)),
            if (gruppo.tappe.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Text(
                  'Nessuna tappa.',
                  style: Testi.secondario.copyWith(color: Colori.grafite),
                ),
              ),
            for (final t in gruppo.tappe)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _RigaIndirizzo(
                  sulla: t,
                  colore: vista.tutto ? coloreGiorno(gruppo.indice) : null,
                  onMappe: _consegnabile(t.tappa)
                      ? () => _alleMappe(t.tappa)
                      : null,
                  onApri: () => _apriTappa(vista, t.tappa),
                ),
              ),
          ],
          if (vista.giorno == null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                'Le tappe arrivano quando il viaggio ha le date.',
                style: Testi.secondario.copyWith(color: Colori.grafite),
              ),
            ),
        ],
      ),
    );
  }

  bool _consegnabile(Tappa t) =>
      t.posto != null || (t.luogoNome?.trim().isNotEmpty ?? false);

  Future<void> _alleMappe(Tappa t) async {
    final aperte = await _servizi.mappeDelTelefono.portami(
      nome: t.titolo,
      posto: t.posto,
      indirizzo: t.luogoNome,
    );
    if (!aperte && mounted) {
      mostraMessaggio(context, 'Le Mappe non si sono aperte.', errore: true);
    }
  }

  // ─── I gesti ─────────────────────────────────────────────────────────────

  void _cambiaVista(_Vista vista, bool tutto) {
    // Già sul giorno: un altro tocco sceglie quale.
    if (!tutto && !_tutto) {
      unawaited(_scegliGiorno(vista));
      return;
    }
    setState(() {
      _tutto = tutto;
      _scelta = null;
    });
  }

  Future<void> _scegliGiorno(_Vista vista) => scegliAzione(context, [
    for (final g in vista.giorni)
      AzioneMenu(
        '${nomeDelGiorno(g.finestra.data)} · '
        '${quanti(vista.tappe.where((t) => t.giornoId == g.id).length, 'tappa', 'tappe')}',
        () => setState(() {
          _giornoId = g.id;
          _scelta = null;
        }),
      ),
  ]);

  Future<void> _segna(_Vista vista, Tappa tappa, StatoTappa stato) async {
    setState(() => _scelta = null);
    await segnaLaTappa(
      context,
      viaggio: vista.viaggio,
      tappa: tappa,
      stato: stato,
    );
  }

  Future<void> _portami(_Vista vista, TappaSullaMappa<Tappa> sulla) =>
      portamiAllaTappa(
        context,
        viaggio: vista.viaggio,
        tappa: sulla.tappa,
        numero: sulla.numero,
      );

  Future<void> _apriTappa(_Vista vista, Tappa tappa) => apri<void>(
    context,
    SchermataTappa(
      viaggio: vista.viaggio,
      giorni: vista.giorni,
      tappe: vista.tappe,
      giornoId: tappa.giornoId,
      tappa: tappa,
    ),
    dalBasso: true,
  );

  // ─── Le parole ───────────────────────────────────────────────────────────

  String _quandoIlGiorno(_Vista vista) {
    final d = vista.giorno!.finestra.data;
    return [
      '${giornoCorto(d)} ${meseBreve(d)}',
      quanti(vista.delGiorno.length, 'tappa', 'tappe'),
      if (vista.senzaPosto > 0) '${vista.senzaPosto} senza posto',
    ].join(' · ');
  }

  String _titoloGruppo(_Vista vista, Giorno g) {
    final d = g.finestra.data;
    final nome = '${giornoCorto(d)} ${meseBreve(d)}';
    final oggi =
        vista.stato == StatoViaggio.inCorso && d == soloData(vista.adesso);
    return oggi ? 'Oggi · $nome' : nome;
  }

  /// «Prossima · 10:30 · Visita · 1 h», o senza «Prossima».
  String _dettaglio(_Vista vista, Tappa t, {bool prossima = false}) {
    final orario = vista.orari[t.id];
    final tipo = t.tipoTappa;
    return [
      if (prossima) 'Prossima',
      if (orario != null) ora(orario.inizio),
      if (tipo != null) nomeTipo(tipo),
      durataBreve(t.durata),
    ].join(' · ');
  }

  String _etichetta(_Vista vista, _Sulla s) {
    final t = s.tappa;
    final come = switch (t.segno) {
      SegnoTappa.fatta => 'fatta',
      SegnoTappa.saltata => 'saltata',
      SegnoTappa.prossima => 'la prossima',
      SegnoTappa.daFare => 'da fare',
    };
    return [
      '${t.numero}',
      t.tappa.titolo,
      if (vista.tutto) giornoBreve(s.giorno.finestra.data),
      come,
    ].join(', ');
  }
}

String _senzaPostoInParole(int senza) => senza == 1
    ? 'Una tappa non ha un posto riconoscibile: sta nell\'itinerario, non qui.'
    : '$senza tappe non hanno un posto riconoscibile: stanno '
          'nell\'itinerario, non qui.';

/// Una tappa sulla mappa con il suo giorno.
typedef _Sulla = ({
  TappaSullaMappa<Tappa> tappa,
  Giorno giorno,
  int indiceGiorno,
});

/// Quello che la mappa mostra adesso, calcolato una volta per disegno.
class _Vista {
  _Vista({
    required this.viaggio,
    required this.stato,
    required this.giorni,
    required this.giorno,
    required this.oggi,
    required this.tutto,
    required this.tappe,
    required this.adesso,
  });

  final Viaggio viaggio;
  final StatoViaggio stato;
  final List<Giorno> giorni;
  final Giorno? giorno;

  /// Il giorno mostrato è oggi, e il viaggio è in corso: c'è la prossima.
  final bool oggi;

  /// «Tutto il viaggio» invece del giorno.
  final bool tutto;
  final List<Tappa> tappe;
  final DateTime adesso;

  /// Le tappe di ogni giorno sulla mappa, nell'ordine dei giorni.
  late final List<_Sulla> _tutte = [
    for (final (i, g) in giorni.indexed)
      for (final s in tappeSullaMappa(
        tappe: [
          for (final t in tappe)
            if (t.giornoId == g.id) t,
        ],
        statoDi: (t) => t.statoTappa,
        postoDi: (t) => t.posto,
        conProssima: oggi && g.id == giorno?.id,
      ))
        (tappa: s, giorno: g, indiceGiorno: i),
  ];

  /// Quelle mostrate: del giorno, o di tutto il viaggio.
  late final List<_Sulla> sullaMappa = tutto
      ? _tutte
      : [
          for (final s in _tutte)
            if (s.giorno.id == giorno?.id) s,
        ];

  late final List<TappaSullaMappa<Tappa>> delGiorno = [
    for (final s in _tutte)
      if (s.giorno.id == giorno?.id) s.tappa,
  ];

  late final List<Coordinate> punti = [
    for (final s in sullaMappa) ?s.tappa.posto,
  ];

  late final int senzaPosto = sullaMappa
      .where((s) => s.tappa.posto == null)
      .length;

  /// L'orario di ogni tappa del giorno mostrato, come in «Adesso».
  late final Map<String, Orario> orari = () {
    final g = giorno;
    if (g == null) return const <String, Orario>{};
    final delG = [for (final s in delGiorno) s.tappa];
    final o = orariDellaGiornata(
      inizioGiornata: g.finestra.inizio,
      tappe: [for (final t in delG) (ora: t.ora, durata: t.durata)],
    );
    return {for (final (i, t) in delG.indexed) t.id: o[i]};
  }();
}

// ─── I pezzi ───────────────────────────────────────────────────────────────

/// In alto sulla mappa: indietro, il giorno o tutto il viaggio, l'elenco.
class _InAlto extends StatelessWidget {
  const _InAlto({
    required this.vista,
    required this.onViaggio,
    required this.onVista,
    required this.onElenco,
  });

  final _Vista vista;
  final VoidCallback onViaggio;
  final ValueChanged<bool> onVista;
  final VoidCallback onElenco;

  /// Quanto è alta: la scelta del viaggio e quella della vista.
  static const altezza = 52.0 + 10 + 48;

  @override
  Widget build(BuildContext context) {
    final indietro = Navigator.of(context).canPop();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (indietro) ...[
              const PulsanteIndietro(),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: _SceltaViaggio(
                viaggio: vista.viaggio,
                stato: vista.stato,
                onTap: onViaggio,
              ),
            ),
            const SizedBox(width: 8),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [_ombra],
              ),
              child: PulsanteTondo(
                icona: icona(
                  ios: CupertinoIcons.list_bullet,
                  android: Icons.format_list_bulleted_rounded,
                ),
                etichetta: 'Elenco',
                onPressed: onElenco,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _SceltaVista(vista: vista, onVista: onVista),
      ],
    );
  }
}

/// Quale viaggio si sta guardando, e il tocco per cambiarlo (tela, 57): il
/// codice del biglietto, la meta, le date e lo stato.
class _SceltaViaggio extends StatelessWidget {
  const _SceltaViaggio({
    required this.viaggio,
    required this.stato,
    required this.onTap,
    this.ombra = true,
  });

  final Viaggio viaggio;
  final StatoViaggio stato;
  final VoidCallback onTap;
  final bool ombra;

  @override
  Widget build(BuildContext context) {
    final (inizio, fine) = (viaggio.inizio, viaggio.fine);
    final sotto = [
      if (inizio != null && fine != null) intervalloBreve(inizio, fine),
      descrizioneStato(stato).toLowerCase(),
    ].join(' · ');
    return Premibile(
      onTap: onTap,
      scala: 0.98,
      etichetta: 'Viaggio: ${titoloViaggio(viaggio)}, $sotto. Cambia viaggio',
      child: ExcludeSemantics(
        child: Container(
          height: 52,
          padding: const EdgeInsets.only(left: 8, right: 10),
          decoration: BoxDecoration(
            color: Colori.bianco,
            borderRadius: BorderRadius.circular(16),
            boxShadow: ombra ? [_ombra] : null,
          ),
          child: Row(
            children: [
              CodiceViaggio(viaggio: viaggio, stato: stato),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titoloViaggio(viaggio),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Testi.evidenza.copyWith(
                        color: Colori.inchiostro,
                        fontSize: 15,
                        height: 1.2,
                      ),
                    ),
                    Text(
                      sotto,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Testi.didascalia.copyWith(
                        color: Colori.grafite,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.expand_more_rounded,
                size: 20,
                color: Colori.ardesia,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Il codice di tre lettere di un viaggio, come un piccolo biglietto:
/// cobalto se è in corso o in programma, d'inchiostro se è concluso.
class CodiceViaggio extends StatelessWidget {
  const CodiceViaggio({super.key, required this.viaggio, required this.stato});

  final Viaggio viaggio;
  final StatoViaggio stato;

  @override
  Widget build(BuildContext context) => Container(
    height: 30,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: switch (stato) {
        StatoViaggio.idea => Colori.sole,
        StatoViaggio.chiuso || StatoViaggio.archiviato => Colori.inchiostro,
        _ => Colori.cobalto,
      },
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      codiceViaggio(viaggio),
      style: Testi.codice(13).copyWith(
        color: stato == StatoViaggio.idea ? Colori.senape : Colori.bianco,
        height: 1,
      ),
    ),
  );
}

/// «Quale viaggio?» (tela, 58): quelli in corso, in programma e conclusi,
/// con quante tappe hanno e quante sono sulla mappa.
class _FoglioViaggi extends StatelessWidget {
  const _FoglioViaggi({
    required this.viaggi,
    required this.conti,
    required this.scelto,
  });

  final Stream<List<ViaggioInElenco>> viaggi;
  final Stream<Map<String, ({int tappe, int conPosto})>> conti;
  final String scelto;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<ViaggioInElenco>>(
    stream: viaggi,
    builder: (context, elenco) =>
        StreamBuilder<Map<String, ({int tappe, int conPosto})>>(
          stream: conti,
          builder: (context, quante) {
            final oggi = DateTime.now();
            final (:inCorso, :inProgramma, :conclusi) = viaggiDellaMappa(
              viaggi: [
                for (final v in elenco.data ?? const <ViaggioInElenco>[])
                  v.viaggio,
              ],
              statoDi: (v) => v.statoA(oggi),
              inizioDi: (v) => v.inizio,
            );
            Widget riga(Viaggio v) {
              final c = quante.data?[v.id];
              final (inizio, fine) = (v.inizio, v.fine);
              final sotto = [
                if (inizio != null && fine != null)
                  intervalloBreve(inizio, fine),
                c == null || c.tappe == 0
                    ? 'nessuna tappa'
                    : c.conPosto == c.tappe
                    ? quanti(c.tappe, 'tappa', 'tappe')
                    : '${quanti(c.tappe, 'tappa', 'tappe')}, '
                          '${c.conPosto} sulla mappa',
              ].join(' · ');
              final eQuesto = v.id == scelto;
              return Semantics(
                selected: eQuesto,
                child: Premibile(
                  onTap: () => Navigator.of(context).pop(v.id),
                  scala: 0.98,
                  etichetta: '${titoloViaggio(v)}, $sotto',
                  child: ExcludeSemantics(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Color(0xFFEEF0F4),
                            width: 1.5,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          CodiceViaggio(viaggio: v, stato: v.statoA(oggi)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  titoloViaggio(v),
                                  style: Testi.evidenza.copyWith(
                                    color: Colori.inchiostro,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  sotto,
                                  style: Testi.didascalia.copyWith(
                                    color: Colori.grafite,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (eQuesto)
                            Container(
                              width: 28,
                              height: 28,
                              decoration: const BoxDecoration(
                                color: Colori.cobalto,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                size: 16,
                                color: Colori.bianco,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            Widget sezione(String titolo) => Padding(
              padding: const EdgeInsets.fromLTRB(0, 14, 0, 2),
              child: Text(
                titolo.toUpperCase(),
                style: Testi.sezione.copyWith(color: Colori.grafite),
              ),
            );

            return Foglio(
              titolo: 'Quale viaggio?',
              children: [
                if (inCorso.isNotEmpty) ...[
                  sezione('In corso'),
                  for (final v in inCorso) riga(v),
                ],
                if (inProgramma.isNotEmpty) ...[
                  sezione('In programma'),
                  for (final v in inProgramma) riga(v),
                ],
                if (conclusi.isNotEmpty) ...[
                  sezione('Conclusi'),
                  for (final v in conclusi) riga(v),
                ],
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    'Le idee non hanno ancora tappe da mettere sulla mappa.',
                    style: Testi.didascalia.copyWith(color: Colori.grafite),
                  ),
                ),
              ],
            );
          },
        ),
  );
}

final _ombra = BoxShadow(
  color: Colori.inchiostro.withValues(alpha: 0.15),
  blurRadius: 16,
  offset: const Offset(0, 6),
);

/// «Oggi» (o il giorno mostrato) e «Tutto il viaggio».
class _SceltaVista extends StatelessWidget {
  const _SceltaVista({
    required this.vista,
    required this.onVista,
    this.ombra = true,
  });

  final _Vista vista;
  final ValueChanged<bool> onVista;
  final bool ombra;

  @override
  Widget build(BuildContext context) {
    final g = vista.giorno;
    final primo = vista.oggi
        ? 'Oggi'
        : g == null
        ? 'Giorno'
        : giornoCorto(g.finestra.data);
    Widget voce(String nome, bool tutto) {
      final scelta = vista.tutto == tutto;
      return Expanded(
        child: Semantics(
          selected: scelta,
          child: Premibile(
            onTap: () => onVista(tutto),
            scala: 0.96,
            etichetta: nome,
            child: AnimatedContainer(
              duration: Ritmo.breve,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scelta ? Colori.inchiostro : Colori.bianco,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                nome,
                maxLines: 1,
                style: Testi.secondario.copyWith(
                  color: scelta ? Colori.bianco : Colori.ardesia,
                  fontWeight: scelta ? FontWeight.w700 : FontWeight.w600,
                  height: 1,
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
        boxShadow: ombra ? [_ombra] : null,
      ),
      child: Row(
        children: [
          voce(primo, false),
          const SizedBox(width: 4),
          voce('Tutto il viaggio', true),
        ],
      ),
    );
  }
}

/// «Sab 11 ott · 4 tappe»: si tocca per cambiare giorno.
class _CapsulaGiorno extends StatelessWidget {
  const _CapsulaGiorno({required this.testo, required this.onTap});

  final String testo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Premibile(
    onTap: onTap,
    scala: 0.96,
    etichetta: '$testo. Cambia giorno',
    child: ExcludeSemantics(
      child: Container(
        height: 32,
        padding: const EdgeInsets.only(left: 12, right: 8),
        decoration: BoxDecoration(
          color: Colori.bianco,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [_ombra],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                testo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Testi.didascalia.copyWith(
                  color: Colori.ardesia,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.expand_more_rounded,
              size: 18,
              color: Colori.ardesia,
            ),
          ],
        ),
      ),
    ),
  );
}

/// Una scheda bianca che galleggia sulla mappa.
class _Scheda extends StatelessWidget {
  const _Scheda({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colori.bianco,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: Colori.inchiostro.withValues(alpha: 0.18),
          blurRadius: 30,
          offset: const Offset(0, 12),
        ),
      ],
    ),
    child: child,
  );
}

/// I tre gesti di una tappa: portami, fatta, salta (tela, 50 e 53).
class _Gesti extends StatelessWidget {
  const _Gesti({
    required this.segno,
    required this.segnabili,
    required this.onPortami,
    required this.onSegna,
  });

  final SegnoTappa segno;
  final bool segnabili;
  final VoidCallback? onPortami;
  final ValueChanged<StatoTappa> onSegna;

  @override
  Widget build(BuildContext context) {
    final segnata = segno == SegnoTappa.fatta || segno == SegnoTappa.saltata;
    return Row(
      children: [
        Expanded(
          flex: 14,
          child: _Pulsante(
            etichetta: 'Portami',
            icona: Icons.navigation_rounded,
            fondo: Colori.cobalto,
            testo: Colori.bianco,
            onTap: onPortami,
          ),
        ),
        if (segnabili && !segnata) ...[
          const SizedBox(width: 8),
          Expanded(
            flex: 10,
            child: _Pulsante(
              etichetta: 'Fatta',
              fondo: const Color(0xFFE3F0EA),
              testo: Colori.verde,
              onTap: () => onSegna(StatoTappa.completata),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 10,
            child: _Pulsante(
              etichetta: 'Salta',
              fondo: Colori.bianco,
              testo: Colori.inchiostro,
              bordo: true,
              onTap: () => onSegna(StatoTappa.saltata),
            ),
          ),
        ] else if (segnabili) ...[
          const SizedBox(width: 8),
          Expanded(
            flex: 20,
            child: _Pulsante(
              etichetta: 'Riportala da fare',
              fondo: Colori.bianco,
              testo: Colori.inchiostro,
              bordo: true,
              onTap: () => onSegna(StatoTappa.daFare),
            ),
          ),
        ],
      ],
    );
  }
}

class _Pulsante extends StatelessWidget {
  const _Pulsante({
    required this.etichetta,
    required this.fondo,
    required this.testo,
    required this.onTap,
    this.icona,
    this.bordo = false,
  });

  final String etichetta;
  final Color fondo;
  final Color testo;
  final VoidCallback? onTap;
  final IconData? icona;
  final bool bordo;

  @override
  Widget build(BuildContext context) => Semantics(
    enabled: onTap != null,
    child: Premibile(
      onTap: onTap,
      scala: 0.95,
      etichetta: etichetta,
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fondo,
            borderRadius: BorderRadius.circular(14),
            border: bordo ? Border.all(color: Colori.cenere, width: 2) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icona != null) ...[
                Icon(icona, size: 18, color: testo),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  etichetta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Testi.evidenza.copyWith(color: testo, height: 1),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// La prossima tappa, in basso (tela, 50).
class _SchedaProssima extends StatelessWidget {
  const _SchedaProssima({
    super.key,
    required this.sulla,
    required this.dettaglio,
    required this.segnabili,
    required this.onApri,
    required this.onPortami,
    required this.onSegna,
  });

  final TappaSullaMappa<Tappa> sulla;
  final String dettaglio;
  final bool segnabili;
  final VoidCallback onApri;
  final VoidCallback onPortami;
  final ValueChanged<StatoTappa> onSegna;

  @override
  Widget build(BuildContext context) {
    final t = sulla.tappa;
    return _Scheda(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Premibile(
            onTap: onApri,
            scala: 0.98,
            etichetta: '${t.titolo}, $dettaglio',
            child: ExcludeSemantics(
              child: Row(
                children: [
                  NumeroTappa(numero: sulla.numero, segno: sulla.segno),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.titolo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Testi.evidenza.copyWith(
                            color: Colori.inchiostro,
                          ),
                        ),
                        Text(
                          dettaglio,
                          maxLines: 1,
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
          const SizedBox(height: 14),
          _Gesti(
            segno: sulla.segno,
            segnabili: segnabili,
            onPortami: _portabile(t) ? onPortami : null,
            onSegna: onSegna,
          ),
        ],
      ),
    );
  }
}

bool _portabile(Tappa t) =>
    t.posto != null || (t.luogoNome?.trim().isNotEmpty ?? false);

/// Una tappa toccata sulla mappa (tela, 53): quando, quanto, che cosa,
/// dove; portami, fatta, salta; e la tappa intera.
class _SchedaTappa extends StatelessWidget {
  const _SchedaTappa({
    super.key,
    required this.vista,
    required this.sulla,
    required this.onChiudi,
    required this.onSegna,
    required this.onPortami,
    required this.onApri,
  });

  final _Vista vista;
  final _Sulla sulla;
  final VoidCallback onChiudi;
  final ValueChanged<StatoTappa> onSegna;
  final VoidCallback onPortami;
  final VoidCallback onApri;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final s = sulla.tappa;
    final t = s.tappa;
    final tipo = t.tipoTappa;
    final orario = t.ora;
    Widget casella(String nome, String valore) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colori.foschia,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(nome, style: Testi.sezione.copyWith(color: Colori.grafite)),
            const SizedBox(height: 4),
            Text(
              valore,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Testi.titoli(
                15,
                spaziatura: 0,
                altezza: 1.2,
                peso: 600,
              ).copyWith(color: Colori.inchiostro),
            ),
          ],
        ),
      ),
    );
    final dove = t.luogoNome?.trim();
    return GestureDetector(
      onVerticalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) > 200) onChiudi();
      },
      child: Container(
        padding: EdgeInsets.fromLTRB(24, 12, 24, mq.padding.bottom + 24),
        decoration: BoxDecoration(
          color: Colori.bianco,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colori.inchiostro.withValues(alpha: 0.15),
              blurRadius: 30,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Semantics(
                button: true,
                label: 'Chiudi',
                child: GestureDetector(
                  onTap: onChiudi,
                  child: Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colori.cenere,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                NumeroTappa(numero: s.numero, segno: s.segno),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      t.titolo,
                      style: Testi.titoli(
                        22,
                        altezza: 1.2,
                      ).copyWith(color: Colori.inchiostro),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                casella('ORA', orario == null ? '—' : ora(orario)),
                const SizedBox(width: 10),
                casella('DURATA', durataBreve(t.durata)),
                const SizedBox(width: 10),
                casella('TIPO', tipo == null ? '—' : nomeTipo(tipo)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.place_outlined,
                    size: 16,
                    color: Colori.grafite,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    [
                      if (vista.tutto)
                        nomeDelGiorno(sulla.giorno.finestra.data),
                      if (dove != null && dove.isNotEmpty) dove,
                      if (s.posto == null) 'non ha un posto sulla mappa',
                    ].join(' · '),
                    style: Testi.secondario.copyWith(color: Colori.ardesia),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _Gesti(
              segno: s.segno,
              segnabili: tappeSegnabili(vista.stato),
              onPortami: _portabile(t) ? onPortami : null,
              onSegna: onSegna,
            ),
            const SizedBox(height: 8),
            Center(
              child: Premibile(
                onTap: onApri,
                etichetta: 'Apri la tappa',
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    'Apri la tappa',
                    style: Testi.secondario.copyWith(
                      color: Colori.cobaltoScuro,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ).entra(context, da: 30);
  }
}

/// La mappa del viaggio: i giorni con i loro colori (tela, 54).
class _Legenda extends StatelessWidget {
  const _Legenda({super.key, required this.vista, required this.onGiorno});

  final _Vista vista;
  final ValueChanged<Giorno> onGiorno;

  @override
  Widget build(BuildContext context) => _Scheda(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (vista.giorni.isEmpty)
          Text(
            'Le tappe arrivano quando il viaggio ha le date.',
            style: Testi.secondario.copyWith(color: Colori.ardesia),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (i, g) in vista.giorni.indexed)
                Premibile(
                  onTap: () => onGiorno(g),
                  scala: 0.95,
                  etichetta: 'Mostra ${nomeDelGiorno(g.finestra.data)}',
                  child: ExcludeSemantics(
                    child: Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colori.foschia,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: coloreGiorno(i),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            giornoCorto(g.finestra.data),
                            style: Testi.pillola.copyWith(
                              color: Colori.inchiostro,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        if (vista.senzaPosto > 0) ...[
          const SizedBox(height: 10),
          Text(
            _senzaPostoInParole(vista.senzaPosto),
            style: Testi.didascalia.copyWith(color: Colori.grafite),
          ),
        ],
      ],
    ),
  );
}

/// La mappa che non c'è: senza rete, o senza fornitore (tela, 55).
class _MappaAssente extends StatelessWidget {
  const _MappaAssente({required this.rete});

  final bool rete;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 180),
    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      gradient: const LinearGradient(
        begin: Alignment(-1, -1),
        end: Alignment(-0.92, -0.92),
        colors: [
          Color(0xFFE3E6EE),
          Color(0xFFE3E6EE),
          Color(0xFFF4F5F8),
          Color(0xFFF4F5F8),
        ],
        stops: [0, 0.5, 0.5, 1],
        tileMode: TileMode.repeated,
      ),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.map_outlined, size: 30, color: Colori.grafite),
        const SizedBox(height: 8),
        Text(
          rete
              ? 'La mappa non è disponibile'
              : 'La mappa ha bisogno della rete',
          textAlign: TextAlign.center,
          style: Testi.evidenza.copyWith(
            color: Colori.inchiostro,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Gli indirizzi delle tappe ci sono: aprili nelle Mappe del '
          'telefono, che possono avere le mappe scaricate.',
          textAlign: TextAlign.center,
          style: Testi.didascalia.copyWith(color: Colori.grafite),
        ),
      ],
    ),
  );
}

class _Etichetta extends StatelessWidget {
  const _Etichetta(this.testo);

  final String testo;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
    child: Text(
      testo.toUpperCase(),
      style: Testi.sezione.copyWith(color: Colori.grafite),
    ),
  );
}

/// Una tappa con il suo indirizzo, e le Mappe del telefono (tela, 55).
class _RigaIndirizzo extends StatelessWidget {
  const _RigaIndirizzo({
    required this.sulla,
    required this.onMappe,
    required this.onApri,
    this.colore,
  });

  final TappaSullaMappa<Tappa> sulla;
  final VoidCallback? onMappe;
  final VoidCallback onApri;
  final Color? colore;

  @override
  Widget build(BuildContext context) {
    final t = sulla.tappa;
    final dove = t.luogoNome?.trim();
    final sotto = dove != null && dove.isNotEmpty ? dove : 'Senza indirizzo';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colori.bianco,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Premibile(
              onTap: onApri,
              scala: 0.98,
              etichetta: '${sulla.numero}, ${t.titolo}, $sotto',
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    if (colore != null)
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colore,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${sulla.numero}',
                          style: Testi.titoli(
                            13,
                            spaziatura: 0,
                            altezza: 1,
                          ).copyWith(color: Colori.bianco),
                        ),
                      )
                    else
                      NumeroTappa(
                        numero: sulla.numero,
                        segno: sulla.segno,
                        lato: 32,
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.titolo,
                            maxLines: 2,
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
          if (onMappe != null) ...[
            const SizedBox(width: 10),
            Premibile(
              onTap: onMappe,
              scala: 0.94,
              etichetta: 'Apri ${t.titolo} in Mappe',
              child: ExcludeSemantics(
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colori.foschia,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.open_in_new_rounded,
                        size: 14,
                        color: Colori.cobaltoScuro,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Mappe',
                        style: Testi.didascalia.copyWith(
                          color: Colori.cobaltoScuro,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
