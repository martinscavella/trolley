import 'dart:async';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../aspetto/elementi.dart';
import '../aspetto/formati.dart';
import '../aspetto/movimento.dart';
import '../aspetto/pagina.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../dati/archivio.dart';
import '../dati/database.dart';
import '../dati/errori.dart';
import '../dati/lettura.dart';
import '../dominio/stato_viaggio.dart';
import '../servizi.dart';
import 'con_la_rete.dart';
import 'cose.dart';
import 'documenti.dart';
import 'foglio_documento.dart';
import 'gesti_partecipanti.dart';
import 'spese.dart';

/// Chi c'è (03-partecipanti-e-inviti.md, "Partecipanti"; tela, 30–32): chi
/// partecipa, chi ne è responsabile, gli inviti in sospeso, chi non c'è più.
///
/// Il modello è paritario sui contenuti; l'unica differenza è che solo chi è
/// responsabile del viaggio toglie qualcuno (regola 6) — e può passare il
/// ruolo. Il ruolo nel server si chiama `creatore`; qui «responsabile», perché
/// dopo un passaggio «ha creato il viaggio» non sarebbe più vero
/// (decisioni/prodotto.md).
///
/// Si legge dalla copia, anche senza rete. Invitare, togliere, passare il
/// ruolo, uscire e vedere gli inviti in sospeso richiedono la rete, e lo
/// dicono prima.
class SchermataPartecipanti extends StatefulWidget {
  const SchermataPartecipanti({super.key, required this.viaggioId});

  final String viaggioId;

  @override
  State<SchermataPartecipanti> createState() => _SchermataPartecipantiState();
}

class _SchermataPartecipantiState extends State<SchermataPartecipanti> {
  late Stream<Viaggio?> _viaggio;
  late Stream<List<(Partecipazione, Utente?)>> _partecipanti;
  late Stream<List<(Partecipazione, Utente?)>> _usciti;
  StreamSubscription<bool>? _rete;
  bool _avviata = false;

