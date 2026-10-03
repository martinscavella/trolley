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

/// Apre la lista. Con [scrivi] il campo in fondo prende subito la tastiera.
Future<void> apriCose(
  BuildContext context,
  String viaggioId, {
  bool scrivi = false,
}) => apri<void>(context, SchermataCose(viaggioId: viaggioId, scrivi: scrivi));

/// Le cose da portare (05-cose-da-portare.md, "Liste del viaggio"; tela, 20,
/// 22 e 23): in cima quanto è piena la valigia; sotto quello che manca e,
/// in fondo, quello che è già in valigia, che non sparisce (regola 6). Il
/// campo in fondo aggiunge una voce dopo l'altra.
///
/// Senza rete la lista si legge e si spunta; aggiungere, cambiare ed
/// eliminare richiedono la rete, e lo dicono prima (regola 5). Esiste anche
/// nelle idee: non ha bisogno di date (regola 4).
///
/// Nella 1.5 la lista è la propria, e la vede solo chi la scrive (regola 3):
/// in un viaggio con altri lo dice.
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
  bool _avviata = false;

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

  Future<void> _altro(List<VoceLista> voci) => scegliAzione(context, [
    if (voci.any((v) => v.spuntata))
      AzioneMenu(
        'Rimetti tutto da mettere',
        () => rimettiTuttoDaMettere(context, voci: voci),
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
            builder: (context, partecipanti) {
              final (v, elenco) = (viaggio.data, voci.data);
              if (v == null || elenco == null) {
                return const Pagina(corpo: Center(child: IndicatoreAttivita()));
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
                        conAltri: (partecipanti.data?.length ?? 0) > 1,
                      ),
                    ),
              );
            },
          ),
    ),
  );

  Widget _pagina(
    Viaggio viaggio,
    List<VoceLista> voci, {
    required bool rete,
    required List<OperazioneInCoda> coda,
    required bool conAltri,
  }) {
    final lista = ordinaVoci(
      voci.map((v) => v.daPortare),
      trattenute: _trattenute,
    );
    final spunteInCoda = [
      for (final op in coda)
        if (op.gesto == GestoOffline.spuntaVoce) op,
    ];
    final sotto = [
      titoloViaggio(viaggio),
      quandoViaggio(viaggio).toLowerCase(),
    ].join(' · ');
    return Pagina(
      azioni: [
        if (!rete) const SeiOffline(),
        PulsanteTondo(
          icona: icona(
            ios: CupertinoIcons.ellipsis,
            android: Icons.more_horiz_rounded,
          ),
          etichetta: 'Altro',
          onPressed: voci.any((v) => v.spuntata) ? () => _altro(voci) : null,
        ),
      ],
      inBasso: _Compositore(viaggio: viaggio, rete: rete, fuoco: widget.scrivi),
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
                  if (conAltri) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          icona(
                            ios: CupertinoIcons.lock,
                            android: Icons.lock_outline_rounded,
                          ),
                          size: 14,
                          color: Colori.grafite,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'La vedi solo tu',
                            style: Testi.didascalia.copyWith(
                              color: Colori.grafite,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ).entra(context),
            const SizedBox(height: 16),
            if (voci.isEmpty)
              Pannello(
                child: Text(
                  'Quello che non vuoi dimenticare, una cosa per riga. Mentre '
                  'fai la valigia la spunti, anche senza rete: non sparisce, '
                  'scende in fondo.',
                  style: Testi.secondario.copyWith(color: Colori.grafite),
                ),
              ).entra(context, ritardo: Ritmo.passo)
            else
              _Conteggio(
                lista: lista,
                inAttesa: !rete && spunteInCoda.isNotEmpty,
              ).entra(context, ritardo: Ritmo.passo),
            ProblemiDellaCoda(operazioni: spunteInCoda),
            if (lista.daMettere.isNotEmpty) ...[
              _Etichetta(
                'DA METTERE · ${lista.daMettere.length}',
                colore: Colori.cobalto,
              ),
              for (final (i, v) in lista.daMettere.indexed) ...[
                if (i > 0) const SizedBox(height: 8),
                RigaVoce(
                  key: ValueKey(v.id),
                  voce: v.voce,
                  conAltri: conAltri,
                  onSpunta: () => _spunta(v.voce, lista),
                ),
              ],
            ],
            if (lista.inValigia.isNotEmpty) ...[
              _Etichetta('IN VALIGIA · ${lista.inValigia.length}'),
              for (final (i, v) in lista.inValigia.indexed) ...[
                if (i > 0) const SizedBox(height: 8),
                RigaVoce(
                  key: ValueKey(v.id),
                  voce: v.voce,
                  conAltri: conAltri,
                  onSpunta: () => _spunta(v.voce, lista),
                ),
              ],
            ],
          ],
        ),
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

