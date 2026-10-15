/// Una conversazione (5.4; 11, regola 4; tela, 78, 114, 115 e 116): solo fra
/// persone collegate, i propri messaggi in cobalto. Tenendo premuto un
/// messaggio ricevuto lo si copia o lo si segnala (12, regola 1); da «…» si
/// segnala o si blocca la persona, o si toglie il collegamento. La prima
/// volta che si è collegati con qualcuno, tre righe di prudenza (M10).
///
/// Quando il collegamento non c'è più la conversazione resta, senza poter
/// scrivere (P6), finché non la si toglie. Dipende dalla rete: i messaggi
/// non restano sul telefono, e senza notifiche arrivano mentre la si guarda.
/// Scrivere non ha un evento: nessuna soglia lo chiede (07, regola 2).
library;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../aspetto/biglietto.dart';
import '../aspetto/elementi.dart';
import '../aspetto/movimento.dart';
import '../aspetto/pagina.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../dati/errori.dart';
import '../dominio/collegamenti.dart';
import '../dominio/parte_pubblica.dart';
import '../servizi.dart';
import 'con_la_rete.dart';
import 'gesti_collegamenti.dart';
import 'persone_bloccate.dart';
import 'segnalazioni.dart';

/// Si chiude con `true` se la conversazione non c'è più per chi guarda —
/// tolta, o la persona bloccata —: chi l'ha aperta ricarica.
class SchermataConversazione extends StatefulWidget {
  const SchermataConversazione({
    super.key,
    required this.utenteId,
    required this.nome,
  });

  final String utenteId;

  /// Il nome com'era dove la si è aperta; `null` se ha chiuso l'account.
  final String? nome;

  @override
  State<SchermataConversazione> createState() => _SchermataConversazioneState();
}