  /// Gli inviti in sospeso: `null` finché non sono arrivati, o senza rete.
  List<InvitoValido>? _inviti;
  bool _inCorso = false;
  bool _invitoInCorso = false;
  final _origineInvito = GlobalKey();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_avviata) return;
    _avviata = true;
    final servizi = Servizi.of(context);
    _viaggio = servizi.archivio.osservaViaggio(widget.viaggioId);
    _partecipanti = servizi.archivio.osservaPartecipanti(widget.viaggioId);
    _usciti = servizi.archivio.osservaUsciti(widget.viaggioId);
    // Gli inviti non stanno nella copia: arrivano quando c'è la rete.
    _rete = servizi.rete.cambi.listen((disponibile) {
      if (disponibile) _caricaInviti();
    });
    unawaited(_caricaInviti());
    unawaited(segnaAperturaSenzaRete(context, 'partecipanti'));
  }

  @override
  void dispose() {
    _rete?.cancel();
    super.dispose();
  }

  Future<void> _caricaInviti() async {
    final archivio = Servizi.of(context).archivio;
    try {
      final inviti = await archivio.invitiValidi(widget.viaggioId);
      if (mounted) setState(() => _inviti = inviti);
    } on ErroreTrolley {
      if (mounted) setState(() => _inviti = null);
    }
  }

  /// Un gesto che richiede la rete, con la rotellina e l'errore detto.
  Future<bool> _fai(Future<void> Function() gesto) async {
    if (_inCorso || !mounted) return false;
    setState(() => _inCorso = true);
    try {
      await gesto();
      return true;
    } on ErroreTrolley catch (e) {
      if (mounted) mostraMessaggio(context, e.messaggio, errore: true);
      return false;
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  Future<bool> _conferma({
    required String titolo,
    required String messaggio,
    required String azione,
  }) async {
    var si = false;
    await AdaptiveAlertDialog.show(
      context: context,
      title: titolo,
      message: messaggio,
      actions: [
        AlertAction(
          title: 'Annulla',
          style: AlertActionStyle.cancel,
          onPressed: () {},
        ),
        AlertAction(
          title: azione,
          style: AlertActionStyle.destructive,
          onPressed: () => si = true,
        ),
      ],
    );
    return si;
  }

  Future<void> _invita() async {
    if (_invitoInCorso) return;
    setState(() => _invitoInCorso = true);
    try {
      await invitaQualcuno(
        context,
        widget.viaggioId,
        origine: posizioneDi(_origineInvito),
      );
      await _caricaInviti();
    } on ErroreTrolley catch (e) {
      if (mounted) mostraMessaggio(context, e.messaggio, errore: true);
    } finally {
      if (mounted) setState(() => _invitoInCorso = false);
    }
  }

  /// Chi è responsabile tocca «…» su una persona (tela, 31).
  Future<void> _suUnaPersona(String utenteId, String nome) =>
      scegliAzione(context, titolo: nome, [
        AzioneMenu(
          'Rendi $nome responsabile',
          () => _rendiResponsabile(utenteId, nome),
        ),
        AzioneMenu(
          'Togli $nome dal viaggio',
          () => _togli(utenteId, nome),
          pericolo: true,
        ),
      ]);

  Future<void> _rendiResponsabile(String utenteId, String nome) async {
    final archivio = Servizi.of(context).archivio;
    if (!await _conferma(
      titolo: 'Rendere $nome responsabile?',
      messaggio:
          '$nome potrà togliere le persone dal viaggio, e tu no. È l\'unica '
          'differenza: per il resto siete uguali.',
      azione: 'Rendi responsabile',
    )) {
      return;
    }
    if (await _fai(
          () => archivio.rendiResponsabile(widget.viaggioId, utenteId),
        ) &&
        mounted) {
      mostraMessaggio(context, 'Ora $nome è responsabile del viaggio.');
    }
  }

  Future<void> _togli(String utenteId, String nome) async {
    final archivio = Servizi.of(context).archivio;
    if (!await _conferma(
      titolo: 'Togliere $nome dal viaggio?',
      messaggio:
          'Non vedrà più il viaggio; quello che ha aggiunto resta, con il suo '
          'nome. I link d\'invito ancora validi si ritirano: chi deve ancora '
          'entrare ne riceverà uno nuovo.',
      azione: 'Togli',
    )) {
      return;
    }
    if (await _fai(
          () => archivio.togliPartecipante(widget.viaggioId, utenteId),
        ) &&
        mounted) {
      mostraMessaggio(context, '$nome non fa più parte del viaggio.');
      unawaited(_caricaInviti());
    }
  }

  Future<void> _ritiraInviti(int quanti) async {
    final archivio = Servizi.of(context).archivio;
    if (!await _conferma(
      titolo: quanti == 1
          ? 'Ritirare il link d\'invito?'
          : 'Ritirare i link d\'invito?',
      messaggio:
          'Chi non è ancora entrato non potrà più usarl${quanti == 1 ? 'o' : 'i'}: '
          'se serve, ne mandi uno nuovo.',
      azione: 'Ritira',
    )) {
      return;
    }
    if (await _fai(() => archivio.ritiraInviti(widget.viaggioId))) {
      await _caricaInviti();
    }
  }

  /// Esce dal viaggio (regola 7). Chi è responsabile prima sceglie a chi
  /// passare il ruolo: un viaggio senza responsabile non può esistere (casi
  /// limite).
  Future<void> _esci(
    Viaggio viaggio, {
    required bool responsabile,
    required List<(Partecipazione, Utente?)> altri,
  }) async {
    if (!responsabile) return _confermaUscita(viaggio);
    await scegliAzione(
      context,
      titolo: 'Chi sarà responsabile?',
      messaggio:
          'Prima di uscire passa il ruolo a qualcuno: è chi può togliere le '
          'persone dal viaggio.',
      [
        for (final (p, u) in altri)
          AzioneMenu(
            u?.nome ?? 'Senza nome',
            () => _confermaUscita(
              viaggio,
              passaA: (p.utenteId, u?.nome ?? 'Senza nome'),
            ),
          ),
      ],
    );
  }

  Future<void> _confermaUscita(
    Viaggio viaggio, {
    (String, String)? passaA,
  }) async {
    final servizi = Servizi.of(context);
    final (documenti, coda) = await (
      servizi.documenti.osserva(viaggio.id).first,
      servizi.archivio.coda.osserva(viaggio.id).first,
    ).wait;
    final persi = coda.where((op) => op.messaDaParte).length;
    final nome = viaggio.destinazione?.nome;
    if (!mounted) return;
    final navigatore = Navigator.of(context);
    final si = await _conferma(
      titolo: nome == null ? 'Uscire da questo viaggio?' : 'Uscire da «$nome»?',
      messaggio: [
        if (passaA != null) '${passaA.$2} sarà responsabile del viaggio.',
        'Quello che hai aggiunto resta agli altri.',
        if (documenti.length == 1)
          'Il tuo documento di questo viaggio si cancella da questo telefono.'
        else if (documenti.length > 1)
          'I tuoi ${documenti.length} documenti di questo viaggio si '
              'cancellano da questo telefono.',
        if (persi == 1)
          'Una cosa fatta senza rete non è arrivata, e andrà persa.'
        else if (persi > 1)
          '$persi cose fatte senza rete non sono arrivate, e andranno perse.',
        'Per rientrare ti servirà un invito.',
      ].join(' '),
      azione: 'Esci',
    );
    if (!si || !mounted) return;
    final uscito = await _fai(() async {
      if (passaA != null) {
        await servizi.archivio.rendiResponsabile(viaggio.id, passaA.$1);
      }
      await servizi.archivio.esciDalViaggio(viaggio.id);
      // Solo dopo che il server ha detto sì: sono l'unica copia.
      await servizi.documenti.eliminaViaggio(viaggio.id);
    });
    if (!uscito) return;
    final contesto = navigatore.overlay?.context;
    navigatore.popUntil((r) => r.isFirst);
    if (contesto != null && contesto.mounted) {
      mostraMessaggio(
        contesto,
        nome == null
            ? 'Non fai più parte di quel viaggio.'
            : 'Non fai più parte di «$nome».',
      );
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<Viaggio?>(
    stream: _viaggio,
    builder: (context, viaggio) =>
        StreamBuilder<List<(Partecipazione, Utente?)>>(
          stream: _partecipanti,
          builder: (context, partecipanti) =>
              StreamBuilder<List<(Partecipazione, Utente?)>>(
                stream: _usciti,
                builder: (context, usciti) {
                  final (v, p) = (viaggio.data, partecipanti.data);
                  if (v == null || p == null) {
                    return Pagina(
                      corpo: Center(
                        child:
                            viaggio.connectionState == ConnectionState.waiting
                            ? const IndicatoreAttivita()
                            : Text(
                                'Questo viaggio non è sul telefono.',
                                style: Testi.corpo.copyWith(
                                  color: Colori.grafite,
                                ),
                              ),
                      ),
                    );
                  }
                  return ConLaRete(
                    builder: (context, rete) =>
                        _pagina(v, p, usciti.data ?? const [], rete),
                  );
                },
              ),
        ),
  );

  Widget _pagina(
    Viaggio viaggio,
    List<(Partecipazione, Utente?)> partecipanti,
    List<(Partecipazione, Utente?)> usciti,
    bool rete,
  ) {
    final io = Servizi.of(context).archivio.io;
    final responsabile = partecipanti.any(
      (x) => x.$1.utenteId == io && x.$1.ruolo == 'creatore',
    );
    final altri = [
      for (final x in partecipanti)
        if (x.$1.utenteId != io) x,
    ];
    final inviti = _inviti;
    return Pagina(
      azioni: [if (!rete) const SeiOffline()],
      corpo: Builder(
        builder: (context) => ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.paddingOf(context).top + 8,
            20,
            MediaQuery.paddingOf(context).bottom + 32,
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
                      'Chi c\'è',
                      style: Testi.titolo.copyWith(color: Colori.inchiostro),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    [
                      titoloViaggio(viaggio),
                      quandoViaggio(viaggio),
                    ].join(' · '),
                    style: Testi.secondario.copyWith(color: Colori.grafite),
                  ),
                ],
              ),
            ).entra(context),
            const SizedBox(height: 16),
            for (final (i, (p, u)) in partecipanti.indexed) ...[
              if (i > 0) const SizedBox(height: 8),
              RigaPersona(
                nome: u?.nome ?? '…',
                tu: p.utenteId == io,
                responsabile: p.ruolo == 'creatore',
                onAltro: responsabile && p.utenteId != io
                    ? (rete && !_inCorso
                          ? () => _suUnaPersona(p.utenteId, u?.nome ?? '…')
                          : null)
                    : null,
                mostraAltro: responsabile && p.utenteId != io,
              ).entra(context, ritardo: Ritmo.passo * (i + 1)),
            ],
            if (responsabile && altri.isNotEmpty && !rete)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
                child: Text(
                  'Per togliere qualcuno o passare il ruolo serve la '
                  'connessione.',
                  style: Testi.didascalia.copyWith(color: Colori.grafite),
                ),
              ),
            const SizedBox(height: 12),
            if (!rete)
              Avviso(
                icona: _iconaLink,
                testo:
                    'Gli inviti ancora in sospeso si vedono con la '
                    'connessione.',
              )
            else if (inviti != null && inviti.isNotEmpty)
              _InvitiInSospeso(
                viaggioId: viaggio.id,
                inviti: inviti,
                onRitira: _inCorso ? null : () => _ritiraInviti(inviti.length),
              ),
            const SizedBox(height: 14),
            PulsanteGrande(
              key: _origineInvito,
              etichetta: 'Invita qualcuno',
              icona: icona(
                ios: CupertinoIcons.person_badge_plus,
                android: Icons.person_add_alt_1_outlined,
              ),
              inCorso: _invitoInCorso,
              motivo: rete ? null : motivoSenzaRete,
              onPressed: _invita,
            ),
            if (usciti.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 26, 4, 8),
                child: Semantics(
                  header: true,
                  child: Text(
                    'NON CI SONO PIÙ',
                    style: Testi.sezione.copyWith(color: Colori.grafite),
                  ),
                ),
              ),
              for (final (i, (_, u)) in usciti.indexed) ...[
                if (i > 0) const SizedBox(height: 8),
                RigaPersona(nome: u?.nome ?? '…', uscito: true),
              ],
            ],
            // Chi è responsabile ed è da solo non esce: il viaggio resterebbe
            // senza nessuno (03, casi limite).
            if (!responsabile || altri.isNotEmpty) ...[
              const SizedBox(height: 26),
              PulsanteGrande(
                etichetta: 'Esci dal viaggio',
                secondario: true,
                pericolo: true,
                inCorso: _inCorso,
                motivo: rete ? null : motivoSenzaRete,
                onPressed: () =>
                    _esci(viaggio, responsabile: responsabile, altri: altri),
              ),
              if (responsabile && rete)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Text(
                    'Prima di uscire rendi responsabile qualcun altro: è chi '
                    'può togliere le persone dal viaggio.',
                    textAlign: TextAlign.center,
                    style: Testi.didascalia.copyWith(color: Colori.grafite),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

IconData get _iconaLink =>
    icona(ios: CupertinoIcons.link, android: Icons.link_rounded);

/// Una persona del viaggio (tela, 30): le iniziali, il nome, cosa fa. Chi è
/// uscito ha le iniziali tratteggiate. Con [mostraAltro], «…» per chi è
/// responsabile; spento senza [onAltro].
class RigaPersona extends StatelessWidget {
  const RigaPersona({
    super.key,
    required this.nome,
    this.tu = false,
    this.responsabile = false,
    this.uscito = false,
    this.mostraAltro = false,
    this.onAltro,
  });

  final String nome;
  final bool tu;
  final bool responsabile;
  final bool uscito;
  final bool mostraAltro;
  final VoidCallback? onAltro;

  @override
  Widget build(BuildContext context) {
    final cosaFa = uscito
        ? 'Quello che ha aggiunto resta nel viaggio'
        : responsabile
        ? 'Responsabile del viaggio'
        : tu
        ? 'Partecipi'
        : 'Partecipa';
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, mostraAltro ? 8 : 16, 12),
      decoration: BoxDecoration(
        color: Colori.bianco,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: uscito
                ? Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colori.piombo, width: 2),
                    ),
                    child: Text(
                      iniziali(nome),
                      style: Testi.titoli(
                        16,
                        spaziatura: 0,
                        altezza: 1,
                        peso: 600,
                      ).copyWith(color: Colori.grafite),
                    ),
                  )
                : Avatar(nome: nome),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Semantics(
              container: true,
              label: [tu ? '$nome, tu' : nome, cosaFa].join(', '),
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: nome,
                        children: [
                          if (tu)
                            TextSpan(
                              text: ' · tu',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colori.grafite,
                              ),
                            ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Testi.evidenza.copyWith(
                        color: uscito ? Colori.ardesia : Colori.inchiostro,
                      ),
                    ),
                    Text(
                      cosaFa,
                      style: Testi.didascalia.copyWith(color: Colori.grafite),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (responsabile && !mostraAltro) ...[
            const SizedBox(width: 8),
            const ExcludeSemantics(child: Pillola('RESPONSABILE')),
          ],
          if (mostraAltro)
            PulsanteTondo(
              icona: icona(
                ios: CupertinoIcons.ellipsis,
                android: Icons.more_horiz_rounded,
              ),
              etichetta: 'Cosa puoi fare con $nome',
              fondo: Colori.bianco,
              onPressed: onAltro,
            ),
        ],
      ),
    );
  }
}

