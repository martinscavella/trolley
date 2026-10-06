import 'dart:async';

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
import '../dominio/calendario.dart';
import '../dominio/divisione.dart';
import '../dominio/spese.dart';
import '../dominio/valute.dart';
import '../servizi.dart';
import 'con_la_rete.dart';
import 'due_versioni.dart';
import 'foglio_spesa.dart';
import 'problemi_coda.dart';
import 'saldi.dart';

/// Quello che serve per mostrare le spese di un viaggio: le spese, la valuta
/// della persona, gli ultimi tassi noti e di quando sono, chi ha pagato e per
/// chi, chi è passato dal viaggio.
class ContoViaggio {
  ContoViaggio({
    required List<Spesa> spese,
    required this.mia,
    required this.perEuro,
    required this.giornoTassi,
    required this.nomi,
    required this.io,
    this.quote = const [],
    this.presenze = const [],
    this.dueSpese = const {},
  }) : spese = [
         for (final s in spese)
           if (!s.rimborso) s,
       ],
       rimborsi = [
         for (final s in spese)
           if (s.rimborso) s,
       ];

  /// Le spese vere, senza i rimborsi.
  final List<Spesa> spese;

  /// I soldi già passati di mano per pareggiare (06, regola 9).
  final List<Spesa> rimborsi;

  /// La valuta in cui la persona vede le spese (06, regola 4).
  final String mia;
  final Map<String, double> perEuro;

  /// Il giorno degli ultimi tassi sul telefono; `null` se non ce ne sono.
  final DateTime? giornoTassi;

  /// Chi è passato dal viaggio, per id.
  final Map<String, String> nomi;
  final String? io;

  /// Per chi sono le spese: le quote, nella valuta di ogni spesa.
  final List<SpesaQuota> quote;

  /// Chi è passato dal viaggio, con quando è entrato e se è uscito.
  final List<Partecipazione> presenze;

  /// Le coppie di spese che chi le ha registrate ha detto essere due.
  final Set<String> dueSpese;

  Totale totale([Iterable<Spesa>? quali]) => totaleSpese(
    (quali ?? spese).map((s) => s.voce),
    mia: mia,
    perEuro: perEuro,
  );

  /// Qualche spesa è in un'altra valuta: il totale passa da un tasso.
  bool get convertite => spese.any((s) => s.valuta != mia);

  /// Nel viaggio c'è, o c'è stato, qualcun altro: si parla di dividere. Da
  /// soli si tiene il conto e basta (06, regola 3).
  bool get diviso => presenze.length > 1 || spese.any((s) => s.paganteId != io);

  /// Quello che vale una spesa nella valuta della persona; `null` senza tasso.
  int? inMiaValuta(Spesa s) =>
      converti(s.centesimi, da: s.valuta, a: mia, perEuro: perEuro);

  /// Chi è nel viaggio adesso: prima la persona, poi gli altri per nome.
  late final List<String> attivi = () {
    final ids = [
      for (final p in presenze)
        if (p.stato == 'attivo') p.utenteId,
    ];
    if (ids.isEmpty && io != null) ids.add(io!);
    return ids..sort((a, b) {
      if (a == io) return -1;
      if (b == io) return 1;
      return (nomi[a] ?? '').compareTo(nomi[b] ?? '');
    });
  }();

  /// Ha lasciato il viaggio: resta nei conti, tratteggiato.
  bool uscito(String id) =>
      presenze.any((p) => p.utenteId == id && p.stato != 'attivo');

  /// «tu», «Marco», «chi è uscito» se il nome non c'è.
  String nome(String id) => id == io ? 'tu' : nomi[id] ?? 'chi è uscito';

  late final Map<String, Map<String, int>> _quotePerSpesa = () {
    final per = <String, Map<String, int>>{};
    for (final q in quote) {
      per.putIfAbsent(q.spesaId, () => {})[q.utenteId] = centesimiDa(q.quota);
    }
    return per;
  }();

  late final List<Presenza> _presenze = [
    for (final p in presenze)
      Presenza(
        p.utenteId,
        entrato: DateTime.tryParse(p.creatoIl ?? ''),
        uscito: p.stato == 'attivo'
            ? null
            : DateTime.tryParse(p.modificatoIl ?? ''),
      ),
  ];

