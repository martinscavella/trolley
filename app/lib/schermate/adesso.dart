import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../aspetto/barra.dart';
import '../aspetto/biglietto.dart';
import '../aspetto/elementi.dart';
import '../aspetto/formati.dart';
import '../aspetto/movimento.dart';
import '../aspetto/pagina.dart';
import '../aspetto/percorso.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../dati/archivio.dart';
import '../dati/database.dart';
import '../dati/lettura.dart';
import '../dominio/adesso.dart';
import '../dominio/calendario.dart';
import '../dominio/divisione.dart';
import '../dominio/documenti.dart';
import '../dominio/stato_viaggio.dart';
import '../dominio/tappe.dart';
import '../dominio/valute.dart';
import '../servizi.dart';
import 'con_la_rete.dart';
import 'documenti.dart';
import 'gesti_spesa.dart';
import 'gesti_tappa.dart';
import 'giornata.dart';
import 'impostazioni.dart';
import 'mappa.dart';
import 'nuovo_viaggio.dart';
import 'spese.dart';
import 'tappa.dart';
import 'viaggio.dart';

/// Con un viaggio in corso l'app si apre su «adesso», non sull'elenco (09,
/// regola 1). Con due, si sceglie quale; la scelta vale fino a sera. Lo
/// chiama l'elenco dei viaggi, una volta, quando li ha letti dalla copia.
Future<void> apriAdessoSeServe(
  BuildContext context,
  List<ViaggioInElenco> viaggi, {
  DateTime Function() orologio = DateTime.now,
}) async {
  final oggi = orologio();
  final inCorso = [
    for (final v in viaggi)
      if (v.viaggio.statoA(oggi) == StatoViaggio.inCorso) v,
  ];
  if (inCorso.isEmpty) return;
  final scelto = await Servizi.of(context).archivio.viaggioSceltoOggi(oggi);
  if (!context.mounted) return;
  final id = viaggioDiAdesso(
    inCorso: [for (final v in inCorso) v.viaggio.id],
    sceltoOggi: scelto,
  );
  await apri<void>(
    context,
    id == null
        ? SchermataDueViaggi(viaggi: inCorso, orologio: orologio)
        : SchermataAdesso(viaggioId: id, orologio: orologio),
  );
}

/// Apre «adesso» di un viaggio in corso scelto a mano: dall'elenco, o fra due.
/// Sceglierlo vale fino a sera.
Future<void> apriAdesso(BuildContext context, String viaggioId) async {
  await Servizi.of(context).archivio
      .scegliViaggioDiOggi(viaggioId, DateTime.now());
  if (context.mounted) {
    await apri<void>(context, SchermataAdesso(viaggioId: viaggioId));
  }
}

/// L'ora di [adesso] come distanza dalla mezzanotte, come gli orari delle
/// tappe.
Duration oraDelGiorno(DateTime adesso) =>
    Duration(hours: adesso.hour, minutes: adesso.minute);

/// Le tre viste: adesso, la giornata di oggi, quella di domani.
enum _Vista { adesso, oggi, domani }

/// «Adesso», mentre il viaggio è in corso (09-durante-il-viaggio.md; tela,
/// 45–48): la tappa di adesso con «Fatta» e «Salta», cosa viene dopo e fra
/// quanto, il documento di questo momento; una spesa con un tocco e
/// l'importo, una tappa in più. Si legge dalla copia, e tutto quello che si
/// fa da qui sono gesti che funzionano senza rete (09, regole 3 e 4).
class SchermataAdesso extends StatefulWidget {
  const SchermataAdesso({
    super.key,
    required this.viaggioId,
    this.orologio = DateTime.now,
  });

  final String viaggioId;

  /// L'ora di adesso; le prove la fissano.
  final DateTime Function() orologio;

  @override
  State<SchermataAdesso> createState() => _SchermataAdessoState();
}

