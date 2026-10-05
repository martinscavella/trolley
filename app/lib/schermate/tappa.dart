import 'dart:async';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../aspetto/elementi.dart';
import '../aspetto/formati.dart';
import '../aspetto/movimento.dart';
import '../aspetto/pagina.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/striscia.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../aspetto/tipi.dart';
import '../dati/coda.dart';
import '../dati/database.dart';
import '../dati/errori.dart';
import '../dati/lettura.dart';
import '../dominio/calendario.dart';
import '../dominio/giornate.dart';
import '../dominio/mappa.dart';
import '../dominio/tappe.dart';
import '../dominio/testo.dart';
import '../servizi.dart';
import 'con_la_rete.dart';
import 'due_versioni.dart';
import 'gesti_mappa.dart';
import 'gesti_tappa.dart';
import 'luogo.dart';

/// Una tappa: nuova, o da cambiare (04-itinerario.md, "Nuova tappa"; tela,
/// 8 e 9). Cosa, che tipo — che propone la durata, sempre correggibile —,
/// quanto dura, dove e a che ora se si vuole, in che giorno.
///
/// La capienza è l'unica regola che rifiuta: se la tappa non entra nel giorno
/// scelto non si aggiunge, si dice quanto manca e si propone di accorciarla,
/// di metterla in un altro giorno o di togliere qualcosa (regola 4).
///
/// Aggiungere funziona anche senza rete: è un gesto della coda. Cambiare,
/// spostare e togliere la richiedono, e senza lo dicono prima.
///
/// Chiudendo, restituisce il giorno da aprire, se la persona ha scelto di
/// togliere qualcosa da un altro giorno.
class SchermataTappa extends StatefulWidget {
  const SchermataTappa({
    super.key,
    required this.viaggio,
    required this.giorni,
    required this.tappe,
    this.giornoId,
    this.tappa,
  });

  final Viaggio viaggio;

  /// I giorni del viaggio, in ordine.
  final List<Giorno> giorni;

  /// Le tappe di tutto il viaggio, come sono adesso.
  final List<Tappa> tappe;

  /// Il giorno proposto. Per una tappa da ricollocare, nessuno.
  final String? giornoId;

  /// La tappa da cambiare; `null` per una nuova.
  final Tappa? tappa;

  @override
  State<SchermataTappa> createState() => _SchermataTappaState();
}

class _SchermataTappaState extends State<SchermataTappa> {
  late final _titolo = TextEditingController(text: widget.tappa?.titolo);
  late String _luogo = widget.tappa?.luogoNome ?? '';

  /// Dove sta, se il posto è stato cercato e trovato (tela, 56).
  late Coordinate? _posto = widget.tappa?.posto;
  late TipoTappa? _tipo = widget.tappa == null
      ? TipoTappa.visita
      : widget.tappa!.tipoTappa;
  late Duration _durata =
      widget.tappa?.durata ?? TipoTappa.visita.durataProposta;
  late Duration? _ora = widget.tappa?.ora;
  late String? _giornoId = _giornoValido(widget.giornoId);
  late StatoTappa? _stato = widget.tappa?.statoTappa;

  /// La persona ha corretto la durata: cambiare tipo non la tocca più.
  bool _durataToccata = false;
  bool _inCorso = false;

  bool get _nuova => widget.tappa == null;

  String? _giornoValido(String? id) =>
      widget.giorni.any((g) => g.id == id) ? id : null;

  @override
  void dispose() {
    _titolo.dispose();
    super.dispose();
  }

  Giorno? get _giorno =>
      widget.giorni.where((g) => g.id == _giornoId).firstOrNull;

  /// Le altre tappe di un giorno, senza questa.
  Iterable<Tappa> _altreNel(String giornoId) => widget.tappe.where(
    (t) => t.giornoId == giornoId && t.id != widget.tappa?.id,
  );

  Duration _libero(Giorno g) => tempoLibero(
    capienza: g.finestra.capienza,
    durateMinuti: _altreNel(g.id).map((t) => t.durataStimataMin),
  );