  /// Per chi è una spesa: le sue quote, o — se è di prima della divisione —
  /// in parti uguali fra chi c'era quando è stata registrata.
  Map<String, int> quoteDi(Spesa s) =>
      _quotePerSpesa[s.id] ??
      partiUguali(
        s.centesimi,
        chiCera(s.registrata, presenze: _presenze, pagante: s.paganteId),
      );

  /// Le quote scritte di una spesa, senza ricavarle: vuote se non ce ne sono.
  Map<String, int> quoteScritte(Spesa s) => _quotePerSpesa[s.id] ?? const {};

  SpesaDaDividere _daDividere(Spesa s) => SpesaDaDividere(
    pagante: s.paganteId,
    centesimi: s.centesimi,
    valuta: s.valuta,
    quote: quoteDi(s),
    rimborso: s.rimborso,
  );

  /// Quanto deve ricevere o dare ognuno, rimborsi compresi.
  late final Saldi saldi = calcolaSaldi(
    [
      for (final s in [...spese, ...rimborsi]) _daDividere(s),
    ],
    mia: mia,
    perEuro: perEuro,
  );

  /// Il giro più corto per pareggiare.
  late final List<Passaggio> passaggi = pareggia(saldi.netti);

  /// Quanti passaggi servirebbero spesa per spesa, senza il giro più corto.
  late final int passaggiSenzaGiro = passaggiUnoAUno(
    [
      for (final s in [...spese, ...rimborsi]) _daDividere(s),
    ],
    mia: mia,
    perEuro: perEuro,
  );

  /// La propria parte delle spese del viaggio.
  Totale get laMiaParte => totaleSpese(
    [
      for (final s in spese)
        if ((quoteDi(s)[io] ?? 0) > 0)
          VoceSpesa(
            spesa: s,
            centesimi: quoteDi(s)[io]!,
            valuta: s.valuta,
            data: s.giorno,
            creataIl: s.registrata,
          ),
    ],
    mia: mia,
    perEuro: perEuro,
  );

  /// Quello che la persona ha pagato.
  Totale get hoPagato => totale(spese.where((s) => s.paganteId == io));

  /// Le spese registrate da altri che sembrano la stessa di una propria
  /// registrata dopo: quella dell'altro, e la propria (06, casi limite).
  late final List<(Spesa, Spesa)> doppie = [
    for (final (sua, mia) in forseDoppie([
      for (final s in spese)
        SpesaRegistrata(
          spesa: s,
          creatore: s.creatoDa,
          centesimi: s.centesimi,
          valuta: s.valuta,
          registrata: s.registrata,
        ),
    ]))
      if (mia.creatoDa == io && !dueSpese.contains(chiaveDueSpese(sua, mia)))
        (sua, mia),
  ];

  /// «Pagata da te», «Pagata da Sara».
  String pagataDa(Spesa s) =>
      s.paganteId == io ? 'pagata da te' : 'pagata da ${nome(s.paganteId)}';

  /// «per tutti e 3», «per te», «per Marco e Sara · importi diversi».
  String perChi(Spesa s) {
    final quote = quoteDi(s);
    final persone = [
      for (final p in [
        ...attivi,
        ...quote.keys.where((k) => !attivi.contains(k)),
      ])
        if ((quote[p] ?? 0) > 0) p,
    ];
    final tutti =
        persone.length == attivi.length && attivi.every(persone.contains);
    final chi = tutti && persone.length > 1
        ? persone.length == 2
              ? 'per tutti e due'
              : 'per tutti e ${persone.length}'
        : persone.length == 1 && persone.single == io
        ? 'per te'
        : 'per ${elenco([for (final p in persone) p == io ? 'te' : nome(p)])}';
    return inPartiUguali(s.centesimi, quote) ? chi : '$chi · importi diversi';
  }
}

/// Il saldo di qualcuno in parole, dai passaggi del giro più corto: «deve
/// 6,20 € a te», «deve ricevere 9,00 € da Sara». `null` se è pari.
String? saldoInParole(ContoViaggio conto, String persona) {
  final parti = [
    for (final p in conto.passaggi)
      if (p.da == persona)
        'deve ${scriviImporto(p.centesimi, conto.mia)} a '
            '${p.a == conto.io ? 'te' : conto.nome(p.a)}'
      else if (p.a == persona)
        'deve ricevere ${scriviImporto(p.centesimi, conto.mia)} da '
            '${p.da == conto.io ? 'te' : conto.nome(p.da)}',
  ];
  return parti.isEmpty ? null : elenco(parti);
}

