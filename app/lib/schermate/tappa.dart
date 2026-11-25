import 'dart:async';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../aspetto/elementi.dart';
import '../aspetto/formati.dart';
import '../aspetto/formati.dart' as formati;
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
import '../dominio/orari.dart';
import '../dominio/tappe.dart';
import '../dominio/testo.dart';
import '../misurazione/misurazione.dart';
import '../servizi.dart';
import 'con_la_rete.dart';
import 'due_versioni.dart';
import 'gesti_mappa.dart';
import 'gesti_tappa.dart';
import 'luogo.dart';

/// Una tappa: nuova, o da cambiare (04-itinerario.md, "Nuova tappa"; tela,
/// 8, 128 e 129). Cosa, che tipo — che propone la durata, sempre
/// correggibile —, quanto dura, dove se si vuole, a che ora, in che giorno.
///
/// L'orario è proposto subito dopo l'ultima tappa del giorno (04, regola 19).
/// Una tappa che si sovrappone a un'altra, o esce dalla giornata, non si
/// salva: si dice perché e si propone solo quello che si può fare (regola
/// 22) — l'orario libero più vicino, spostare in avanti le tappe dopo,
/// accorciarla, un altro giorno, togliere qualcosa.
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
    this.ora,
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

  /// Per una tappa nuova, l'ora toccata sulla linea del tempo.
  final Duration? ora;

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
  late String? _giornoId = _giornoValido(widget.giornoId);

  /// A che ora comincia: quella della tappa, o la proposta.
  late Duration _ora = _oraIniziale();

  /// L'ora di prima, per una tappa che c'era: la sua, o quella che le
  /// proponeva la linea del tempo.
  late final Duration? _oraDiPrima = widget.tappa == null ? null : _ora;

  /// La persona ha corretto la durata, o l'ora: cambiare tipo o giorno non le
  /// tocca più.
  bool _durataToccata = false;
  late bool _oraToccata = widget.tappa != null || widget.ora != null;

  /// «Tienila a quest'ora e sposta le tappe dopo» (regola 22): chi va dove,
  /// salvando.
  List<Spostamento<Tappa>>? _spostaDopo;
  bool _inCorso = false;

  /// Per `tappa_non_entrata` (07): perché non entrava, la prima volta che lo
  /// si è detto, e che cosa si è scelto.
  String? _motivoVisto;
  String? _scelta;
  bool _finita = false;
  late final _misurazione = Servizi.of(context).misurazione;

  bool get _nuova => widget.tappa == null;

  String? _giornoValido(String? id) =>
      widget.giorni.any((g) => g.id == id) ? id : null;

  Duration _oraIniziale() {
    final t = widget.tappa;
    final g = _giorno;
    if (t != null) {
      if (t.ora != null) return t.ora!;
      final collocata = g == null
          ? null
          : tappeDelGiorno(
              g,
              widget.tappe,
            ).where((c) => c.tappa.id == t.id).firstOrNull;
      return collocata?.inizio ?? primaOraProposta;
    }
    return widget.ora ?? _proposta(g) ?? g?.finestra.inizio ?? primaOraProposta;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _misurazione;
  }

  @override
  void dispose() {
    _titolo.dispose();
    final motivo = _motivoVisto;
    if (motivo != null) {
      unawaited(
        _misurazione.registra(Eventi.tappaNonEntrata, {
          'motivo': motivo,
          'scelta': _finita ? (_scelta ?? 'a_mano') : 'lasciata',
        }),
      );
    }
    super.dispose();
  }

  Giorno? get _giorno =>
      widget.giorni.where((g) => g.id == _giornoId).firstOrNull;

  /// Le altre tappe di un giorno, senza questa.
  Iterable<Tappa> _altreNel(String giornoId) => widget.tappe.where(
    (t) => t.giornoId == giornoId && t.id != widget.tappa?.id,
  );

  /// Le altre tappe di un giorno al loro posto, con quelle che si è scelto di
  /// spostare già dove andranno.
  List<Occupato<Tappa>> _occupati(Giorno g) {
    final sposta = {
      for (final s in _spostaDopo ?? const <Spostamento<Tappa>>[])
        s.chi.id: s.inizio,
    };
    return [
      for (final o in occupatiDel(g, widget.tappe, tranne: widget.tappa?.id))
        sposta.containsKey(o.chi.id)
            ? Occupato(
                o.chi,
                inizio: sposta[o.chi.id]!,
                durata: o.durata,
                segnata: o.segnata,
              )
            : o,
    ];
  }

  Duration? _proposta(Giorno? g) => g == null
      ? null
      : oraProposta(
          g.finestra,
          occupatiDel(g, widget.tappe, tranne: widget.tappa?.id),
          _durata,
        );

  /// Che problema ha la tappa così com'è adesso nel foglio.
  ProblemaOrario<Tappa>? get _problema {
    final g = _giorno;
    if (g == null) return null;
    return problemaOrario(g.finestra, _occupati(g), _ora, _durata);
  }

  /// Si è toccato quello che decide dove sta: l'ora, la durata, il giorno.
  /// Cambiare solo il nome o il posto di una tappa già fuori posto non si
  /// blocca (regola 24).
  bool get _toccaIlPosto {
    final t = widget.tappa;
    return t == null || _ora != _oraDiPrima || _durata != t.durata || _spostata;
  }

  Duration _libero(Giorno g) => tempoLibero(
    capienza: g.finestra.capienza,
    durateMinuti: _altreNel(g.id).map((t) => t.durataStimataMin),
  );

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
      // Un orario proposto si conferma salvando (regola 27).
      if (_ora != t.ora) 'ora_inizio': scriviOra(_ora),
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
    final problema = _problema;
    if (problema != null && _toccaIlPosto) {
      return conMaiuscola(problemaInBreve(problema));
    }
    if (_spostaDopo != null && !rete) return motivoSenzaRete;
    if (!_nuova && !rete && (_cambiamenti.isNotEmpty || _spostata)) {
      return motivoSenzaRete;
    }
    return null;
  }

  void _scegliTipo(TipoTappa tipo) => setState(() {
    _tipo = tipo;
    if (!_durataToccata) _durata = tipo.durataProposta;
    _riproponi();
  });

  void _cambiaDurata(Duration d) => setState(() {
    _durata = d;
    _durataToccata = true;
    _spostaDopo = null;
    _riproponi();
  });

  /// Finché la persona non ha scelto un'ora, l'ora segue il giorno e la
  /// durata: resta «subito dopo l'ultima».
  void _riproponi() {
    if (_oraToccata) return;
    _ora = _proposta(_giorno) ?? _ora;
  }

  void _metti(Duration ora, String scelta) => setState(() {
    _ora = ora;
    _oraToccata = true;
    _spostaDopo = null;
    _scelta = scelta;
  });

  Future<void> _scegliOra() async {
    final scelta = await AdaptiveTimePicker.show(
      context: context,
      initialTime: TimeOfDay(
        hour: _ora.inHours % 24,
        minute: _ora.inMinutes % 60,
      ),
      use24HourFormat: true,
      minuteInterval: 5,
    );
    if (scelta != null && mounted) {
      setState(() {
        _ora = Duration(hours: scelta.hour, minutes: scelta.minute);
        _oraToccata = true;
        _spostaDopo = null;
        _scelta = null;
      });
    }
  }

  String _comeVa(Giorno g) {
    final libero = _libero(g);
    return libero.isNegative
        ? 'sfora di ${durataBreve(-libero)}'
        : 'restano ${durataBreve(libero)}';
  }

  /// Sotto l'ora: quando finisce, e da dove viene la proposta.
  String get _dellOra {
    final fine = 'finisce alle ${ora(_ora + _durata)}';
    final t = widget.tappa;
    if (t != null && t.ora == null && _ora == _oraDiPrima) {
      return 'Orario proposto, perché la tappa non ne aveva uno: '
          'salvando resta questo.';
    }
    if (!_oraToccata) {
      final g = _giorno;
      final prima = g == null
          ? null
          : _occupati(g).where((o) => o.fine == _ora).firstOrNull;
      if (prima != null) {
        return 'Subito dopo «${prima.chi.titolo}»: $fine. Toccala per '
            'cambiarla.';
      }
    }
    return '${conMaiuscola(fine)}.';
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
        () => setState(() {
          _giornoId = g.id;
          _spostaDopo = null;
          _riproponi();
        }),
      ),
  ]);

  /// Prima di salvare, le tappe che si è scelto di spostare in avanti: con
  /// la loro versione. Se una è cambiata intanto si ferma tutto, e il foglio
  /// resta com'era.
  Future<bool> _spostaPrima() async {
    final sposta = _spostaDopo;
    if (sposta == null) return true;
    for (final s in sposta) {
      final riuscito = await spostaLaTappa(context, s.chi, s.inizio);
      if (!riuscito || !mounted) return false;
    }
    return true;
  }

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
    if (valori.isEmpty && _spostaDopo == null) {
      Navigator.of(context).pop();
      return;
    }
    final archivio = Servizi.of(context).archivio;
    setState(() => _inCorso = true);
    try {
      if (!await _spostaPrima()) return;
      if (!mounted) return;
      // Se qualcuno l'ha cambiata intanto, si sceglie fra le due versioni;
      // tornando indietro senza scegliere, quello che si è scritto è qui.
      final scelta = await salvaOScegli(
        context,
        () => archivio.modificaTappa(tappa, valori),
      );
      if (scelta != null && mounted) {
        _finita = true;
        Navigator.of(context).pop();
      }
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
    setState(() => _inCorso = true);
    try {
      if (!await _spostaPrima()) return;
      if (!mounted) return;
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
      _finita = true;
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
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

  @override
  Widget build(BuildContext context) => ConLaRete(
    builder: (context, rete) {
      final motivo = _motivo(rete);
      final g = _giorno;
      final tappa = widget.tappa;
      final problema = _problema;
      final proposte = g == null || problema == null
          ? null
          : proposteOrario<Giorno, Tappa>(
              finestra: g.finestra,
              altre: _occupati(g),
              inizio: _ora,
              durata: _durata,
              altriGiorni: [
                for (final altro in widget.giorni)
                  if (altro.id != g.id)
                    (
                      giorno: altro,
                      finestra: altro.finestra,
                      occupati: occupatiDel(
                        altro,
                        widget.tappe,
                        tranne: tappa?.id,
                      ),
                    ),
              ],
            );
      if (problema != null && proposte != null && _toccaIlPosto) {
        _motivoVisto ??= proposte.libero < _durata
            ? 'piena'
            : problema is Sovrapposta<Tappa>
            ? 'sovrapposta'
            : 'fuori_giornata';
      }
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
                  segnaposto: 'Scegli l\'ora',
                  valore: ora(_ora),
                  onTap: _scegliOra,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Text(
              _dellOra,
              style: Testi.didascalia.copyWith(color: Colori.grafite),
            ),
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
          AnimatedSize(
            duration: Ritmo.medio,
            curve: Ritmo.curva,
            alignment: Alignment.topCenter,
            child: g == null || problema == null || proposte == null
                ? (_spostaDopo == null
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: _Spostamenti(
                            spostamenti: _spostaDopo!,
                            rete: rete,
                            onAnnulla: () => setState(() {
                              _spostaDopo = null;
                              _scelta = null;
                            }),
                          ),
                        ))
                : Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _NonSta(
                      problema: problema,
                      proposte: proposte,
                      ora: _ora,
                      durata: _durata,
                      giorno: g,
                      rete: rete,
                      onOrario: (o) => _metti(o, 'orario_libero'),
                      onSpostaDopo: (s) => setState(() {
                        _spostaDopo = s;
                        _scelta = 'sposta_dopo';
                      }),
                      onAccorcia: (d) {
                        _cambiaDurata(d);
                        _scelta = 'accorcia';
                      },
                      onAltroGiorno: (altro, alle) => setState(() {
                        _giornoId = altro.id;
                        _ora = alle;
                        _oraToccata = true;
                        _spostaDopo = null;
                        _scelta = 'altro_giorno';
                      }),
                      onTogliQualcosa: () {
                        _scelta = 'togli';
                        _finita = true;
                        Navigator.of(context).pop(g.id);
                      },
                    ),
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
              daOra: g.finestra.inizio,
              pezzi: [
                for (final o in _occupati(g))
                  PezzoStriscia(
                    o.durata,
                    coloreTipo(o.chi.tipoTappa),
                    inizio: o.inizio,
                  ),
                PezzoStriscia(
                  _durata,
                  Colori.cobalto,
                  tratteggiato: true,
                  inizio: _ora,
                  rosso: problema != null,
                ),
              ],
            ),
          ],
          // Com'è andata si dice dal dettaglio della tappa (tela, 156–157):
          // questo foglio è per cambiarla.
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

/// Elenca dei titoli: «A», «A» e «B», «A», «B» e «C».
String _titoli(Iterable<Tappa> tappe) {
  final nomi = [for (final t in tappe) '«${t.titolo}»'];
  if (nomi.length <= 1) return nomi.join();
  return '${nomi.sublist(0, nomi.length - 1).join(', ')} e ${nomi.last}';
}

/// Non sta lì: perché, e cosa si può fare (tela, 9 e 129; 04, regola 22).
class _NonSta extends StatelessWidget {
  const _NonSta({
    required this.problema,
    required this.proposte,
    required this.ora,
    required this.durata,
    required this.giorno,
    required this.rete,
    required this.onOrario,
    required this.onSpostaDopo,
    required this.onAccorcia,
    required this.onAltroGiorno,
    required this.onTogliQualcosa,
  });

  final ProblemaOrario<Tappa> problema;
  final ProposteOrario<Giorno, Tappa> proposte;
  final Duration ora;
  final Duration durata;
  final Giorno giorno;
  final bool rete;
  final ValueChanged<Duration> onOrario;
  final ValueChanged<List<Spostamento<Tappa>>> onSpostaDopo;
  final ValueChanged<Duration> onAccorcia;
  final void Function(Giorno giorno, Duration ora) onAltroGiorno;
  final VoidCallback onTogliQualcosa;

  @override
  Widget build(BuildContext context) {
    final nome = giornoBreve(giorno.finestra.data).toLowerCase();
    final (inizio, testo) = switch (problema) {
      Sovrapposta(:final con) when con.length == 1 => (
        'Alle ${formati.ora(ora)} c\'è già «${con.single.chi.titolo}»',
        'dalle ${formati.ora(con.single.inizio)} alle '
            '${formati.ora(con.single.fine)}.',
      ),
      Sovrapposta(:final con) => (
        'Si sovrappone a ${_titoli([for (final o in con) o.chi])}.',
        '',
      ),
      PrimaDellInizio(:final inizio) => (
        'Il primo giorno arrivi alle ${formati.ora(inizio)}.',
        '',
      ),
      DopoLaFine(:final fine) when fine >= fineGiornata => (
        'Finirebbe dopo mezzanotte.',
        'Una tappa non attraversa la notte.',
      ),
      DopoLaFine(:final fine) => (
        'L\'ultimo giorno riparti alle ${formati.ora(fine)}.',
        '',
      ),
    };
    final piena = proposte.libero < durata;
    final sotto = [
      if (testo.isNotEmpty) testo,
      if (piena)
        proposte.libero <= Duration.zero
            ? 'La giornata è già piena.'
            : 'In tutto restano ${formati.durata(proposte.libero)}: ne '
                  'mancano ${formati.durata(durata - proposte.libero)}.',
    ].join(' ');
    final libero = proposte.orarioLibero;
    final dopo = proposte.spostaDopo;
    final accorcia = proposte.accorciaA;
    final altro = proposte.altroGiorno;
    return Avviso(
      errore: true,
      icona: icona(ios: CupertinoIcons.clock, android: Icons.schedule_rounded),
      inizio: inizio,
      testo: sotto,
      azioni: [
        if (libero != null)
          PulsantePiccolo(
            etichetta: 'Mettila alle ${formati.ora(libero)}',
            onPressed: () => onOrario(libero),
          ),
        // Spostare le altre è cambiarle: richiede la rete.
        if (dopo != null && rete)
          PulsantePiccolo(
            etichetta:
                'Tienila alle ${formati.ora(ora)} e sposta più tardi '
                '${_titoli([for (final s in dopo) s.chi])}',
            onPressed: () => onSpostaDopo(dopo),
          ),
        if (accorcia != null)
          PulsantePiccolo(
            etichetta: 'Accorciala a ${formati.durata(accorcia)}',
            onPressed: () => onAccorcia(accorcia),
          ),
        if (altro != null)
          PulsantePiccolo(
            etichetta:
                'Mettila ${giornoBreve(altro.data).toLowerCase()} alle '
                '${formati.ora(altro.ora)}',
            onPressed: () => onAltroGiorno(altro.giorno, altro.ora),
          ),
        PulsantePiccolo(
          etichetta: 'Togli qualcosa da $nome',
          onPressed: onTogliQualcosa,
        ),
      ],
    );
  }
}

/// Le tappe che si sposteranno in avanti salvando, con «Annulla».
class _Spostamenti extends StatelessWidget {
  const _Spostamenti({
    required this.spostamenti,
    required this.rete,
    required this.onAnnulla,
  });

  final List<Spostamento<Tappa>> spostamenti;
  final bool rete;
  final VoidCallback onAnnulla;

  @override
  Widget build(BuildContext context) => Avviso(
    fondo: Colori.foschia,
    icona: icona(
      ios: CupertinoIcons.arrow_down,
      android: Icons.arrow_downward_rounded,
    ),
    colore: Colori.cobalto,
    inizio: 'Salvando, si spostano più tardi:',
    testo: [
      for (final s in spostamenti)
        '«${s.chi.titolo}» alle ${formati.ora(s.inizio)}',
    ].join(', '),
    azioni: [PulsantePiccolo(etichetta: 'Annulla', onPressed: onAnnulla)],
  );
}
