import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../aspetto/barra.dart';
import '../aspetto/elementi.dart';
import '../aspetto/formati.dart';
import '../aspetto/mappamondo.dart';
import '../aspetto/movimento.dart';
import '../aspetto/pagina.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../dati/database.dart';
import '../dati/destinazioni.dart';
import '../dati/lettura.dart';
import '../dominio/mappa.dart';
import '../dominio/ricordo.dart';
import '../servizi.dart';
import 'con_la_rete.dart';
import 'globo.dart';

/// Dove guarda il globo di chi non ha ancora un viaggio chiuso: l'Europa.
const centroSenzaViaggi = (lat: 42.0, lon: 12.0);

/// Dove sta un paese sul globo: il suo punto nell'elenco, o quello di una
/// città del viaggio per i paesi che l'elenco tiene dentro un altro (la
/// Martinica). Senza l'elenco, ancora da caricare, nessuno.
Map<String, Coordinate> puntiDeiPaesi(
  ElencoDestinazioni? elenco,
  List<Meta> mete,
) {
  if (elenco == null) return const {};
  final punti = <String, Coordinate>{};
  for (final m in mete) {
    final paese = m.paese;
    if (paese == null || punti.containsKey(paese)) continue;
    final d = elenco.trova(paese: paese);
    final c =
        coordinate(d?.lat, d?.lon) ??
        switch (elenco.trova(citta: m.citta, paese: paese)) {
          final citta? => coordinate(citta.lat, citta.lon),
          null => null,
        };
    if (c != null) punti[paese] = c;
  }
  return punti;
}

/// Il mappamondo (10, regola 5; tela, 66): i paesi e le città di ogni viaggio
/// chiuso, verificato o no — è il ricordo, non il merito. Il globo si gira
/// col dito, e toccando un paese ci si gira da soli. Si legge dalla copia, e
/// i confini sono nell'app (ADR-005): funziona anche senza rete.
class SchermataMappamondo extends StatefulWidget with ConLaBarra {
  const SchermataMappamondo({super.key});

  @override
  State<SchermataMappamondo> createState() => _SchermataMappamondoState();
}

