/// Con i mezzi pubblici: il percorso a passi, senza mappa (CR-07, passo 3;
/// 04, regola 37; tela, 164). A piedi fino alla fermata, la linea con la
/// direzione e l'ora, quante fermate, dove scendere, a piedi fino alla
/// tappa. Il passo di adesso si accende con la posizione.
///
/// I passi sono di Google (Routes API) e non stanno con nessuna mappa (le
/// condizioni europee, ADR-014): la linea del percorso è in «Vedi sulla
/// mappa», da sola. Si chiedono una volta, da dove si è (arrotondato a circa
/// 100 metri), e si tengono solo finché la schermata è aperta.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../aspetto/elementi.dart';
import '../aspetto/formati.dart';
import '../aspetto/pagina.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/segni_mappa.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../dati/database.dart';
import '../dati/errori.dart';
import '../dati/lettura.dart';
import '../dati/mappe.dart';
import '../dominio/mappa.dart';
import '../dominio/mezzi_pubblici.dart';
import '../dominio/tragitti.dart';
import '../misurazione/misurazione.dart';
import '../servizi.dart';
import 'gesti_mappa.dart';

/// Da dove si è aperto il percorso, per `percorso_coi_mezzi` (07).
enum DaDoveMezzi { portami, guida }

class SchermataMezzi extends StatefulWidget {
  const SchermataMezzi({
    super.key,
    required this.viaggio,
    required this.tappa,
    required this.numero,
    required this.da,
    this.orologio = DateTime.now,
  });

  final Viaggio viaggio;
  final Tappa tappa;

  /// Il suo numero nella giornata: il segno su «Vedi sulla mappa».
  final int numero;
  final DaDoveMezzi da;
  final DateTime Function() orologio;

  @override
  State<SchermataMezzi> createState() => _SchermataMezziState();
}

class _SchermataMezziState extends State<SchermataMezzi> {
  late Servizi _servizi;
  late ConsumoMappe _prima;
  bool _avviata = false;

  PercorsoMezzi? _percorso;
  bool _cerco = true;
  String? _errore;
  int _passo = 0;
  StreamSubscription<Coordinate>? _posizione;

