import 'dart:async';

import 'package:flutter/material.dart';

import '../aspetto/elementi.dart';
import '../aspetto/formati.dart';
import '../aspetto/mezzi.dart';
import '../aspetto/movimento.dart';
import '../aspetto/pagina.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/segni_mappa.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../dati/database.dart';
import '../dati/errori.dart';
import '../dati/guida.dart';
import '../dati/lettura.dart';
import '../dati/mappe.dart';
import '../dominio/mappa.dart';
import '../dominio/tappe.dart';
import '../dominio/tragitti.dart';
import '../servizi.dart';
import 'gesti_mappa.dart';
import 'gesti_tappa.dart';
import 'mezzi.dart';
import 'salta.dart';
import 'tragitto.dart';

/// La guida verso una tappa, dentro Trolley (08-mappa.md, regola 2; CR-06,
/// passo 4; tela, 163): la mappa di Google che segue la persona, in alto la
/// nostra intestazione con la svolta che viene, in basso la nostra scheda,
/// quanto manca e a che ora si arriva. Spostata la mappa col dito, il
/// pulsante tondo la riporta dove si è. Di Google resta il logo. All'arrivo, «Sei qui» propone di
/// segnare la tappa con un tocco (tela, 52): è il gesto della verifica, e va
/// dove la persona si trova già (regola 4).
///
/// «Apri in Google Maps» c'è sempre, per chi preferisce, e quando la guida
/// non parte: chi la apre non resta mai senza indicazioni (ADR-006).
///
/// Si apre solo con la rete, il fornitore e il permesso di posizione
/// ([portamiAllaTappa]); la tappa ha un posto. Prima di partire il server
/// conta la destinazione sul tetto (U.2): si paga.
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

enum _Fase {
  /// Le condizioni di Google, la sessione.
  preparo,

  /// La strada si sta chiedendo.
  parto,

  /// Si cammina.
  guida,

  /// La guida non è partita.
  ferma,
}

class _SchermataNavigazioneState extends State<SchermataNavigazione> {
  late Servizi _servizi;
  late ConsumoMappe _prima;
  bool _avviata = false;

  var _fase = _Fase.preparo;
  String? _errore;

  /// La vista della guida c'è solo con la sessione pronta.
  bool _sessione = false;
  final _vistaPronta = Completer<ControlloGuida>();

  /// La mappa segue la persona, finché non la si sposta col dito.
  /// All'inizio la mappa guarda la tappa: il pulsante tondo porta da te.
  bool _segue = false;

  /// La voce della guida e la mappa in 3D: come le ha lasciate la persona
  /// l'ultima volta (tela, 163).
  bool _voce = true;
  bool _inclinata = true;

  /// Quanto è alta l'intestazione: il pulsante della voce sta sotto.
  double _altoSopra = 96;
  Indicazione? _indicazione;
  Rimasto? _rimasto;

  /// Dove dice di essere il telefono: il puntino e la mappa della guida lo
  /// usano quando la guida non dà la sua posizione sulla strada.
  Coordinate? _qui;

  /// Dove punta il telefono: il cono del puntino (tela, 163).
  double? _verso;
  final _ascolti = <StreamSubscription<Object?>>[];
  bool _arrivoMostrato = false;

  /// Quanto è alta la scheda in basso: la mappa lascia libero lo spazio.
  double _alto = 140;

  Coordinate get _posto => widget.tappa.posto!;

  /// Il mezzo con cui si guida: quello della tappa, se la guida lo porta;
  /// altrimenti a piedi (CR-07; tela, 171).
  late Mezzo _mezzo = switch (widget.tappa.mezzoTappa) {
    final m? when m.guidabile => m,
    _ => Mezzo.aPiedi,
  };