class _SchermataAdessoState extends State<SchermataAdesso> {
  late Stream<Viaggio?> _viaggio;
  late Stream<List<Giorno>> _giorni;
  late Stream<List<Tappa>> _tappe;
  late Stream<List<Documento>> _documenti;
  late Stream<List<OperazioneInCoda>> _coda;
  Timer? _minuto;
  bool _avviata = false;
  _Vista _vista = _Vista.adesso;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_avviata) return;
    _avviata = true;
    final servizi = Servizi.of(context);
    final archivio = servizi.archivio;
    _viaggio = archivio.osservaViaggio(widget.viaggioId);
    _giorni = archivio.osservaGiorni(widget.viaggioId);
    _tappe = archivio.osservaTappe(widget.viaggioId);
    _documenti = servizi.documenti.osserva(widget.viaggioId);
    _coda = archivio.coda.osserva(widget.viaggioId);
    unawaited(segnaAperturaSenzaRete(context, 'adesso'));
    // «Fra 25 minuti» cambia con l'orologio.
    _minuto = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _minuto?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<Viaggio?>(
    stream: _viaggio,
    builder: (context, viaggio) => StreamBuilder<List<Giorno>>(
      stream: _giorni,
      builder: (context, giorni) => StreamBuilder<List<Tappa>>(
        stream: _tappe,
        builder: (context, tappe) => StreamBuilder<List<Documento>>(
          stream: _documenti,
          builder: (context, documenti) =>
              StreamBuilder<List<OperazioneInCoda>>(
                stream: _coda,
                builder: (context, coda) {
                  final (v, g, t) = (viaggio.data, giorni.data, tappe.data);
                  if (v == null || g == null || t == null) {
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
                  return _pagina(
                    v,
                    g,
                    t,
                    documenti.data ?? const [],
                    coda.data ?? const [],
                  );
                },
              ),
        ),
      ),
    ),
  );

  Widget _pagina(
    Viaggio viaggio,
    List<Giorno> giorni,
    List<Tappa> tappe,
    List<Documento> documenti,
    List<OperazioneInCoda> coda,
  ) {
    final adesso = widget.orologio();
    final oggi = soloData(adesso);
    final domani = oggi.add(const Duration(days: 1));
    final indiceOggi = giorni.indexWhere((g) => g.finestra.data == oggi);
    final giornoOggi = indiceOggi < 0 ? null : giorni[indiceOggi];
    final giornoDomani = giorni
        .where((g) => g.finestra.data == domani)
        .firstOrNull;
    final gruppi = raggruppaPerElenco(documenti, giorni, adesso);
    List<Documento> delGruppo(TipoGruppo tipo) =>
        gruppi.where((g) => g.tipo == tipo).firstOrNull?.documenti ?? const [];
    final vista = _vista == _Vista.domani && giornoDomani == null
        ? _Vista.adesso
        : _vista;
    final luogo = viaggio.destinazione?.nome ?? titoloViaggio(viaggio);

    final Widget contenuto = switch (vista) {
      _Vista.adesso => _VistaAdesso(
        viaggio: viaggio,
        giorni: giorni,
        tappe: tappe,
        giorno: giornoOggi,
        domani: giornoDomani,
        documentoDiAdesso: documentoDiAdesso<Documento>(
          diOggi: delGruppo(TipoGruppo.oggi),
          oraDi: (d) => d.momento,
          adesso: oraDelGiorno(adesso),
        ),
        documentoDiDomani: delGruppo(TipoGruppo.domani).firstOrNull,
        adesso: adesso,
        inCoda: coda.length,
      ),
      _Vista.oggi => _VistaGiorno(
        viaggio: viaggio,
        giorni: giorni,
        tappe: tappe,
        giorno: giornoOggi,
        oggi: true,
      ),
      _Vista.domani => _VistaGiorno(
        viaggio: viaggio,
        giorni: giorni,
        tappe: tappe,
        giorno: giornoDomani,
        oggi: false,
      ),
    };

    return Pagina(
      sinistra: const SizedBox.shrink(),
      azioni: [
        PulsanteTondo(
          icona: icona(
            ios: CupertinoIcons.tickets,
            android: Icons.confirmation_number_outlined,
          ),
          etichetta: 'Tutto il viaggio',
          onPressed: () =>
              apri<void>(context, SchermataViaggio(viaggioId: viaggio.id)),
        ),
      ],
      inBasso: BarraPrincipale(
        prima: [
          VoceBarra(
            icona: icona(
              ios: CupertinoIcons.briefcase,
              android: Icons.luggage_outlined,
            ),
            etichetta: 'Viaggi',
            attiva: true,
            onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
          ),
          VoceBarra(
            icona: icona(
              ios: CupertinoIcons.globe,
              android: Icons.public_rounded,
            ),
            etichetta: 'Mappa',
            onTap: () =>
                apri<void>(context, SchermataMappa(viaggioId: viaggio.id)),
          ),
        ],
        dopo: [
          VoceBarra(
            icona: icona(
              ios: CupertinoIcons.person,
              android: Icons.person_outline,
            ),
            etichetta: 'Profilo',
            onTap: () => apri<void>(context, const SchermataImpostazioni()),
          ),
        ],
        etichettaAggiungi: 'Nuovo viaggio',
        onAggiungi: () =>
            apri<void>(context, const SchermataNuovoViaggio(), dalBasso: true),
      ),
      corpo: Builder(
        builder: (context) => ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.paddingOf(context).top,
            20,
            BarraPrincipale.ingombro + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            _Testata(
              sopra: [
                luogo,
                if (giornoOggi != null)
                  'giorno ${indiceOggi + 1} di ${giorni.length}',
              ].join(' · ').toUpperCase(),
            ).entra(context),
            const SizedBox(height: 16),
            _SceltaVista(
              vista: vista,
              conDomani: giornoDomani != null,
              onCambio: (v) => setState(() => _vista = v),
            ).entra(context, ritardo: Ritmo.passo),
            _SenzaRete(viaggio: viaggio, adesso: adesso),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: movimentoRidotto(context) ? Duration.zero : Ritmo.breve,
              child: KeyedSubtree(key: ValueKey(vista), child: contenuto),
            ),
          ],
        ),
      ),
    );
  }
}

