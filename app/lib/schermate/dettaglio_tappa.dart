/// Il dettaglio di una tappa (tela, 156–158): aprendo una tappa da «Adesso»,
/// dalla giornata o dalla mappa non esce più il foglio per cambiarla, ma
/// questa pagina, che si legge. La matita in alto apre il foglio di sempre.
///
/// Dentro: quando, cosa e quanto dura; durante il viaggio «Fatta» e «Salta»
/// (che chiede, tela 152); dove, con «Portami lì» e «Apri in Mappe»; il
/// documento di quel momento; chi l'ha aggiunta. La mini mappa del posto, la
/// descrizione e la guida arrivano con Google (ADR-014; CR-03, CR-01).
///
/// Si legge anche senza rete, dalla copia. «Fatta» e «Salta e basta» sono
/// gesti della coda; rimandare e cambiarla vogliono la rete, e lo dicono i
/// loro fogli.
library;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../aspetto/elementi.dart';
import '../aspetto/formati.dart';
import '../aspetto/pagina.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../aspetto/segni_mappa.dart';
import '../dati/database.dart';
import '../dati/errori.dart';
import '../dati/mappe.dart';
import '../dati/lettura.dart';
import '../dominio/mappa.dart';
import '../dominio/orari.dart';
import '../dominio/tappe.dart';
import '../servizi.dart';
import 'documenti.dart';
import 'gesti_mappa.dart';
import 'gesti_tappa.dart';
import 'luogo.dart';
import 'salta.dart';
import 'tappa.dart';

/// Apre il dettaglio di [tappa]. Restituisce il giorno da aprire, se dal
/// foglio della modifica si è scelto di togliere qualcosa da un altro giorno
/// (lo stesso valore del foglio).
Future<String?> apriLaTappa(
  BuildContext context, {
  required Viaggio viaggio,
  required Tappa tappa,
}) => apri<String>(
  context,
  SchermataDettaglioTappa(viaggioId: viaggio.id, tappaId: tappa.id),
);

class SchermataDettaglioTappa extends StatefulWidget {
  const SchermataDettaglioTappa({
    super.key,
    required this.viaggioId,
    required this.tappaId,
  });

  final String viaggioId;
  final String tappaId;

  @override
  State<SchermataDettaglioTappa> createState() =>
      _SchermataDettaglioTappaState();
}

typedef _Dati = ({
  Viaggio viaggio,
  List<Giorno> giorni,
  List<Tappa> tappe,
  List<Documento> documenti,
  List<(Partecipazione, Utente?)> partecipanti,
});

