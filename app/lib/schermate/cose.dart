import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../aspetto/elementi.dart';
import '../aspetto/formati.dart';
import '../aspetto/movimento.dart';
import '../aspetto/pagina.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../aspetto/timbro.dart';
import '../aspetto/valigia.dart';
import '../dati/database.dart';
import '../dati/errori.dart';
import '../dati/lettura.dart';
import '../dominio/liste.dart';
import '../servizi.dart';
import 'con_la_rete.dart';
import 'foglio_voce.dart';
import 'gesti_voce.dart';
import 'problemi_coda.dart';
import 'spese.dart' show elenco;

/// Apre le cose da portare. Con [scrivi] il campo in fondo prende subito la
/// tastiera.
Future<void> apriCose(
  BuildContext context,
  String viaggioId, {
  bool scrivi = false,
}) => apri<void>(context, SchermataCose(viaggioId: viaggioId, scrivi: scrivi));

/// Le cose da portare (05-cose-da-portare.md, "Liste del viaggio"; tela, 20,
/// 22, 23, 42 e 44). Quando nel viaggio c'è qualcun altro le liste sono due,
/// con il selettore in cima: «Del viaggio», che vedono tutti e dove ogni voce
/// dice chi la porta, e «Mie», che vede solo la persona (regole 1–3). Da soli
/// c'è la propria, e basta.
///
/// In ciascuna, sotto quello che manca e in fondo quello che è già in valigia,
/// che non sparisce (regola 6); nella propria, in cima, quanto è piena la
/// valigia. Il campo in fondo aggiunge una voce dopo l'altra alla lista che
/// si sta guardando. Se chi portava qualcosa lascia il viaggio, lo dice un
/// avviso in cima alla lista del viaggio.
///
/// Senza rete le liste si leggono e si spuntano; aggiungere, cambiare,
/// assegnare e spostare richiedono la rete, e lo dicono prima (regola 5).
/// Esistono anche nelle idee: non hanno bisogno di date (regola 4).
class SchermataCose extends StatefulWidget {
  const SchermataCose({
    super.key,
    required this.viaggioId,
    this.scrivi = false,
  });

  final String viaggioId;
  final bool scrivi;

  @override
  State<SchermataCose> createState() => _SchermataCoseState();
}

class _SchermataCoseState extends State<SchermataCose> {
  late Stream<Viaggio?> _viaggio;
  late Stream<List<VoceLista>> _voci;
  late Stream<List<OperazioneInCoda>> _coda;
  late Stream<List<(Partecipazione, Utente?)>> _partecipanti;
  late Stream<Map<String, String>> _nomi;
  late Stream<Set<String>> _viste;
  bool _avviata = false;

  /// La lista scelta nel selettore. All'inizio quella del viaggio, se non è
  /// vuota mentre la propria ha già qualcosa: chi aveva la sua lista prima
  /// che arrivassero gli altri la ritrova. Scelta una volta, non cambia più
  /// da sola mentre la si guarda.
  TipoLista? _scelta;

  /// Le voci appena toccate, che restano un attimo dov'erano.
  final _trattenute = <String>{};
  final _timer = <String, Timer>{};