/// Il posto e il giorno, e il titolo; senza rete, «Sei offline» accanto.
class _Testata extends StatelessWidget {
  const _Testata({required this.sopra});

  final String sopra;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(sopra, style: Testi.sezione.copyWith(color: Colori.cobalto)),
            const SizedBox(height: 6),
            Semantics(
              header: true,
              child: Text(
                'Adesso',
                style: Testi.titolo.copyWith(color: Colori.inchiostro),
              ),
            ),
          ],
        ),
      ),
      ConLaRete(
        builder: (context, rete) =>
            rete ? const SizedBox.shrink() : const SeiOffline(),
      ),
    ],
  );
}

/// Senza rete lo si dice una volta, con l'età della copia (09, regola 7 e
/// casi limite): quello che si fa parte da solo quando torna.
class _SenzaRete extends StatelessWidget {
  const _SenzaRete({required this.viaggio, required this.adesso});

  final Viaggio viaggio;
  final DateTime adesso;

  @override
  Widget build(BuildContext context) => ConLaRete(
    builder: (context, rete) => AnimatedSize(
      duration: Ritmo.medio,
      curve: Ritmo.curva,
      child: rete
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Avviso(
                icona: icona(
                  ios: CupertinoIcons.wifi_slash,
                  android: Icons.wifi_off,
                ),
                inizio: 'Sei offline.',
                testo:
                    'Stai vedendo la copia sul telefono, aggiornata '
                    '${quantoFa(viaggio.scaricatoIl, adesso)}. Quello che '
                    'fai parte da solo quando torna la rete.',
              ),
            ),
    ),
  );
}

/// Adesso, Oggi, Domani. L'ultimo giorno non c'è un domani.
class _SceltaVista extends StatelessWidget {
  const _SceltaVista({
    required this.vista,
    required this.conDomani,
    required this.onCambio,
  });

  final _Vista vista;
  final bool conDomani;
  final ValueChanged<_Vista> onCambio;