  bool get _entra {
    final g = _giorno;
    if (g == null) return true;
    // Una tappa che resta dov'era e non si allunga non si rifiuta: una
    // giornata già troppo piena si sistema togliendo, non bloccando.
    final t = widget.tappa;
    if (t != null && t.giornoId == g.id && _durata <= t.durata) return true;
    return entraNellaGiornata(
      capienza: g.finestra.capienza,
      durateMinuti: _altreNel(g.id).map((t) => t.durataStimataMin),
      nuovaMinuti: _durata.inMinutes,
    );
  }

  /// Un'altra tappa del giorno scelto con lo stesso nome, se c'è: si
  /// avvisa, non si blocca, perché due pranzi nello stesso posto possono
  /// essere voluti.
  Tappa? get _doppia {
    final titolo = normalizza(_titolo.text);
    final giorno = _giornoId;
    if (titolo.isEmpty || giorno == null) return null;
    return _altreNel(giorno)
        .where((t) => normalizza(t.titolo) == titolo)
        .firstOrNull;
  }

  /// Cosa è cambiato, nei nomi del server. Vuoto per una tappa nuova.
  Map<String, Object?> get _cambiamenti {
    final t = widget.tappa;
    if (t == null) return const {};
    final luogo = _luogo.trim();
    return {
      if (_titolo.text.trim() != t.titolo) 'titolo': _titolo.text.trim(),
      if (_tipo?.name != t.tipo) 'tipo': _tipo?.name,
      if (_durata != t.durata) 'durata_stimata_min': _durata.inMinutes,
      if (_ora != t.ora) 'ora_inizio': _ora == null ? null : scriviOra(_ora!),
      // Il posto va col suo nome: cambia l'uno, cambiano insieme.
      if (luogo != (t.luogoNome ?? '') || _posto != t.posto) ...{
        'luogo_nome': luogo.isEmpty ? null : luogo,
        'lat': _posto?.lat,
        'lon': _posto?.lon,
      },
    };
  }

  bool get _spostata =>
      widget.tappa != null &&
      _giornoId != null &&
      _giornoId != widget.tappa!.giornoId;

  /// Perché non si può ancora salvare; `null` se si può.
  String? _motivo(bool rete) {
    if (_titolo.text.trim().isEmpty) return 'Scrivi cosa';
    if (_giorno == null) return 'Scegli il giorno';
    if (!_entra) return 'Non entra nella giornata';
    if (!_nuova && !rete && (_cambiamenti.isNotEmpty || _spostata)) {
      return motivoSenzaRete;
    }
    return null;
  }

  void _scegliTipo(TipoTappa tipo) => setState(() {
    _tipo = tipo;
    if (!_durataToccata) _durata = tipo.durataProposta;
  });

  void _cambiaDurata(Duration d) => setState(() {
    _durata = d;
    _durataToccata = true;
  });

  Future<void> _scegliOra() async {
    final attuale = _ora ?? const Duration(hours: 10);
    final scelta = await AdaptiveTimePicker.show(
      context: context,
      initialTime: TimeOfDay(
        hour: attuale.inHours % 24,
        minute: attuale.inMinutes % 60,
      ),
      use24HourFormat: true,
      minuteInterval: 5,
    );
    if (scelta != null && mounted) {
      setState(
        () => _ora = Duration(hours: scelta.hour, minutes: scelta.minute),
      );
    }
  }

  String _comeVa(Giorno g) {
    final libero = _libero(g);
    return libero.isNegative
        ? 'sfora di ${durataBreve(-libero)}'
        : 'restano ${durataBreve(libero)}';
  }

  /// «Dove?»: si cerca il posto (tela, 56), vicino alle tappe del viaggio o
  /// alla sua meta. Senza rete si scrive soltanto.
  Future<void> _scegliLuogo() async {
    final vicino = await centroDelViaggio(widget.viaggio, widget.tappe);
    if (!mounted) return;
    final scelta = await apriFoglio<SceltaLuogo>(
      context,
      FoglioLuogo(
        viaggioId: widget.viaggio.id,
        iniziale: _luogo,
        titolo: _titolo.text,
        vicinoA: vicino?.centro,
        dalleTappe: vicino?.dalleTappe ?? false,
        cercaSubito: _posto == null,
      ),
    );
    if (scelta == null || !mounted) return;
    setState(() {
      _luogo = scelta.testo;
      _posto = scelta.posto;
      // Un posto trovato dà il nome a una tappa che non ce l'ha ancora.
      if (_titolo.text.trim().isEmpty && scelta.nome != null) {
        _titolo.text = scelta.nome!;
      }
    });
  }

