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
import '../dati/database.dart';
import '../dati/lettura.dart';
import '../dominio/calendario.dart';
import '../dominio/spese.dart';
import '../dominio/valute.dart';
import '../servizi.dart';
import 'con_la_rete.dart';
import 'foglio_spesa.dart';
import 'problemi_coda.dart';

/// Quello che serve per mostrare le spese di un viaggio: le spese, la valuta
/// della persona, gli ultimi tassi noti e di quando sono, chi ha pagato.
class ContoViaggio {
  const ContoViaggio({
    required this.spese,
    required this.mia,
    required this.perEuro,
    required this.giornoTassi,
    required this.nomi,
    required this.io,
  });

  final List<Spesa> spese;

  /// La valuta in cui la persona vede le spese (06, regola 4).
  final String mia;
  final Map<String, double> perEuro;

  /// Il giorno degli ultimi tassi sul telefono; `null` se non ce ne sono.
  final DateTime? giornoTassi;

  /// Chi è passato dal viaggio, per id.
  final Map<String, String> nomi;
  final String? io;

  Totale totale([Iterable<Spesa>? quali]) => totaleSpese(
    (quali ?? spese).map((s) => s.voce),
    mia: mia,
    perEuro: perEuro,
  );

  /// Qualche spesa è in un'altra valuta: il totale passa da un tasso.
  bool get convertite => spese.any((s) => s.valuta != mia);

  /// Qualcun altro ha pagato qualcosa: si dice quanto è proprio.
  bool get condivise => spese.any((s) => s.paganteId != io);

  /// Quello che vale una spesa nella valuta della persona; `null` senza tasso.
  int? inMiaValuta(Spesa s) =>
      converti(s.centesimi, da: s.valuta, a: mia, perEuro: perEuro);
}

/// Mette insieme le spese di un viaggio, la valuta della persona, i tassi e i
/// nomi, dalla copia locale: si legge anche senza rete.
class ConConto extends StatefulWidget {
  const ConConto({super.key, required this.viaggioId, required this.builder});

  final String viaggioId;
  final Widget Function(BuildContext context, ContoViaggio? conto) builder;

  @override
  State<ConConto> createState() => _ConContoState();
}

class _ConContoState extends State<ConConto> {
  late Stream<List<Spesa>> _spese;
  late Stream<List<TassoCambio>> _tassi;
  late Stream<Utente?> _profilo;
  late Stream<Map<String, String>> _nomi;
  bool _avviato = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_avviato) return;
    _avviato = true;
    final archivio = Servizi.of(context).archivio;
    _spese = archivio.osservaSpese(widget.viaggioId);
    _tassi = archivio.osservaTassi();
    _profilo = archivio.osservaProfilo();
    _nomi = archivio.osservaNomi(widget.viaggioId);
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Spesa>>(
    stream: _spese,
    builder: (context, spese) => StreamBuilder<List<TassoCambio>>(
      stream: _tassi,
      builder: (context, tassi) => StreamBuilder<Utente?>(
        stream: _profilo,
        builder: (context, profilo) => StreamBuilder<Map<String, String>>(
          stream: _nomi,
          builder: (context, nomi) {
            final elenco = spese.data;
            if (elenco == null) return widget.builder(context, null);
            final t = tassi.data ?? const <TassoCambio>[];
            return widget.builder(
              context,
              ContoViaggio(
                spese: elenco,
                mia: profilo.data?.valutaPredefinita ?? valutaIniziale,
                perEuro: tassiPerEuro(t),
                giornoTassi: giornoDeiTassi(t),
                nomi: nomi.data ?? const {},
                io: Servizi.of(context).archivio.io,
              ),
            );
          },
        ),
      ),
    ),
  );
}

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
    final mie = conto.condivise
        ? conto.totale(conto.spese.where((s) => s.paganteId == conto.io))
        : null;
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
          if (mie != null) ...[
            const SizedBox(height: 6),
            Text(
              'Pagate da te: ${scriviImporto(mie.centesimi, conto.mia)}',
              style: Testi.evidenza.copyWith(color: Colori.ardesia),
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
    final pagante = s.paganteId == conto.io
        ? null
        : 'pagata da ${conto.nomi[s.paganteId] ?? 'chi è uscito'}';
    final dettaglio = [
      if (straniera) scriviImporto(s.centesimi, s.valuta),
      if (conData) '${s.giorno.day} ${nomiDeiMesi[s.giorno.month - 1]}',
      ?pagante,
      if (straniera && convertita == null) 'senza tasso',
      if (s.inCoda) 'parte con la rete',
    ].join(' · ');
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