  @override
  Widget build(BuildContext context) {
    Widget voce(String nome, _Vista valore) {
      final scelta = vista == valore;
      return Expanded(
        child: Semantics(
          selected: scelta,
          child: Premibile(
            onTap: () => onCambio(valore),
            scala: 0.96,
            etichetta: nome,
            child: AnimatedContainer(
              duration: Ritmo.breve,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scelta ? Colori.inchiostro : Colori.bianco,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                nome,
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
          voce('Adesso', _Vista.adesso),
          const SizedBox(width: 4),
          voce('Oggi', _Vista.oggi),
          if (conDomani) ...[
            const SizedBox(width: 4),
            voce('Domani', _Vista.domani),
          ],
        ],
      ),
    );
  }
}

/// Le tre cose in un colpo d'occhio (09, regola 2), e i due gesti che
/// capitano in giro: una spesa, una tappa.
class _VistaAdesso extends StatelessWidget {
  const _VistaAdesso({
    required this.viaggio,
    required this.giorni,
    required this.tappe,
    required this.giorno,
    required this.domani,
    required this.documentoDiAdesso,
    required this.documentoDiDomani,
    required this.adesso,
    required this.inCoda,
  });

  final Viaggio viaggio;
  final List<Giorno> giorni;
  final List<Tappa> tappe;

  /// Il giorno del viaggio che è oggi.
  final Giorno? giorno;
  final Giorno? domani;
  final Documento? documentoDiAdesso;
  final Documento? documentoDiDomani;
  final DateTime adesso;

  /// Quanti gesti fatti senza rete aspettano di partire.
  final int inCoda;

  List<Tappa> _del(Giorno? g) => [
    for (final t in tappe)
      if (g != null && t.giornoId == g.id) t,
  ];

  Future<void> _apriTappa(BuildContext context, {Tappa? tappa}) =>
      apriFoglio<String>(
        context,
        SchermataTappa(
          viaggio: viaggio,
          giorni: giorni,
          tappe: tappe,
          giornoId: tappa?.giornoId ?? giorno?.id,
          tappa: tappa,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final delGiorno = _del(giorno);
    final stato = cosaSuccedeAdesso<Tappa>(
      tappe: delGiorno,
      oraDi: (t) => t.ora,
      durataDi: (t) => t.durata,
      daFare: (t) => t.statoTappa == StatoTappa.daFare,
      inizioGiornata: giorno?.finestra.inizio ?? Duration.zero,
      adesso: oraDelGiorno(adesso),
    );
    final corrente = stato.corrente;
    final dopo = stato.dopo;
    final delDomani = _del(domani);
    final senzaTappe = corrente == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (corrente != null)
          _TappaDiAdesso(
            viaggio: viaggio,
            tappa: corrente.tappa,
            orario: corrente.orario,
            puntualita: stato.puntualita!,
            restano: stato.restano,
            finoAlle: stato.finoAlle,
            onApri: () => _apriTappa(context, tappa: corrente.tappa),
          ).entra(context, ritardo: Ritmo.passo)
        else
          _GiornataSenzaTappe(
            finita: stato.finita,
            onAggiungi: () => _apriTappa(context),
          ).entra(context, ritardo: Ritmo.passo),
        if (dopo != null) ...[
          _Etichetta(
            stato.traQuanto == null
                ? 'Dopo'
                : 'Dopo · tra ${_traQuanto(stato.traQuanto!)}',
          ),
          _RigaTappa(
            numero: delGiorno.indexOf(dopo.tappa) + 1,
            titolo: dopo.tappa.titolo,
            dettaglio: [
              ora(dopo.orario.inizio),
              if (dopo.tappa.tipoTappa != null) nomeTipo(dopo.tappa.tipoTappa!),
              durataBreve(dopo.tappa.durata),
            ].join(' · '),
            onTap: () => _apriTappa(context, tappa: dopo.tappa),
          ),
        ],
        // Una giornata senza niente da fare guarda a domani (tela, 47).
        if (senzaTappe && domani != null && delDomani.isNotEmpty) ...[
          _Etichetta('Domani · ${giornoBreve(domani!.finestra.data)}'),
          _RigaTappa(
            numero: 1,
            titolo: delDomani.first.titolo,
            dettaglio: _riassuntoDelGiorno(domani!, delDomani),
            onTap: () => apri<void>(
              context,
              SchermataGiornata(viaggioId: viaggio.id, giornoId: domani!.id),
            ),
          ),
        ],
        if (!senzaTappe && documentoDiAdesso != null) ...[
          const _Etichetta('Il documento di adesso'),
          RigaDocumento(documento: documentoDiAdesso!),
        ] else if (senzaTappe &&
            (documentoDiAdesso ?? documentoDiDomani) != null) ...[
          _Etichetta(
            documentoDiAdesso != null
                ? 'Il documento di adesso'
                : 'Il documento di domani',
          ),
          RigaDocumento(documento: (documentoDiAdesso ?? documentoDiDomani)!),
        ],
        if (inCoda > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 14, 4, 0),
            child: Row(
              children: [
                Icon(
                  icona(ios: CupertinoIcons.clock, android: Icons.schedule),
                  size: 16,
                  color: Colori.grafite,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    inCoda == 1
                        ? 'Una cosa fatta senza rete aspetta di partire'
                        : '$inCoda cose fatte senza rete aspettano di partire',
                    style: Testi.didascalia.copyWith(color: Colori.grafite),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: PulsanteGrande(
                etichetta: 'Spesa',
                icona: Icons.add_rounded,
                onPressed: () => apriFoglio<void>(
                  context,
                  FoglioSpesaVeloce(viaggio: viaggio),
                ),
              ),
            ),
            if (!senzaTappe) ...[
              const SizedBox(width: 12),
              Expanded(
                child: PulsanteGrande(
                  etichetta: 'Tappa',
                  icona: Icons.add_rounded,
                  secondario: true,
                  onPressed: () => _apriTappa(context),
                ),
              ),
            ],
          ],
        ).entra(context, ritardo: Ritmo.passo * 2),
      ],
    );
  }

  /// `9:00 · e altre 3 tappe, fino alle 16:00`.
  static String _riassuntoDelGiorno(Giorno giorno, List<Tappa> tappe) {
    final orari = orariDellaGiornata(
      inizioGiornata: giorno.finestra.inizio,
      tappe: [for (final t in tappe) (ora: t.ora, durata: t.durata)],
    );
    final altre = tappe.length - 1;
    return [
      ora(orari.first.inizio),
      if (altre == 0)
        'fino alle ${ora(orari.last.fine)}'
      else
        'e ${altre == 1 ? 'un\'altra tappa' : 'altre $altre tappe'}, '
            'fino alle ${ora(orari.last.fine)}',
    ].join(' · ');
  }

  /// `25 minuti`, `un'ora`, `2 ore e 15 minuti`.
  static String _traQuanto(Duration d) {
    String minuti(int m) => m == 1 ? 'un minuto' : '$m minuti';
    final (h, m) = (d.inHours, d.inMinutes % 60);
    if (h == 0) return minuti(m);
    final ore = h == 1 ? 'un\'ora' : '$h ore';
    return m == 0 ? ore : '$ore e ${minuti(m)}';
  }
}

/// La tappa di adesso, sul cobalto: quando, cosa, e i due gesti da un tocco
/// (09, regola 10). Se il programma è indietro non rimprovera: dice da quando
/// era in programma e cosa resta.
class _TappaDiAdesso extends StatelessWidget {
  const _TappaDiAdesso({
    required this.viaggio,
    required this.tappa,
    required this.orario,
    required this.puntualita,
    required this.restano,
    required this.finoAlle,
    required this.onApri,
  });