/// La chiave di due spese che chi le ha registrate ha detto essere due.
String chiaveDueSpese(Spesa a, Spesa b) {
  final ids = [a.id, b.id]..sort();
  return ids.join('|');
}

/// «Marco», «Marco e Sara», «te, Marco e Sara».
String elenco(List<String> nomi) => switch (nomi.length) {
  0 => 'nessuno',
  1 => nomi.single,
  _ => '${nomi.sublist(0, nomi.length - 1).join(', ')} e ${nomi.last}',
};

/// Mette insieme le spese di un viaggio, la valuta della persona, i tassi, i
/// nomi, le quote e chi c'è, dalla copia locale: si legge anche senza rete.
class ConConto extends StatefulWidget {
  const ConConto({super.key, required this.viaggioId, required this.builder});

  final String viaggioId;
  final Widget Function(BuildContext context, ContoViaggio? conto) builder;

  @override
  State<ConConto> createState() => _ConContoState();
}

class _ConContoState extends State<ConConto> {
  late Stream<ContoViaggio> _conto;
  bool _avviato = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_avviato) return;
    _avviato = true;
    _conto = osservaConto(Servizi.of(context).archivio, widget.viaggioId);
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<ContoViaggio>(
    stream: _conto,
    builder: (context, conto) => widget.builder(context, conto.data),
  );
}

/// Il conto del viaggio dalla copia, che si aggiorna con lei.
Stream<ContoViaggio> osservaConto(Archivio archivio, String viaggioId) {
  final controllore = StreamController<ContoViaggio>();
  List<Spesa>? spese;
  var tassi = const <TassoCambio>[];
  Utente? profilo;
  var nomi = const <String, String>{};
  var quote = const <SpesaQuota>[];
  var presenze = const <Partecipazione>[];
  var dueSpese = const <String>{};
  void manda() {
    final elenco = spese;
    if (elenco == null || controllore.isClosed) return;
    controllore.add(
      ContoViaggio(
        spese: elenco,
        mia: profilo?.valutaPredefinita ?? valutaIniziale,
        perEuro: tassiPerEuro(tassi),
        giornoTassi: giornoDeiTassi(tassi),
        nomi: nomi,
        io: archivio.io,
        quote: quote,
        presenze: presenze,
        dueSpese: dueSpese,
      ),
    );
  }

  // Si manda solo quando ogni pezzo è arrivato almeno una volta: un saldo
  // senza le quote sarebbe sbagliato, anche per un istante.
  final arrivati = <int>{};
  void arrivato(int pezzo) {
    arrivati.add(pezzo);
    if (arrivati.length == 7) manda();
  }

  final abbonamenti = <StreamSubscription<Object?>>[];
  controllore
    ..onListen = () {
      abbonamenti.addAll([
        archivio.osservaSpese(viaggioId).listen((v) {
          spese = v;
          arrivato(0);
        }),
        archivio.osservaTassi().listen((v) {
          tassi = v;
          arrivato(1);
        }),
        archivio.osservaProfilo().listen((v) {
          profilo = v;
          arrivato(2);
        }),
        archivio.osservaNomi(viaggioId).listen((v) {
          nomi = v;
          arrivato(3);
        }),
        archivio.osservaQuote(viaggioId).listen((v) {
          quote = v;
          arrivato(4);
        }),
        archivio.osservaPresenze(viaggioId).listen((v) {
          presenze = v;
          arrivato(5);
        }),
        archivio.osservaDueSpese().listen((v) {
          dueSpese = v;
          arrivato(6);
        }),
      ]);
    }
    ..onCancel = () async {
      for (final a in abbonamenti) {
        await a.cancel();
      }
    };
  return controllore.stream;
}

/// Il conto del viaggio com'è adesso: per un dialogo, una volta.
Future<ContoViaggio> contoDi(Archivio archivio, String viaggioId) =>
    osservaConto(archivio, viaggioId).first;

/// Apre il foglio di una spesa nuova.
Future<void> nuovaSpesa(BuildContext context, Viaggio viaggio) =>
    apriFoglio<void>(context, FoglioSpesa(viaggio: viaggio));

/// Le spese del viaggio (06-spese.md, "Spese del viaggio"; tela, 16): in cima
/// il totale nella valuta della persona, con di quando sono i tassi; sotto le
/// spese giorno per giorno, dall'ultima. Si leggono e si registrano anche
/// senza rete.
class SchermataSpese extends StatefulWidget {
  const SchermataSpese({super.key, required this.viaggioId});