/// I link d'invito ancora validi (tela, 30): quanti sono, chi ha creato
/// l'ultimo, e il modo di ritirarli tutti.
class _InvitiInSospeso extends StatelessWidget {
  const _InvitiInSospeso({
    required this.viaggioId,
    required this.inviti,
    required this.onRitira,
  });

  final String viaggioId;
  final List<InvitoValido> inviti;
  final VoidCallback? onRitira;

  @override
  Widget build(BuildContext context) => StreamBuilder<Map<String, String>>(
    stream: Servizi.of(context).archivio.osservaNomi(viaggioId),
    builder: (context, nomi) {
      final n = inviti.length;
      final ultimo = inviti.last;
      final io = Servizi.of(context).archivio.io;
      final chi = ultimo.creatoDa == io
          ? 'tu'
          : (nomi.data?[ultimo.creatoDa] ?? 'qualcuno del viaggio');
      final quando = quantoFa(ultimo.creatoIl, DateTime.now());
      return Avviso(
        icona: _iconaLink,
        inizio: n == 1
            ? 'Un link d\'invito ancora valido.'
            : '$n link d\'invito ancora validi.',
        testo:
            'Chi ne ha uno entra, anche se gli è arrivato inoltrato. '
            '${n == 1 ? 'L\'ha' : 'L\'ultimo l\'ha'} creato $chi, $quando.',
        azioni: [
          PulsantePiccolo(
            etichetta: n == 1 ? 'Ritira il link' : 'Ritira i link',
            pericolo: true,
            onPressed: onRitira,
          ),
        ],
      );
    },
  );
}