/// Una voce (tela, 20): il cerchio da spuntare a sinistra, il testo, quante
/// a destra. In valigia il testo si barra e si spegne, ma resta. Il cerchio
/// spunta; il resto della riga apre la voce.
class RigaVoce extends StatelessWidget {
  const RigaVoce({
    super.key,
    required this.voce,
    required this.onSpunta,
    this.conAltri = false,
  });

  final VoceLista voce;
  final VoidCallback onSpunta;
  final bool conAltri;

  @override
  Widget build(BuildContext context) {
    final v = voce;
    final quante = v.quantita > 1 ? '× ${v.quantita}' : null;
    final nome = [v.testo, ?quante].join(' ');
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
                  ? '$nome, in valigia. Tocca per rimetterla da mettere'
                  : '$nome, da mettere. Tocca per spuntarla',
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
                FoglioVoce(voce: v, conAltri: conAltri),
              ),
              scala: 0.98,
              etichetta: 'Cambia $nome',
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

/// Il campo in fondo (tela, 20): si scrive, invio, e il campo è pronto per la
/// prossima. Senza rete si spegne e dice perché (tela, 22).
class _Compositore extends StatefulWidget {
  const _Compositore({
    required this.viaggio,
    required this.rete,
    required this.fuoco,
  });

  final Viaggio viaggio;
  final bool rete;
  final bool fuoco;

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
      await aggiungiLaVoce(context, viaggio: widget.viaggio, testo: testo);
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
            placeholder: 'Aggiungi una cosa…',
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
              hintText: 'Aggiungi una cosa…',
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
                    label: 'Aggiungi una cosa da portare',
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
class SezioneCose extends StatelessWidget {
  const SezioneCose({super.key, required this.viaggio});

  final Viaggio viaggio;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<VoceLista>>(
    stream: Servizi.of(context).archivio.osservaVoci(viaggio.id),
    builder: (context, snapshot) {
      final voci = snapshot.data ?? const <VoceLista>[];
      final lista = ordinaVoci(voci.map((v) => v.daPortare));
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
                    'Quello che non vuoi dimenticare, da spuntare mentre fai '
                    'la valigia: anche senza rete.',
                    style: Testi.secondario.copyWith(color: Colori.grafite),
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
            _Riassunto(lista: lista, onTutte: tutte, onNuova: scrivi),
        ],
      );
    },
  );
}

class _Riassunto extends StatelessWidget {
  const _Riassunto({
    required this.lista,
    required this.onTutte,
    required this.onNuova,
  });

  final ListaOrdinata<VoceLista> lista;
  final VoidCallback onTutte;
  final VoidCallback onNuova;

  @override
  Widget build(BuildContext context) {
    final prossima = lista.prossima?.voce.testo;
    final sotto = lista.valigiaFatta
        ? 'Tutto in valigia'
        : prossima == null
        ? ''
        : 'Prossima: $prossima';
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
              etichetta: '${lista.fatte} su ${lista.tutte} in valigia. $sotto',
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