  final String viaggioId;

  @override
  State<SchermataSpese> createState() => _SchermataSpeseState();
}

class _SchermataSpeseState extends State<SchermataSpese> {
  late Stream<Viaggio?> _viaggio;
  late Stream<List<OperazioneInCoda>> _coda;
  bool _avviata = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_avviata) return;
    _avviata = true;
    final archivio = Servizi.of(context).archivio;
    _viaggio = archivio.osservaViaggio(widget.viaggioId);
    _coda = archivio.coda.osserva(widget.viaggioId);
    unawaited(segnaAperturaSenzaRete(context, 'spese'));
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<Viaggio?>(
    stream: _viaggio,
    builder: (context, viaggio) => ConConto(
      viaggioId: widget.viaggioId,
      builder: (context, conto) {
        final v = viaggio.data;
        if (v == null || conto == null) {
          return const Pagina(corpo: Center(child: IndicatoreAttivita()));
        }
        return ConLaRete(
          builder: (context, rete) => StreamBuilder<List<OperazioneInCoda>>(
            stream: _coda,
            builder: (context, coda) =>
                _pagina(v, conto, rete, coda.data ?? const []),
          ),
        );
      },
    ),
  );

  Widget _pagina(
    Viaggio viaggio,
    ContoViaggio conto,
    bool rete,
    List<OperazioneInCoda> coda,
  ) {
    final oggi = DateTime.now();
    final ammesse = speseAmmesse(viaggio.statoA(oggi));
    final (inizio, fine) = (viaggio.inizio, viaggio.fine);
    final gruppi = raggruppaSpese(
      [for (final s in conto.spese) s.voce],
      inizio: inizio,
      fine: fine,
    );
    final sotto = [
      titoloViaggio(viaggio),
      if (inizio != null && fine != null) intervalloDate(inizio, fine),
    ].join(' · ');
    void registra() => nuovaSpesa(context, viaggio);

    return Pagina(
      azioni: [
        if (!rete)
          const SeiOffline()
        else if (ammesse)
          PulsanteTondo(
            icona: Icons.add_rounded,
            etichetta: 'Registra una spesa',
            onPressed: registra,
          ),
      ],
      inBasso: ammesse
          ? PulsanteGrande(
              etichetta: 'Registra una spesa',
              icona: Icons.add_rounded,
              onPressed: registra,
            )
          : null,
      corpo: Builder(
        builder: (context) => ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.paddingOf(context).top + 8,
            20,
            MediaQuery.paddingOf(context).bottom + 96,
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
                      'Spese',
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
            const SizedBox(height: 16),
            if (conto.spese.isEmpty)
              Pannello(
                child: Text(
                  ammesse
                      ? 'Quanto spendete, mentre lo spendete: bastano '
                            'l\'importo e un tocco, anche senza rete. Il volo e '
                            'gli acconti vanno in «Prima del viaggio».'
                      : 'Le spese tornano in vista quando il viaggio ha di '
                            'nuovo le date.',
                  style: Testi.secondario.copyWith(color: Colori.grafite),
                ),
              ).entra(context, ritardo: Ritmo.passo)
            else
              _Totale(
                conto: conto,
                rete: rete,
              ).entra(context, ritardo: Ritmo.passo),
            if (conto.diviso &&
                (conto.spese.isNotEmpty || conto.rimborsi.isNotEmpty)) ...[
              const SizedBox(height: 10),
              RigaSaldi(
                conto: conto,
                viaggio: viaggio,
              ).entra(context, ritardo: Ritmo.passo),
            ],
            for (final (sua, mia) in conto.doppie) ...[
              const SizedBox(height: 12),
              _ForseDoppia(sua: sua, mia: mia, conto: conto, rete: rete),
            ],
            ProblemiDellaCoda(
              operazioni: [
                for (final op in coda)
                  if (op.gesto == GestoOffline.registraSpesa) op,
              ],
            ),
            for (final (i, gruppo) in gruppi.indexed)
              ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
                  child: Semantics(
                    header: true,
                    child: Text(
                      titoloGruppoSpese(gruppo.tipo, gruppo.data, oggi),
                      style: Testi.sezione.copyWith(
                        color:
                            gruppo.data != null &&
                                soloData(gruppo.data!) == soloData(oggi)
                            ? Colori.cobalto
                            : Colori.grafite,
                      ),
                    ),
                  ),
                ),
                for (final (j, voce) in gruppo.spese.indexed) ...[
                  if (j > 0) const SizedBox(height: 8),
                  RigaSpesa(
                    spesa: voce.spesa,
                    conto: conto,
                    viaggio: viaggio,
                    conData: gruppo.tipo != TipoGruppoSpese.giorno,
                  ),
                ],
              ].map((w) => w.entra(context, ritardo: Ritmo.passo * (i + 2))),
          ],
        ),
      ),
    );
  }
}