// ─── Nella schermata del viaggio ──────────────────────────────────────────

/// `Giulia, Marco e tu`; da soli, `Solo tu, per ora`; oltre in quattro,
/// `Giulia, Marco e altre 3 persone`.
String chiCe(List<String> altri) {
  if (altri.isEmpty) return 'Solo tu, per ora';
  if (altri.length <= 3) return '${altri.join(', ')} e tu';
  return '${altri.take(2).join(', ')} e altre ${altri.length - 1} persone';
}

/// Chi c'è, in una riga (tela, 29): le iniziali, i nomi, chi è responsabile.
/// Si tocca per aprire l'elenco.
class SezioneChiCe extends StatelessWidget {
  const SezioneChiCe({super.key, required this.viaggioId});

  final String viaggioId;

  @override
  Widget build(BuildContext context) {
    final archivio = Servizi.of(context).archivio;
    return StreamBuilder<List<(Partecipazione, Utente?)>>(
      stream: archivio.osservaPartecipanti(viaggioId),
      builder: (context, snapshot) {
        final persone = snapshot.data ?? const [];
        final io = archivio.io;
        final altri = [
          for (final (p, u) in persone)
            if (p.utenteId != io) u?.nome ?? '…',
        ];
        final responsabile = persone
            .where((x) => x.$1.ruolo == 'creatore')
            .firstOrNull
            ?.$2;
        final sonoResponsabile = persone.any(
          (x) => x.$1.utenteId == io && x.$1.ruolo == 'creatore',
        );
        final titolo = chiCe(altri);
        final sotto = altri.isEmpty
            ? 'Invita chi viene con te'
            : [
                quanti(persone.length, 'persona', 'persone'),
                sonoResponsabile
                    ? 'tu sei responsabile'
                    : '${responsabile?.nome ?? '…'} è responsabile',
              ].join(' · ');
        return Premibile(
          onTap: () =>
              apri<void>(context, SchermataPartecipanti(viaggioId: viaggioId)),
          scala: 0.98,
          etichetta: 'Chi c\'è: $titolo. $sotto',
          child: ExcludeSemantics(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colori.bianco,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  PilaAvatar(
                    nomi: [
                      for (final (p, u) in persone)
                        if (p.utenteId != io) u?.nome ?? '?',
                      for (final (p, u) in persone)
                        if (p.utenteId == io) u?.nome ?? '?',
                    ],
                    dimensione: 36,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titolo,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Testi.evidenza.copyWith(
                            color: Colori.inchiostro,
                          ),
                        ),
                        Text(
                          sotto,
                          style: Testi.didascalia.copyWith(
                            color: Colori.grafite,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    icona(
                      ios: CupertinoIcons.chevron_right,
                      android: Icons.chevron_right,
                    ),
                    size: 16,
                    color: Colori.grafite,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Il primo minuto di chi è appena entrato da un invito (03, regola 9; tela,
/// 29): il viaggio è già tutto lì sotto, e qui ci sono tre cose sue da fare —
/// il biglietto, una spesa, le cose da portare. Biglietto e spesa vogliono le
/// date. Sparisce al primo contributo, o con la ×.
class BenvenutoInvitato extends StatelessWidget {
  const BenvenutoInvitato({
    super.key,
    required this.viaggio,
    required this.stato,
  });

  final Viaggio viaggio;
  final StatoViaggio stato;

  @override
  Widget build(BuildContext context) {
    final archivio = Servizi.of(context).archivio;
    return StreamBuilder<bool>(
      stream: archivio.osservaBenvenuto(viaggio.id),
      builder: (context, mostra) {
        if (mostra.data != true) return const SizedBox.shrink();
        return StreamBuilder<List<(Partecipazione, Utente?)>>(
          stream: archivio.osservaPartecipanti(viaggio.id),
          builder: (context, persone) {
            final io = archivio.io;
            final altri = [
              for (final (p, u)
                  in persone.data ?? const <(Partecipazione, Utente?)>[])
                if (p.utenteId != io) u?.nome ?? '',
            ];
            return Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _SchedaBenvenuto(
                viaggio: viaggio,
                conDate: stato.haGiorni,
                altri: altri,
                onChiudi: () => archivio.chiudiBenvenuto(viaggio.id),
              ),
            ).entra(context, ritardo: Ritmo.passo, da: 10);
          },
        );
      },
    );
  }
}

class _SchedaBenvenuto extends StatelessWidget {
  const _SchedaBenvenuto({
    required this.viaggio,
    required this.conDate,
    required this.altri,
    required this.onChiudi,
  });

  final Viaggio viaggio;
  final bool conDate;
  final List<String> altri;
  final VoidCallback onChiudi;

  Future<void> _biglietto(BuildContext context) async {
    final giorni = await Servizi.of(context).archivio
        .osservaGiorni(viaggio.id)
        .first;
    if (!context.mounted) return;
    await apriFoglio<void>(
      context,
      FoglioDocumento(viaggio: viaggio, giorni: giorni),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nome = viaggio.destinazione?.nome;
    final con = altri.where((n) => n.trim().isNotEmpty).toList();
    final dove = nome == null ? 'in questo viaggio' : 'nel viaggio a $nome';
    final testo = [
      con.isEmpty ? 'Sei $dove:' : 'Sei $dove con ${elencoNomi(con)}:',
      'qui sotto c\'è tutto quello che avete già deciso. Comincia da qualcosa '
          'di tuo.',
    ].join(' ');
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
      decoration: BoxDecoration(
        color: Colori.bianco,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (con.isNotEmpty) ...[
                ExcludeSemantics(child: PilaAvatar(nomi: con, dimensione: 36)),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'Sei dentro!',
                    style: Testi.titoli(
                      20,
                      altezza: 1.15,
                    ).copyWith(color: Colori.inchiostro),
                  ),
                ),
              ),
              PulsanteTondo(
                icona: icona(ios: CupertinoIcons.xmark, android: Icons.close),
                etichetta: 'Chiudi il benvenuto',
                fondo: Colori.foschia,
                onPressed: onChiudi,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(testo, style: Testi.corpo.copyWith(color: Colori.ardesia)),
          const SizedBox(height: 4),
          if (conDate)
            _CosaTua(
              simbolo: icona(
                ios: CupertinoIcons.tickets,
                android: Icons.confirmation_number_outlined,
              ),
              titolo: 'Il tuo biglietto',
              sotto: 'Resta sul tuo telefono, e si apre anche senza rete',
              onTap: () => _biglietto(context),
            ),
          if (conDate)
            _CosaTua(
              simbolo: icona(
                ios: CupertinoIcons.creditcard,
                android: Icons.credit_card_rounded,
              ),
              titolo: 'La tua prima spesa',
              sotto: 'Il volo, l\'acconto: anche senza rete',
              onTap: () => nuovaSpesa(context, viaggio),
            ),
          _CosaTua(
            simbolo: icona(
              ios: CupertinoIcons.bag,
              android: Icons.luggage_outlined,
            ),
            titolo: 'Le tue cose da portare',
            sotto: 'La lista è tua: gli altri non la vedono',
            ultima: true,
            onTap: () => apriCose(context, viaggio.id, scrivi: true),
          ),
        ],
      ),
    );
  }
}

class _CosaTua extends StatelessWidget {
  const _CosaTua({
    required this.simbolo,
    required this.titolo,
    required this.sotto,
    required this.onTap,
    this.ultima = false,
  });

  final IconData simbolo;
  final String titolo;
  final String sotto;
  final VoidCallback onTap;
  final bool ultima;

  @override
  Widget build(BuildContext context) => Premibile(
    onTap: onTap,
    scala: 0.98,
    etichetta: '$titolo. $sotto',
    child: ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: ultima
              ? null
              : const Border(
                  bottom: BorderSide(color: Colori.foschia, width: 1.5),
                ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colori.cobaltoChiaro,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(simbolo, size: 22, color: Colori.cobalto),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titolo,
                    style: Testi.evidenza.copyWith(color: Colori.inchiostro),
                  ),
                  Text(
                    sotto,
                    style: Testi.didascalia.copyWith(color: Colori.grafite),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              icona(
                ios: CupertinoIcons.chevron_right,
                android: Icons.chevron_right,
              ),
              size: 16,
              color: Colori.grafite,
            ),
          ],
        ),
      ),
    ),
  );
}

// ─── Nell'elenco dei viaggi ───────────────────────────────────────────────

/// I viaggi da cui si è stati tolti, o usciti da un altro telefono (tela,
/// 33): lo si dice invece di farli sparire in silenzio, con i gesti fatti
/// senza rete che non arriveranno più e i propri documenti rimasti sul
/// telefono, da guardare o eliminare (sono l'unica copia).
class AvvisiViaggiLasciati extends StatelessWidget {
  const AvvisiViaggiLasciati({super.key});

  @override
  Widget build(BuildContext context) => StreamBuilder<List<ViaggioLasciato>>(
    stream: Servizi.of(context).archivio.osservaViaggiLasciati(),
    builder: (context, snapshot) {
      final lasciati = snapshot.data ?? const <ViaggioLasciato>[];
      if (lasciati.isEmpty) return const SizedBox.shrink();
      return Column(
        children: [
          for (final l in lasciati)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: _AvvisoLasciato(lasciato: l),
            ),
        ],
      );
    },
  );
}

class _AvvisoLasciato extends StatelessWidget {
  const _AvvisoLasciato({required this.lasciato});