class _SchermataConversazioneState extends State<SchermataConversazione>
    with WidgetsBindingObserver {
  final _testo = TextEditingController();
  Conversazione? _conversazione;
  List<Messaggio> _messaggi = const [];
  ErroreTrolley? _errore;
  bool _primaVolta = true;
  bool _chiedendo = false;
  bool _prudenza = false;
  bool _inPrimoPiano = true;
  Timer? _orologio;

  String? get _nome => _conversazione?.nome ?? widget.nome;
  bool get _collegati => _conversazione?.collegati ?? false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _testo.addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_primaVolta) {
      _primaVolta = false;
      unawaited(_carica());
      _orologio = Timer.periodic(intervalloConversazione, (_) => _aggiorna());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _orologio?.cancel();
    _testo.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState stato) {
    _inPrimoPiano = stato == AppLifecycleState.resumed;
    if (_inPrimoPiano) unawaited(_aggiorna());
  }

  Future<void> _carica() async {
    final servizi = Servizi.of(context);
    try {
      final c = await servizi.partePubblica.conversazione(widget.utenteId);
      final prudenza = c.collegati && !await servizi.archivio.prudenzaVista();
      if (!mounted) return;
      setState(() {
        _conversazione = c;
        _messaggi = unisci(_messaggi, c.messaggi);
        _errore = null;
        _prudenza = prudenza;
      });
    } on ErroreTrolley catch (e) {
      if (mounted) setState(() => _errore = e);
    }
  }

  /// I messaggi arrivati dopo l'ultimo che si ha, mentre la si guarda.
  Future<void> _aggiorna() async {
    final servizi = Servizi.of(context);
    if (_chiedendo ||
        !_inPrimoPiano ||
        _conversazione == null ||
        !servizi.rete.disponibile ||
        !(ModalRoute.of(context)?.isCurrent ?? false)) {
      return;
    }
    _chiedendo = true;
    try {
      final c = await servizi.partePubblica.conversazione(
        widget.utenteId,
        dopo: daQuandoChiedere(_messaggi),
      );
      if (!mounted) return;
      setState(() {
        _conversazione = Conversazione(
          utenteId: c.utenteId,
          nome: c.nome,
          collegati: c.collegati,
          dal: c.dal,
          messaggi: const [],
        );
        _messaggi = unisci(_messaggi, c.messaggi);
      });
    } on ErroreTrolley catch (e) {
      // Bloccati, o un profilo spento: la conversazione non c'è più.
      if (mounted && e.codice == CodiciServer.nonTrovato) {
        setState(() => _errore = e);
      }
    } finally {
      _chiedendo = false;
    }
  }

  Future<void> _manda([Messaggio? riprova]) async {
    final testo = (riprova?.testo ?? _testo.text).trim();
    if (testo.isEmpty) return;
    final servizi = Servizi.of(context);
    final inViaggio = Messaggio(
      id: riprova?.id ?? const Uuid().v4(),
      mio: true,
      testo: testo,
      scrittoIl: DateTime.now(),
      inViaggio: true,
    );
    setState(() {
      _messaggi = unisci(_messaggi, [inViaggio]);
      if (riprova == null) _testo.clear();
    });
    try {
      final arrivato = await servizi.partePubblica.scrivi(
        id: inViaggio.id,
        utenteId: widget.utenteId,
        testo: testo,
      );
      if (mounted) setState(() => _messaggi = unisci(_messaggi, [arrivato]));
    } on ErroreTrolley catch (e) {
      if (!mounted) return;
      setState(() => _messaggi = unisci(_messaggi, [inViaggio.nonPartito()]));
      mostraMessaggio(context, e.messaggio, errore: true);
      if (e.codice == CodiciServer.nonTrovato) unawaited(_carica());
    }
  }

  // ─── «…» e il messaggio tenuto premuto ───────────────────────────────────

  Future<void> _menu() {
    final nome = _nome;
    return scegliAzione(context, [
      if (nome != null) ...[
        AzioneMenu('Segnala $nome', () => _segnalaProfilo(nome)),
        AzioneMenu('Blocca $nome', () => _blocca(nome), pericolo: true),
      ],
      if (_collegati && nome != null)
        AzioneMenu('Togli il collegamento', _togliCollegamento, pericolo: true)
      else if (!_collegati)
        AzioneMenu(
          'Togli la conversazione',
          _togliConversazione,
          pericolo: true,
        ),
    ]);
  }

  Future<void> _segnalaProfilo(String nome) => _segnala(
    tipo: TipoSegnalato.profilo,
    oggettoId: widget.utenteId,
    nome: nome,
  );

  Future<void> _segnala({
    required TipoSegnalato tipo,
    required String oggettoId,
    required String nome,
  }) async {
    final servizi = Servizi.of(context);
    await segnala(
      context,
      tipo: tipo,
      oggettoId: oggettoId,
      utenteId: widget.utenteId,
      nome: nome,
    );
    if (!mounted) return;
    // Con «Blocca anche», acceso di partenza, non vi vedete più.
    final bloccate = await servizi.partePubblica.personeBloccate().catchError(
      (_) => const <PersonaBloccata>[],
    );
    if (mounted && bloccate.any((b) => b.id == widget.utenteId)) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _blocca(String nome) async {
    final fatto = await blocca(
      context,
      utenteId: widget.utenteId,
      nome: nome,
      da: DaDoveSiBlocca.messaggio,
    );
    if (!fatto || !mounted) return;
    mostraMessaggio(context, 'Hai bloccato $nome: non vi vedete più.');
    Navigator.of(context).pop(true);
  }

  Future<void> _togliCollegamento() async {
    final nome = _nome;
    if (nome == null) return;
    if (await togliIlCollegamento(
          context,
          utenteId: widget.utenteId,
          nome: nome,
        ) &&
        mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _togliConversazione() async {
    if (await togliLaConversazione(context, utenteId: widget.utenteId) &&
        mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _tenuto(Messaggio m) {
    final testo = m.testo;
    if (testo == null) return Future.value();
    final nome = _nome;
    return scegliAzione(
      context,
      [
        AzioneMenu('Copia', () => copiaMessaggio(context, testo)),
        if (!m.mio && nome != null && Servizi.of(context).rete.disponibile)
          AzioneMenu(
            'Segnala il messaggio',
            () => _segnala(
              tipo: TipoSegnalato.messaggio,
              oggettoId: m.id,
              nome: nome,
            ),
            pericolo: true,
          ),
      ],
      titolo: m.mio
          ? 'Il tuo messaggio · ${quandoInElenco(m.scrittoIl, DateTime.now())}'
          : 'Messaggio di ${nomeOAccountChiuso(nome)} · '
                '${quandoInElenco(m.scrittoIl, DateTime.now())}',
    );
  }

  Future<void> _hoCapito() async {
    await Servizi.of(context).archivio.segnaPrudenzaVista();
    if (mounted) setState(() => _prudenza = false);
  }

  // ─── La schermata ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) => Pagina(
    sinistra: _Testata(nome: _nome),
    azioni: [
      if (_conversazione != null && _errore == null)
        ConLaRete(
          builder: (context, rete) => PulsanteTondo(
            icona: icona(
              ios: CupertinoIcons.ellipsis,
              android: Icons.more_horiz,
            ),
            etichetta: _collegati
                ? 'Segnala, blocca o togli il collegamento'
                : 'Segnala o togli la conversazione',
            onPressed: rete ? _menu : null,
          ),
        ),
    ],
    corpo: Builder(
      builder: (context) {
        final mq = MediaQuery.of(context);
        final errore = _errore;
        if (errore != null && _conversazione == null ||
            errore?.codice == CodiciServer.nonTrovato) {
          return _NonSiLegge(
            errore: errore!,
            sopra: mq.padding.top,
            onRiprova: () {
              setState(() => _errore = null);
              unawaited(_carica());
            },
          );
        }
        if (_conversazione == null) {
          return const Center(child: IndicatoreAttivita());
        }
        return Column(
          children: [
            Expanded(child: _elenco(mq.padding.top)),
            if (_collegati)
              _Compositore(
                controller: _testo,
                onManda: _manda,
                sotto: mq.padding.bottom,
              )
            else
              _Finita(sotto: mq.padding.bottom, onTogli: _togliConversazione),
          ],
        );
      },
    ),
  );

  /// I messaggi dal basso, con il giorno quando cambia; in cima, la prima
  /// volta, le righe di prudenza.
  Widget _elenco(double sopra) {
    final adesso = DateTime.now();
    final righe = <Widget>[];
    String? giorno;
    for (final m in _messaggi) {
      final questo = giornoDellaConversazione(m.scrittoIl, adesso);
      if (questo != giorno) {
        giorno = questo;
        righe.add(_Giorno(questo));
      }
      righe.add(
        _Fumetto(
          messaggio: m,
          onTenuto: () => _tenuto(m),
          onRiprova: m.nonInviato ? () => _manda(m) : null,
        ),
      );
    }
    final inCima = [
      if (_prudenza) _Prudenza(onHoCapito: _hoCapito).entra(context),
      if (_messaggi.isEmpty && _collegati)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            'Siete collegati: scrivi tu per primo.',
            textAlign: TextAlign.center,
            style: Testi.secondario.copyWith(color: Colori.grafite),
          ),
        ),
    ];
    final tutte = [...inCima, ...righe];
    return ListView.separated(
      reverse: true,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(20, 12, 20, sopra + 8),
      itemCount: tutte.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) => tutte[tutte.length - 1 - i],
    );
  }
}