/// Il totale in cima all'elenco (tela, 16): in tutto, nella valuta della
/// persona; quello che non si può convertire, a parte; di quando sono i tassi
/// e, senza rete, che possono essere cambiati (06, regola 6).
class _Totale extends StatelessWidget {
  const _Totale({required this.conto, required this.rete});

  final ContoViaggio conto;
  final bool rete;

  @override
  Widget build(BuildContext context) {
    final totale = conto.totale();
    final altre = {
      for (final s in conto.spese)
        if (s.valuta != conto.mia) s.valuta,
    };
    final spiegazione = <String>[
      if (conto.convertite) ...[
        rete
            ? 'Con i ${quandoITassi(conto.giornoTassi, DateTime.now())}.'
            : 'Con i ${quandoITassi(conto.giornoTassi, DateTime.now())}: '
                  'senza rete possono essere cambiati.',
        altre.length == 1
            ? 'Conta quello che hai pagato, in '
                  '${nomeCortoValuta(altre.single).toLowerCase()}.'
            : 'Conta quello che hai pagato, ciascuna nella sua valuta.',
      ] else
        quanti(conto.spese.length, 'spesa', 'spese'),
    ].join(' ');
    final (parte, pagato) = conto.diviso
        ? (conto.laMiaParte, conto.hoPagato)
        : (null, null);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: Colori.bianco,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'IN TUTTO',
            style: Testi.sezione.copyWith(color: Colori.grafite),
          ),
          const SizedBox(height: 6),
          Text(
            scriviImporto(totale.centesimi, conto.mia),
            style: Testi.titoli(
              34,
              altezza: 1.05,
            ).copyWith(color: Colori.inchiostro),
          ),
          for (final MapEntry(key: valuta, value: centesimi)
              in totale.nonConvertite.entries)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '+ ${scriviImporto(centesimi, valuta)}, senza tasso',
                style: Testi.numero.copyWith(color: Colori.ardesia),
              ),
            ),
          if (parte != null && pagato != null) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Cifra(
                    'La tua parte',
                    scriviImporto(parte.centesimi, conto.mia),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Cifra(
                    'Hai pagato',
                    scriviImporto(pagato.centesimi, conto.mia),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text(
            spiegazione,
            style: Testi.didascalia.copyWith(color: Colori.ardesia),
          ),
        ],
      ),
    );
  }
}

/// Una cifra piccola sotto il totale: «La tua parte», «Hai pagato».
class _Cifra extends StatelessWidget {
  const _Cifra(this.etichetta, this.valore);

  final String etichetta;
  final String valore;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etichetta,
          style: Testi.didascalia.copyWith(color: Colori.grafite),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            valore,
            style: Testi.numero.copyWith(color: Colori.inchiostro),
          ),
        ),
      ],
    ),
  );
}

/// La riga dei saldi sotto il totale (tela, 37): quanto ti devono o devi, e
/// un tocco porta al giro più corto per pareggiare.
class RigaSaldi extends StatelessWidget {
  const RigaSaldi({
    super.key,
    required this.conto,
    required this.viaggio,
    this.sotto = 'Saldi: il giro più corto per pareggiare',
  });

  final ContoViaggio conto;
  final Viaggio viaggio;

  /// La riga sotto: nel riepilogo di chiusura, che i saldi restano aperti.
  final String sotto;