  final ViaggioLasciato lasciato;

  Future<void> _elimina(BuildContext context, int quanti) async {
    var si = false;
    final nome = lasciato.nome;
    await AdaptiveAlertDialog.show(
      context: context,
      title: quanti == 1
          ? 'Eliminare il documento${nome == null ? '' : ' di «$nome»'}?'
          : 'Eliminare i documenti${nome == null ? '' : ' di «$nome»'}?',
      message: 'Sono solo su questo telefono: eliminati, non si recuperano.',
      actions: [
        AlertAction(
          title: 'Annulla',
          style: AlertActionStyle.cancel,
          onPressed: () {},
        ),
        AlertAction(
          title: 'Elimina',
          style: AlertActionStyle.destructive,
          onPressed: () => si = true,
        ),
      ],
    );
    if (!si || !context.mounted) return;
    final servizi = Servizi.of(context);
    await servizi.documenti.eliminaViaggio(lasciato.viaggioId);
    await servizi.archivio.dimenticaViaggioLasciato(lasciato.viaggioId);
  }

  @override
  Widget build(BuildContext context) {
    final servizi = Servizi.of(context);
    return StreamBuilder<List<Documento>>(
      stream: servizi.documenti.osserva(lasciato.viaggioId),
      builder: (context, snapshot) {
        final documenti = snapshot.data ?? const <Documento>[];
        final n = documenti.length;
        final nome = lasciato.nome;
        final g = lasciato.gestiPersi;
        return Avviso(
          icona: icona(
            ios: CupertinoIcons.person_crop_circle_badge_xmark,
            android: Icons.person_remove_outlined,
          ),
          inizio: nome == null
              ? 'Non fai più parte di un viaggio.'
              : 'Non fai più parte di «$nome».',
          testo: [
            lasciato.motivo == MotivoUscita.rimosso
                ? 'Chi ne è responsabile ti ha tolto; quello che avevi '
                      'aggiunto resta agli altri.'
                : 'L\'hai lasciato da un altro telefono; quello che avevi '
                      'aggiunto resta agli altri.',
            if (g == 1)
              'Una cosa fatta senza rete non è arrivata.'
            else if (g > 1)
              '$g cose fatte senza rete non sono arrivate.',
            if (n == 1)
              'Su questo telefono resta un tuo documento di quel viaggio.'
            else if (n > 1)
              'Su questo telefono restano $n tuoi documenti di quel viaggio.',
          ].join(' '),
          azioni: n == 0
              ? [
                  PulsantePiccolo(
                    etichetta: 'Ho capito',
                    onPressed: () => servizi.archivio.dimenticaViaggioLasciato(
                      lasciato.viaggioId,
                    ),
                  ),
                ]
              : [
                  PulsantePiccolo(
                    etichetta: n == 1 ? 'Guardalo' : 'Guardali',
                    onPressed: () => apriFoglio<void>(
                      context,
                      _FoglioDocumentiRimasti(lasciato: lasciato),
                    ),
                  ),
                  PulsantePiccolo(
                    etichetta: n == 1 ? 'Eliminalo' : 'Eliminali',
                    pericolo: true,
                    onPressed: () => _elimina(context, n),
                  ),
                ],
        );
      },
    );
  }
}

/// I propri documenti di un viaggio lasciato: si aprono come sempre.
class _FoglioDocumentiRimasti extends StatelessWidget {
  const _FoglioDocumentiRimasti({required this.lasciato});

  final ViaggioLasciato lasciato;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Documento>>(
    stream: Servizi.of(context).documenti.osserva(lasciato.viaggioId),
    builder: (context, snapshot) {
      final documenti = snapshot.data ?? const <Documento>[];
      return Foglio(
        titolo: lasciato.nome == null
            ? 'I tuoi documenti'
            : 'I tuoi documenti di «${lasciato.nome}»',
        children: [
          for (final d in documenti)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Colori.cenere, width: 1.5),
                  borderRadius: BorderRadius.circular(19),
                ),
                child: RigaDocumento(documento: d),
              ),
            ),
        ],
      );
    },
  );
}