class _SchermataMappamondoState extends State<SchermataMappamondo>
    with SingleTickerProviderStateMixin {
  late Stream<List<(Partecipazione, Viaggio)>> _miei;
  late Stream<Set<String>> _scoperti;
  ElencoDestinazioni? _elenco;
  bool _avviata = false;

  /// Il paese toccato nell'elenco, dove il globo si gira.
  String? _guardato;

  /// Il paese appena scoperto, per dire quale è: «il tuo 7° paese».
  String? _appena;
  Timer? _dimentica;

  /// Il globo piccolo e quello a tutto schermo, che parte dal suo posto e
  /// ci torna (tela, 149). Uno solo si vede alla volta.
  final _piccolo = GlobalKey<StatoMappamondo>();
  final _grande = GlobalKey<StatoMappamondo>();
  final _portale = OverlayPortalController();

  /// Quanto è aperto quello grande: 0 al posto del piccolo, 1 a tutto
  /// schermo. Può passare appena oltre, con le molle e con le dita.
  late final _apertura = AnimationController.unbounded(vsync: this);
  bool _aperto = false;
  Disco? _da;
  Coordinate? _centroAperto;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_avviata) return;
    _avviata = true;
    final archivio = Servizi.of(context).archivio;
    _miei = archivio.osservaMieiViaggi();
    _scoperti = archivio.osservaPaesiScoperti();
    ElencoDestinazioni.carica().then((elenco) {
      if (mounted) setState(() => _elenco = elenco);
    });
    unawaited(segnaAperturaSenzaRete(context, 'mappamondo'));
  }

  @override
  void dispose() {
    _dimentica?.cancel();
    _apertura.dispose();
    super.dispose();
  }

  /// Il globo grande compare dove sta il piccolo, che si nasconde: da qui
  /// lo muovono le dita, o la sua molla.
  void _apri() {
    if (_aperto) return;
    final piccolo = _piccolo.currentState;
    _da = piccolo?.disco;
    _centroAperto = piccolo?.centroAttuale;
    _apertura.value = 0;
    setState(() => _aperto = true);
    _portale.show();
  }

  /// Il globo grande è tornato al posto del piccolo: il piccolo ricompare
  /// guardando dove guardava il grande.
  void _chiuso() {
    final dove = _grande.currentState?.centroAttuale;
    _portale.hide();
    setState(() => _aperto = false);
    if (dove != null) _piccolo.currentState?.guarda(dove);
  }

  /// Il paese è scoperto, col dito o con «Scopri»: si ricorda su questo
  /// telefono, e per un momento si dice quale paese è.
  Future<void> _scoperto(String paese) async {
    _dimentica?.cancel();
    setState(() => _appena = paese);
    _dimentica = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _appena = null);
    });
    await Servizi.of(context).archivio.segnaPaeseScoperto(paese);
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<Set<String>>(
    stream: _scoperti,
    builder: (context, scoperti) =>
        StreamBuilder<List<(Partecipazione, Viaggio)>>(
          stream: _miei,
          builder: (context, letti) {
            final viaggi = delPassaporto(
              letti.data ?? const [],
              DateTime.now(),
            );
            final mete = meteDi(viaggi);
            final visite = visiteDi(viaggi);
            final paesi = paesiGrattati(mete);
            final citta = cittaGrattate(mete);
            final punti = puntiDeiPaesi(_elenco, mete);
            // Finché non si sa che cosa è già scoperto, non si chiede di grattare.
            final daScoprire = scoperti.hasData
                ? daGrattare(
                    visite,
                    scoperti: scoperti.data!,
                    oggi: DateTime.now(),
                  )
                : const <String>[];
            final ora = daScoprire.firstOrNull;
            final centro =
                punti[_guardato] ??
                (paesi.isEmpty ? null : punti[paesi.first]) ??
                centroSenzaViaggi;
            final appena = _appena;
            final mq = MediaQuery.of(context);
            final grattati = {
              for (final p in paesi)
                if (!daScoprire.contains(p)) p,
            };
            // Aperto, il globo sta sopra tutto, anche sopra la barra; indietro lo
            // richiude, invece di lasciare la schermata.
            return PopScope(
              canPop: !_aperto,
              onPopInvokedWithResult: (uscito, _) {
                if (!uscito) _grande.currentState?.chiudi();
              },
              child: _pagina(
                context,
                paesi: paesi,
                citta: citta,
                visite: visite,
                daScoprire: daScoprire,
                ora: ora,
                appena: appena,
                centro: centro,
                punti: punti,
                grattati: grattati,
                mq: mq,
                globo: SchermataGlobo(
                  globo: _grande,
                  apertura: _apertura,
                  da: _da,
                  onChiuso: _chiuso,
                  viaggi: viaggi,
                  grattati: grattati,
                  daScoprire: daScoprire.toSet(),
                  punti: punti,
                  centro: _centroAperto ?? centro,
                  inOrdine: paesiInOrdine(visite),
                  quanti: [
                    quanti(paesi.length, 'paese', 'paesi'),
                    if (citta.isNotEmpty)
                      quanti(citta.length, 'città', 'città'),
                  ].join(' · '),
                ),
              ),
            );
          },
        ),
  );

  Widget _pagina(
    BuildContext context, {
    required List<String> paesi,
    required List<Meta> citta,
    required List<Visita> visite,
    required List<String> daScoprire,
    required String? ora,
    required String? appena,
    required Coordinate centro,
    required Map<String, Coordinate> punti,
    required Set<String> grattati,
    required MediaQueryData mq,
    required SchermataGlobo globo,
  }) =>
      // Tutto sul blu della notte, con il titolo accanto alla freccia
      // (tela, 144).
      Pagina(
        notte: true,
        titolo: 'Mappamondo',
        corpo: Builder(
          builder: (context) => Padding(
            padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // I numeri stanno grandi sopra il globo (tela, 144).
                if (paesi.isEmpty || ora != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                    child: Text(
                      paesi.isEmpty
                          ? 'Si accende con i viaggi chiusi, verificati o '
                                'no, e con quelli fatti prima di Trolley che '
                                'aggiungi al passaporto.'
                          : 'Un paese nuovo: grattalo col dito.',
                      style: Testi.secondario.copyWith(
                        color: Colori.bianco.withValues(alpha: 0.7),
                      ),
                    ).entra(context),
                  ),
                Padding(
                  // Le chiavi tengono il globo e il suo portale dove sono
                  // quando sopra compare o sparisce una riga.
                  key: const ValueKey('globo'),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: EdgeInsets.fromLTRB(
                      0,
                      16,
                      0,
                      ora != null || appena != null ? 60 : 16,
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        Column(
                          children: [
                            if (paesi.isNotEmpty && ora == null)
                              _Numeri(paesi: paesi.length, citta: citta.length),
                            ConstrainedBox(
                              key: const ValueKey('globo'),
                              constraints: BoxConstraints(
                                maxHeight: mq.size.height * 0.36,
                              ),
                              child: Center(
                                // Il globo a tutto schermo sta sopra tutto,
                                // anche sopra la barra, e parte da qui.
                                child: OverlayPortal(
                                  controller: _portale,
                                  overlayLocation:
                                      OverlayChildLocation.rootOverlay,
                                  overlayChildBuilder: (_) => globo,
                                  child: Opacity(
                                    // Aperto, il globo è quello a tutto
                                    // schermo, che è partito da qui.
                                    opacity: _aperto ? 0 : 1,
                                    child: Mappamondo(
                                      key: _piccolo,
                                      grattati: grattati,
                                      centro: centro,
                                      punti: punti,
                                      daGrattare: ora,
                                      onScoperto: _scoperto,
                                      giraDaSolo: true,
                                      // Allargandolo con due dita cresce fino
                                      // a tutto schermo, sotto le dita (tela,
                                      // 149); col paese da grattare, il dito
                                      // gratta.
                                      onAllarga: (scala, spostamento) {
                                        _apri();
                                        _grande.currentState?.seguiDita(
                                          scala,
                                          spostamento,
                                        );
                                      },
                                      onAllargaFine: (velocita) {
                                        final grande = _grande.currentState;
                                        if (grande == null) {
                                          _chiuso();
                                        } else {
                                          grande.lasciaDita(velocita);
                                        }
                                      },
                                      onApri: ora != null
                                          ? null
                                          : () {
                                              _apri();
                                              WidgetsBinding.instance
                                                  .addPostFrameCallback(
                                                    (_) => _grande.currentState
                                                        ?.apri(),
                                                  );
                                            },
                                      etichetta: ora != null
                                          ? 'Mappamondo: ${nomeDelPaese(ora) ?? ora} '
                                                'da grattare'
                                          : 'Mappamondo: '
                                                '${quanti(paesi.length, 'paese visitato', 'paesi visitati')}',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (paesi.isNotEmpty && ora == null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  'Giralo col dito · allargalo per entrarci',
                                  style: Testi.didascalia.copyWith(
                                    color: Colori.bianco.withValues(alpha: 0.6),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (ora != null)
                          Positioned(
                            top: -4,
                            right: 12,
                            child: PulsantePiccolo(
                              etichetta: 'Scopri',
                              onPressed: () => _scoperto(ora),
                            ),
                          ),
                        if (appena != null || ora != null)
                          Positioned(
                            bottom: -46,
                            child: _Capsula(
                              key: ValueKey(appena ?? ora),
                              testo: appena != null
                                  ? '${nomeDelPaese(appena) ?? appena}: il '
                                        'tuo ${paesiInOrdine(visite).indexOf(appena) + 1}° '
                                        'paese'
                                  : '${nomeDelPaese(ora!) ?? ora}: grattalo '
                                        'col dito',
                              fatto: appena != null,
                            ).sboccia(context),
                          ),
                      ],
                    ),
                  ).entra(context, ritardo: Ritmo.passo),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      12,
                      20,
                      BarraPrincipale.ingombro + mq.padding.bottom,
                    ),
                    children: [
                      if (paesi.isNotEmpty) ...[
                        EtichettaSezione(
                          'Paesi · ${paesi.length}',
                          colore: _velato,
                        ),
                        _Paesi(
                          paesi: paesi,
                          daScoprire: daScoprire.toSet(),
                          onTap: (p) => setState(() => _guardato = p),
                        ).entra(context, ritardo: Ritmo.passo * 2),
                      ],
                      if (citta.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        EtichettaSezione(
                          'Città · ${citta.length}',
                          colore: _velato,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            [for (final c in citta) c.citta].join(', '),
                            style: Testi.secondario.copyWith(color: _velato),
                          ),
                        ).entra(context, ritardo: Ritmo.passo * 3),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  static String _quanti(int paesi, int citta) => [
    quanti(paesi, 'paese', 'paesi'),
    if (citta > 0) quanti(citta, 'città', 'città'),
  ].join(' e ');
}

/// «Portogallo: grattalo sul mappamondo» (tela, 95): nel riepilogo di un
/// viaggio che ha portato un paese nuovo, finché non lo si gratta.
class RigaDaGrattare extends StatelessWidget {
  const RigaDaGrattare({super.key, required this.paese});

  final String? paese;

  @override
  Widget build(BuildContext context) {
    final paese = this.paese;
    if (paese == null) return const SizedBox.shrink();
    final archivio = Servizi.of(context).archivio;
    return StreamBuilder<Set<String>>(
      stream: archivio.osservaPaesiScoperti(),
      builder: (context, scoperti) =>
          StreamBuilder<List<(Partecipazione, Viaggio)>>(
            stream: archivio.osservaMieiViaggi(),
            builder: (context, letti) {
              final viaggi = delPassaporto(
                letti.data ?? const [],
                DateTime.now(),
              );
              if (!scoperti.hasData ||
                  !daGrattare(
                    visiteDi(viaggi),
                    scoperti: scoperti.data!,
                    oggi: DateTime.now(),
                  ).contains(paese)) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: RigaScheda(
                  simbolo: icona(
                    ios: CupertinoIcons.globe,
                    android: Icons.public_rounded,
                  ),
                  titolo:
                      '${nomeDelPaese(paese) ?? paese}: grattalo sul '
                      'mappamondo',
                  sottotitolo: 'Un paese nuovo, sotto una patina',
                  onTap: () => apri<void>(context, const SchermataMappamondo()),
                ),
              );
            },
          ),
    );
  }
}

/// La capsula sotto il globo (tela, 95–97 e 145): che cosa grattare, bianca
/// sul blu della notte, e il paese appena scoperto, in cobalto.
class _Capsula extends StatelessWidget {
  const _Capsula({super.key, required this.testo, required this.fatto});

  final String testo;
  final bool fatto;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: testo,
    child: ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: fatto ? Colori.cobalto : Colori.bianco,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!fatto) ...[
              Icon(
                icona(
                  ios: CupertinoIcons.hand_draw,
                  android: Icons.touch_app_outlined,
                ),
                size: 18,
                color: Colori.inchiostro,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              testo,
              style: Testi.secondario.copyWith(
                color: fatto ? Colori.bianco : Colori.inchiostro,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// In cima alla scheda del globo, grandi: quanti paesi e quante città
/// (tela, 144).
class _Numeri extends StatelessWidget {
  const _Numeri({required this.paesi, required this.citta});

  final int paesi;
  final int citta;

  @override
  Widget build(BuildContext context) {
    Widget numero(int n, String cosa) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$n', style: Testi.codice(30).copyWith(color: Colori.bianco)),
        const SizedBox(height: 4),
        Text(
          cosa,
          style: Testi.didascalia.copyWith(
            color: Colori.bianco.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
    return Semantics(
      label: _SchermataMappamondoState._quanti(paesi, citta),
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
          child: Row(
            children: [
              numero(paesi, paesi == 1 ? 'paese' : 'paesi'),
              if (citta > 0) ...[
                const SizedBox(width: 22),
                numero(citta, 'città'),
              ],
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Il testo secondario sul blu della notte.
final _velato = Colori.bianco.withValues(alpha: 0.7);

/// I paesi grattati, due per riga, dal più recente (tela, 66): il codice in
/// cobalto e il nome. Toccandone uno il globo ci si gira.
class _Paesi extends StatelessWidget {
  const _Paesi({
    required this.paesi,
    required this.daScoprire,
    required this.onTap,
  });

  final List<String> paesi;

  /// Quelli ancora sotto la patina: il codice grigio, e «da grattare».
  final Set<String> daScoprire;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, vincoli) {
      final larghezza = (vincoli.maxWidth - 10) / 2;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final p in paesi)
            SizedBox(
              width: larghezza,
              child: Premibile(
                onTap: () => onTap(p),
                scala: 0.97,
                etichetta: [
                  nomeDelPaese(p) ?? p,
                  if (daScoprire.contains(p)) 'da grattare',
                  'mostralo sul globo',
                ].join(', '),
                child: ExcludeSemantics(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      color: Colori.bianco.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Text(
                          p,
                          style: Testi.codice(15).copyWith(
                            color: daScoprire.contains(p)
                                ? Colori.piombo
                                : Colori.cobaltoNotte,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nomeDelPaese(p) ?? p,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Testi.secondario.copyWith(
                                  color: Colori.bianco,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (daScoprire.contains(p))
                                Text(
                                  'da grattare',
                                  style: Testi.didascalia.copyWith(
                                    color: _velato,
                                    fontSize: 12,
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
            ),
        ],
      );
    },
  );
}