  final Viaggio viaggio;
  final Tappa tappa;
  final Orario orario;
  final Puntualita puntualita;
  final int restano;
  final Duration? finoAlle;
  final VoidCallback onApri;

  @override
  Widget build(BuildContext context) {
    final quando = switch (puntualita) {
      Puntualita.inCorso => 'Ora · ${ora(orario.inizio)}–${ora(orario.fine)}',
      Puntualita.inArrivo => 'Alle ${ora(orario.inizio)}–${ora(orario.fine)}',
      Puntualita.indietro => 'In programma dalle ${ora(orario.inizio)}',
    }.toUpperCase();
    final dettaglio = [
      if (tappa.tipoTappa != null) nomeTipo(tappa.tipoTappa!),
      durataBreve(tappa.durata),
      if (tappa.luogoNome?.trim().isNotEmpty ?? false) tappa.luogoNome!.trim(),
    ].join(' · ');
    final bianco = Colori.bianco.withValues(alpha: 0.9);
    Future<void> segna(StatoTappa stato) =>
        segnaLaTappa(context, viaggio: viaggio, tappa: tappa, stato: stato);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Colori.cobalto,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Premibile(
            onTap: onApri,
            scala: 0.98,
            etichetta: 'Apri ${tappa.titolo}',
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quando,
                    style: Testi.sezione.copyWith(
                      color: Colori.bianco.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tappa.titolo,
                    style: Testi.titoloScheda.copyWith(
                      color: Colori.bianco,
                      fontSize: 24,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dettaglio,
                    style: Testi.secondario.copyWith(color: bianco),
                  ),
                  if (puntualita == Puntualita.indietro &&
                      finoAlle != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      restano == 1
                          ? 'È l\'ultima di oggi.'
                          : 'Restano $restano tappe oggi, fino alle '
                                '${ora(finoAlle!)}.',
                      style: Testi.didascalia.copyWith(
                        color: Colori.bianco.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _GestoTappa(
                  etichetta: 'Fatta',
                  pieno: true,
                  onTap: () => segna(StatoTappa.completata),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _GestoTappa(
                  etichetta: 'Salta',
                  pieno: false,
                  onTap: () => segna(StatoTappa.saltata),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// «Fatta», bianco con il testo verde e la spunta; «Salta», solo il bordo.
class _GestoTappa extends StatelessWidget {
  const _GestoTappa({
    required this.etichetta,
    required this.pieno,
    required this.onTap,
  });

  final String etichetta;
  final bool pieno;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: Premibile(
      onTap: onTap,
      scala: 0.95,
      etichetta: etichetta,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: pieno ? Colori.bianco : null,
          borderRadius: BorderRadius.circular(16),
          border: pieno
              ? null
              : Border.all(
                  color: Colori.bianco.withValues(alpha: 0.6),
                  width: 2,
                ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (pieno) ...[
              const Icon(Icons.check_rounded, size: 22, color: Colori.verde),
              const SizedBox(width: 8),
            ],
            Text(
              etichetta,
              style: Testi.pulsante.copyWith(
                color: pieno ? Colori.verde : Colori.bianco,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Oggi senza niente da fare: libera, o già tutta segnata. Non sembra rotta
/// (09, casi limite): lo dice, e lascia aggiungere una tappa anche senza rete.
class _GiornataSenzaTappe extends StatelessWidget {
  const _GiornataSenzaTappe({required this.finita, required this.onAggiungi});

  final bool finita;
  final VoidCallback onAggiungi;

  @override
  Widget build(BuildContext context) => Pannello(
    raggio: 24,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: finita ? Colori.verde.withValues(alpha: 0.12) : _crema,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                finita
                    ? Icons.check_rounded
                    : icona(
                        ios: CupertinoIcons.sun_max,
                        android: Icons.wb_sunny_outlined,
                      ),
                size: 22,
                color: finita ? Colori.verde : _ocra,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                finita ? 'Per oggi è tutto' : 'Oggi niente in programma',
                style: Testi.titoli(
                  20,
                  altezza: 1.2,
                ).copyWith(color: Colori.inchiostro),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          finita
              ? 'Le tappe di oggi sono tutte segnate. Se ti viene un\'idea, '
                    'aggiungila: entra anche senza rete.'
              : 'Una giornata libera. Se ti viene un\'idea, aggiungila: entra '
                    'anche senza rete.',
          style: Testi.corpo.copyWith(color: Colori.ardesia),
        ),
        const SizedBox(height: 14),
        PulsanteGrande(
          etichetta: 'Aggiungi una tappa',
          icona: Icons.add_rounded,
          secondario: true,
          onPressed: onAggiungi,
        ),
      ],
    ),
  );

  /// Il sole della giornata libera (tela, 47).
  static const _crema = Color(0xFFFFF4D1);
  static const _ocra = Color(0xFF8A6A00);
}

/// L'etichetta piccola sopra una riga: «DOPO · TRA 25 MINUTI».
class _Etichetta extends StatelessWidget {
  const _Etichetta(this.testo);

  final String testo;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
    child: Text(
      testo.toUpperCase(),
      style: Testi.sezione.copyWith(color: Colori.grafite),
    ),
  );
}

/// Una tappa in una riga: il suo numero nella giornata, il titolo, quando.
class _RigaTappa extends StatelessWidget {
  const _RigaTappa({
    required this.numero,
    required this.titolo,
    required this.dettaglio,
    required this.onTap,
  });

  final int numero;
  final String titolo;
  final String dettaglio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Premibile(
    onTap: onTap,
    scala: 0.98,
    etichetta: '$titolo, $dettaglio',
    child: ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colori.bianco,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Colori.inchiostro,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$numero',
                style: Testi.titoli(
                  14,
                  spaziatura: 0,
                  altezza: 1,
                ).copyWith(color: Colori.bianco),
              ),
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
                    style: Testi.evidenza.copyWith(color: Colori.inchiostro),
                  ),
                  Text(
                    dettaglio,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Testi.didascalia.copyWith(color: Colori.grafite),
                  ),
                ],
              ),
            ),
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

/// «Oggi» e «Domani»: la giornata come percorso, da segnare con un tocco come
/// nella giornata (tela, 7), e la strada per aprirla per intero.
class _VistaGiorno extends StatelessWidget {
  const _VistaGiorno({
    required this.viaggio,
    required this.giorni,
    required this.tappe,
    required this.giorno,
    required this.oggi,
  });

  final Viaggio viaggio;
  final List<Giorno> giorni;
  final List<Tappa> tappe;
  final Giorno? giorno;
  final bool oggi;

  @override
  Widget build(BuildContext context) {
    final g = giorno;
    if (g == null) {
      return Pannello(
        child: Text(
          'Oggi non è un giorno del viaggio.',
          style: Testi.corpo.copyWith(color: Colori.grafite),
        ),
      );
    }
    final delGiorno = [
      for (final t in tappe)
        if (t.giornoId == g.id) t,
    ];
    final orari = orariDellaGiornata(
      inizioGiornata: g.finestra.inizio,
      tappe: [for (final t in delGiorno) (ora: t.ora, durata: t.durata)],
    );
    final prossima = oggi
        ? delGiorno.where((t) => t.statoTappa == StatoTappa.daFare).firstOrNull
        : null;
    Future<void> segna(Tappa t, StatoTappa stato) =>
        segnaLaTappa(context, viaggio: viaggio, tappa: t, stato: stato);
    Future<void> apriTappa(Tappa t) => apriFoglio<String>(
      context,
      SchermataTappa(
        viaggio: viaggio,
        giorni: giorni,
        tappe: tappe,
        giornoId: t.giornoId,
        tappa: t,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
          child: Text(
            nomeDelGiorno(g.finestra.data),
            style: Testi.titoloSezione.copyWith(color: Colori.inchiostro),
          ),
        ),
        if (delGiorno.isEmpty)
          Pannello(
            child: Text(
              oggi
                  ? 'Oggi niente in programma: una giornata libera.'
                  : 'Domani niente in programma: una giornata libera.',
              style: Testi.corpo.copyWith(color: Colori.grafite),
            ),
          )
        else
          PercorsoTappe(
            punti: [
              for (final (i, t) in delGiorno.indexed)
                PuntoPercorso(
                  titolo: t.titolo,
                  dettaglio: [
                    ora(orari[i].inizio),
                    if (t.tipoTappa != null) nomeTipo(t.tipoTappa!),
                    durataBreve(t.durata),
                    if (t.statoTappa == StatoTappa.completata) 'fatta',
                    if (t.statoTappa == StatoTappa.saltata) 'saltata',
                  ].join(' · '),
                  aspetto: switch (t.statoTappa) {
                    StatoTappa.completata => AspettoPunto.completata,
                    StatoTappa.saltata => AspettoPunto.saltata,
                    StatoTappa.daFare when t.id == prossima?.id =>
                      AspettoPunto.prossima,
                    StatoTappa.daFare => AspettoPunto.daFare,
                  },
                  capsula: t.id == prossima?.id ? 'Adesso' : null,
                  etichetta: '${i + 1}, ${t.titolo}',
                  onApri: () => apriTappa(t),
                  onTocca: () => segna(
                    t,
                    t.statoTappa == StatoTappa.daFare
                        ? StatoTappa.completata
                        : StatoTappa.daFare,
                  ),
                  suggerimentoTocca: t.statoTappa == StatoTappa.daFare
                      ? 'segnarla fatta'
                      : 'riportarla da fare',
                  onTieni: () => segna(
                    t,
                    t.statoTappa == StatoTappa.saltata
                        ? StatoTappa.daFare
                        : StatoTappa.saltata,
                  ),
                  suggerimentoTieni: t.statoTappa == StatoTappa.saltata
                      ? 'riportarla da fare'
                      : 'saltarla',
                ),
            ],
          ),
        const SizedBox(height: 16),
        PulsanteGrande(
          etichetta: 'La giornata intera',
          secondario: true,
          onPressed: () => apri<void>(
            context,
            SchermataGiornata(viaggioId: viaggio.id, giornoId: g.id),
          ),
        ),
      ],
    );
  }
}

/// Una spesa da «adesso»: un tocco e l'importo (09, regola 9; tela, 46). La
/// valuta della persona, oggi, pagata da lei per tutti quelli che sono nel
/// viaggio: il resto è già scelto, e si cambia dopo dalle spese. Si registra
/// anche senza rete.
class FoglioSpesaVeloce extends StatelessWidget {
  const FoglioSpesaVeloce({super.key, required this.viaggio});

  final Viaggio viaggio;

  @override
  Widget build(BuildContext context) => ConConto(
    viaggioId: viaggio.id,
    builder: (context, conto) => conto == null
        ? const SizedBox(
            height: 240,
            child: Center(child: IndicatoreAttivita()),
          )
        : _FoglioSpesaVeloce(viaggio: viaggio, conto: conto),
  );
}

class _FoglioSpesaVeloce extends StatefulWidget {
  const _FoglioSpesaVeloce({required this.viaggio, required this.conto});

  final Viaggio viaggio;
  final ContoViaggio conto;

  @override
  State<_FoglioSpesaVeloce> createState() => _FoglioSpesaVeloceState();
}

class _FoglioSpesaVeloceState extends State<_FoglioSpesaVeloce> {
  String _testo = '';
  bool _inCorso = false;

  String get _valuta => widget.conto.mia;
  int get _decimali => valutaDi(_valuta).decimali;
  int? get _centesimi => leggiImporto(_testo, decimali: _decimali);

  void _premi(String tasto) {
    final nuovo = conIlTasto(_testo, tasto, decimali: _decimali);
    if (nuovo == _testo) return;
    HapticFeedback.selectionClick();
    setState(() => _testo = nuovo);
  }

  Future<void> _registra() async {
    final centesimi = _centesimi;
    if (centesimi == null) return;
    final conto = widget.conto;
    setState(() => _inCorso = true);
    try {
      await registraLaSpesa(
        context,
        viaggio: widget.viaggio,
        centesimi: centesimi,
        valuta: _valuta,
        data: soloData(DateTime.now()),
        pagante: conto.diviso ? conto.io : null,
        quote: conto.diviso ? partiUguali(centesimi, conto.attivi) : const {},
      );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final conto = widget.conto;
    final persone = conto.attivi.length;
    final gia = [
      'In ${nomeCortoValuta(_valuta).toLowerCase()}',
      'oggi',
      if (conto.diviso)
        persone == 2
            ? 'pagata da te per tutti e due'
            : 'pagata da te per tutti e $persone',
    ];
    final scritto = _testo.isEmpty ? '0' : _testo;
    final tasti = [
      for (var i = 1; i <= 9; i++) '$i',
      tastoVirgola,
      '0',
      tastoCancella,
    ];
    return Foglio(
      titolo: 'Una spesa',
      inBasso: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PulsanteGrande(
            etichetta: 'Registra',
            inCorso: _inCorso,
            onPressed: _centesimi == null ? null : _registra,
          ),
          const SizedBox(height: 10),
          Text(
            'Anche senza rete. Descrizione, valuta e per chi si cambiano '
            'dopo, dalle spese.',
            textAlign: TextAlign.center,
            style: Testi.didascalia.copyWith(color: Colori.grafite),
          ),
        ],
      ),
      children: [
        Text(
          '${gia.join(', ')}: il resto è già scelto.',
          style: Testi.secondario.copyWith(color: Colori.grafite),
        ),
        const SizedBox(height: 12),
        Semantics(
          liveRegion: true,
          label: _centesimi == null
              ? 'Nessun importo'
              : scriviImporto(_centesimi!, _valuta),
          child: ExcludeSemantics(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      scritto,
                      style: Testi.titoli(52, spaziatura: 0, altezza: 1.1)
                          .copyWith(
                            color: _testo.isEmpty
                                ? Colori.piombo
                                : Colori.inchiostro,
                          ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  simboloValuta(_valuta),
                  style: Testi.titoloSezione.copyWith(
                    color: Colori.grafite,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2,
          children: [
            for (final tasto in tasti)
              _Tasto(
                tasto: tasto,
                spento: tasto == tastoVirgola && _decimali == 0,
                onTap: () => _premi(tasto),
              ),
          ],
        ),
      ],
    );
  }
}

/// Un tasto del tastierino.
class _Tasto extends StatelessWidget {
  const _Tasto({
    required this.tasto,
    required this.spento,
    required this.onTap,
  });

  final String tasto;
  final bool spento;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final etichetta = switch (tasto) {
      tastoCancella => 'Cancella',
      tastoVirgola => 'Virgola',
      _ => tasto,
    };
    return Opacity(
      opacity: spento ? 0.3 : 1,
      child: Premibile(
        onTap: spento ? null : onTap,
        scala: 0.94,
        etichetta: etichetta,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colori.foschia,
            borderRadius: BorderRadius.circular(16),
          ),
          child: tasto == tastoCancella
              ? Icon(
                  icona(
                    ios: CupertinoIcons.delete_left,
                    android: Icons.backspace_outlined,
                  ),
                  size: 22,
                  color: Colori.inchiostro,
                )
              : Text(
                  tasto,
                  style: Testi.titoli(
                    22,
                    spaziatura: 0,
                    altezza: 1,
                    peso: 600,
                  ).copyWith(color: Colori.inchiostro),
                ),
        ),
      ),
    );
  }
}

/// Due viaggi in corso: quale apri (09, casi limite; tela, 49). La scelta vale
/// fino a sera; domani si richiede.
class SchermataDueViaggi extends StatelessWidget {
  const SchermataDueViaggi({
    super.key,
    required this.viaggi,
    this.orologio = DateTime.now,
  });

  final List<ViaggioInElenco> viaggi;
  final DateTime Function() orologio;

  Future<void> _scegli(BuildContext context, String viaggioId) async {
    await Servizi.of(context).archivio
        .scegliViaggioDiOggi(viaggioId, orologio());
    if (!context.mounted) return;
    await Navigator.of(context).pushReplacement(
      rotta<void>(SchermataAdesso(viaggioId: viaggioId, orologio: orologio)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final oggi = orologio();
    return Pagina(
      corpo: Builder(
        builder: (context) => ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.paddingOf(context).top,
            20,
            MediaQuery.paddingOf(context).bottom + 32,
          ),
          children: [
            TitoloPagina(
              viaggi.length == 2
                  ? 'Due viaggi in corso'
                  : '${viaggi.length} viaggi in corso',
              sottotitolo:
                  'Quale apri? La scelta vale fino a stasera: domani te lo '
                  'richiediamo.',
            ).entra(context),
            for (final (i, v) in viaggi.indexed) ...[
              if (i > 0) const SizedBox(height: 14),
              _BigliettoInCorso(
                dati: v,
                oggi: oggi,
                colore: i == 0 ? Colori.cobalto : Colori.inchiostro,
                onTap: () => _scegli(context, v.viaggio.id),
              ).entra(context, ritardo: Ritmo.passo * (i + 1)),
            ],
            const SizedBox(height: 16),
            Text(
              'Gli altri viaggi restano in «Viaggi».',
              textAlign: TextAlign.center,
              style: Testi.didascalia.copyWith(color: Colori.grafite),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un viaggio in corso fra cui scegliere: quante tappe ha oggi, e quanti
/// siete.
class _BigliettoInCorso extends StatelessWidget {
  const _BigliettoInCorso({
    required this.dati,
    required this.oggi,
    required this.colore,
    required this.onTap,
  });

  final ViaggioInElenco dati;
  final DateTime oggi;
  final Color colore;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final v = dati.viaggio;
    final archivio = Servizi.of(context).archivio;
    return StreamBuilder<List<Giorno>>(
      stream: archivio.osservaGiorni(v.id),
      builder: (context, giorni) => StreamBuilder<List<Tappa>>(
        stream: archivio.osservaTappe(v.id),
        builder: (context, tappe) {
          final giorno = (giorni.data ?? const <Giorno>[])
              .where((g) => g.finestra.data == soloData(oggi))
              .firstOrNull;
          final diOggi = [
            for (final t in tappe.data ?? const <Tappa>[])
              if (giorno != null && t.giornoId == giorno.id) t,
          ].length;
          final (inizio, fine) = (v.inizio, v.fine);
          final persone = dati.persone.length;
          return Biglietto(
            codice: codiceViaggio(v),
            nome: titoloViaggio(v),
            sinistra: descrizioneStato(StatoViaggio.inCorso).toUpperCase(),
            destra: inizio != null && fine != null
                ? 'GIORNO ${giorniDiCalendario(inizio, oggi)} '
                      'DI ${giorniDiCalendario(inizio, fine)}'
                : null,
            colore: colore,
            campi: [
              CampoMatrice('Oggi', quanti(diOggi, 'tappa', 'tappe')),
              CampoMatrice('Persone', '$persone'),
            ],
            onTap: onTap,
            etichetta: [
              titoloViaggio(v),
              'oggi ${quanti(diOggi, 'tappa', 'tappe')}',
              quanti(persone, 'persona', 'persone'),
            ].join(', '),
          );
        },
      ),
    );
  }
}