  @override
  Widget build(BuildContext context) {
    final io = conto.io;
    final mio = io == null ? 0 : conto.saldi.di(io);
    final miei = [
      for (final p in conto.passaggi)
        if (p.da == io) p.a else if (p.a == io) p.da,
    ];
    final titolo = mio > 0
        ? 'Ti devono ${scriviImporto(mio, conto.mia)}'
        : mio < 0
        ? 'Devi ${scriviImporto(-mio, conto.mia)}'
        : conto.passaggi.isEmpty
        ? 'Siete pari'
        : 'Tu sei pari';
    return Premibile(
      onTap: () => apri<void>(context, SchermataSaldi(viaggioId: viaggio.id)),
      scala: 0.98,
      etichetta: '$titolo. $sotto',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: Colori.bianco,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              if (miei.isNotEmpty) ...[
                PilaAvatar(
                  nomi: [for (final p in miei) conto.nomi[p] ?? '?'],
                  dimensione: 32,
                ),
                const SizedBox(width: 14),
              ],
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
              Icon(
                icona(
                  ios: CupertinoIcons.chevron_forward,
                  android: Icons.chevron_right_rounded,
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
}

/// Due spese che sembrano la stessa, registrate da due persone (tela, 37; 06,
/// casi limite): non si può impedire, si segnala a chi ha registrato la
/// seconda. Togliere la propria richiede la rete; «Sono due spese» no.
class _ForseDoppia extends StatelessWidget {
  const _ForseDoppia({
    required this.sua,
    required this.mia,
    required this.conto,
    required this.rete,
  });

  final Spesa sua;
  final Spesa mia;
  final ContoViaggio conto;
  final bool rete;

  @override
  Widget build(BuildContext context) {
    final archivio = Servizi.of(context).archivio;
    final minuti = mia.registrata.difference(sua.registrata).inMinutes;
    final quando = minuti < 1
        ? 'un attimo prima della tua'
        : '${quanti(minuti, 'minuto', 'minuti')} prima della tua';
    final cosa = [
      scriviImporto(sua.centesimi, sua.valuta),
      ?sua.descrizione,
    ].join(' · ');
    return Avviso(
      icona: icona(
        ios: CupertinoIcons.arrow_right_arrow_left,
        android: Icons.swap_horiz_rounded,
      ),
      inizio: 'Sembra la stessa spesa di ${conto.nome(sua.creatoDa)}:',
      testo: '$cosa, $quando.',
      azioni: [
        PulsantePiccolo(
          etichetta: 'È la stessa: togli la mia',
          pericolo: true,
          onPressed: rete
              ? () async {
                  try {
                    await salvaOScegli(context, () => archivio.togliSpesa(mia));
                  } on ErroreTrolley catch (e) {
                    if (context.mounted) {
                      mostraMessaggio(context, e.messaggio, errore: true);
                    }
                  }
                }
              : null,
        ),
        PulsantePiccolo(
          etichetta: 'Sono due spese',
          onPressed: () => archivio.sonoDueSpese(chiaveDueSpese(sua, mia)),
        ),
      ],
    );
  }
}

/// Una spesa nell'elenco (tela, 15 e 16): la valuta in un quadrato, che cosa
/// era, quanto si è pagato nella sua valuta e, a destra, quanto vale nella
/// valuta della persona. Se è ancora in coda lo dice. Un tocco la apre.
class RigaSpesa extends StatelessWidget {
  const RigaSpesa({
    super.key,
    required this.spesa,
    required this.conto,
    required this.viaggio,
    this.conData = false,
  });

  final Spesa spesa;
  final ContoViaggio conto;
  final Viaggio viaggio;

  /// Fuori dai giorni del viaggio il gruppo non dice il giorno: lo dice la riga.
  final bool conData;

  @override
  Widget build(BuildContext context) {
    final s = spesa;
    final straniera = s.valuta != conto.mia;
    final convertita = conto.inMiaValuta(s);
    final pagante = conto.diviso
        ? '${conto.pagataDa(s)} · ${conto.perChi(s)}'
        : null;
    final dettaglio = conMaiuscola(
      [
        if (straniera) scriviImporto(s.centesimi, s.valuta),
        if (conData) '${s.giorno.day} ${nomiDeiMesi[s.giorno.month - 1]}',
        ?pagante,
        if (straniera && convertita == null) 'senza tasso',
        if (s.inCoda) 'parte con la rete',
      ].join(' · '),
    );
    final destra = straniera
        ? convertita == null
              ? scriviImporto(s.centesimi, s.valuta)
              : '≈ ${scriviImporto(convertita, conto.mia)}'
        : scriviImporto(s.centesimi, s.valuta);
    final titolo = s.descrizione ?? 'Spesa';
    return Premibile(
      onTap: () =>
          apriFoglio<void>(context, FoglioSpesa(viaggio: viaggio, spesa: s)),
      scala: 0.98,
      etichetta: [
        titolo,
        destra,
        if (dettaglio.isNotEmpty) dettaglio,
      ].join(', '),
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
          decoration: BoxDecoration(
            color: Colori.bianco,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              QuadratoValuta(s.valuta),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titolo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Testi.evidenza.copyWith(color: Colori.inchiostro),
                    ),
                    if (dettaglio.isNotEmpty)
                      Row(
                        children: [
                          if (s.inCoda) ...[
                            Icon(
                              icona(
                                ios: CupertinoIcons.cloud_upload,
                                android: Icons.cloud_upload_outlined,
                              ),
                              size: 14,
                              color: Colori.grafite,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              dettaglio,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Testi.didascalia.copyWith(
                                color: Colori.grafite,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                destra,
                style: Testi.numero.copyWith(
                  color: Colori.inchiostro,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La valuta in un quadrato grigio: il simbolo dell'euro grande, un codice
/// piccolo.
class QuadratoValuta extends StatelessWidget {
  const QuadratoValuta(this.valuta, {super.key});

  final String valuta;

  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 44,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colori.foschia,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      simboloValuta(valuta),
      style: Testi.titoli(
        valuta == 'EUR' ? 18 : 11,
        spaziatura: 0,
        altezza: 1,
      ).copyWith(color: Colori.cobalto),
    ),
  );
}

/// Le spese nella schermata del viaggio (tela, 15): il totale, quanto oggi, e
/// il pulsante per registrarne una, a un tocco.
class SezioneSpese extends StatelessWidget {
  const SezioneSpese({super.key, required this.viaggio});

  final Viaggio viaggio;

  @override
  Widget build(BuildContext context) => ConConto(
    viaggioId: viaggio.id,
    builder: (context, conto) {
      final spese = conto?.spese ?? const <Spesa>[];
      void tutte() =>
          apri<void>(context, SchermataSpese(viaggioId: viaggio.id));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: TitoloSezione('Spese')),
              if (spese.isNotEmpty)
                Premibile(
                  onTap: tutte,
                  etichetta: 'Tutte le spese, ${spese.length}',
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 4, 8),
                    child: Text(
                      'Tutte · ${spese.length}',
                      style: Testi.secondario.copyWith(
                        color: Colori.cobaltoScuro,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (conto == null || spese.isEmpty)
            Pannello(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quanto spendete, mentre lo spendete: bastano l\'importo '
                    'e un tocco, anche senza rete.',
                    style: Testi.secondario.copyWith(color: Colori.grafite),
                  ),
                  const SizedBox(height: 10),
                  PulsantePiccolo(
                    etichetta: 'Registra una spesa',
                    onPressed: () => nuovaSpesa(context, viaggio),
                  ),
                ],
              ),
            )
          else
            _Riassunto(
              conto: conto,
              onTutte: tutte,
              onNuova: () => nuovaSpesa(context, viaggio),
            ),
        ],
      );
    },
  );
}

class _Riassunto extends StatelessWidget {
  const _Riassunto({
    required this.conto,
    required this.onTutte,
    required this.onNuova,
  });

  final ContoViaggio conto;
  final VoidCallback onTutte;
  final VoidCallback onNuova;

  @override
  Widget build(BuildContext context) {
    final oggi = soloData(DateTime.now());
    final totale = conto.totale();
    final diOggi = conto.spese.where((s) => s.giorno == oggi);
    final sotto = [
      if (diOggi.isNotEmpty)
        'oggi ${scriviImporto(conto.totale(diOggi).centesimi, conto.mia)}'
      else
        quanti(conto.spese.length, 'spesa', 'spese'),
      if (!totale.completo) 'non tutte convertite',
      if (conto.convertite) quandoITassi(conto.giornoTassi, DateTime.now()),
    ].join(' · ');
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
              etichetta:
                  'In tutto ${scriviImporto(totale.centesimi, conto.mia)}, '
                  '$sotto',
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        scriviImporto(totale.centesimi, conto.mia),
                        style: Testi.titoli(
                          26,
                          altezza: 1.1,
                        ).copyWith(color: Colori.inchiostro),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sotto,
                      style: Testi.didascalia.copyWith(color: Colori.grafite),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Premibile(
            onTap: onNuova,
            scala: 0.94,
            etichetta: 'Registra una spesa',
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
                      'Spesa',
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