  Coordinate get _posto => widget.tappa.posto!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_avviata) return;
    _avviata = true;
    _servizi = Servizi.of(context);
    _prima = _servizi.mappe.consumo;
    unawaited(_cerca());
  }

  @override
  void dispose() {
    unawaited(_posizione?.cancel());
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

  Future<void> _cerca() async {
    final qui = await _servizi.posizione.qui();
    if (!mounted) return;
    if (qui == null) {
      return _finisci(
        errore:
            'Il telefono non sa dove sei: senza, il percorso non si '
            'calcola.',
        esito: 'senza_posizione',
      );
    }
    try {
      final percorso = await _servizi.mappe.mezzi(
        viaggioId: widget.viaggio.id,
        // Circa cento metri: quanto basta per la fermata, e non di più.
        da: arrotondataACento(qui),
        a: _posto,
        placeId: widget.tappa.placeId,
      );
      if (!mounted) return;
      if (percorso == null) {
        return _finisci(
          errore:
              'Google non trova un percorso con i mezzi fino a qui, '
              'adesso.',
          esito: 'nessuno',
        );
      }
      setState(() {
        _percorso = percorso;
        _passo = passoDiAdesso(percorso.passi, qui);
        _cerco = false;
      });
      unawaited(_registra('ok'));
      _posizione = _servizi.posizione.segui().listen((p) {
        final percorso = _percorso;
        if (!mounted || percorso == null) return;
        final passo = passoDiAdesso(percorso.passi, p, almeno: _passo);
        if (passo != _passo) setState(() => _passo = passo);
      }, onError: (Object _) {});
    } on ErroreTrolley catch (e) {
      _finisci(
        errore: e.messaggio,
        esito: e.codice == CodiciServer.tettoMappe ? 'tetto' : 'errore',
      );
    }
  }

  void _finisci({required String errore, required String esito}) {
    if (!mounted) return;
    setState(() {
      _errore = errore;
      _cerco = false;
    });
    unawaited(_registra(esito));
  }

  /// `percorso_coi_mezzi` (07): da dove, com'è andata, quanti passi e
  /// cambi. Mai dove, mai quali linee.
  Future<void> _registra(String esito) async {
    final p = _percorso;
    await _servizi.misurazione.registra(Eventi.percorsoCoiMezzi, {
      'viaggio_id': widget.viaggio.id,
      'da': widget.da.name,
      'esito': esito,
      if (p != null) ...{'passi': p.passi.length, 'cambi': p.cambi},
    });
    unawaited(_servizi.misurazione.invia());
  }

  Future<void> _aGoogleMaps() async {
    final aperte = await _servizi.mappeDelTelefono.portami(
      nome: widget.tappa.titolo,
      posto: _posto,
      indirizzo: widget.tappa.luogoNome,
      placeId: widget.tappa.placeId,
      conGoogle: true,
      mezzo: Mezzo.mezzi,
    );
    if (!aperte && mounted) {
      mostraMessaggio(context, 'Google Maps non si è aperto.', errore: true);
    }
  }

  Future<void> _sullaMappa() => apri<void>(
    context,
    _LineaSullaMappa(
      viaggioId: widget.viaggio.id,
      tappa: widget.tappa,
      numero: widget.numero,
      linea: _percorso?.linea ?? const [],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final p = _percorso;
    final adesso = widget.orologio();
    return Scaffold(
      backgroundColor: Colori.nebbia,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          mq.padding.top + 12,
          20,
          mq.padding.bottom + 24,
        ),
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: PulsanteIndietro(),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    'PER ${widget.tappa.titolo.toUpperCase()}',
                    if (p != null) durataBreve(p.durata).toUpperCase(),
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Testi.etichetta.copyWith(
                    color: Colori.cobalto,
                    fontSize: 11,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  p == null ? 'Con i mezzi' : titoloDelPercorso(p),
                  style: Testi.titolo,
                ),
                if (p != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Arrivi alle ${ora(_orario(p.arrivo(adesso)))} · '
                    '${cambi(p.cambi)}',
                    style: Testi.corpo.copyWith(color: Colori.ardesia),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_cerco)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: IndicatoreAttivita()),
            )
          else if (_errore != null)
            Avviso(
              errore: true,
              fondo: Colori.rosa,
              colore: Colori.pericolo,
              icona: Icons.directions_transit_rounded,
              inizio: 'Niente percorso.',
              testo: _errore!,
            )
          else if (p != null)
            ..._passi(p, adesso),
          if (p != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Il passo di adesso si accende con la tua posizione. La '
                'linea sulla mappa è in «Vedi sulla mappa», senza i passi: '
                'Google non li lascia insieme.',
                style: Testi.didascalia.copyWith(color: Colori.grafite),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              if (p != null && p.linea.isNotEmpty) ...[
                Expanded(
                  child: PulsanteGrande(
                    etichetta: 'Vedi sulla mappa',
                    secondario: true,
                    onPressed: _sullaMappa,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: PulsanteGrande(
                  etichetta: 'Apri in Google Maps',
                  secondario: true,
                  onPressed: _aGoogleMaps,
                ),
              ),
            ],
          ),
          if (p != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Center(
                child: Text(
                  _servizi.mappe.attribuzioneRicerca,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF5E5E5E),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Le righe dei passi (tela, 164): a piedi, la linea, dove scendere.
  List<Widget> _passi(PercorsoMezzi p, DateTime adesso) {
    final orari = p.orariDeiPassi(adesso);
    final righe = <Widget>[];
    for (var i = 0; i < p.passi.length; i++) {
      final passo = p.passi[i];
      final acceso = i == _passo;
      final ultimo = i == p.passi.length - 1;
      switch (passo) {
        case APiediFino():
          righe.add(
            _Riga(
              segno: 'A',
              titolo: 'A piedi fino a ${passo.verso ?? widget.tappa.titolo}',
              sotto: '${tempoAPiedi(passo.durata)} · ${distanza(passo.metri)}',
              ora: ora(_orario(orari[i])),
              acceso: acceso,
              poi: !ultimo,
            ),
          );
        case SullaLinea():
          final dopo = p.passi.skip(i + 1).whereType<SullaLinea>().firstOrNull;
          righe
            ..add(
              _Riga(
                segno: passo.linea.isEmpty ? '·' : passo.linea,
                titolo: [
                  '${nomeVeicolo(passo.veicolo)} ${passo.linea}'.trim(),
                  if (passo.direzione != null) 'direzione ${passo.direzione}',
                ].join(', '),
                sotto: [
                  if (passo.sali != null) 'da ${passo.sali}',
                  if (passo.fermate != null) fermate(passo.fermate!),
                  if (passo.partenza case final t? when t.isAfter(adesso))
                    'fra ${durataBreve(_almenoUnMinuto(t.difference(adesso)))}',
                ].join(' · '),
                ora: ora(_orario(orari[i])),
                acceso: acceso,
                poi: true,
              ),
            )
            ..add(
              _Riga(
                segno: '↓',
                titolo: 'Scendi a ${passo.scendi ?? 'destinazione'}',
                sotto: dopo == null
                    ? 'Poi a piedi'
                    : [
                        '${nomeVeicolo(dopo.veicolo)} ${dopo.linea}'.trim(),
                        if (dopo.partenza case final t?)
                          if (passo.arrivo case final a? when t.isAfter(a))
                            'fra ${durataBreve(_almenoUnMinuto(t.difference(a)))}',
                      ].join(' '),
                ora: passo.arrivo == null ? null : ora(_orario(passo.arrivo!)),
                acceso: false,
                poi: !ultimo,
              ),
            );
      }
    }
    return righe;
  }

  static Duration _orario(DateTime d) =>
      Duration(hours: d.hour, minutes: d.minute);

  static Duration _almenoUnMinuto(Duration d) =>
      d < const Duration(minutes: 1) ? const Duration(minutes: 1) : d;
}

/// «In metro», «In bus»: dal primo mezzo.
String titoloDelPercorso(PercorsoMezzi p) => switch (p.veicolo) {
  Veicolo.metro => 'In metro',
  Veicolo.bus => 'In bus',
  Veicolo.tram => 'In tram',
  Veicolo.treno => 'In treno',
  Veicolo.traghetto => 'In traghetto',
  Veicolo.altro || null => 'Con i mezzi',
};

String nomeVeicolo(Veicolo v) => switch (v) {
  Veicolo.metro => 'Metro',
  Veicolo.bus => 'Bus',
  Veicolo.tram => 'Tram',
  Veicolo.treno => 'Treno',
  Veicolo.traghetto => 'Traghetto',
  Veicolo.altro => 'Linea',
};

String cambi(int n) => switch (n) {
  0 => 'senza cambi',
  1 => 'un cambio',
  _ => '$n cambi',
};

String fermate(int n) => n == 1 ? '1 fermata' : '$n fermate';

/// Un passo: il segno tondo, cosa fare, l'ora. Acceso, è quello di adesso.
class _Riga extends StatelessWidget {
  const _Riga({
    required this.segno,
    required this.titolo,
    required this.sotto,
    required this.ora,
    required this.acceso,
    required this.poi,
  });

  final String segno;
  final String titolo;
  final String sotto;
  final String? ora;
  final bool acceso;

  /// Dopo c'è un altro passo: la linea che li unisce.
  final bool poi;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: acceso,
    label: [titolo, sotto, ?ora, if (acceso) 'adesso'].join(', '),
    excludeSemantics: true,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (poi)
            const Positioned(
              left: 30,
              top: 52,
              bottom: -14,
              child: SizedBox(
                width: 3,
                child: ColoredBox(color: Colori.cenere),
              ),
            ),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: acceso ? Colori.cobaltoChiaro : Colori.bianco,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: acceso ? Colori.cobalto : Colori.cenere,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  constraints: const BoxConstraints(minWidth: 34),
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colori.bianco,
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(
                      color: acceso ? Colori.cobalto : Colori.cenere,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    segno,
                    style: Testi.secondario.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: Colori.inchiostro,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titolo,
                        style: Testi.evidenza.copyWith(
                          color: Colori.inchiostro,
                          fontSize: 15,
                        ),
                      ),
                      if (sotto.isNotEmpty)
                        Text(
                          sotto,
                          style: Testi.didascalia.copyWith(
                            color: Colori.grafite,
                          ),
                        ),
                    ],
                  ),
                ),
                if (ora != null) ...[
                  const SizedBox(width: 8),
                  Text(ora!, style: Testi.numero.copyWith(fontSize: 14)),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// «Vedi sulla mappa»: la linea del percorso e la tappa, senza i passi.
class _LineaSullaMappa extends StatelessWidget {
  const _LineaSullaMappa({
    required this.viaggioId,
    required this.tappa,
    required this.numero,
    required this.linea,
  });

  final String viaggioId;
  final Tappa tappa;
  final int numero;
  final List<Coordinate> linea;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final posto = tappa.posto!;
    final mappe = Servizi.of(context).mappe;
    return Scaffold(
      backgroundColor: const Color(0xFFE7EAF0),
      body: Stack(
        children: [
          Positioned.fill(
            child: mappe.mappa(
              context,
              viaggioId: viaggioId,
              segni: [
                SegnoMappa(
                  id: 'tappa',
                  posto: posto,
                  lato: latoImmagineSegno,
                  aspetto: 'mezzi|$numero',
                  disegno: SegnoSullaMappa(
                    numero: numero,
                    segno: SegnoTappa.prossima,
                    etichetta: '$numero, ${tappa.titolo}',
                    onTap: () {},
                  ),
                ),
              ],
              linee: [
                LineaMappa(id: 'mezzi', punti: linea, colore: Colori.cobalto),
              ],
              centro: posto,
              zoom: 14,
              margini: EdgeInsets.fromLTRB(
                40,
                mq.padding.top + 80,
                40,
                mq.padding.bottom + 40,
              ),
              onPronta: (c) => c.inquadra([...linea, posto]),
            ),
          ),
          Positioned(
            top: mq.padding.top + 12,
            left: 20,
            child: const PulsanteIndietro(),
          ),
        ],
      ),
    );
  }
}
