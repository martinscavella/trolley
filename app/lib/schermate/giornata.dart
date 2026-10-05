import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../aspetto/elementi.dart';
import '../aspetto/formati.dart';
import '../aspetto/movimento.dart';
import '../aspetto/pagina.dart';
import '../aspetto/percorso.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/striscia.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../aspetto/timbro.dart';
import '../aspetto/tipi.dart';
import '../dati/coda.dart';
import '../dati/database.dart';
import '../dati/errori.dart';
import '../dati/lettura.dart';
import '../dominio/calendario.dart';
import '../dominio/giornate.dart';
import '../dominio/stato_viaggio.dart';
import '../dominio/tappe.dart';
import '../servizi.dart';
import 'con_la_rete.dart';
import 'gesti_tappa.dart';
import 'mappa.dart';
import 'problemi_coda.dart';
import 'tappa.dart';

/// Una giornata del viaggio (04-itinerario.md, "Giornata"; tela, 7): quanto
/// è piena, e le sue tappe in ordine. Come percorso — punti collegati, da
/// segnare con un tocco — o come elenco, per riordinarle trascinando.
///
/// Si legge dalla copia, anche senza rete. Aggiungere e segnare funzionano
/// senza; riordinare la richiede, e senza lo dice.
class SchermataGiornata extends StatefulWidget {
  const SchermataGiornata({
    super.key,
    required this.viaggioId,
    required this.giornoId,
  });

  final String viaggioId;
  final String giornoId;

  @override
  State<SchermataGiornata> createState() => _SchermataGiornataState();
}

class _SchermataGiornataState extends State<SchermataGiornata> {
  late Stream<Viaggio?> _viaggio;
  late Stream<List<Giorno>> _giorni;
  late Stream<List<Tappa>> _tappe;
  late Stream<List<OperazioneInCoda>> _coda;
  bool _avviata = false;

  /// Elenco invece di percorso.
  bool _elenco = false;

