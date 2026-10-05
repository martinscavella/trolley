import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../aspetto/elementi.dart';
import '../aspetto/formati.dart';
import '../aspetto/movimento.dart';
import '../aspetto/pagina.dart';
import '../aspetto/segni_mappa.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../dati/database.dart';
import '../dati/errori.dart';
import '../dati/lettura.dart';
import '../dati/mappe.dart';
import '../dominio/mappa.dart';
import '../dominio/navigazione.dart';
import '../dominio/tappe.dart';
import '../servizi.dart';
import 'gesti_mappa.dart';
import 'gesti_tappa.dart';

/// La navigazione verso una tappa, dentro Trolley (08-mappa.md, regola 2;
/// tela, 51): il percorso a piedi sulla mappa, l'indicazione grande in alto,
/// quanto manca in basso, la posizione che si aggiorna mentre si cammina.
/// All'arrivo, «Sei qui» propone di segnare la tappa con un tocco (tela, 52):
/// è il gesto della verifica, e va dove la persona si trova già (regola 4).
///
/// «Apri in Mappe» c'è sempre: per i mezzi e l'auto, e quando la strada non
/// si trova o si è chiesta troppe volte (ADR-006). Chi la apre non resta mai
/// senza indicazioni.
///
/// Si apre solo con la rete, il fornitore e il permesso di posizione
/// ([portamiAllaTappa]); la tappa ha un posto.
class SchermataNavigazione extends StatefulWidget {
  const SchermataNavigazione({
    super.key,
    required this.viaggio,
    required this.tappa,
    required this.numero,
    this.orologio = DateTime.now,
  });

  final Viaggio viaggio;
  final Tappa tappa;

  /// Il suo numero nella giornata.
  final int numero;
  final DateTime Function() orologio;

  @override
  State<SchermataNavigazione> createState() => _SchermataNavigazioneState();
}

LatLng _ll(Coordinate c) => LatLng(c.lat, c.lon);

class _SchermataNavigazioneState extends State<SchermataNavigazione> {
  late Servizi _servizi;
  late ConsumoMappe _prima;
  bool _avviata = false;

  final _controllo = MapController();
  bool _pronta = false;

  /// La mappa segue la persona finché non la sposta con le dita.
  bool _segui = true;

  StreamSubscription<Coordinate>? _seguo;
  Coordinate? _qui;
  Percorso? _percorso;
  Avanzamento? _avanzamento;

  /// I metri del percorso già alle spalle, alla posizione di prima.
  double _fatti = 0;

  /// Le posizioni di fila fuori strada.
  int _fuori = 0;
  int _ricalcoli = 0;
  DateTime? _ultimoRicalcolo;
  bool _chiedendo = false;
  String? _errore;

  /// Si è chiesta la strada troppe volte: si consegna alle Mappe.
  bool _basta = false;
  bool _arrivoMostrato = false;