  Future<void> _scegliGiorno() => scegliAzione(context, [
    for (final g in widget.giorni)
      AzioneMenu(
        '${giornoBreve(g.finestra.data)} · ${_comeVa(g)}',
        () => setState(() => _giornoId = g.id),
      ),
  ]);

  Future<void> _salva() async {
    if (_nuova) return _aggiungi();
    final tappa = widget.tappa!;
    final valori = {
      ..._cambiamenti,
      if (_spostata) ...{
        'giorno_id': _giornoId,
        'ordine': ordineInFondo(_altreNel(_giornoId!).map((t) => t.ordine)),
      },
    };
    if (valori.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    final archivio = Servizi.of(context).archivio;
    setState(() => _inCorso = true);
    try {
      // Se qualcuno l'ha cambiata intanto, si sceglie fra le due versioni;
      // tornando indietro senza scegliere, quello che si è scritto è qui.
      final scelta = await salvaOScegli(
        context,
        () => archivio.modificaTappa(tappa, valori),
      );
      if (scelta != null && mounted) Navigator.of(context).pop();
    } on ErroreTrolley catch (e) {
      if (mounted) mostraMessaggio(context, e.messaggio, errore: true);
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  /// Aggiunge la tappa: nella copia subito, al server appena c'è rete. Con
  /// i suoi eventi (07): il primo elemento del viaggio (H2), la funzione usata
  /// (H1), il primo contributo di chi è stato invitato (H3).
  Future<void> _aggiungi() async {
    final viaggio = widget.viaggio;
    final giornoId = _giornoId!;
    await aggiungiLeTappe(
      context,
      viaggio: viaggio,
      tappe: [
        NuovaTappa(
          id: const Uuid().v4(),
          viaggioId: viaggio.id,
          giornoId: giornoId,
          ordine: ordineInFondo(_altreNel(giornoId).map((t) => t.ordine)),
          titolo: _titolo.text,
          tipo: _tipo,
          durata: _durata,
          ora: _ora,
          luogo: _luogo,
          posto: _posto,
        ),
      ],
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _togli() async {
    final tappa = widget.tappa!;
    var conferma = false;
    await AdaptiveAlertDialog.show(
      context: context,
      title: 'Togliere «${tappa.titolo}»?',
      message: 'Sparisce dalla giornata per tutti quelli del viaggio.',
      actions: [
        AlertAction(
          title: 'Annulla',
          style: AlertActionStyle.cancel,
          onPressed: () {},
        ),
        AlertAction(
          title: 'Togli',
          style: AlertActionStyle.destructive,
          onPressed: () => conferma = true,
        ),
      ],
    );
    if (!conferma || !mounted) return;
    final archivio = Servizi.of(context).archivio;
    setState(() => _inCorso = true);
    try {
      final scelta = await salvaOScegli(
        context,
        () => archivio.togliTappa(tappa),
      );
      if (scelta != null && mounted) Navigator.of(context).pop();
    } on ErroreTrolley catch (e) {
      if (mounted) mostraMessaggio(context, e.messaggio, errore: true);
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  Future<void> _segna(StatoTappa stato) async {
    setState(() => _stato = stato);
    await segnaLaTappa(
      context,
      viaggio: widget.viaggio,
      tappa: widget.tappa!,
      stato: stato,
    );
  }

  @override
  Widget build(BuildContext context) => ConLaRete(
    builder: (context, rete) {
      final motivo = _motivo(rete);
      final g = _giorno;
      final tappa = widget.tappa;
      final segnabili = tappeSegnabili(widget.viaggio.statoA(DateTime.now()));
      return Foglio(
        titolo: _nuova ? 'Nuova tappa' : 'La tappa',
        inBasso: AzioniFoglio(
          motivo: motivo,
          azione: PulsanteGrande(
            etichetta: _nuova ? 'Aggiungi' : 'Salva',
            inCorso: _inCorso,
            onPressed: motivo == null ? _salva : null,
          ),
        ),
        children: [
          Campo(
            controller: _titolo,
            etichetta: 'Cosa?',
            segnaposto: 'Es. Torre dei Clérigos',
            maiuscole: TextCapitalization.sentences,
            fuoco: _nuova,
            onCambia: (_) => setState(() {}),
          ),
          if (_doppia case final doppia?)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
              child: Text(
                'C\'è già «${doppia.titolo}» in questo giorno.',
                style: Testi.didascalia.copyWith(
                  color: Colori.pericolo,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 16),
          const _Etichetta('Che tipo?'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in TipoTappa.values)
                Gettone(
                  etichetta: nomeTipo(t),
                  scelto: t == _tipo,
                  onTap: () => _scegliTipo(t),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const _Etichetta('Quanto dura?'),
          _Durata(
            valore: _durata,
            onPiuCorta: _durata <= durataMinima
                ? null
                : () => _cambiaDurata(durataPiuCorta(_durata)),
            onPiuLunga: () => _cambiaDurata(durataPiuLunga(_durata)),
          ),
          if (_tipo != null && _durata == _tipo!.durataProposta)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
              child: Text(
                'Proposta per ${unTipo(_tipo!)}: correggila se serve.',
                style: Testi.didascalia.copyWith(color: Colori.grafite),
              ),
            ),
          AnimatedSize(
            duration: Ritmo.medio,
            curve: Ritmo.curva,
            alignment: Alignment.topCenter,
            child: g == null || _entra
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _NonEntra(
                      lunga: _durata,
                      giorno: g,
                      libero: _libero(g),
                      altri: [
                        for (final altro in widget.giorni)
                          if (altro.id != g.id)
                            (
                              giorno: altro,
                              data: altro.finestra.data,
                              libero: _libero(altro),
                            ),
                      ],
                      onAccorcia: (d) => _cambiaDurata(d),
                      onSposta: (altro) => setState(() => _giornoId = altro.id),
                      onTogliQualcosa: () => Navigator.of(context).pop(g.id),
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CampoScelta(
                  etichetta: 'Dove?',
                  simbolo: icona(
                    ios: CupertinoIcons.location,
                    android: Icons.place_outlined,
                  ),
                  segnaposto: 'Facoltativo',
                  valore: _luogo.trim().isEmpty ? null : _luogo.trim(),
                  righe: 2,
                  onTap: _scegliLuogo,
                  onCancella: () => setState(() {
                    _luogo = '';
                    _posto = null;
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CampoScelta(
                  etichetta: 'A che ora?',
                  simbolo: icona(
                    ios: CupertinoIcons.clock,
                    android: Icons.schedule_rounded,
                  ),
                  segnaposto: 'Facoltativa',
                  valore: _ora == null ? null : ora(_ora!),
                  onTap: _scegliOra,
                  onCancella: () => setState(() => _ora = null),
                ),
              ),
            ],
          ),
          if (_luogo.trim().isNotEmpty &&
              _posto == null &&
              Servizi.of(context).mappe.disponibili)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
              child: Text(
                'Non è sulla mappa: tocca «Dove?» per cercare il posto.',
                style: Testi.didascalia.copyWith(color: Colori.grafite),
              ),
            ),
          const SizedBox(height: 16),
          CampoScelta(
            etichetta: 'Giorno',
            simbolo: icona(
              ios: CupertinoIcons.calendar,
              android: Icons.calendar_month_outlined,
            ),
            segnaposto: 'Scegli il giorno',
            valore: g == null
                ? null
                : '${giornoBreve(g.finestra.data)} · ${_comeVa(g)}',
            onTap: _scegliGiorno,
          ),
          if (g != null) ...[
            const SizedBox(height: 8),
            StrisciaGiornata(
              capienza: g.finestra.capienza,
              pezzi: [
                for (final t in _altreNel(g.id))
                  PezzoStriscia(t.durata, coloreTipo(t.tipoTappa)),
                PezzoStriscia(_durata, Colori.cobalto, tratteggiato: true),
              ],
            ),
          ],
          if (tappa != null && segnabili) ...[
            const SizedBox(height: 16),
            const _Etichetta('Com\'è andata?'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (s, nome) in const [
                  (StatoTappa.daFare, 'Da fare'),
                  (StatoTappa.completata, 'Fatta'),
                  (StatoTappa.saltata, 'Saltata'),
                ])
                  Gettone(
                    etichetta: nome,
                    scelto: _stato == s,
                    onTap: () => _segna(s),
                  ),
              ],
            ),
          ],
          if (tappa != null) ...[
            const SizedBox(height: 20),
            PulsanteGrande(
              etichetta: 'Togli la tappa',
              secondario: true,
              pericolo: true,
              motivo: rete ? null : motivoSenzaRete,
              onPressed: _inCorso ? null : _togli,
            ),
          ],
        ],
      );
    },
  );
}

class _Etichetta extends StatelessWidget {
  const _Etichetta(this.testo);

  final String testo;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 2, bottom: 8),
    child: Text(testo, style: Testi.etichetta.copyWith(color: Colori.ardesia)),
  );
}

/// Quanto dura: un quarto d'ora in meno o in più.
class _Durata extends StatelessWidget {
  const _Durata({
    required this.valore,
    required this.onPiuCorta,
    required this.onPiuLunga,
  });

  final Duration valore;
  final VoidCallback? onPiuCorta;
  final VoidCallback onPiuLunga;

  @override
  Widget build(BuildContext context) {
    Widget pulsante(IconData simbolo, String etichetta, VoidCallback? onTap) =>
        Premibile(
          onTap: onTap,
          scala: 0.9,
          etichetta: etichetta,
          child: Opacity(
            opacity: onTap == null ? 0.35 : 1,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colori.bianco,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(simbolo, size: 20, color: Colori.inchiostro),
            ),
          ),
        );
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colori.foschia,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          pulsante(Icons.remove_rounded, 'Più corta', onPiuCorta),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(
                durata(valore),
                textAlign: TextAlign.center,
                style: Testi.numero.copyWith(color: Colori.inchiostro),
              ),
            ),
          ),
          pulsante(Icons.add_rounded, 'Più lunga', onPiuLunga),
        ],
      ),
    );
  }
}

