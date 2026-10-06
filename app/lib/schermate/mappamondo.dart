import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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

/// Dove guarda il globo di chi non ha ancora un viaggio chiuso: l'Europa.
const _europa = (lat: 42.0, lon: 12.0);

/// Il mappamondo (10, regola 5; tela, 66): i paesi e le città di ogni viaggio
/// chiuso, verificato o no — è il ricordo, non il merito. Il globo si gira
/// col dito, e toccando un paese ci si gira da soli. Si legge dalla copia, e
/// i confini sono nell'app (ADR-005): funziona anche senza rete.
class SchermataMappamondo extends StatefulWidget {
  const SchermataMappamondo({super.key});

  @override
  State<SchermataMappamondo> createState() => _SchermataMappamondoState();
}

class _SchermataMappamondoState extends State<SchermataMappamondo> {
  late Stream<List<(Partecipazione, Viaggio)>> _miei;
  late Stream<Set<String>> _scoperti;
  ElencoDestinazioni? _elenco;
  bool _avviata = false;

  /// Il paese toccato nell'elenco, dove il globo si gira.
  String? _guardato;

  /// Il paese appena scoperto, per dire quale è: «il tuo 7° paese».
  String? _appena;
  Timer? _dimentica;

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
    super.dispose();
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

  /// Dove sta un paese sul globo: il suo punto nell'elenco, o quello di una
  /// città del viaggio per i paesi che l'elenco tiene dentro un altro (la
  /// Martinica).
  Map<String, Coordinate> _punti(List<Meta> mete) {
    final elenco = _elenco;
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

  @override
  Widget build(BuildContext context) => StreamBuilder<Set<String>>(
    stream: _scoperti,
    builder: (context, scoperti) => StreamBuilder<List<(Partecipazione, Viaggio)>>(
      stream: _miei,
      builder: (context, letti) {
        final viaggi = delPassaporto(letti.data ?? const [], DateTime.now());
        final mete = meteDi(viaggi);
        final visite = visiteDi(viaggi);
        final paesi = paesiGrattati(mete);
        final citta = cittaGrattate(mete);
        final punti = _punti(mete);
        // Finché non si sa che cosa è già scoperto, non si chiede di grattare.
        final daScoprire = scoperti.hasData
            ? daGrattare(visite, scoperti: scoperti.data!, oggi: DateTime.now())
            : const <String>[];
        final ora = daScoprire.firstOrNull;
        final centro =
            punti[_guardato] ??
            (paesi.isEmpty ? null : punti[paesi.first]) ??
            _europa;
        final appena = _appena;
        final mq = MediaQuery.of(context);
        return Pagina(
          corpo: Builder(
            builder: (context) => Padding(
              padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TitoloPagina(
                      'Mappamondo',
                      sottotitolo: paesi.isEmpty
                          ? 'Si colora con i viaggi chiusi, verificati o no: '
                                'il primo paese arriva con il primo viaggio.'
                          : ora != null
                          ? '${_quanti(paesi.length, citta.length)}. Un '
                                'paese nuovo: grattalo col dito.'
                          : '${_quanti(paesi.length, citta.length)}: ogni '
                                'viaggio chiuso, verificato o no.',
                    ).entra(context),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Pannello(
                      raggio: 24,
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
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: mq.size.height * 0.36,
                            ),
                            child: Center(
                              child: Mappamondo(
                                grattati: {
                                  for (final p in paesi)
                                    if (!daScoprire.contains(p)) p,
                                },
                                centro: centro,
                                punti: punti,
                                daGrattare: ora,
                                onScoperto: _scoperto,
                                etichetta: ora != null
                                    ? 'Mappamondo: ${nomeDelPaese(ora) ?? ora} '
                                          'da grattare'
                                    : 'Mappamondo: '
                                          '${quanti(paesi.length, 'paese visitato', 'paesi visitati')}',
                              ),
                            ),
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
                        mq.padding.bottom + 32,
                      ),
                      children: [
                        if (paesi.isNotEmpty) ...[
                          EtichettaSezione('Paesi · ${paesi.length}'),
                          _Paesi(
                            paesi: paesi,
                            daScoprire: daScoprire.toSet(),
                            onTap: (p) => setState(() => _guardato = p),
                          ).entra(context, ritardo: Ritmo.passo * 2),
                        ],
                        if (citta.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          EtichettaSezione('Città · ${citta.length}'),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              [for (final c in citta) c.citta].join(', '),
                              style: Testi.secondario.copyWith(
                                color: Colori.grafite,
                              ),
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
      },
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

/// La capsula sotto il globo (tela, 95–97): che cosa grattare, d'inchiostro,
/// e il paese appena scoperto, in cobalto.
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
          color: fatto ? Colori.cobalto : Colori.inchiostro,
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
                color: Colori.bianco,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              testo,
              style: Testi.secondario.copyWith(
                color: Colori.bianco,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

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
                      color: Colori.bianco,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Text(
                          p,
                          style: Testi.codice(15).copyWith(
                            color: daScoprire.contains(p)
                                ? Colori.piombo
                                : Colori.cobalto,
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
                                  color: Colori.inchiostro,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (daScoprire.contains(p))
                                Text(
                                  'da grattare',
                                  style: Testi.didascalia.copyWith(
                                    color: Colori.grafite,
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