  Coordinate get _posto => widget.tappa.posto!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_avviata) return;
    _avviata = true;
    _servizi = Servizi.of(context);
    _prima = _servizi.mappe.consumo;
    _seguo = _servizi.posizione.segui().listen(
      _nuovaPosizione,
      onError: (Object _) {},
    );
  }

  @override
  void dispose() {
    unawaited(_seguo?.cancel());
    _controllo.dispose();
    unawaited(
      registraConsumo(
        _servizi.misurazione,
        _servizi.mappe,
        viaggioId: widget.viaggio.id,
        prima: _prima,
      ),
    );
    super.dispose();
  }

  void _nuovaPosizione(Coordinate p) {
    if (!mounted) return;
    setState(() {
      _qui = p;
      final percorso = _percorso;
      if (percorso == null) return;
      final a = percorso.avanzamento(p, giaFatti: _fatti);
      _avanzamento = a;
      _fatti = a.fatti;
      _fuori = a.fuoriStrada ? _fuori + 1 : 0;
    });
    if (_percorso == null) {
      if (!_chiedendo && _errore == null) unawaited(_chiediPercorso(p));
    } else {
      switch (vaRicalcolato(
        fuori: _fuori,
        fatti: _ricalcoli,
        ultimo: _ultimoRicalcolo,
        adesso: widget.orologio(),
      )) {
        case Ricalcolo.si:
          _ricalcoli++;
          _ultimoRicalcolo = widget.orologio();
          _fuori = 0;
          unawaited(_chiediPercorso(p));
        case Ricalcolo.basta:
          if (!_basta) setState(() => _basta = true);
        case Ricalcolo.no:
          break;
      }
    }
    if (_segui && _pronta) {
      _controllo.move(_ll(p), max(_controllo.camera.zoom, 16.5));
    }
    if (!_arrivoMostrato &&
        widget.tappa.statoTappa == StatoTappa.daFare &&
        arrivato(posizione: p, tappa: _posto)) {
      _arrivoMostrato = true;
      unawaited(_arrivo());
    }
  }

  Future<void> _chiediPercorso(Coordinate da) async {
    if (!_servizi.rete.disponibile) {
      if (_percorso == null) {
        setState(() => _errore = 'Senza rete la strada non si calcola.');
      }
      return;
    }
    _chiedendo = true;
    try {
      final percorso = await _servizi.mappe.percorsoAPiedi(da, _posto);
      if (!mounted) return;
      setState(() {
        _percorso = percorso;
        _fatti = 0;
        _fuori = 0;
        _avanzamento = percorso.avanzamento(_qui ?? da);
        _errore = null;
      });
    } on ErroreTrolley catch (e) {
      // Un ricalcolo che non riesce lascia la strada di prima.
      if (mounted && _percorso == null) setState(() => _errore = e.messaggio);
    } finally {
      _chiedendo = false;
    }
  }

  Future<void> _alleMappe() async {
    final aperte = await _servizi.mappeDelTelefono.portami(
      nome: widget.tappa.titolo,
      posto: _posto,
      indirizzo: widget.tappa.luogoNome,
    );
    if (!aperte && mounted) {
      mostraMessaggio(context, 'Le Mappe non si sono aperte.', errore: true);
    }
  }

  /// «Sei qui»: segnarla da dove si è (tela, 52). Fatta o saltata chiudono
  /// anche la navigazione; «Dopo» lascia la strada dov'è.
  Future<void> _arrivo() async {
    final segnabili = tappeSegnabili(widget.viaggio.statoA(DateTime.now()));
    final scelta = await apriFoglio<StatoTappa>(
      context,
      _FoglioArrivo(titolo: widget.tappa.titolo, segnabili: segnabili),
    );
    if (scelta == null || !mounted) return;
    await segnaLaTappa(
      context,
      viaggio: widget.viaggio,
      tappa: widget.tappa,
      stato: scelta,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final percorso = _percorso;
    final a = _avanzamento;
    final qui = _qui;
    return Scaffold(
      backgroundColor: const Color(0xFFE7EAF0),
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _controllo,
              options: MapOptions(
                backgroundColor: const Color(0xFFE7EAF0),
                initialCenter: _ll(qui ?? _posto),
                initialZoom: 16.5,
                minZoom: 3,
                maxZoom: 19,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onMapReady: () => _pronta = true,
                onPositionChanged: (_, conLeDita) {
                  if (conLeDita && _segui) setState(() => _segui = false);
                },
              ),
              children: [
                _servizi.mappe.riquadri(context),
                if (percorso != null)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [for (final p in percorso.punti) _ll(p)],
                        color: Colori.cobalto,
                        strokeWidth: 6,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _ll(_posto),
                      width: latoSegno,
                      height: latoSegno,
                      child: SegnoSullaMappa(
                        numero: widget.numero,
                        segno: SegnoTappa.prossima,
                        etichetta: '${widget.numero}, ${widget.tappa.titolo}',
                        onTap: () => _controllo.move(_ll(_posto), 17),
                      ),
                    ),
                    if (qui != null)
                      Marker(
                        point: _ll(qui),
                        width: PuntinoPosizione.lato,
                        height: PuntinoPosizione.lato,
                        child: const PuntinoPosizione(),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            top: mq.padding.top + 4,
            left: 12,
            right: 12,
            child: _Indicazione(
              titolo: widget.tappa.titolo,
              cercaPosizione: qui == null,
              cercaStrada: qui != null && percorso == null && _errore == null,
              errore: _errore,
              basta: _basta,
              avanzamento: a,
            ),
          ),
          if (!_segui && qui != null)
            Positioned(
              right: 20,
              bottom: mq.padding.bottom + 210,
              child: PulsanteTondo(
                icona: Icons.my_location_rounded,
                etichetta: 'Torna dove sei',
                onPressed: () {
                  setState(() => _segui = true);
                  _controllo.move(_ll(qui), max(_controllo.camera.zoom, 16.5));
                },
              ),
            ),
          Positioned(
            left: 20,
            right: 20,
            bottom: mq.padding.bottom > 0 ? mq.padding.bottom + 8 : 32,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Attribuzione(_servizi.mappe.attribuzione),
                const SizedBox(height: 8),
                _QuantoManca(
                  numero: widget.numero,
                  tappa: widget.tappa,
                  avanzamento: a,
                  adesso: widget.orologio(),
                  onFine: () => Navigator.of(context).pop(),
                  onMappe: _alleMappe,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// L'indicazione grande in alto: la svolta che viene e fra quanto (tela, 51).
class _Indicazione extends StatelessWidget {
  const _Indicazione({
    required this.titolo,
    required this.cercaPosizione,
    required this.cercaStrada,
    required this.errore,
    required this.basta,
    required this.avanzamento,
  });

  final String titolo;
  final bool cercaPosizione;
  final bool cercaStrada;
  final String? errore;
  final bool basta;
  final Avanzamento? avanzamento;

  @override
  Widget build(BuildContext context) {
    final a = avanzamento;
    final prossima = a?.prossima;
    final (IconData simbolo, String grande, String sotto) = switch (()) {
      _ when errore != null => (
        Icons.wrong_location_outlined,
        'Niente strada',
        '$errore Ti portano le Mappe del telefono.',
      ),
      _ when cercaPosizione => (
        Icons.location_searching_rounded,
        'Cerco dove sei…',
        'All\'aperto si trova prima.',
      ),
      _ when cercaStrada || a == null => (
        Icons.alt_route_rounded,
        'Cerco la strada…',
        'A piedi fino a $titolo.',
      ),
      _ when basta => (
        Icons.alt_route_rounded,
        distanza(a.metriRimasti),
        'Da qui ti portano meglio le Mappe del telefono.',
      ),
      _ when prossima == null || prossima.manovra == Manovra.arrivo => (
        Icons.flag_rounded,
        distanza(a.metriAllaProssima),
        'Arrivi a $titolo',
      ),
      _ => (
        iconaManovra(prossima.manovra),
        distanza(a.metriAllaProssima),
        prossima.istruzione,
      ),
    };
    return Semantics(
      liveRegion: true,
      label: '$grande, $sotto',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: Colori.inchiostro,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Icon(simbolo, size: 40, color: Colori.bianco),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedSwitcher(
                    duration: movimentoRidotto(context)
                        ? Duration.zero
                        : Ritmo.breve,
                    child: Text(
                      grande,
                      key: ValueKey(grande),
                      style: Testi.titoli(
                        26,
                        altezza: 1.1,
                      ).copyWith(color: Colori.bianco),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sotto,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Testi.corpo.copyWith(
                      color: Colori.bianco.withValues(alpha: 0.85),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// L'icona di una manovra.
IconData iconaManovra(Manovra m) => switch (m) {
  Manovra.partenza => Icons.navigation_rounded,
  Manovra.dritto => Icons.straight_rounded,
  Manovra.leggermenteADestra => Icons.turn_slight_right_rounded,
  Manovra.aDestra => Icons.turn_right_rounded,
  Manovra.strettaADestra => Icons.turn_sharp_right_rounded,
  Manovra.leggermenteASinistra => Icons.turn_slight_left_rounded,
  Manovra.aSinistra => Icons.turn_left_rounded,
  Manovra.strettaASinistra => Icons.turn_sharp_left_rounded,
  Manovra.inversione => Icons.u_turn_left_rounded,
  Manovra.tieniLaDestra => Icons.fork_right_rounded,
  Manovra.tieniLaSinistra => Icons.fork_left_rounded,
  Manovra.rotonda => Icons.roundabout_right_rounded,
  Manovra.mezzi => Icons.directions_transit_rounded,
  Manovra.arrivo => Icons.flag_rounded,
};

/// In basso: la tappa, quanto manca, «Fine» e «Apri in Mappe» (tela, 51).
class _QuantoManca extends StatelessWidget {
  const _QuantoManca({
    required this.numero,
    required this.tappa,
    required this.avanzamento,
    required this.adesso,
    required this.onFine,
    required this.onMappe,
  });

  final int numero;
  final Tappa tappa;
  final Avanzamento? avanzamento;
  final DateTime adesso;
  final VoidCallback onFine;
  final VoidCallback onMappe;

  @override
  Widget build(BuildContext context) {
    final a = avanzamento;
    final sotto = a == null
        ? (tappa.luogoNome?.trim().isNotEmpty ?? false)
              ? tappa.luogoNome!.trim()
              : 'A piedi'
        : [
            '${tempoAPiedi(a.tempoRimasto)} a piedi',
            distanza(a.metriRimasti),
            'arrivi alle ${ora(_orario(adesso.add(a.tempoRimasto)))}',
          ].join(' · ');
    return Container(
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: '${tappa.titolo}, $sotto',
            excludeSemantics: true,
            child: Row(
              children: [
                NumeroTappa(numero: numero, segno: SegnoTappa.prossima),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tappa.titolo,
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
                        style: Testi.didascalia.copyWith(color: Colori.grafite),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 10,
                child: Premibile(
                  onTap: onFine,
                  etichetta: 'Fine',
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colori.bianco,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colori.cenere, width: 2),
                    ),
                    child: Text(
                      'Fine',
                      style: Testi.evidenza.copyWith(color: Colori.inchiostro),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 16,
                child: Premibile(
                  onTap: onMappe,
                  etichetta: 'Apri in Mappe',
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colori.foschia,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.open_in_new_rounded,
                          size: 16,
                          color: Colori.cobaltoScuro,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Apri in Mappe',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Testi.evidenza.copyWith(
                              color: Colori.cobaltoScuro,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Duration _orario(DateTime d) =>
      Duration(hours: d.hour, minutes: d.minute);
}

/// «Sei qui» (tela, 52): fatta, saltata, o dopo.
class _FoglioArrivo extends StatelessWidget {
  const _FoglioArrivo({required this.titolo, required this.segnabili});

  final String titolo;
  final bool segnabili;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    Widget pulsante(
      String etichetta, {
      required Color fondo,
      required Color testo,
      bool bordo = false,
      IconData? simbolo,
      required VoidCallback onTap,
    }) => Premibile(
      onTap: onTap,
      etichetta: etichetta,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: BorderRadius.circular(18),
          border: bordo ? Border.all(color: Colori.cenere, width: 2) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (simbolo != null) ...[
              Icon(simbolo, size: 22, color: testo),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Text(
                etichetta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Testi.pulsante.copyWith(color: testo),
              ),
            ),
          ],
        ),
      ),
    );
    return Container(
      padding: EdgeInsets.fromLTRB(24, 12, 24, mq.padding.bottom + 24),
      decoration: const BoxDecoration(
        color: Colori.bianco,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          const SizedBox(height: 14),
          Text('SEI QUI', style: Testi.sezione.copyWith(color: Colori.cobalto)),
          const SizedBox(height: 8),
          Semantics(
            header: true,
            child: Text(
              titolo,
              style: Testi.titoloFoglio.copyWith(color: Colori.inchiostro),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            segnabili
                ? 'Quando hai finito, segnala la tappa: basta un tocco. '
                      'Conta per la verifica del viaggio.'
                : 'Sei arrivato alla tappa.',
            style: Testi.corpo.copyWith(color: Colori.ardesia, fontSize: 15),
          ),
          const SizedBox(height: 18),
          if (segnabili) ...[
            Row(
              children: [
                Expanded(
                  child: pulsante(
                    'Fatta',
                    fondo: Colori.verde,
                    testo: Colori.bianco,
                    simbolo: Icons.check_rounded,
                    onTap: () =>
                        Navigator.of(context).pop(StatoTappa.completata),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: pulsante(
                    'Salta',
                    fondo: Colori.bianco,
                    testo: Colori.inchiostro,
                    bordo: true,
                    onTap: () => Navigator.of(context).pop(StatoTappa.saltata),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          pulsante(
            segnabili ? 'Dopo' : 'Va bene',
            fondo: Colori.bianco,
            testo: Colori.inchiostro,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