/// In alto: indietro, l'iniziale e il nome (tela, 78). Chi ha chiuso
/// l'account è un punto di domanda grigio (116).
class _Testata extends StatelessWidget {
  const _Testata({required this.nome});

  final String? nome;

  @override
  Widget build(BuildContext context) {
    final nome = this.nome;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const PulsanteIndietro(),
        const SizedBox(width: 10),
        AvatarConversazione(nome: nome, dimensione: 36),
        const SizedBox(width: 10),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width - 210,
          ),
          child: Semantics(
            header: true,
            child: Text(
              nomeOAccountChiuso(nome),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Testi.evidenza.copyWith(
                fontSize: 17,
                color: nome == null ? Colori.grafite : Colori.inchiostro,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// L'iniziale di una persona, o un punto di domanda grigio se ha chiuso
/// l'account.
class AvatarConversazione extends StatelessWidget {
  const AvatarConversazione({
    super.key,
    required this.nome,
    this.dimensione = 44,
  });

  final String? nome;
  final double dimensione;

  @override
  Widget build(BuildContext context) {
    final nome = this.nome;
    if (nome != null) return Avatar(nome: nome, dimensione: dimensione);
    return Container(
      width: dimensione,
      height: dimensione,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colori.piombo,
      ),
      child: Text(
        '?',
        style: Testi.titoli(
          dimensione * 0.36,
          spaziatura: 0,
          altezza: 1,
          peso: 600,
        ).copyWith(color: Colori.bianco),
      ),
    );
  }
}

/// «OGGI», «IERI», «29 SETTEMBRE».
class _Giorno extends StatelessWidget {
  const _Giorno(this.testo);

  final String testo;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(
      testo,
      textAlign: TextAlign.center,
      style: Testi.sezione.copyWith(color: Colori.grafite),
    ),
  );
}

/// Un messaggio: i propri a destra in cobalto, gli altri a sinistra in
/// bianco. Uno tolto da chi modera lo dice, tratteggiato.
class _Fumetto extends StatelessWidget {
  const _Fumetto({
    required this.messaggio,
    required this.onTenuto,
    this.onRiprova,
  });

  final Messaggio messaggio;
  final VoidCallback onTenuto;
  final VoidCallback? onRiprova;

  @override
  Widget build(BuildContext context) {
    final m = messaggio;
    final larghezza = MediaQuery.sizeOf(context).width * 0.72;
    final Widget fumetto;
    if (m.tolto) {
      fumetto = CustomPaint(
        painter: const BordoTratteggiato(Colori.piombo, raggio: 18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Text(
            'Messaggio tolto da chi modera',
            style: Testi.secondario.copyWith(
              color: Colori.grafite,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    } else {
      fumetto = AnimatedOpacity(
        duration: Ritmo.breve,
        opacity: m.inViaggio ? 0.6 : 1,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: m.mio ? Colori.cobalto : Colori.bianco,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(m.mio ? 18 : 6),
              bottomRight: Radius.circular(m.mio ? 6 : 18),
            ),
          ),
          child: Text(
            m.testo ?? '',
            style: Testi.corpo.copyWith(
              fontSize: 15,
              height: 1.4,
              color: m.mio ? Colori.bianco : Colori.inchiostro,
            ),
          ),
        ),
      );
    }
    final etichetta = m.tolto
        ? 'Messaggio tolto da chi modera'
        : '${m.mio ? 'Tu' : 'Messaggio'}: ${m.testo ?? ''}';
    return Align(
      alignment: m.mio ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: larghezza),
        child: Column(
          crossAxisAlignment: m.mio
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Semantics(
              label: etichetta,
              onLongPressHint: m.tolto ? null : 'copiare o segnalare',
              onLongPress: m.tolto ? null : onTenuto,
              excludeSemantics: true,
              child: GestureDetector(
                onLongPress: m.tolto ? null : onTenuto,
                child: fumetto,
              ),
            ),
            if (onRiprova != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: PulsantePiccolo(
                  etichetta: 'Non inviato · Riprova',
                  pericolo: true,
                  onPressed: onRiprova,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// «Prima di incontrarvi» (tela, 114; M10): una volta sola.
class _Prudenza extends StatelessWidget {
  const _Prudenza({required this.onHoCapito});

  final VoidCallback onHoCapito;

  static const _righe = [
    'La prima volta vedetevi in un posto pubblico, di giorno.',
    'Di\' a qualcuno di cui ti fidi dove vai e con chi.',
    'Se qualcosa non va, da «…» segnali o blocchi. In pericolo, chiama il '
        '112.',
  ];

  @override
  Widget build(BuildContext context) => Pannello(
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
    raggio: 22,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colori.cobaltoChiaro,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icona(
                  ios: CupertinoIcons.checkmark_shield,
                  android: Icons.verified_user_outlined,
                ),
                size: 24,
                color: Colori.cobalto,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  'Prima di incontrarvi',
                  style: Testi.titoli(
                    18,
                    altezza: 1.25,
                  ).copyWith(color: Colori.inchiostro),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final riga in _righe)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '•  ',
                  style: Testi.secondario.copyWith(color: Colori.ardesia),
                ),
                Expanded(
                  child: Text(
                    riga,
                    style: Testi.secondario.copyWith(
                      fontSize: 15,
                      color: Colori.ardesia,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        PulsanteGrande(etichetta: 'Ho capito', onPressed: onHoCapito),
        const SizedBox(height: 8),
        Text(
          'Te lo diciamo una volta sola.',
          style: Testi.didascalia.copyWith(color: Colori.grafite),
        ),
      ],
    ),
  );
}

/// Dove si scrive (tela, 78). Senza rete si spegne e lo dice.
class _Compositore extends StatelessWidget {
  const _Compositore({
    required this.controller,
    required this.onManda,
    required this.sotto,
  });

  final TextEditingController controller;
  final VoidCallback onManda;
  final double sotto;

  @override
  Widget build(BuildContext context) => ConLaRete(
    builder: (context, rete) {
      final pieno = controller.text.trim().isNotEmpty;
      return Container(
        color: Colori.nebbia,
        padding: EdgeInsets.fromLTRB(20, 10, 20, sotto + 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
              decoration: BoxDecoration(
                color: Colori.bianco,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _CampoMessaggio(
                      controller: controller,
                      attivo: rete,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Semantics(
                    button: true,
                    enabled: rete && pieno,
                    label: 'Invia',
                    child: Premibile(
                      onTap: rete && pieno ? onManda : null,
                      scala: 0.92,
                      child: AnimatedOpacity(
                        duration: Ritmo.breve,
                        opacity: rete && pieno ? 1 : 0.35,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colori.inchiostro,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(
                            icona(
                              ios: CupertinoIcons.paperplane,
                              android: Icons.send_rounded,
                            ),
                            size: 18,
                            color: Colori.bianco,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!rete) ...[
              const SizedBox(height: 6),
              Text(
                motivoSenzaRete,
                textAlign: TextAlign.center,
                style: Testi.didascalia.copyWith(color: Colori.grafite),
              ),
            ],
          ],
        ),
      );
    },
  );
}

/// Il campo del messaggio, senza cornice: la fa il compositore.
class _CampoMessaggio extends StatelessWidget {
  const _CampoMessaggio({required this.controller, required this.attivo});

  final TextEditingController controller;
  final bool attivo;

  @override
  Widget build(BuildContext context) {
    final stile = Testi.campo.copyWith(fontSize: 16, color: Colori.inchiostro);
    final segnaposto = stile.copyWith(color: Colori.grafite);
    final limite = [LengthLimitingTextInputFormatter(lunghezzaMessaggio)];
    return suIOS
        ? CupertinoTextField(
            controller: controller,
            enabled: attivo,
            placeholder: 'Scrivi…',
            placeholderStyle: segnaposto,
            style: stile,
            cursorColor: Colori.cobalto,
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: null,
            minLines: 1,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: limite,
          )
        : TextField(
            controller: controller,
            enabled: attivo,
            style: stile,
            cursorColor: Colori.cobalto,
            decoration: InputDecoration(
              hintText: 'Scrivi…',
              hintStyle: segnaposto,
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            minLines: 1,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: limite,
          );
  }
}

/// Una conversazione finita (tela, 116): resta, senza scrivere.
class _Finita extends StatelessWidget {
  const _Finita({required this.sotto, required this.onTogli});

  final double sotto;
  final VoidCallback onTogli;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(20, 10, 20, sotto + 10),
    child: Pannello(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      raggio: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            const TextSpan(
              children: [
                TextSpan(
                  text: 'Non siete più collegati. ',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colori.inchiostro,
                  ),
                ),
                TextSpan(
                  text:
                      'La conversazione resta a te, ma non potete più '
                      'scrivervi.',
                ),
              ],
            ),
            style: Testi.secondario.copyWith(
              fontSize: 15,
              color: Colori.ardesia,
            ),
          ),
          const SizedBox(height: 12),
          ConLaRete(
            builder: (context, rete) => PulsanteGrande(
              etichetta: 'Togli la conversazione',
              secondario: true,
              pericolo: true,
              motivo: rete ? null : motivoSenzaRete,
              onPressed: onTogli,
            ),
          ),
        ],
      ),
    ),
  );
}

/// La conversazione non si legge: senza rete, o non c'è più.
class _NonSiLegge extends StatelessWidget {
  const _NonSiLegge({
    required this.errore,
    required this.sopra,
    required this.onRiprova,
  });

  final ErroreTrolley errore;
  final double sopra;
  final VoidCallback onRiprova;

  @override
  Widget build(BuildContext context) {
    final nonCe = errore.codice == CodiciServer.nonTrovato;
    return ListView(
      padding: EdgeInsets.fromLTRB(20, sopra + 8, 20, 32),
      children: [
        Avviso(
          icona: nonCe
              ? icona(
                  ios: CupertinoIcons.chat_bubble,
                  android: Icons.chat_bubble_outline,
                )
              : icona(
                  ios: CupertinoIcons.wifi_slash,
                  android: Icons.wifi_off_rounded,
                ),
          errore: !nonCe,
          testo: errore.messaggio,
        ).entra(context),
        if (!nonCe) ...[
          const SizedBox(height: 16),
          ConLaRete(
            builder: (context, rete) => PulsanteGrande(
              etichetta: 'Riprova',
              secondario: true,
              motivo: rete ? null : motivoSenzaRete,
              onPressed: onRiprova,
            ),
          ),
        ],
      ],
    );
  }
}