  /// Quanto resta al suo posto una voce appena spuntata.
  static const trattieni = Duration(milliseconds: 900);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_avviata) return;
    _avviata = true;
    final archivio = Servizi.of(context).archivio;
    _viaggio = archivio.osservaViaggio(widget.viaggioId);
    _voci = archivio.osservaVoci(widget.viaggioId);
    _coda = archivio.coda.osserva(widget.viaggioId);
    _partecipanti = archivio.osservaPartecipanti(widget.viaggioId);
    _nomi = archivio.osservaNomi(widget.viaggioId);
    _viste = archivio.osservaVociLasciateViste(widget.viaggioId);
    unawaited(segnaAperturaSenzaRete(context, 'liste'));
  }

  @override
  void dispose() {
    for (final t in _timer.values) {
      t.cancel();
    }
    super.dispose();
  }

  Future<void> _spunta(VoceLista voce, ListaOrdinata<VoceLista> lista) async {
    final spuntata = !voce.spuntata;
    setState(() => _trattenute.add(voce.id));
    _timer[voce.id]?.cancel();
    _timer[voce.id] = Timer(trattieni, () {
      _timer.remove(voce.id);
      if (mounted) setState(() => _trattenute.remove(voce.id));
    });
    // L'ultima che manca: la valigia è fatta, e si sente.
    final ultima = spuntata && lista.fatte == lista.tutte - 1;
    await spuntaLaVoce(context, voce: voce, spuntata: spuntata);
    if (ultima) HapticFeedback.heavyImpact();
  }

  Future<void> _altro(TipoLista lista, List<VoceLista> daRimettere) =>
      scegliAzione(context, [
        if (daRimettere.isNotEmpty)
          AzioneMenu(
            lista == TipoLista.viaggio
                ? 'Rimetti da mettere quelle che porti tu'
                : 'Rimetti tutto da mettere',
            () => rimettiTuttoDaMettere(context, voci: daRimettere),
          ),
      ]);

  @override
  Widget build(BuildContext context) => StreamBuilder<Viaggio?>(
    stream: _viaggio,
    builder: (context, viaggio) => StreamBuilder<List<VoceLista>>(
      stream: _voci,
      builder: (context, voci) =>
          StreamBuilder<List<(Partecipazione, Utente?)>>(
            stream: _partecipanti,
            builder: (context, partecipanti) =>
                StreamBuilder<Map<String, String>>(
                  stream: _nomi,
                  builder: (context, nomi) => StreamBuilder<Set<String>>(
                    stream: _viste,
                    builder: (context, viste) {
                      final (v, elenco) = (viaggio.data, voci.data);
                      if (v == null || elenco == null) {
                        return const Pagina(
                          corpo: Center(child: IndicatoreAttivita()),
                        );
                      }
                      return ConLaRete(
                        builder: (context, rete) =>
                            StreamBuilder<List<OperazioneInCoda>>(
                              stream: _coda,
                              builder: (context, coda) => _pagina(
                                v,
                                elenco,
                                rete: rete,
                                coda: coda.data ?? const [],
                                presenti: {
                                  for (final (p, _)
                                      in partecipanti.data ??
                                          const <(Partecipazione, Utente?)>[])
                                    p.utenteId,
                                },
                                nomi: nomi.data ?? const {},
                                viste: viste.data ?? const {},
                              ),
                            ),
                      );
                    },
                  ),
                ),
          ),
    ),
  );

  Widget _pagina(
    Viaggio viaggio,
    List<VoceLista> voci, {
    required bool rete,
    required List<OperazioneInCoda> coda,
    required Set<String> presenti,
    required Map<String, String> nomi,
    required Set<String> viste,
  }) {
    final io = Servizi.of(context).archivio.io ?? '';
    final delViaggio = [
      for (final v in voci)
        if (v.tipo == TipoLista.viaggio.codice) v,
    ];
    final mie = [
      for (final v in voci)
        if (v.tipo == TipoLista.personale.codice) v,
    ];
    final due = dueListe(
      conAltri: presenti.length > 1,
      vociDelViaggio: delViaggio.isNotEmpty,
    );
    final lista = due
        ? _scelta ??= delViaggio.isEmpty && mie.isNotEmpty
              ? TipoLista.personale
              : TipoLista.viaggio
        : TipoLista.personale;
    final visibili = lista == TipoLista.viaggio ? delViaggio : mie;
    String? porta(VoceLista v) => chiLaPorta(v.assegnatoA, presenti);
    final ordinata = ordinaVoci(
      visibili.map((v) => v.daPortare),
      trattenute: _trattenute,
    );
    final daRimettere = [
      for (final v in visibili)
        if (siRimetteDaMettere(
          lista: lista,
          spuntata: v.spuntata,
          portaChi: porta(v),
          io: io,
        ))
          v,
    ];
    final lasciate = lista == TipoLista.viaggio
        ? vociLasciate(
            delViaggio.map(
              (v) => VoceLasciata(
                voce: v,
                id: v.id,
                lasciataDa: v.lasciataDa == io ? null : v.lasciataDa,
                portaChi: porta(v),
                creataIl: v.creata,
              ),
            ),
            viste: viste,
          )
        : const <String, List<VoceLista>>{};
    final spunteInCoda = [
      for (final op in coda)
        if (op.gesto == GestoOffline.spuntaVoce) op,
    ];
    final sotto = [
      titoloViaggio(viaggio),
      quandoViaggio(viaggio).toLowerCase(),
    ].join(' · ');
    Widget riga(VoceDaPortare<VoceLista> v) {
      final chi = porta(v.voce);
      return RigaVoce(
        key: ValueKey(v.id),
        voce: v.voce,
        dueListe: due,
        delViaggio: lista == TipoLista.viaggio,
        porta: chi == null
            ? null
            : chi == io
            ? 'Tu'
            : nomi[chi] ?? '?',
        nomePorta: chi == null ? null : nomi[chi] ?? '?',
        onSpunta: () => _spunta(v.voce, ordinata),
      );
    }

    return Pagina(
      azioni: [
        if (!rete) const SeiOffline(),
        PulsanteTondo(
          icona: icona(
            ios: CupertinoIcons.ellipsis,
            android: Icons.more_horiz_rounded,
          ),
          etichetta: 'Altro',
          onPressed: daRimettere.isNotEmpty
              ? () => _altro(lista, daRimettere)
              : null,
        ),
      ],
      inBasso: _Compositore(
        viaggio: viaggio,
        rete: rete,
        fuoco: widget.scrivi,
        lista: lista,
        dueListe: due,
      ),
      corpo: Builder(
        builder: (context) => ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.paddingOf(context).top + 8,
            20,
            MediaQuery.paddingOf(context).bottom + 120,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'Cose da portare',
                      style: Testi.titolo.copyWith(color: Colori.inchiostro),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    sotto,
                    style: Testi.secondario.copyWith(color: Colori.grafite),
                  ),
                ],
              ),
            ).entra(context),
            if (due) ...[
              const SizedBox(height: 16),
              _SceltaLista(
                lista: lista,
                delViaggio: delViaggio.length,
                mie: mie.length,
                onScegli: (l) => setState(() => _scelta = l),
              ).entra(context, ritardo: Ritmo.passo),
              if (visibili.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                  child: Text(
                    lista == TipoLista.viaggio
                        ? 'La vedete tutti: chi porta cosa, perché nessuno '
                              'porti due caricabatterie.'
                        : 'Le vedi solo tu: gli altri del viaggio non le '
                              'vedono.',
                    style: Testi.didascalia.copyWith(color: Colori.grafite),
                  ),
                ),
            ],
            for (final MapEntry(key: chi, value: cose) in lasciate.entries) ...[
              const SizedBox(height: 12),
              Avviso(
                icona: icona(
                  ios: CupertinoIcons.person_2,
                  android: Icons.people_outline_rounded,
                ),
                inizio: '${nomi[chi] ?? 'Qualcuno'} ha lasciato il viaggio:',
                testo: vociTornateLibere([for (final v in cose) v.testo]),
                azioni: [
                  PulsantePiccolo(
                    etichetta: 'Ho capito',
                    onPressed: () => Servizi.of(context).archivio
                        .vociLasciateViste(viaggio.id, [
                          for (final v in cose) v.id,
                        ]),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            if (visibili.isEmpty)
              Pannello(
                child: Text(switch ((lista, due)) {
                  (TipoLista.viaggio, _) =>
                    'Qui le cose che servono a tutti, come l\'adattatore o '
                        'la crema solare. Nella voce si dice chi la porta: '
                        'così niente arriva due volte e niente manca.',
                  (TipoLista.personale, true) =>
                    'Qui le cose che servono solo a te, come lo spazzolino '
                        'o le medicine. Le vedi solo tu, e le spunti anche '
                        'senza rete.',
                  (TipoLista.personale, false) =>
                    'Quello che non vuoi dimenticare, una cosa per riga. '
                        'Mentre fai la valigia la spunti, anche senza rete: '
                        'non sparisce, scende in fondo.',
                }, style: Testi.secondario.copyWith(color: Colori.grafite)),
              ).entra(context, ritardo: Ritmo.passo)
            else if (lista == TipoLista.personale)
              _Conteggio(
                lista: ordinata,
                inAttesa: !rete && spunteInCoda.isNotEmpty,
              ).entra(context, ritardo: Ritmo.passo),
            ProblemiDellaCoda(operazioni: spunteInCoda),
            if (ordinata.daMettere.isNotEmpty) ...[
              _Etichetta(
                '${lista == TipoLista.viaggio ? 'DA PORTARE' : 'DA METTERE'}'
                ' · ${ordinata.daMettere.length}',
                colore: Colori.cobalto,
              ),
              for (final (i, v) in ordinata.daMettere.indexed) ...[
                if (i > 0) const SizedBox(height: 8),
                riga(v),
              ],
            ],
            if (ordinata.inValigia.isNotEmpty) ...[
              _Etichetta('IN VALIGIA · ${ordinata.inValigia.length}'),
              for (final (i, v) in ordinata.inValigia.indexed) ...[
                if (i > 0) const SizedBox(height: 8),
                riga(v),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// «Crema solare e Ombrellone, che portava, sono tornate libere.» Oltre tre
/// voci, le prime due e quante altre.
String vociTornateLibere(List<String> testi) {
  final cose = testi.length <= 3
      ? elenco(testi)
      : '${testi.take(2).join(', ')} e altre ${testi.length - 2}';
  return testi.length == 1
      ? '$cose, che portava, è tornata libera.'
      : '$cose, che portava, sono tornate libere.';
}

/// Il selettore fra le due liste (tela, 42): una scheda bianca con due
/// metà, quella scelta d'inchiostro. Ciascuna dice quante voci ha.
class _SceltaLista extends StatelessWidget {
  const _SceltaLista({
    required this.lista,
    required this.delViaggio,
    required this.mie,
    required this.onScegli,
  });

  final TipoLista lista;
  final int delViaggio;
  final int mie;
  final ValueChanged<TipoLista> onScegli;

  @override
  Widget build(BuildContext context) {
    Widget meta(TipoLista l, String testo, String etichetta) {
      final scelta = l == lista;
      return Expanded(
        child: Semantics(
          selected: scelta,
          child: Premibile(
            onTap: () => onScegli(l),
            scala: 0.97,
            etichetta: etichetta,
            child: AnimatedContainer(
              duration: movimentoRidotto(context) ? Duration.zero : Ritmo.breve,
              curve: Ritmo.curva,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scelta ? Colori.inchiostro : Colori.bianco,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                testo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
      ),
      child: Row(
        children: [
          meta(
            TipoLista.viaggio,
            'Del viaggio · $delViaggio',
            'Lista del viaggio, $delViaggio',
          ),
          const SizedBox(width: 4),
          meta(TipoLista.personale, 'Mie · $mie', 'Le tue cose, $mie'),
        ],
      ),
    );
  }
}

class _Etichetta extends StatelessWidget {
  const _Etichetta(this.testo, {this.colore = Colori.grafite});

  final String testo;
  final Color colore;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
    child: Semantics(
      header: true,
      child: Text(testo, style: Testi.sezione.copyWith(color: colore)),
    ),
  );
}

/// Quanto è piena la valigia (tela, 20): quante in valigia su quante, una
/// tacca per voce. Quando è tutto dentro, il timbro (tela, 23).
class _Conteggio extends StatelessWidget {
  const _Conteggio({required this.lista, required this.inAttesa});

  final ListaOrdinata<VoceLista> lista;

  /// Senza rete, con delle spunte che aspettano di partire.
  final bool inAttesa;

  @override
  Widget build(BuildContext context) {
    final (fatte, tutte) = (lista.fatte, lista.tutte);
    final mancano = tutte - fatte;
    final sotto = lista.valigiaFatta
        ? 'Tutto in valigia. Se la rifai al ritorno, «…» in alto le rimette '
              'da mettere.'
        : inAttesa
        ? 'Le spunte restano qui e partono quando torna la rete.'
        : fatte == 0
        ? 'Tocca il cerchio quando la metti in valigia: la voce scende in '
              'fondo, non sparisce.'
        : mancano == 1
        ? 'Ne manca una.'
        : 'Ne mancano $mancano.';
    return Semantics(
      container: true,
      label: lista.valigiaFatta
          ? 'Valigia fatta: $tutte su $tutte in valigia'
          : '$fatte su $tutte in valigia',
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            decoration: BoxDecoration(
              color: Colori.bianco,
              borderRadius: BorderRadius.circular(20),
            ),
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'IN VALIGIA',
                    style: Testi.sezione.copyWith(color: Colori.grafite),
                  ),
                  const SizedBox(height: 6),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '$fatte '),
                        TextSpan(
                          text: 'di $tutte',
                          style: Testi.titoli(
                            20,
                            altezza: 1.05,
                          ).copyWith(color: Colori.grafite),
                        ),
                      ],
                    ),
                    style: Testi.titoli(
                      34,
                      altezza: 1.05,
                    ).copyWith(color: Colori.inchiostro),
                  ),
                  const SizedBox(height: 12),
                  BarraValigia(fatte: fatte, tutte: tutte),
                  const SizedBox(height: 10),
                  Text(
                    sotto,
                    style: Testi.didascalia.copyWith(color: Colori.ardesia),
                  ),
                ],
              ),
            ),
          ),
          if (lista.valigiaFatta)
            Positioned(
              right: 18,
              top: 12,
              child: const Timbro('FATTA', sotto: 'VALIGIA').sboccia(context),
            ),
        ],
      ),
    );
  }
}

