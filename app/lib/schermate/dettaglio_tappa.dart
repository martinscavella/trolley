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

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../aspetto/elementi.dart';
import '../aspetto/formati.dart';
import '../aspetto/pagina.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../dati/database.dart';
import '../dati/lettura.dart';
import '../dominio/orari.dart';
import '../dominio/tappe.dart';
import '../servizi.dart';
import 'documenti.dart';
import 'gesti_mappa.dart';
import 'gesti_tappa.dart';
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
          EtichettaSezione('Dove'),
          _Dove(
            tappa: tappa,
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

/// Dove sta (tela, 156 e 158): il posto, con «Portami lì» e «Apri in
/// Mappe»; senza un posto sulla mappa, «Cerca il posto» apre la modifica.
class _Dove extends StatelessWidget {
  const _Dove({
    required this.tappa,
    required this.onPortami,
    required this.onCerca,
  });

  final Tappa tappa;
  final VoidCallback onPortami;
  final VoidCallback onCerca;

  @override
  Widget build(BuildContext context) {
    final nome = tappa.luogoNome?.trim();
    final conNome = nome != null && nome.isNotEmpty;
    if (tappa.posto == null) {
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
          PulsantePiccolo(etichetta: 'Cerca il posto', onPressed: onCerca),
        ],
      );
    }
    final mappe = Servizi.of(context).mappeDelTelefono;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colori.bianco,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                icona(
                  ios: CupertinoIcons.location,
                  android: Icons.place_outlined,
                ),
                color: Colori.cobalto,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  conNome ? nome : 'Sulla mappa',
                  style: Testi.evidenza.copyWith(color: Colori.inchiostro),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: PulsanteGrande(
                  etichetta: 'Portami lì',
                  onPressed: onPortami,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PulsanteGrande(
                  etichetta: 'Apri in Mappe',
                  secondario: true,
                  onPressed: () async {
                    final aperte = await mappe.portami(
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
        ],
      ),
    );
  }
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