class _SchermataDettaglioTappaState extends State<SchermataDettaglioTappa> {
  late Stream<Viaggio?> _viaggio;
  late Stream<List<Giorno>> _giorni;
  late Stream<List<Tappa>> _tappe;
  late Stream<List<Documento>> _documenti;
  late Stream<List<(Partecipazione, Utente?)>> _partecipanti;
  bool _avviata = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_avviata) return;
    _avviata = true;
    final servizi = Servizi.of(context);
    final v = widget.viaggioId;
    _viaggio = servizi.archivio.osservaViaggio(v);
    _giorni = servizi.archivio.osservaGiorni(v);
    _tappe = servizi.archivio.osservaTappe(v);
    _documenti = servizi.documenti.osserva(v);
    _partecipanti = servizi.archivio.osservaPartecipanti(v);
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
              StreamBuilder<List<(Partecipazione, Utente?)>>(
                stream: _partecipanti,
                builder: (context, partecipanti) {
                  final (v, g, t) = (viaggio.data, giorni.data, tappe.data);
                  if (v == null || g == null || t == null) {
                    return const Pagina(
                      corpo: Center(child: IndicatoreAttivita()),
                    );
                  }
                  final tappa = t
                      .where((x) => x.id == widget.tappaId)
                      .firstOrNull;
                  if (tappa == null) return const _NonCePiu();
                  return _pagina((
                    viaggio: v,
                    giorni: g,
                    tappe: t,
                    documenti: documenti.data ?? const [],
                    partecipanti: partecipanti.data ?? const [],
                  ), tappa);
                },
              ),
        ),
      ),
    ),
  );

  Future<void> _modifica(_Dati d, Tappa tappa) async {
    final altroGiorno = await apriFoglio<String>(
      context,
      SchermataTappa(
        viaggio: d.viaggio,
        giorni: d.giorni,
        tappe: d.tappe,
        giornoId: tappa.giornoId,
        tappa: tappa,
      ),
    );
    if (altroGiorno != null && mounted) {
      Navigator.of(context).pop(altroGiorno);
    }
  }

  Widget _pagina(_Dati d, Tappa tappa) {
    final giorno = d.giorni.where((g) => g.id == tappa.giornoId).firstOrNull;
    final delGiorno = giorno == null
        ? const <Collocata<Tappa>>[]
        : tappeDelGiorno(giorno, d.tappe);
    final qui = delGiorno.where((c) => c.tappa.id == tappa.id).firstOrNull;
    final numero = qui == null ? 1 : delGiorno.indexOf(qui) + 1;
    final stato = tappa.statoTappa;
    final segnabili = tappeSegnabili(d.viaggio.statoA(DateTime.now()));

    final quando = [
      if (giorno != null) giornoBreve(giorno.finestra.data),
      if (qui != null) '${ora(qui.inizio)}–${ora(qui.fine)}',
    ].join(' · ');
    final sotto = [
      if (tappa.tipoTappa != null) nomeTipo(tappa.tipoTappa!),
      durataBreve(tappa.durata),
      if (stato == StatoTappa.saltata) 'saltata',
      if (stato == StatoTappa.completata) 'fatta',
    ].join(' · ');

    // Il documento di quel momento: dello stesso giorno, con l'ora dentro la
    // tappa.
    final documenti = qui == null
        ? const <Documento>[]
        : [
            for (final doc in d.documenti)
              if (doc.giornoId == tappa.giornoId &&
                  doc.momento != null &&
                  doc.momento! >= qui.inizio &&
                  doc.momento! < qui.fine)
                doc,
          ];

    final io = Servizi.of(context).archivio.io;
    final chi = tappa.creatoDa == io
        ? 'te'
        : d.partecipanti
              .where((p) => p.$1.utenteId == tappa.creatoDa)
              .map((p) => p.$2?.nome)
              .firstOrNull;

    return Pagina(
      azioni: [
        PulsanteTondo(
          icona: icona(
            ios: CupertinoIcons.pencil,
            android: Icons.edit_outlined,
          ),
          etichetta: 'Modifica',
          onPressed: () => _modifica(d, tappa),
        ),
      ],
      corpo: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          MediaQuery.paddingOf(context).top + Pagina.altezzaBarra,
          20,
          32 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          if (quando.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                quando.toUpperCase(),
                style: Testi.sezione.copyWith(color: Colori.cobalto),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Semantics(
              header: true,
              child: Text(
                tappa.titolo,
                style: Testi.titolo.copyWith(color: Colori.inchiostro),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Text(
              sotto,
              style: Testi.corpo.copyWith(color: Colori.ardesia),
            ),
          ),
          if (segnabili) ..._gesti(d.viaggio, tappa, stato),
          if (tappa.posto == null) EtichettaSezione('Dove'),
          _Dove(
            viaggioId: d.viaggio.id,
            tappa: tappa,
            numero: numero,
            giorno: giorno?.finestra.data,
            onPortami: () => portamiAllaTappa(
              context,
              viaggio: d.viaggio,
              tappa: tappa,
              numero: numero,
            ),
            onCerca: () => _modifica(d, tappa),
          ),
          if (documenti.isNotEmpty) ...[
            EtichettaSezione(
              documenti.length == 1 ? 'Il documento' : 'I documenti',
            ),
            for (final doc in documenti) ...[
              RigaDocumento(documento: doc),
              const SizedBox(height: 8),
            ],
          ],
          if (chi != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 18, 4, 0),
              child: Text(
                'Aggiunta da $chi',
                style: Testi.didascalia.copyWith(color: Colori.grafite),
              ),
            ),
        ],
      ),
    );
  }

  /// Durante il viaggio: da fare, «Fatta» e «Salta» (tela, 156); segnata,
  /// com'è andata e come tornare indietro (157).
  List<Widget> _gesti(Viaggio viaggio, Tappa tappa, StatoTappa stato) =>
      switch (stato) {
        StatoTappa.daFare => [
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: PulsanteGrande(
                  etichetta: 'Fatta',
                  colore: Colori.verde,
                  icona: icona(
                    ios: CupertinoIcons.check_mark,
                    android: Icons.check_rounded,
                  ),
                  onPressed: () => segnaLaTappa(
                    context,
                    viaggio: viaggio,
                    tappa: tappa,
                    stato: StatoTappa.completata,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PulsanteGrande(
                  etichetta: 'Salta',
                  secondario: true,
                  onPressed: () =>
                      saltaLaTappa(context, viaggio: viaggio, tappa: tappa),
                ),
              ),
            ],
          ),
        ],
        StatoTappa.saltata => [
          const SizedBox(height: 16),
          Avviso(
            fondo: Colori.cobaltoChiaro,
            colore: Colori.cobalto,
            icona: icona(
              ios: CupertinoIcons.arrow_counterclockwise,
              android: Icons.replay_rounded,
            ),
            inizio: 'Ci vuoi ancora andare?',
            testo:
                'Rimandala: torna da fare, più tardi oggi o in un altro '
                'giorno.',
            azioni: [
              PulsantePiccolo(
                etichetta: 'Rimandala',
                onPressed: () =>
                    rimandaLaTappa(context, viaggio: viaggio, tappa: tappa),
              ),
              PulsantePiccolo(
                etichetta: 'Riportala da fare',
                onPressed: () => segnaLaTappa(
                  context,
                  viaggio: viaggio,
                  tappa: tappa,
                  stato: StatoTappa.daFare,
                ),
              ),
            ],
          ),
        ],
        StatoTappa.completata => [
          const SizedBox(height: 16),
          Avviso(
            fondo: Colori.menta,
            colore: Colori.verde,
            icona: icona(
              ios: CupertinoIcons.check_mark_circled,
              android: Icons.check_circle_outline_rounded,
            ),
            inizio: 'Fatta.',
            testo: 'Conta per la verifica del viaggio.',
            azioni: [
              PulsantePiccolo(
                etichetta: 'Riportala da fare',
                onPressed: () => segnaLaTappa(
                  context,
                  viaggio: viaggio,
                  tappa: tappa,
                  stato: StatoTappa.daFare,
                ),
              ),
            ],
          ),
        ],
      };
}