  /// Si sta ricalcolando la strada per un mezzo nuovo.
  bool _cambio = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_avviata) return;
    _avviata = true;
    _servizi = Servizi.of(context);
    _prima = _servizi.mappe.consumo;
    unawaited(_avvia());
  }

  @override
  void dispose() {
    for (final a in _ascolti) {
      unawaited(a.cancel());
    }
    unawaited(_servizi.guida.ferma());
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

  Future<void> _avvia() async {
    final guida = _servizi.guida;
    final pronta = await guida.prepara();
    if (!mounted) return;
    if (pronta != EsitoGuida.ok) return _ferma(messaggioDellaGuida(pronta));
    _ascolti.add(
      _servizi.posizione.segui().listen((p) {
        if (mounted) setState(() => _qui = p);
      }, onError: (Object _) {}),
    );
    _ascolti.add(
      _servizi.posizione.direzione().listen((g) {
        if (mounted) setState(() => _verso = g);
      }, onError: (Object _) {}),
    );
    _voce = await _preferenza(_servizi.db, _chiaveVoce);
    _inclinata = await _preferenza(_servizi.db, _chiave3D);
    // La guida la tiene come la persona l'ha lasciata, dall'inizio.
    await guida.voce(accesa: _voce);
    if (!mounted) return;
    _ascolti
      ..add(
        guida.rimasto.listen((r) {
          if (mounted) setState(() => _rimasto = r);
        }),
      )
      ..add(
        guida.indicazioni.listen((i) {
          if (mounted) setState(() => _indicazione = i);
        }),
      )
      ..add(guida.arrivo.listen((_) => _arrivato()));
    setState(() {
      _sessione = true;
      _fase = _Fase.parto;
    });

    // Ogni destinazione si paga: prima la conta il server, sul tetto.
    try {
      await _servizi.mappe.guidaConsentita(viaggioId: widget.viaggio.id);
    } on ErroreTrolley catch (e) {
      return _ferma(e.messaggio);
    }
    await _vistaPronta.future;
    if (!mounted) return;
    final partita = await guida.parti(
      titolo: widget.tappa.titolo,
      posto: _posto,
      placeId: widget.tappa.placeId,
      mezzo: _mezzo,
    );
    if (!mounted) return;
    if (partita != EsitoGuida.ok) return _ferma(messaggioDellaGuida(partita));
    setState(() => _fase = _Fase.guida);
    // Partiti, la mappa segue la persona.
    unawaited(_tornaDoveSei());
  }

  /// La tappa com'è adesso nella copia: dopo aver cambiato il mezzo ha una
  /// versione nuova, e segnarla con quella di prima sarebbe un conflitto.
  Future<Tappa> _tappaAdesso() async {
    final tappe = await _servizi.archivio.osservaTappe(widget.viaggio.id).first;
    return tappe.where((t) => t.id == widget.tappa.id).firstOrNull ??
        widget.tappa;
  }

  /// «Come ci vai?» dalla guida (tela, 172): il mezzo nuovo si scrive nella
  /// tappa, per tutti, e la strada si ricalcola. Con i mezzi pubblici, che
  /// la guida non ha, si apre Google Maps e la guida si chiude.
  Future<void> _cambiaMezzo() async {
    final qui = _qui;
    final scelto = await apriFoglio<Mezzo>(
      context,
      FoglioMezzoDellaGuida(
        a: widget.tappa.titolo,
        scelto: _mezzo,
        metri: qui == null ? null : distanzaInMetri(qui, _posto),
      ),
    );
    if (scelto == null || !mounted) return;
    final tappa = await _tappaAdesso();
    if (!mounted) return;
    setState(() => _cambio = true);
    try {
      final prima = tappa.mezzoTappa;
      if (scelto != prima) {
        final scritto = await scriviIlMezzo(context, tappa, scelto);
        if (!scritto || !mounted) return;
        unawaited(
          registraIlMezzo(
            _servizi,
            viaggioId: widget.viaggio.id,
            mezzo: scelto,
            prima: prima,
            da: DaDove.guida,
          ),
        );
      }
      if (!scelto.guidabile) {
        // Con i mezzi, al posto della guida il percorso a passi (tela, 164).
        await Navigator.of(context, rootNavigator: true).pushReplacement(
          rottaAPienoSchermo<void>(
            SchermataMezzi(
              viaggio: widget.viaggio,
              tappa: tappa,
              numero: widget.numero,
              da: DaDoveMezzi.guida,
            ),
          ),
        );
        return;
      }
      // Una strada nuova è una destinazione nuova: si conta sul tetto.
      try {
        await _servizi.mappe.guidaConsentita(viaggioId: widget.viaggio.id);
      } on ErroreTrolley catch (e) {
        if (mounted) mostraMessaggio(context, e.messaggio, errore: true);
        return;
      }
      final partita = await _servizi.guida.parti(
        titolo: widget.tappa.titolo,
        posto: _posto,
        placeId: widget.tappa.placeId,
        mezzo: scelto,
      );
      if (!mounted) return;
      if (partita != EsitoGuida.ok) {
        mostraMessaggio(context, messaggioDellaGuida(partita), errore: true);
        return;
      }
      setState(() {
        _mezzo = scelto;
        _rimasto = null;
        _indicazione = null;
      });
    } finally {
      if (mounted) setState(() => _cambio = false);
    }
  }

  Future<void> _cambiaVoce() async {
    final accesa = !_voce;
    setState(() => _voce = accesa);
    await _servizi.guida.voce(accesa: accesa);
    await _ricorda(_servizi.db, _chiaveVoce, accesa);
  }

  Future<void> _cambiaVista() async {
    final inclinata = !_inclinata;
    setState(() => _inclinata = inclinata);
    final controllo = await _vistaPronta.future;
    await controllo.inclina(inclinata: inclinata);
    await _ricorda(_servizi.db, _chiave3D, inclinata);
  }

  Future<void> _tornaDoveSei() async {
    setState(() => _segue = true);
    final controllo = await _vistaPronta.future;
    await controllo.seguimi();
  }

  void _ferma(String messaggio) {
    if (!mounted) return;
    setState(() {
      _fase = _Fase.ferma;
      _errore = messaggio;
    });
  }

  void _arrivato() {
    if (!mounted ||
        _arrivoMostrato ||
        widget.tappa.statoTappa != StatoTappa.daFare) {
      return;
    }
    _arrivoMostrato = true;
    unawaited(_arrivo());
  }

  Future<void> _aGoogleMaps({Mezzo? mezzo}) async {
    final aperte = await _servizi.mappeDelTelefono.portami(
      nome: widget.tappa.titolo,
      posto: _posto,
      indirizzo: widget.tappa.luogoNome,
      placeId: widget.tappa.placeId,
      conGoogle: true,
      mezzo: mezzo ?? _mezzo,
    );
    if (!aperte && mounted) {
      mostraMessaggio(context, 'Google Maps non si è aperto.', errore: true);
    }
  }

  /// «Sei qui»: segnarla da dove si è (tela, 52). Fatta o saltata chiudono
  /// anche la guida; «Dopo» lascia la mappa dov'è.
  Future<void> _arrivo() async {
    final segnabili = tappeSegnabili(widget.viaggio.statoA(DateTime.now()));
    final scelta = await apriFoglio<StatoTappa>(
      context,
      _FoglioArrivo(titolo: widget.tappa.titolo, segnabili: segnabili),
    );
    if (scelta == null || !mounted) return;
    final tappa = await _tappaAdesso();
    if (!mounted) return;
    if (scelta == StatoTappa.saltata) {
      // Chiede se rimandarla o saltarla e basta (tela, 152).
      await saltaLaTappa(context, viaggio: widget.viaggio, tappa: tappa);
    } else {
      await segnaLaTappa(
        context,
        viaggio: widget.viaggio,
        tappa: tappa,
        stato: scelta,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // Sotto la scheda resta una striscia per il logo di Google, in fondo a
    // destra come nelle altre mappe: lì non copre niente e non è coperto
    // (le condizioni di Google lo vogliono sempre visibile), e sta sopra la
    // curva dello schermo, dove si taglierebbe.
    final inBasso = mq.padding.bottom > 0
        ? mq.padding.bottom + sopraLaZonaSicura + altezzaDelLogo + 10
        : 50.0;
    return Scaffold(
      backgroundColor: const Color(0xFFE7EAF0),
      body: Stack(
        children: [
          if (_sessione)
            Positioned.fill(
              child: _servizi.guida.vista(
                centro: _posto,
                // Il logo di Google va in basso, al centro (scelta
                // dell'utente): la mappa lo mette nell'angolo della zona
                // che le si lascia, e la zona è una striscia larga quanto
                // il logo, in mezzo. Uguale a destra e a sinistra: il
                // centro della mappa, dove sta la persona, non si sposta.
                margini: EdgeInsets.fromLTRB(
                  latoPerIlLogo(mq.size.width),
                  0,
                  latoPerIlLogo(mq.size.width),
                  0,
                ),
                inclinata: _inclinata,
                qui: _qui,
                verso: _verso,
                segni: [
                  SegnoMappa(
                    id: 'tappa',
                    posto: _posto,
                    lato: latoImmagineSegno,
                    aspetto: 'guida|${widget.numero}',
                    disegno: SegnoSullaMappa(
                      numero: widget.numero,
                      segno: SegnoTappa.prossima,
                      etichetta: '${widget.numero}, ${widget.tappa.titolo}',
                      onTap: () {},
                    ),
                  ),
                ],
                onPronta: (c) {
                  if (!_vistaPronta.isCompleted) _vistaPronta.complete(c);
                },
                onSegue: (segue) {
                  if (mounted && segue != _segue) {
                    setState(() => _segue = segue);
                  }
                },
              ),
            ),
          // L'intestazione è nostra, dall'inizio alla fine (tela, 51 e 163).
          Positioned(
            top: mq.padding.top + 4,
            left: 12,
            right: 12,
            child: MisuraAltezza(
              onAltezza: (a) {
                if (mounted && a != _altoSopra) setState(() => _altoSopra = a);
              },
              child: _Intestazione(
                titolo: widget.tappa.titolo,
                fase: _fase,
                errore: _errore,
                indicazione: _indicazione,
              ),
            ),
          ),
          if (_fase == _Fase.guida)
            Positioned(
              right: 20,
              top: mq.padding.top + 4 + _altoSopra + 12,
              child: PulsanteTondo(
                icona: _voce
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                etichetta: _voce ? 'Togli la voce' : 'Rimetti la voce',
                onPressed: _cambiaVoce,
              ),
            ),
          if (_fase == _Fase.guida)
            Positioned(
              right: 20,
              top: mq.padding.top + 4 + _altoSopra + 12 + 44 + 12,
              // La scritta dice dove si va: «2D» quando la mappa è in 3D.
              child: PulsanteTondo(
                testo: _inclinata ? '2D' : '3D',
                icona: Icons.layers_rounded,
                etichetta: _inclinata ? 'Mappa in 2D' : 'Mappa in 3D',
                onPressed: _cambiaVista,
              ),
            ),
          if (_sessione && !_segue)
            Positioned(
              right: 20,
              bottom: inBasso + _alto + 16,
              child: PulsanteTondo(
                icona: Icons.my_location_rounded,
                etichetta: 'Torna dove sei',
                onPressed: _tornaDoveSei,
              ),
            ),
          Positioned(
            left: 20,
            right: 20,
            bottom: inBasso,
            child: MisuraAltezza(
              onAltezza: (a) {
                if (mounted && a != _alto) setState(() => _alto = a);
              },
              child: _QuantoManca(
                numero: widget.numero,
                tappa: widget.tappa,
                rimasto: _rimasto,
                adesso: widget.orologio(),
                mezzo: _mezzo,
                onMezzo: _fase == _Fase.guida && !_cambio ? _cambiaMezzo : null,
                onFine: () => Navigator.of(context).pop(),
                onGoogleMaps: _aGoogleMaps,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _chiaveVoce = 'guida_voce';
const _chiave3D = 'guida_3d';

/// Una scelta della guida che il telefono ricorda; accesa se non c'è.
Future<bool> _preferenza(DatabaseLocale db, String chiave) async {
  final riga = await (db.select(
    db.impostazioni,
  )..where((i) => i.chiave.equals(chiave))).getSingleOrNull();
  return riga?.valore != 'no';
}

Future<void> _ricorda(DatabaseLocale db, String chiave, bool si) => db
    .into(db.impostazioni)
    .insertOnConflictUpdate(
      ImpostazioniCompanion.insert(chiave: chiave, valore: si ? 'si' : 'no'),
    );

/// Che cosa dire quando la guida non parte. Restano sempre le Mappe.
String messaggioDellaGuida(EsitoGuida esito) => switch (esito) {
  EsitoGuida.ok => '',
  EsitoGuida.condizioniRifiutate =>
    'Senza le condizioni di Google la guida non parte.',
  EsitoGuida.senzaPosizione => 'Il telefono non sa dove sei.',
  EsitoGuida.nonTrovata => 'Non c\'è una strada fino alla tappa.',
  EsitoGuida.senzaRete => 'Senza rete la strada non si calcola.',
  EsitoGuida.tetto => 'Per questo mese le guide sono finite.',
  EsitoGuida.nonDisponibile => 'La guida non risponde.',
};

/// In alto (tela, 51 e 163): prima si prepara, poi la svolta che viene,
/// fra quanto e come la dice la guida; o la guida non è partita.
class _Intestazione extends StatelessWidget {
  const _Intestazione({
    required this.titolo,
    required this.fase,
    required this.errore,
    required this.indicazione,
  });

  final String titolo;
  final _Fase fase;
  final String? errore;
  final Indicazione? indicazione;

  @override
  Widget build(BuildContext context) {
    final i = indicazione;
    final (IconData simbolo, String grande, String sotto) = switch (fase) {
      _Fase.ferma => (
        Icons.wrong_location_outlined,
        'Niente strada',
        '${errore ?? ''} Ti porta Google Maps.'.trim(),
      ),
      _Fase.preparo => (
        Icons.location_searching_rounded,
        'Preparo la guida…',
        'A piedi fino a $titolo.',
      ),
      _Fase.parto => (
        Icons.alt_route_rounded,
        'Cerco la strada…',
        'A piedi fino a $titolo.',
      ),
      _Fase.guida when i == null => (
        Icons.navigation_rounded,
        'Si parte',
        'A piedi fino a $titolo.',
      ),
      _Fase.guida when i!.ricalcolo => (
        Icons.alt_route_rounded,
        'Ricalcolo…',
        i.testo,
      ),
      _Fase.guida => (
        iconaSvolta(i!.svolta),
        i.metri == null ? '' : distanza(i.metri!),
        i.svolta == Svolta.arrivo && i.testo.isEmpty
            ? 'Arrivi a $titolo'
            : i.testo,
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
                  if (grande.isNotEmpty)
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
                  if (grande.isNotEmpty && sotto.isNotEmpty)
                    const SizedBox(height: 2),
                  if (sotto.isNotEmpty)
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

/// L'icona di una svolta.
IconData iconaSvolta(Svolta s) => switch (s) {
  Svolta.dritto => Icons.straight_rounded,
  Svolta.leggermenteADestra => Icons.turn_slight_right_rounded,
  Svolta.aDestra => Icons.turn_right_rounded,
  Svolta.strettaADestra => Icons.turn_sharp_right_rounded,
  Svolta.leggermenteASinistra => Icons.turn_slight_left_rounded,
  Svolta.aSinistra => Icons.turn_left_rounded,
  Svolta.strettaASinistra => Icons.turn_sharp_left_rounded,
  Svolta.inversione => Icons.u_turn_left_rounded,
  Svolta.tieniLaDestra => Icons.fork_right_rounded,
  Svolta.tieniLaSinistra => Icons.fork_left_rounded,
  Svolta.rotonda => Icons.roundabout_right_rounded,
  Svolta.traghetto => Icons.directions_boat_rounded,
  Svolta.arrivo => Icons.flag_rounded,
};

/// In basso: la tappa, quanto manca, «Fine» e «Apri in Google Maps» (tela,
/// 163).
class _QuantoManca extends StatelessWidget {
  const _QuantoManca({
    required this.numero,
    required this.tappa,
    required this.rimasto,
    required this.adesso,
    required this.mezzo,
    required this.onMezzo,
    required this.onFine,
    required this.onGoogleMaps,
  });

  final int numero;
  final Tappa tappa;
  final Rimasto? rimasto;
  final DateTime adesso;

  /// Il mezzo con cui si guida: toccato, si cambia (tela, 171).
  final Mezzo mezzo;
  final VoidCallback? onMezzo;
  final VoidCallback onFine;
  final VoidCallback onGoogleMaps;

  @override
  Widget build(BuildContext context) {
    final r = rimasto;
    final sotto = r == null
        ? (tappa.luogoNome?.trim().isNotEmpty ?? false)
              ? tappa.luogoNome!.trim()
              : nomeMezzo(mezzo)
        : '${tempoAPiedi(r.tempo)} · '
              'arrivi alle ${ora(_orario(adesso.add(r.tempo)))}';
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
          Row(
            children: [
              Expanded(
                child: Semantics(
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
              const SizedBox(width: 8),
              _MezzoDellaGuida(mezzo: mezzo, onTap: onMezzo),
            ],
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
                  onTap: onGoogleMaps,
                  etichetta: 'Apri in Google Maps',
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colori.foschia,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'Apri in Google Maps',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Testi.evidenza.copyWith(
                        color: Colori.cobaltoScuro,
                        fontSize: 15,
                      ),
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

/// Il mezzo della guida, nella scheda in basso (tela, 171): toccato apre
/// «Come ci vai?».
class _MezzoDellaGuida extends StatelessWidget {
  const _MezzoDellaGuida({required this.mezzo, required this.onTap});

  final Mezzo mezzo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    enabled: onTap != null,
    child: Premibile(
      onTap: onTap,
      etichetta: '${nomeMezzo(mezzo)}: cambia il mezzo',
      child: ExcludeSemantics(
        child: Opacity(
          opacity: onTap == null ? 0.5 : 1,
          child: Container(
            height: 40,
            padding: const EdgeInsets.only(left: 9, right: 8),
            decoration: BoxDecoration(
              color: Colori.bianco,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colori.cenere, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(iconaMezzo(mezzo), size: 18, color: Colori.cobalto),
                const SizedBox(width: 5),
                Text(
                  nomeMezzo(mezzo),
                  style: Testi.secondario.copyWith(
                    color: Colori.inchiostro,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.expand_more_rounded,
                  size: 18,
                  color: Colori.grafite,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
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