/// Non entra: quanto manca, e cosa si può fare (tela, 9).
class _NonEntra extends StatelessWidget {
  const _NonEntra({
    required this.lunga,
    required this.giorno,
    required this.libero,
    required this.altri,
    required this.onAccorcia,
    required this.onSposta,
    required this.onTogliQualcosa,
  });

  /// Quanto dura la tappa che non entra.
  final Duration lunga;
  final Giorno giorno;
  final Duration libero;
  final List<GiornoLibero<Giorno>> altri;
  final ValueChanged<Duration> onAccorcia;
  final ValueChanged<Giorno> onSposta;
  final VoidCallback onTogliQualcosa;

  @override
  Widget build(BuildContext context) {
    final proposte = proposteSeNonEntra<Giorno>(
      durata: lunga,
      data: giorno.finestra.data,
      libero: libero,
      altriGiorni: altri,
    );
    final nome = giornoBreve(giorno.finestra.data).toLowerCase();
    final accorcia = proposte.accorciaA;
    final altro = proposte.altroGiorno;
    return Avviso(
      errore: true,
      icona: icona(ios: CupertinoIcons.clock, android: Icons.schedule_rounded),
      inizio: 'Non entra in $nome.',
      testo: libero.isNegative || libero == Duration.zero
          ? 'La giornata è già piena.'
          : 'Restano ${durata(libero)}: ne mancano ${durata(proposte.manca)}.',
      azioni: [
        if (accorcia != null)
          PulsantePiccolo(
            etichetta: 'Accorciala a ${durata(accorcia)}',
            onPressed: () => onAccorcia(accorcia),
          ),
        if (altro != null)
          PulsantePiccolo(
            etichetta:
                'Mettila ${giornoBreve(altro.data).toLowerCase()} · restano '
                '${durataBreve(altro.libero)}',
            onPressed: () => onSposta(altro.giorno),
          ),
        PulsantePiccolo(
          etichetta: 'Togli qualcosa da $nome',
          onPressed: onTogliQualcosa,
        ),
      ],
    );
  }
}