/// Una voce (tela, 20 e 42): il cerchio da spuntare a sinistra, il testo,
/// quante e, nella lista del viaggio, chi la porta o «Libera». In valigia il
/// testo si barra e si spegne, ma resta. Il cerchio spunta; il resto della
/// riga apre la voce.
class RigaVoce extends StatelessWidget {
  const RigaVoce({
    super.key,
    required this.voce,
    required this.onSpunta,
    this.dueListe = false,
    this.delViaggio = false,
    this.porta,
    this.nomePorta,
  });

  final VoceLista voce;
  final VoidCallback onSpunta;

  /// Si vedono tutte e due le liste: il foglio della voce lo ricorda, e
  /// propone di spostarla.
  final bool dueListe;

  /// È nella lista del viaggio: dice chi la porta.
  final bool delViaggio;

  /// Chi la porta, come si dice: «Tu», «Marco»; `null` se nessuno.
  final String? porta;

  /// Il nome vero di chi la porta, per le sue iniziali.
  final String? nomePorta;

  @override
  Widget build(BuildContext context) {
    final v = voce;
    final quante = v.quantita > 1 ? '× ${v.quantita}' : null;
    final chi = !delViaggio
        ? null
        : porta == null
        ? 'libera'
        : 'la porta ${porta == 'Tu' ? 'tu' : porta}';
    final nome = [v.testo, ?quante].join(' ');
    final descritta = [nome, ?chi].join(', ');
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
      decoration: BoxDecoration(
        color: Colori.bianco,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Semantics(
            checked: v.spuntata,
            child: Premibile(
              onTap: onSpunta,
              scala: 0.88,
              etichetta: v.spuntata
                  ? '$descritta, in valigia. Tocca per rimetterla da mettere'
                  : '$descritta, da mettere. Tocca per spuntarla',
              child: SizedBox.square(
                dimension: 48,
                child: Center(child: CerchioSpunta(spuntata: v.spuntata)),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Premibile(
              onTap: () => apriFoglio<void>(
                context,
                FoglioVoce(voce: v, dueListe: dueListe),
              ),
              scala: 0.98,
              etichetta: 'Cambia $descritta',
              child: ExcludeSemantics(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Row(
                    children: [
                      Expanded(
                        child: AnimatedDefaultTextStyle(
                          duration: movimentoRidotto(context)
                              ? Duration.zero
                              : Ritmo.breve,
                          style: Testi.evidenza.copyWith(
                            color: v.spuntata
                                ? Colori.grafite
                                : Colori.inchiostro,
                            fontWeight: FontWeight.w600,
                            decoration: v.spuntata
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                            decorationColor: Colori.grafite.withValues(
                              alpha: 0.6,
                            ),
                          ),
                          child: Text(
                            v.testo,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      if (quante != null) ...[
                        const SizedBox(width: 10),
                        Text(
                          quante,
                          style: Testi.numero.copyWith(
                            fontSize: 14,
                            color: v.spuntata ? Colori.piombo : Colori.grafite,
                          ),
                        ),
                      ],
                      if (delViaggio) ...[
                        const SizedBox(width: 10),
                        if (porta == null)
                          const _Libera()
                        else
                          _ChiLaPorta(porta: porta!, nome: nomePorta ?? porta!),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// «Libera»: una voce del viaggio che non porta nessuno (tela, 42).
class _Libera extends StatelessWidget {
  const _Libera();

  @override
  Widget build(BuildContext context) => Container(
    height: 26,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colori.foschia,
      borderRadius: BorderRadius.circular(13),
    ),
    child: Text(
      'LIBERA',
      style: Testi.sezione.copyWith(
        color: Colori.grafite,
        letterSpacing: 1.1,
        height: 1,
      ),
    ),
  );
}

/// Chi porta una voce del viaggio: le sue iniziali e «Tu» o il nome (tela,
/// 42).
class _ChiLaPorta extends StatelessWidget {
  const _ChiLaPorta({required this.porta, required this.nome});

  final String porta;
  final String nome;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 110),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Avatar(nome: nome, dimensione: 24),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            porta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Testi.didascalia.copyWith(
              color: Colori.ardesia,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Il campo in fondo (tela, 20): si scrive, invio, e il campo è pronto per la
/// prossima. Senza rete si spegne e dice perché (tela, 22).
class _Compositore extends StatefulWidget {
  const _Compositore({
    required this.viaggio,
    required this.rete,
    required this.fuoco,
    required this.lista,
    required this.dueListe,
  });

  final Viaggio viaggio;
  final bool rete;
  final bool fuoco;

  /// La lista che si sta guardando: la voce nuova finisce lì.
  final TipoLista lista;
  final bool dueListe;

  String get segnaposto => switch ((lista, dueListe)) {
    (TipoLista.viaggio, _) => 'Aggiungi alla lista del viaggio…',
    (TipoLista.personale, true) => 'Aggiungi alle tue cose…',
    (TipoLista.personale, false) => 'Aggiungi una cosa…',
  };

  @override
  State<_Compositore> createState() => _CompositoreState();
}

class _CompositoreState extends State<_Compositore> {
  final _testo = TextEditingController();
  final _nodo = FocusNode();
  bool _inCorso = false;

  @override
  void initState() {
    super.initState();
    _testo.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _testo.dispose();
    _nodo.dispose();
    super.dispose();
  }

  bool get _pronto =>
      widget.rete && !_inCorso && testoVoce(_testo.text) != null;

  /// Il campo si svuota subito, pronto per la prossima: la voce compare
  /// quando il server la conferma. Se non arriva, il testo torna nel campo.
  Future<void> _aggiungi() async {
    final testo = testoVoce(_testo.text);
    if (testo == null || !widget.rete || _inCorso) return;
    setState(() => _inCorso = true);
    _testo.clear();
    _nodo.requestFocus();
    try {
      await aggiungiLaVoce(
        context,
        viaggio: widget.viaggio,
        testo: testo,
        lista: widget.lista,
      );
    } on ErroreTrolley catch (e) {
      if (_testo.text.isEmpty) _testo.text = testo;
      if (mounted) mostraMessaggio(context, e.messaggio, errore: true);
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final attivo = widget.rete;
    final stile = Testi.campo.copyWith(color: Colori.inchiostro);
    final segnaposto = stile.copyWith(
      color: Colori.grafite.withValues(alpha: 0.8),
    );
    final formattatori = [
      LengthLimitingTextInputFormatter(lunghezzaMassimaVoce),
    ];
    final campo = suIOS
        ? CupertinoTextField(
            controller: _testo,
            focusNode: _nodo,
            enabled: attivo,
            autofocus: widget.fuoco && attivo,
            placeholder: widget.segnaposto,
            placeholderStyle: segnaposto,
            style: stile,
            cursorColor: Colori.cobalto,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: null,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            inputFormatters: formattatori,
            onSubmitted: (_) => _aggiungi(),
          )
        : TextField(
            controller: _testo,
            focusNode: _nodo,
            enabled: attivo,
            autofocus: widget.fuoco && attivo,
            style: stile,
            cursorColor: Colori.cobalto,
            decoration: InputDecoration.collapsed(
              hintText: widget.segnaposto,
              hintStyle: segnaposto,
            ),
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            inputFormatters: formattatori,
            onSubmitted: (_) => _aggiungi(),
          );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedOpacity(
          duration: Ritmo.breve,
          opacity: attivo ? 1 : 0.45,
          child: Container(
            height: 56,
            padding: const EdgeInsets.fromLTRB(18, 0, 6, 0),
            decoration: BoxDecoration(
              color: Colori.bianco,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colori.inchiostro.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    label: widget.lista == TipoLista.viaggio
                        ? 'Aggiungi alla lista del viaggio'
                        : 'Aggiungi una cosa da portare',
                    textField: true,
                    child: campo,
                  ),
                ),
                const SizedBox(width: 10),
                Premibile(
                  onTap: _pronto ? _aggiungi : null,
                  scala: 0.92,
                  etichetta: 'Aggiungi',
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colori.inchiostro.withValues(
                        alpha: _pronto ? 1 : 0.35,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: _inCorso
                        ? const Center(
                            child: IndicatoreAttivita(
                              colore: Colori.bianco,
                              piccolo: true,
                            ),
                          )
                        : const Icon(
                            Icons.add_rounded,
                            size: 22,
                            color: Colori.bianco,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!attivo) ...[
          const SizedBox(height: 8),
          Text(
            'Senza rete si spunta e basta: per aggiungere serve la '
            'connessione.',
            textAlign: TextAlign.center,
            style: Testi.didascalia.copyWith(color: Colori.grafite),
          ),
        ],
      ],
    );
  }
}

/// Le cose da portare nella schermata del viaggio (tela, 19): quante sono in
/// valigia, la prossima che manca, e il pulsante per aggiungerne una. C'è
/// anche nelle idee: la lista non aspetta le date.
///
/// Con dei compagni conta la propria valigia: le proprie voci e quelle del
/// viaggio che porta la persona. Le voci del viaggio che non porta ancora
/// nessuno si contano a parte, perché qualcuno le prenda.
class SezioneCose extends StatelessWidget {
  const SezioneCose({super.key, required this.viaggio});

  final Viaggio viaggio;

  @override
  Widget build(BuildContext context) {
    final archivio = Servizi.of(context).archivio;
    return StreamBuilder<List<VoceLista>>(
      stream: archivio.osservaVoci(viaggio.id),
      builder: (context, snapshot) =>
          StreamBuilder<List<(Partecipazione, Utente?)>>(
            stream: archivio.osservaPartecipanti(viaggio.id),
            builder: (context, partecipanti) {
              final voci = snapshot.data ?? const <VoceLista>[];
              final presenti = {
                for (final (p, _)
                    in partecipanti.data ?? const <(Partecipazione, Utente?)>[])
                  p.utenteId,
              };
              final io = archivio.io;
              String? porta(VoceLista v) => chiLaPorta(v.assegnatoA, presenti);
              final mie = [
                for (final v in voci)
                  if (v.tipo == TipoLista.personale.codice || porta(v) == io) v,
              ];
              final libere = presenti.length > 1
                  ? voci
                        .where(
                          (v) =>
                              v.tipo == TipoLista.viaggio.codice &&
                              porta(v) == null &&
                              !v.spuntata,
                        )
                        .length
                  : 0;
              final lista = ordinaVoci(
                (mie.isNotEmpty ? mie : voci).map((v) => v.daPortare),
              );
              void tutte() => apriCose(context, viaggio.id);
              void scrivi() => apriCose(context, viaggio.id, scrivi: true);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(child: TitoloSezione('Cose da portare')),
                      if (voci.isNotEmpty)
                        Premibile(
                          onTap: tutte,
                          etichetta: 'Tutte le cose da portare, ${voci.length}',
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 4, 4, 8),
                            child: Text(
                              'Tutte · ${voci.length}',
                              style: Testi.secondario.copyWith(
                                color: Colori.cobaltoScuro,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (voci.isEmpty)
                    Pannello(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quello che non vuoi dimenticare, da spuntare '
                            'mentre fai la valigia: anche senza rete.',
                            style: Testi.secondario.copyWith(
                              color: Colori.grafite,
                            ),
                          ),
                          const SizedBox(height: 10),
                          PulsantePiccolo(
                            etichetta: 'Scrivi la lista',
                            onPressed: scrivi,
                          ),
                        ],
                      ),
                    )
                  else
                    _Riassunto(
                      lista: lista,
                      prossima: mie.isNotEmpty,
                      libere: libere,
                      onTutte: tutte,
                      onNuova: scrivi,
                    ),
                ],
              );
            },
          ),
    );
  }
}

class _Riassunto extends StatelessWidget {
  const _Riassunto({
    required this.lista,
    required this.prossima,
    required this.libere,
    required this.onTutte,
    required this.onNuova,
  });

  final ListaOrdinata<VoceLista> lista;

  /// Si conta la propria valigia, e la prossima che manca è da mettere lì.
  final bool prossima;

  /// Le voci del viaggio che non porta ancora nessuno.
  final int libere;
  final VoidCallback onTutte;
  final VoidCallback onNuova;

  @override
  Widget build(BuildContext context) {
    final testo = prossima ? lista.prossima?.voce.testo : null;
    final sotto = lista.valigiaFatta
        ? 'Tutto in valigia'
        : testo == null
        ? ''
        : 'Prossima: $testo';
    final nessuno = switch (libere) {
      0 => '',
      1 => 'Una del viaggio non la porta ancora nessuno',
      _ => '$libere del viaggio non le porta ancora nessuno',
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colori.bianco,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Premibile(
              onTap: onTutte,
              scala: 0.98,
              etichetta: [
                '${lista.fatte} su ${lista.tutte} in valigia',
                sotto,
                nessuno,
              ].where((t) => t.isNotEmpty).join('. '),
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${lista.fatte} di ${lista.tutte}',
                          style: Testi.titoli(
                            26,
                            altezza: 1.1,
                          ).copyWith(color: Colori.inchiostro),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'in valigia',
                          style: Testi.didascalia.copyWith(
                            color: Colori.grafite,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    BarraValigia(
                      fatte: lista.fatte,
                      tutte: lista.tutte,
                      altezza: 8,
                    ),
                    if (sotto.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        sotto,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Testi.didascalia.copyWith(
                          color: lista.valigiaFatta
                              ? Colori.verde
                              : Colori.grafite,
                          fontWeight: lista.valigiaFatta
                              ? FontWeight.w600
                              : null,
                        ),
                      ),
                    ],
                    if (nessuno.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        nessuno,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Testi.didascalia.copyWith(
                          color: Colori.cobaltoScuro,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Premibile(
            onTap: onNuova,
            scala: 0.94,
            etichetta: 'Aggiungi una cosa da portare',
            child: ExcludeSemantics(
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colori.inchiostro,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: Colori.bianco,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Voce',
                      style: Testi.evidenza.copyWith(
                        color: Colori.bianco,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