/// Dove sta. Senza un posto sulla mappa, «Cerca il posto» apre la modifica
/// (tela, 158). Con il posto, due schede mai visibili insieme (tela, 161 e
/// 162; ADR-014): «Info», con l'indirizzo, gli orari e la descrizione di
/// Google, chiesti con la rete e non tenuti; «Mappa», con la mini mappa e
/// sopra solo il nostro segno. Sotto, «Portami lì» e «Apri in Mappe».
class _Dove extends StatefulWidget {
  const _Dove({
    required this.viaggioId,
    required this.tappa,
    required this.numero,
    required this.giorno,
    required this.onPortami,
    required this.onCerca,
  });

  final String viaggioId;
  final Tappa tappa;
  final int numero;

  /// Il giorno della tappa: gli orari di quel giorno.
  final DateTime? giorno;
  final VoidCallback onPortami;
  final VoidCallback onCerca;

  @override
  State<_Dove> createState() => _DoveState();
}

class _DoveState extends State<_Dove> {
  bool _info = true;

  /// La scheda di Google del posto, per [_di].
  SchedaPosto? _scheda;
  String? _di;
  bool _chiede = false;

  late Servizi _servizi;
  late ConsumoMappe _prima;
  bool _avviato = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_avviato) return;
    _avviato = true;
    _servizi = Servizi.of(context);
    _prima = _servizi.mappe.consumo;
    unawaited(_chiedi());
  }

  @override
  void didUpdateWidget(_Dove prima) {
    super.didUpdateWidget(prima);
    if (prima.tappa.placeId != widget.tappa.placeId) unawaited(_chiedi());
  }

  @override
  void dispose() {
    unawaited(
      registraConsumo(
        _servizi.misurazione,
        _servizi.mappe,
        viaggioId: widget.viaggioId,
        prima: _prima,
      ),
    );
    super.dispose();
  }

  /// La scheda si chiede solo quando «Info» si vede, e una volta: è la
  /// chiamata più cara di Google.
  Future<void> _chiedi() async {
    final id = widget.tappa.placeId;
    if (!_info || id == null || id == _di || widget.tappa.posto == null) {
      return;
    }
    if (!_servizi.rete.disponibile || !_servizi.mappe.disponibili) return;
    _di = id;
    setState(() => _chiede = true);
    try {
      final scheda = await _servizi.mappe.scheda(
        id,
        viaggioId: widget.viaggioId,
      );
      if (mounted && widget.tappa.placeId == id) {
        setState(() => _scheda = scheda);
      }
    } on ErroreTrolley {
      // Senza la scheda resta «Sulla mappa»: si può andare lo stesso.
      if (mounted) _di = null;
    } finally {
      if (mounted) setState(() => _chiede = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tappa = widget.tappa;
    final posto = tappa.posto;
    if (posto == null) {
      final nome = tappa.luogoNome?.trim();
      final conNome = nome != null && nome.isNotEmpty;
      return Avviso(
        icona: icona(
          ios: CupertinoIcons.location,
          android: Icons.place_outlined,
        ),
        colore: Colori.cobalto,
        inizio: conNome ? nome : 'Non ha un posto sulla mappa.',
        testo: conNome
            ? 'Non è sulla mappa: cercalo da «Modifica», poi la mappa la '
                  'mostra e ti ci porta.'
            : 'Cercalo da «Modifica»: poi la mappa la mostra e ti ci porta.',
        azioni: [
          PulsantePiccolo(
            etichetta: 'Cerca il posto',
            onPressed: widget.onCerca,
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        DueSchede(
          prima: 'Info',
          seconda: 'Mappa',
          sullaPrima: _info,
          onScegli: (info) {
            setState(() => _info = info);
            unawaited(_chiedi());
          },
        ),
        const SizedBox(height: 12),
        if (_info) _schedaInfo(tappa) else _schedaMappa(tappa, posto),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: PulsanteGrande(
                etichetta: 'Portami lì',
                onPressed: widget.onPortami,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PulsanteGrande(
                etichetta: 'Apri in Mappe',
                secondario: true,
                onPressed: () async {
                  final aperte = await _servizi.mappeDelTelefono.portami(
                    nome: tappa.titolo,
                    posto: tappa.posto,
                    indirizzo: tappa.luogoNome,
                  );
                  if (!aperte && context.mounted) {
                    mostraMessaggio(
                      context,
                      'Le Mappe non si sono aperte.',
                      errore: true,
                    );
                  }
                },
              ),
            ),
          ],
        ),
        if (!_info && tappa.placeId != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
            child: Text(
              'Indirizzo e orari stanno in «Info»: Google non li lascia '
              'accanto alla mappa.',
              style: Testi.didascalia.copyWith(color: Colori.grafite),
            ),
          ),
      ],
    );
  }

  Widget _schedaInfo(Tappa tappa) {
    final scheda = tappa.placeId != null && _di == tappa.placeId
        ? _scheda
        : null;
    final righe = <Widget>[];
    if (scheda == null) {
      righe.add(
        _RigaInfo(
          icona: icona(
            ios: CupertinoIcons.location,
            android: Icons.place_outlined,
          ),
          titolo:
              doveDellaTappa(tappa.luogoNome, tappa.placeId) ?? postoSullaMappa,
          sotto: tappa.placeId == null || _chiede
              ? null
              : 'Con la rete qui ci sono l\'indirizzo e gli orari.',
        ),
      );
      if (_chiede) {
        righe.add(
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Center(child: IndicatoreAttivita()),
          ),
        );
      }
    } else {
      final apertura = descriviApertura(
        scheda,
        giorno: widget.giorno,
        adesso: DateTime.now(),
      );
      righe.addAll([
        // In alto a destra, piccolo: le condizioni di Google lo vogliono
        // vicino al contenuto, nello stesso riquadro, e non più piccolo di
        // 12 punti.
        const Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: EdgeInsets.only(top: 8),
            child: AttribuzioneGoogle(compatta: true),
          ),
        ),
        _RigaInfo(
          icona: icona(
            ios: CupertinoIcons.location,
            android: Icons.place_outlined,
          ),
          titolo: scheda.indirizzo ?? postoSullaMappa,
        ),
        if (apertura != null)
          _RigaInfo(
            icona: icona(
              ios: CupertinoIcons.clock,
              android: Icons.schedule_rounded,
            ),
            colore: Colori.verde,
            titolo: apertura.titolo,
            coloreTitolo: apertura.aperto ? Colori.verde : null,
            sotto: apertura.sotto,
          ),
        if (scheda.descrizione case final descrizione?)
          _RigaInfo(
            icona: icona(
              ios: CupertinoIcons.book,
              android: Icons.menu_book_outlined,
            ),
            titolo: descrizione,
            normale: true,
          ),
      ]);
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      decoration: BoxDecoration(
        color: Colori.bianco,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: righe,
      ),
    );
  }

  Widget _schedaMappa(Tappa tappa, Coordinate posto) {
    final segno = switch (tappa.statoTappa) {
      StatoTappa.completata => SegnoTappa.fatta,
      StatoTappa.saltata => SegnoTappa.saltata,
      _ => SegnoTappa.prossima,
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 240,
        child: _servizi.mappe.mappa(
          context,
          viaggioId: widget.viaggioId,
          centro: posto,
          zoom: 16,
          interattiva: false,
          onPronta: (_) {},
          segni: [
            SegnoMappa(
              id: 'segno-${tappa.id}',
              posto: posto,
              aspetto: '${widget.numero}|${segno.name}',
              lato: latoImmagineSegno,
              disegno: SegnoSullaMappa(
                numero: widget.numero,
                segno: segno,
                etichetta: '${widget.numero}, ${tappa.titolo}',
                onTap: () {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Una riga di «Info»: l'icona, il testo, una riga sotto.
class _RigaInfo extends StatelessWidget {
  const _RigaInfo({
    required this.icona,
    required this.titolo,
    this.sotto,
    this.colore = Colori.cobalto,
    this.coloreTitolo,
    this.normale = false,
  });

  final IconData icona;
  final String titolo;
  final String? sotto;
  final Color colore;
  final Color? coloreTitolo;

  /// Un testo lungo, non un'etichetta: senza grassetto.
  final bool normale;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icona, color: colore, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titolo,
                style: (normale ? Testi.corpo : Testi.evidenza).copyWith(
                  color: coloreTitolo ?? Colori.inchiostro,
                ),
              ),
              if (sotto case final sotto?) ...[
                const SizedBox(height: 2),
                Text(
                  sotto,
                  style: Testi.didascalia.copyWith(color: Colori.grafite),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

/// Come dire se un posto è aperto (tela, 161): adesso, e il giorno in cui
/// ci si va. `null` se Google non sa niente degli orari.
({String titolo, String? sotto, bool aperto})? descriviApertura(
  SchedaPosto scheda, {
  DateTime? giorno,
  required DateTime adesso,
}) {
  if (scheda.chiusoPerSempre) {
    return (titolo: 'Chiuso per sempre', sotto: null, aperto: false);
  }
  if (scheda.chiusoPerOra) {
    return (titolo: 'Chiuso per ora', sotto: null, aperto: false);
  }
  final orari = scheda.orari;
  String? quel;
  if (giorno != null && orari != null) {
    final nome = conMaiuscola(giornoDellaSettimana(giorno));
    final aperture = orari.del(giorno);
    quel = orari.sempre
        ? '$nome, quando ci vai: sempre aperto'
        : aperture.isEmpty
        ? '$nome, quando ci vai: chiuso'
        : '$nome, quando ci vai: '
              '${aperture.map((a) => '${ora(a.apre)}–${ora(a.chiude)}').join(', ')}';
  }
  final aperto = scheda.apertoOra;
  if (aperto == null) {
    return quel == null ? null : (titolo: quel, sotto: null, aperto: false);
  }
  final cambia = scheda.cambiaAlle;
  String? quando;
  if (cambia != null) {
    final alle = ora(Duration(hours: cambia.hour, minutes: cambia.minute));
    final li = scheda.scarto == null
        ? null
        : adesso.toUtc().add(scheda.scarto!);
    final oggi =
        li == null ||
        (li.year == cambia.year &&
            li.month == cambia.month &&
            li.day == cambia.day);
    quando = aperto
        ? 'fino alle $alle'
        : oggi
        ? 'apre alle $alle'
        : 'apre ${giornoDellaSettimana(cambia)} alle $alle';
  }
  return (
    titolo: [aperto ? 'Aperto' : 'Chiuso', ?quando].join(' · '),
    sotto: quel,
    aperto: aperto,
  );
}

/// La tappa è stata tolta, da qui o da un altro telefono.
class _NonCePiu extends StatelessWidget {
  const _NonCePiu();

  @override
  Widget build(BuildContext context) => Pagina(
    corpo: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'Questa tappa non c\'è più: è stata tolta dal viaggio.',
          textAlign: TextAlign.center,
          style: Testi.corpo.copyWith(color: Colori.grafite),
        ),
      ),
    ),
  );
}