  /// L'ordine appena trascinato, finché il server non lo conferma.
  List<String>? _ordine;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_avviata) return;
    _avviata = true;
    final archivio = Servizi.of(context).archivio;
    unawaited(segnaAperturaSenzaRete(context, 'giornata'));
    _viaggio = archivio.osservaViaggio(widget.viaggioId);
    _giorni = archivio.osservaGiorni(widget.viaggioId);
    _tappe = archivio.osservaTappe(widget.viaggioId);
    _coda = archivio.coda.osserva(widget.viaggioId);
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<Viaggio?>(
    stream: _viaggio,
    builder: (context, viaggio) => StreamBuilder<List<Giorno>>(
      stream: _giorni,
      builder: (context, giorni) => StreamBuilder<List<Tappa>>(
        stream: _tappe,
        builder: (context, tappe) => StreamBuilder<List<OperazioneInCoda>>(
          stream: _coda,
          builder: (context, coda) {
            final (v, g, t) = (viaggio.data, giorni.data, tappe.data);
            if (v == null || g == null || t == null) {
              return const Pagina(corpo: Center(child: IndicatoreAttivita()));
            }
            return _pagina(v, g, t, coda.data ?? const []);
          },
        ),
      ),
    ),
  );

  Widget _pagina(
    Viaggio viaggio,
    List<Giorno> giorni,
    List<Tappa> tappe,
    List<OperazioneInCoda> coda,
  ) {
    final indice = giorni.indexWhere((g) => g.id == widget.giornoId);
    if (indice < 0) {
      return Pagina(
        corpo: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'Questo giorno non fa più parte del viaggio.',
              textAlign: TextAlign.center,
              style: Testi.corpo.copyWith(color: Colori.grafite),
            ),
          ),
        ),
      );
    }
    final finestra = giorni[indice].finestra;
    final adesso = DateTime.now();
    final statoViaggio = viaggio.statoA(adesso);
    final oggi =
        finestra.data == soloData(adesso) &&
        statoViaggio == StatoViaggio.inCorso;
    final segnabili = tappeSegnabili(statoViaggio);
    final delGiorno = _inOrdine([
      for (final t in tappe)
        if (t.giornoId == widget.giornoId) t,
    ]);
    final sfora = tempoLibero(
      capienza: finestra.capienza,
      durateMinuti: delGiorno.map((t) => t.durataStimataMin),
    ).isNegative;
    final inCoda = {for (final op in coda) ?Coda.tappaDi(op)};
    final aggiunteInCoda = {
      for (final op in coda)
        if (op.gesto == GestoOffline.aggiungiTappa) ?Coda.tappaDi(op),
    };
    final prossima = oggi
        ? delGiorno.where((t) => t.statoTappa == StatoTappa.daFare).firstOrNull
        : null;

    Future<void> apriTappa({Tappa? tappa}) async {
      final altroGiorno = await apriFoglio<String>(
        context,
        SchermataTappa(
          viaggio: viaggio,
          giorni: giorni,
          tappe: tappe,
          giornoId: tappa?.giornoId ?? widget.giornoId,
          tappa: tappa,
        ),
      );
      if (altroGiorno != null && altroGiorno != widget.giornoId && mounted) {
        await apri<void>(
          context,
          SchermataGiornata(viaggioId: viaggio.id, giornoId: altroGiorno),
        );
      }
    }

    Future<void> segna(Tappa tappa, StatoTappa stato) =>
        segnaLaTappa(context, viaggio: viaggio, tappa: tappa, stato: stato);

    String dettaglio(Tappa t) => [
      if (t.tipoTappa != null) nomeTipo(t.tipoTappa!),
      durataBreve(t.durata),
      if (t.ora != null) 'alle ${ora(t.ora!)}',
      if (t.luogoNome?.trim().isNotEmpty ?? false) t.luogoNome!.trim(),
      if (t.statoTappa == StatoTappa.completata) 'fatta',
      if (t.statoTappa == StatoTappa.saltata) 'saltata',
      if (aggiunteInCoda.contains(t.id)) 'parte con la rete',
      if (sfora && t.eccedente) 'sfora la giornata',
    ].join(' · ');

    final luogo = viaggio.destinazione?.nome ?? titoloViaggio(viaggio);
    return Pagina(
      azioni: [
        _Luogo(luogo),
        PulsanteTondo(
          icona: icona(ios: CupertinoIcons.map, android: Icons.map_outlined),
          etichetta: 'Mappa del giorno',
          onPressed: () => apri<void>(
            context,
            SchermataMappa(
              viaggioId: widget.viaggioId,
              giornoId: widget.giornoId,
            ),
          ),
        ),
      ],
      corpo: Builder(
        builder: (context) => ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.paddingOf(context).top + 8,
            20,
            MediaQuery.paddingOf(context).bottom + 32,
          ),
          children: [
            Text(
              [
                if (oggi) 'OGGI',
                'GIORNO ${indice + 1} DI ${giorni.length}',
              ].join(' · '),
              style: Testi.sezione.copyWith(
                color: Colori.cobalto,
                fontSize: 12,
              ),
            ).entra(context),
            const SizedBox(height: 8),
            Semantics(
              header: true,
              child: Text(
                nomeDelGiorno(finestra.data),
                style: Testi.titoloFoglio.copyWith(color: Colori.inchiostro),
              ),
            ).entra(context),
            const SizedBox(height: 18),
            _Capienza(
              finestra: finestra,
              tappe: delGiorno,
            ).entra(context, ritardo: Ritmo.passo),
            ProblemiDellaCoda(operazioni: coda),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(child: TitoloSezione('Tappe')),
                if (delGiorno.isNotEmpty)
                  _SceltaVista(
                    elenco: _elenco,
                    onCambio: (elenco) => setState(() => _elenco = elenco),
                  ),
              ],
            ),
            if (delGiorno.isEmpty)
              const _Vuota()
            else if (!_elenco)
              PercorsoTappe(
                punti: [
                  for (final (i, t) in delGiorno.indexed)
                    PuntoPercorso(
                      titolo: t.titolo,
                      dettaglio: dettaglio(t),
                      dettaglioInRosso: sfora && t.eccedente,
                      aspetto: switch (t.statoTappa) {
                        StatoTappa.completata => AspettoPunto.completata,
                        StatoTappa.saltata => AspettoPunto.saltata,
                        StatoTappa.daFare when t.id == prossima?.id =>
                          AspettoPunto.prossima,
                        StatoTappa.daFare => AspettoPunto.daFare,
                      },
                      capsula: t.id == prossima?.id
                          ? [
                              'Prossima',
                              if (t.ora != null) ora(t.ora!),
                            ].join(' · ')
                          : null,
                      inCoda: inCoda.contains(t.id),
                      etichetta:
                          '${i + 1}, ${t.titolo}, ${_parola(t.statoTappa)}',
                      onApri: () => apriTappa(tappa: t),
                      onTocca: segnabili
                          ? () => segna(
                              t,
                              t.statoTappa == StatoTappa.daFare
                                  ? StatoTappa.completata
                                  : StatoTappa.daFare,
                            )
                          : null,
                      suggerimentoTocca: !segnabili
                          ? 'aprirla'
                          : t.statoTappa == StatoTappa.daFare
                          ? 'segnarla fatta'
                          : 'riportarla da fare',
                      onTieni: segnabili
                          ? () => segna(
                              t,
                              t.statoTappa == StatoTappa.saltata
                                  ? StatoTappa.daFare
                                  : StatoTappa.saltata,
                            )
                          : null,
                      suggerimentoTieni: !segnabili
                          ? null
                          : t.statoTappa == StatoTappa.saltata
                          ? 'riportarla da fare'
                          : 'saltarla',
                    ),
                ],
              ).entra(context, ritardo: Ritmo.passo * 2)
            else
              ConLaRete(
                builder: (context, rete) => _Elenco(
                  tappe: delGiorno,
                  riordinabile: rete,
                  onRiordina: (da, a) => _riordina(delGiorno, da, a),
                  riga: (t) => _RigaElenco(
                    tappa: t,
                    dettaglio: dettaglio(t),
                    dettaglioInRosso: sfora && t.eccedente,
                    segnabili: segnabili,
                    onApri: () => apriTappa(tappa: t),
                    onSegna: (stato) => segna(t, stato),
                  ),
                ),
              ),
            if (delGiorno.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
                child: _elenco
                    ? ConLaRete(
                        builder: (context, rete) => _Suggerimento(
                          rete
                              ? 'Tieni premuta una tappa e trascinala per '
                                    'cambiare l\'ordine.'
                              : 'Per cambiare l\'ordine serve la connessione.',
                        ),
                      )
                    : _Suggerimento(
                        segnabili
                            ? 'Tocca un punto per segnare la tappa fatta, '
                                  'tienilo premuto per saltarla.'
                            : 'Le tappe si segnano dal primo giorno del '
                                  'viaggio. Tocca una tappa per cambiarla.',
                      ),
              ),
            const SizedBox(height: 16),
            PulsanteGrande(
              etichetta: 'Aggiungi una tappa',
              icona: Icons.add_rounded,
              onPressed: () => apriTappa(),
            ).entra(context, ritardo: Ritmo.passo * 3),
            // Tutte le tappe del giorno in un colpo (tela, 59).
            if (delGiorno.isNotEmpty) ...[
              const SizedBox(height: 10),
              ConLaRete(
                builder: (context, rete) => PulsanteGrande(
                  etichetta: 'Svuota la giornata',
                  icona: Icons.delete_outline_rounded,
                  secondario: true,
                  pericolo: true,
                  motivo: rete ? null : motivoSenzaRete,
                  onPressed: () => svuotaLeTappe(
                    context,
                    viaggioId: viaggio.id,
                    tappe: delGiorno,
                    titolo:
                        'Togliere ${delGiorno.length == 1 ? 'la tappa' : 'le ${delGiorno.length} tappe'} '
                        'di ${nomeDelGiorno(finestra.data).toLowerCase()}?',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Le tappe nell'ordine appena trascinato, se c'è, altrimenti in quello
  /// della copia.
  List<Tappa> _inOrdine(List<Tappa> tappe) {
    final ordine = _ordine;
    if (ordine == null) return tappe;
    int posto(Tappa t) {
      final i = ordine.indexOf(t.id);
      return i < 0 ? ordine.length : i;
    }

    return [...tappe]..sort((a, b) => posto(a).compareTo(posto(b)));
  }

  Future<void> _riordina(List<Tappa> tappe, int da, int a) async {
    final ids = [for (final t in tappe) t.id];
    // [a] è già il posto nell'elenco senza la tappa spostata.
    ids.insert(a, ids.removeAt(da));
    setState(() => _ordine = ids);
    try {
      await Servizi.of(context).archivio.ordinaTappe(widget.giornoId, ids);
    } on ErroreTrolley catch (e) {
      if (mounted) mostraMessaggio(context, e.messaggio, errore: true);
    } finally {
      if (mounted) setState(() => _ordine = null);
    }
  }

  static String _parola(StatoTappa stato) => switch (stato) {
    StatoTappa.daFare => 'da fare',
    StatoTappa.completata => 'fatta',
    StatoTappa.saltata => 'saltata',
  };
}

/// La destinazione, in alto a destra.
class _Luogo extends StatelessWidget {
  const _Luogo(this.nome);

  final String nome;

  @override
  Widget build(BuildContext context) => Container(
    height: 32,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: Colori.bianco,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icona(ios: CupertinoIcons.location_solid, android: Icons.place),
          size: 16,
          color: Colori.cobalto,
        ),
        const SizedBox(width: 6),
        Text(
          nome,
          style: Testi.secondario.copyWith(
            color: Colori.inchiostro,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
      ],
    ),
  );
}

/// Quanto è piena la giornata: la somma delle tappe sulla sua capienza, la
/// striscia, e quanto resta. Se sfora lo dice in rosso.
class _Capienza extends StatelessWidget {
  const _Capienza({required this.finestra, required this.tappe});

  final FinestraGiorno finestra;
  final List<Tappa> tappe;

  @override
  Widget build(BuildContext context) {
    final capienza = finestra.capienza;
    final occupato = Duration(
      minutes: tappe.fold(0, (s, t) => s + t.durataStimataMin),
    );
    final libero = capienza - occupato;
    final (testo, rosso) = switch (libero) {
      Duration(isNegative: true) => (
        'Sfora di ${durata(-libero)}: togli o accorcia qualcosa.',
        true,
      ),
      Duration.zero => ('La giornata è piena.', false),
      const Duration(hours: 1) => ('Resta un\'ora libera.', false),
      _ => ('Restano ${durata(libero)} liberi.', false),
    };
    return Pannello(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'La giornata',
                  style: Testi.etichetta.copyWith(
                    color: Colori.grafite,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                occupato == Duration.zero
                    ? '${durataBreve(capienza)} libere'
                    : '${durataBreve(occupato)} su ${durataBreve(capienza)}',
                style: Testi.numero.copyWith(
                  color: Colori.inchiostro,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          StrisciaGiornata(
            capienza: capienza,
            altezza: 24,
            pezzi: [
              for (final t in tappe)
                PezzoStriscia(
                  t.durata,
                  t.statoTappa == StatoTappa.completata
                      ? Colori.verde
                      : coloreTipo(t.tipoTappa),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            testo,
            style: Testi.didascalia.copyWith(
              color: rosso ? Colori.pericolo : Colori.grafite,
              fontWeight: rosso ? FontWeight.w600 : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Percorso o elenco.
class _SceltaVista extends StatelessWidget {
  const _SceltaVista({required this.elenco, required this.onCambio});

  final bool elenco;
  final ValueChanged<bool> onCambio;

  @override
  Widget build(BuildContext context) {
    Widget voce(String nome, bool scelta, bool valore) => Semantics(
      selected: scelta,
      child: Premibile(
        onTap: () => onCambio(valore),
        scala: 0.96,
        etichetta: nome,
        child: AnimatedContainer(
          duration: Ritmo.breve,
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scelta ? Colori.bianco : Colori.cenere,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            nome,
            style: Testi.didascalia.copyWith(
              color: scelta ? Colori.inchiostro : Colori.ardesia,
              fontWeight: scelta ? FontWeight.w700 : FontWeight.w600,
              height: 1,
            ),
          ),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colori.cenere,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          voce('Percorso', !elenco, false),
          const SizedBox(width: 2),
          voce('Elenco', elenco, true),
        ],
      ),
    );
  }
}

class _Vuota extends StatelessWidget {
  const _Vuota();

  @override
  Widget build(BuildContext context) => Pannello(
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
    child: Row(
      children: [
        const CerchioTratteggiato(dimensione: 40, colore: Colori.piombo),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            'Nessuna tappa ancora. Mettile qui nell\'ordine in cui le farete: '
            'la durata la propone il tipo.',
            style: Testi.secondario.copyWith(color: Colori.grafite),
          ),
        ),
      ],
    ),
  );
}

class _Suggerimento extends StatelessWidget {
  const _Suggerimento(this.testo);

  final String testo;

  @override
  Widget build(BuildContext context) =>
      Text(testo, style: Testi.didascalia.copyWith(color: Colori.grafite));
}

/// Le tappe in elenco, da riordinare trascinandole quando c'è la rete.
class _Elenco extends StatelessWidget {
  const _Elenco({
    required this.tappe,
    required this.riordinabile,
    required this.onRiordina,
    required this.riga,
  });

  final List<Tappa> tappe;
  final bool riordinabile;
  final void Function(int da, int a) onRiordina;
  final Widget Function(Tappa tappa) riga;

  @override
  Widget build(BuildContext context) => ReorderableListView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    buildDefaultDragHandles: false,
    itemCount: tappe.length,
    onReorderItem: onRiordina,
    proxyDecorator: (figlio, _, _) => Material(
      color: const Color(0x00000000),
      elevation: 6,
      shadowColor: Colori.inchiostro.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(16),
      child: figlio,
    ),
    itemBuilder: (context, i) {
      final t = tappe[i];
      final contenuto = Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: riga(t),
      );
      return KeyedSubtree(
        key: ValueKey(t.id),
        child: riordinabile
            ? ReorderableDelayedDragStartListener(index: i, child: contenuto)
            : contenuto,
      );
    },
  );
}

/// Una tappa nell'elenco: il tipo, il titolo, e a destra il suo segno — il
/// timbro se è fatta o saltata, un posto vuoto se è da fare.
class _RigaElenco extends StatelessWidget {
  const _RigaElenco({
    required this.tappa,
    required this.dettaglio,
    required this.dettaglioInRosso,
    required this.segnabili,
    required this.onApri,
    required this.onSegna,
  });

  final Tappa tappa;
  final String dettaglio;
  final bool dettaglioInRosso;
  final bool segnabili;
  final VoidCallback onApri;
  final ValueChanged<StatoTappa> onSegna;

  @override
  Widget build(BuildContext context) {
    final stato = tappa.statoTappa;
    final segnata = DateTime.tryParse(tappa.marcataIl ?? '')?.toLocal();
    final segno = switch (stato) {
      StatoTappa.completata => Timbro(
        'FATTA',
        sotto: segnata == null ? null : '${segnata.day}·${segnata.month}',
      ),
      StatoTappa.saltata => const Timbro('SALTATA', colore: Colori.grafite),
      StatoTappa.daFare => const CerchioTratteggiato(colore: Colori.piombo),
    };
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: Colori.bianco,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colori.foschia,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              iconaTipo(tappa.tipoTappa),
              size: 22,
              color: coloreIconaTipo(tappa.tipoTappa),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Premibile(
              onTap: onApri,
              scala: 0.98,
              etichetta: 'Apri ${tappa.titolo}',
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tappa.titolo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Testi.evidenza.copyWith(
                        color: Colori.inchiostro,
                        fontSize: 15,
                        height: 1.25,
                      ),
                    ),
                    Text(
                      dettaglio,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Testi.didascalia.copyWith(
                        color: dettaglioInRosso
                            ? Colori.pericolo
                            : Colori.grafite,
                        fontWeight: dettaglioInRosso ? FontWeight.w600 : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (segnabili)
            Semantics(
              button: true,
              label: switch (stato) {
                StatoTappa.daFare => 'Da fare',
                StatoTappa.completata => 'Fatta',
                StatoTappa.saltata => 'Saltata',
              },
              onTapHint: stato == StatoTappa.daFare
                  ? 'segnarla fatta'
                  : 'riportarla da fare',
              onLongPressHint: stato == StatoTappa.saltata
                  ? 'riportarla da fare'
                  : 'saltarla',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSegna(
                  stato == StatoTappa.daFare
                      ? StatoTappa.completata
                      : StatoTappa.daFare,
                ),
                onLongPress: () => onSegna(
                  stato == StatoTappa.saltata
                      ? StatoTappa.daFare
                      : StatoTappa.saltata,
                ),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: Center(child: segno),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
