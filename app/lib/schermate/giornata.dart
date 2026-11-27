import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../aspetto/mezzi.dart';
import '../aspetto/elementi.dart';
import '../aspetto/formati.dart';
import '../aspetto/linea_del_tempo.dart';
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
import '../dominio/tragitti.dart';
import '../dominio/calendario.dart';
import '../dominio/chiusura.dart';
import '../dominio/giornate.dart';
import '../dominio/orari.dart';
import '../dominio/stato_viaggio.dart';
import '../dominio/tappe.dart';
import '../servizi.dart';
import 'adesso.dart' show oraDelGiorno;
import 'dettaglio_tappa.dart';
import 'con_la_rete.dart';
import 'gesti_tappa.dart';
import 'salta.dart';
import 'mappa.dart';
import 'problemi_coda.dart';
import 'tappa.dart';

/// Una giornata del viaggio (04-itinerario.md, "Giornata"; tela, 127–131):
/// quanto è piena, e la linea del tempo dalle 0 alle 24 con le tappe ai loro
/// orari. Il cerchio di una tappa la segna, la tappa toccata si apre, tenuta
/// premuta si sposta; uno spazio libero toccato è una tappa nuova a
/// quell'ora.
///
/// Si legge dalla copia, anche senza rete. Aggiungere e segnare funzionano
/// senza; spostare la richiede, e senza lo dice.
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
    final giorno = giorni[indice];
    final finestra = giorno.finestra;
    final adesso = DateTime.now();
    final statoViaggio = viaggio.statoA(adesso);
    final oggi =
        finestra.data == soloData(adesso) &&
        statoViaggio == StatoViaggio.inCorso;
    final segnabili = tappeSegnabili(statoViaggio);
    final collocate = tappeDelGiorno(giorno, tappe);
    final fuori = conflitti(finestra, collocate);
    final aggiunteInCoda = {
      for (final op in coda)
        if (op.gesto == GestoOffline.aggiungiTappa) ?Coda.tappaDi(op),
    };
    final prossima = oggi
        ? collocate
              .where((c) => c.tappa.statoTappa == StatoTappa.daFare)
              .firstOrNull
              ?.tappa
        : null;
    final perId = {for (final c in collocate) c.tappa.id: c};

    // Una tappa che c'è apre il suo dettaglio (tela, 156); una nuova, il
    // foglio.
    Future<void> apriTappa({Tappa? tappa, Duration? alle}) async {
      final altroGiorno = tappa != null
          ? await apriLaTappa(context, viaggio: viaggio, tappa: tappa)
          : await apriFoglio<String>(
              context,
              SchermataTappa(
                viaggio: viaggio,
                giorni: giorni,
                tappe: tappe,
                giornoId: widget.giornoId,
                ora: alle,
              ),
            );
      if (altroGiorno != null && altroGiorno != widget.giornoId && mounted) {
        await apri<void>(
          context,
          SchermataGiornata(viaggioId: viaggio.id, giornoId: altroGiorno),
        );
      }
    }

    Future<void> segna(String id, {required bool salta}) {
      final t = perId[id]!.tappa;
      final stato = t.statoTappa;
      // Tenere premuto per saltarla chiede se rimandarla (tela, 152).
      if (salta && stato != StatoTappa.saltata) {
        return saltaLaTappa(context, viaggio: viaggio, tappa: t);
      }
      return segnaLaTappa(
        context,
        viaggio: viaggio,
        tappa: t,
        stato: salta
            ? (stato == StatoTappa.saltata
                  ? StatoTappa.daFare
                  : StatoTappa.saltata)
            : (stato == StatoTappa.daFare
                  ? StatoTappa.completata
                  : StatoTappa.daFare),
      );
    }

    String? problemaA(String id, Duration inizio) {
      final c = perId[id];
      if (c == null) return null;
      final p = problemaOrario(
        finestra,
        occupatiDel(giorno, tappe, tranne: id),
        inizio,
        c.durata,
      );
      return p == null ? null : problemaInBreve(p);
    }

    // Fra una tappa e la dopo, il tragitto (CR-07; tela, 166).
    final tragitti = tragittiDelGiorno([
      for (final c in collocate)
        (
          id: c.tappa.id,
          inizio: c.inizio,
          fine: c.fine,
          saltata: c.tappa.statoTappa == StatoTappa.saltata,
          mezzo: c.tappa.mezzoTappa,
          posto: c.tappa.posto,
        ),
    ]);

    TragittoLinea sullaLinea(Tragitto t) {
      final mezzo = t.mezzo;
      final stima = t.stima();
      final a = perId[t.aId]!.tappa.titolo;
      return TragittoLinea(
        id: t.aId,
        partenza: t.partenza,
        arrivo: t.arrivo,
        icona: iconaMezzo(mezzo),
        aspetto: mezzo == null
            ? AspettoTragitto.daScegliere
            : t.nonCiStai
            ? AspettoTragitto.stretto
            : AspettoTragitto.scelto,
        testo: mezzo == null
            ? 'Come ci vai?'
            : [
                nomeMezzo(mezzo),
                if (stima != null) circa(stima),
                if (t.nonCiStai) 'non ci stai',
              ].join(' · '),
        etichetta: mezzo == null
            ? 'Fino a $a: come ci vai?'
            : [
                'Fino a $a ${mezzoInFrase(mezzo)}',
                if (stima != null) circa(stima),
                if (t.nonCiStai)
                  'non ci stai: fra le due tappe ci sono '
                      '${durataBreve(t.spazio)}',
              ].join(', '),
      );
    }

    BloccoLinea blocco(Collocata<Tappa> c) {
      final t = c.tappa;
      final inCoda = aggiunteInCoda.contains(t.id);
      final fuoriPosto = fuori.contains(t);
      final quando = '${ora(c.inizio)}–${ora(c.fine)}';
      final aspetto = fuoriPosto
          ? AspettoBlocco.fuoriPosto
          : switch (t.statoTappa) {
              StatoTappa.completata => AspettoBlocco.fatta,
              StatoTappa.saltata => AspettoBlocco.saltata,
              StatoTappa.daFare when t.id == prossima?.id =>
                AspettoBlocco.prossima,
              StatoTappa.daFare when inCoda => AspettoBlocco.inCoda,
              StatoTappa.daFare => AspettoBlocco.daFare,
            };
      final dettaglio = [
        if (t.tipoTappa != null) nomeTipo(t.tipoTappa!),
        quando,
        if (fuoriPosto)
          'da sistemare'
        else if (c.proposto)
          'orario proposto'
        else if (t.id == prossima?.id)
          'la prossima'
        else if (inCoda)
          'parte con la rete'
        else if (t.luogoNome?.trim().isNotEmpty ?? false)
          t.luogoNome!.trim(),
      ].join(' · ');
      return BloccoLinea(
        id: t.id,
        inizio: c.inizio,
        durata: c.durata,
        titolo: t.titolo,
        dettaglio: dettaglio,
        aspetto: aspetto,
        colore: coloreTipo(t.tipoTappa),
        proposto: c.proposto,
        etichetta: [
          quando,
          t.titolo,
          switch (t.statoTappa) {
            StatoTappa.daFare => 'da fare',
            StatoTappa.completata => 'fatta',
            StatoTappa.saltata => 'saltata',
          },
          if (fuoriPosto) 'da sistemare',
          if (c.proposto) 'orario proposto',
        ].join(', '),
      );
    }

    // Aprendo: un po' prima di adesso, il giorno stesso; altrimenti un po'
    // prima della prima tappa, o dell'inizio della giornata.
    final apriA = oggi
        ? oraDelGiorno(adesso) - const Duration(hours: 1)
        : (collocate.firstOrNull?.inizio ??
                  (finestra.inizio > primaOraProposta
                      ? finestra.inizio
                      : primaOraProposta)) -
              const Duration(minutes: 30);
    final aggiungibili = tappeAggiungibili(statoViaggio);

    final luogo = viaggio.destinazione?.nome ?? titoloViaggio(viaggio);
    final suggerimento = [
      if (segnabili)
        'Tocca il cerchio per segnare una tappa fatta, tienilo premuto per '
            'saltarla.'
      else
        'Le tappe si segnano dal primo giorno del viaggio.',
      if (collocate.isNotEmpty) 'Tieni premuta una tappa per spostarla.',
      if (aggiungibili) 'Tocca un\'ora libera per mettere lì una tappa.',
    ].join(' ');
    final piede = Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              suggerimento,
              style: Testi.didascalia.copyWith(color: Colori.grafite),
            ),
          ),
          if (!aggiungibili) ...[
            const SizedBox(height: 10),
            Text(
              'Il viaggio è concluso: le tappe restano com\'erano, e non se '
              'ne aggiungono.',
              textAlign: TextAlign.center,
              style: Testi.didascalia.copyWith(color: Colori.grafite),
            ),
          ],
          // Tutte le tappe del giorno in un colpo (tela, 59).
          if (collocate.isNotEmpty) ...[
            const SizedBox(height: 16),
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
                  tappe: [for (final c in collocate) c.tappa],
                  titolo:
                      'Togliere ${collocate.length == 1 ? 'la tappa' : 'le ${collocate.length} tappe'} '
                      'di ${nomeDelGiorno(finestra.data).toLowerCase()}?',
                ),
              ),
            ),
          ],
        ],
      ),
    );
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
      // In alto il giorno e quanto è pieno; sotto la linea del tempo, che è
      // la sola cosa che scorre; in basso «Aggiungi una tappa», sempre lì.
      corpo: Builder(
        builder: (context) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.paddingOf(context).top + 8,
            20,
            MediaQuery.paddingOf(context).bottom + 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const SizedBox(height: 6),
              Semantics(
                header: true,
                child: Text(
                  nomeDelGiorno(finestra.data),
                  style: Testi.titoloFoglio.copyWith(color: Colori.inchiostro),
                ),
              ).entra(context),
              const SizedBox(height: 14),
              _Capienza(
                finestra: finestra,
                collocate: collocate,
                fuori: fuori.length,
              ).entra(context, ritardo: Ritmo.passo),
              ProblemiDellaCoda(operazioni: coda),
              const SizedBox(height: 12),
              Expanded(
                child: ConLaRete(
                  builder: (context, rete) => LineaDelTempo(
                    inizioGiornata: finestra.inizio,
                    fineGiornata: finestra.fine,
                    apriA: apriA < Duration.zero ? Duration.zero : apriA,
                    adesso: oggi ? oraDelGiorno(adesso) : null,
                    blocchi: [for (final c in collocate) blocco(c)],
                    onApri: (id) => apriTappa(tappa: perId[id]!.tappa),
                    onSegna: segnabili ? (id) => segna(id, salta: false) : null,
                    onSalta: segnabili ? (id) => segna(id, salta: true) : null,
                    problemaA: problemaA,
                    onSposta: rete
                        ? (id, inizio) async {
                            await spostaLaTappa(
                              context,
                              perId[id]!.tappa,
                              inizio,
                            );
                          }
                        : null,
                    onNonSpostabile: () => mostraMessaggio(
                      context,
                      'Per spostare una tappa serve la connessione.',
                    ),
                    onNuova: aggiungibili
                        ? (alle) => apriTappa(alle: alle)
                        : null,
                    piede: piede,
                    // Il tragitto si vede soltanto: il mezzo si sceglie nella
                    // tappa o nella guida (tela, 166 e 170). Un viaggio
                    // concluso mostra solo quelli scelti.
                    tragitti: [
                      for (final t in tragitti)
                        if (aggiungibili || t.mezzo != null) sullaLinea(t),
                    ],
                  ),
                ).entra(context, ritardo: Ritmo.passo * 2),
              ),
              // Concluso, il programma è finito: le tappe restano com'erano
              // (tela, 93).
              if (aggiungibili) ...[
                const SizedBox(height: 12),
                PulsanteGrande(
                  etichetta: 'Aggiungi una tappa',
                  icona: Icons.add_rounded,
                  onPressed: () => apriTappa(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
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
/// striscia con le tappe ai loro orari, e quanto resta. Se sfora, o se delle
/// tappe sono fuori posto, lo dice in rosso.
class _Capienza extends StatelessWidget {
  const _Capienza({
    required this.finestra,
    required this.collocate,
    required this.fuori,
  });

  final FinestraGiorno finestra;
  final List<Collocata<Tappa>> collocate;

  /// Quante tappe sono fuori posto.
  final int fuori;

  @override
  Widget build(BuildContext context) {
    final capienza = finestra.capienza;
    final occupato = collocate.fold(Duration.zero, (s, c) => s + c.durata);
    final libero = capienza - occupato;
    final (testo, rosso) = switch (libero) {
      Duration(isNegative: true) => (
        'Sfora di ${durata(-libero)}: togli o accorcia qualcosa.',
        true,
      ),
      _ when fuori > 0 => (
        fuori == 1
            ? 'Una tappa esce dalla giornata: sistemala.'
            : 'Delle tappe si sovrappongono: sistemale.',
        true,
      ),
      Duration.zero => ('La giornata è piena.', false),
      const Duration(hours: 1) => ('Resta un\'ora libera.', false),
      _ => ('Restano ${durata(libero)} liberi.', false),
    };
    final etichette = Testi.titoli(
      10,
      peso: 600,
      spaziatura: 0,
    ).copyWith(color: const Color(0xFF8A90A2));
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
            altezza: 18,
            daOra: finestra.inizio,
            pezzi: pezziDelGiorno(finestra, collocate),
          ),
          const SizedBox(height: 4),
          ExcludeSemantics(
            child: Row(
              children: [
                Text(ora(finestra.inizio), style: etichette),
                const Spacer(),
                Text(ora(finestra.fine), style: etichette),
              ],
            ),
          ),
          const SizedBox(height: 8),
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
