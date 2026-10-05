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
import '../dati/errori.dart';
import '../dati/lettura.dart';
import '../dominio/liste.dart';
import '../dominio/partenza.dart';
import '../dominio/tappe.dart';
import '../misurazione/misurazione.dart';
import '../servizi.dart';
import 'con_la_rete.dart';
import 'cose.dart';
import 'documenti.dart';
import 'due_versioni.dart';
import 'foglio_documento.dart';
import 'gesti_mappa.dart';
import 'luogo.dart';

/// Il giro di controllo prima di partire, com'è adesso: i documenti, la
/// valigia, le tappe senza un posto, e se il viaggio è già pronto senza rete.
class Controllo {
  const Controllo({
    required this.viaggio,
    required this.giorni,
    required this.tappe,
    required this.documenti,
    required this.documentiMancanti,
    required this.valigia,
    required this.senzaPosto,
    required this.conAltri,
    required this.tassiDel,
    required this.preparato,
    required this.copia,
  });

  final Viaggio viaggio;

  /// I giorni del viaggio, in ordine.
  final List<Giorno> giorni;

  /// Le tappe di tutti i giorni.
  final List<Tappa> tappe;
  final List<Documento> documenti;

  /// I nomi dei documenti il cui file non c'è più: tornato da un backup a
  /// metà, o tolto dal telefono (03, casi limite).
  final List<String> documentiMancanti;
  final ValigiaPrimaDiPartire valigia;

  /// Le tappe da fare senza un posto sulla mappa, giorno per giorno.
  final List<Tappa> senzaPosto;

  /// Nel viaggio c'è qualcun altro: ci sono anche i saldi.
  final bool conAltri;

  /// Il giorno dei tassi di cambio sul telefono, se ce ne sono.
  final DateTime? tassiDel;

  /// Quando la persona l'ha preparato su questo telefono, se l'ha fatto.
  final DateTime? preparato;

  /// Quando la copia del viaggio è stata scaricata l'ultima volta.
  final DateTime? copia;

  bool get documentiAPosto => documenti.isNotEmpty && documentiMancanti.isEmpty;
  bool get valigiaAPosto => valigia.fatta;
  bool get tappeAPosto => senzaPosto.isEmpty;
  bool get prontoSenzaRete => preparato != null;

  /// Quante righe del giro di controllo chiedono ancora uno sguardo.
  int get daGuardare => [
    documentiAPosto,
    valigiaAPosto,
    tappeAPosto,
    prontoSenzaRete,
  ].where((aPosto) => !aPosto).length;
}

/// Ascolta la copia e i documenti di un viaggio e costruisce il [Controllo]
/// ogni volta che cambia qualcosa. Finché non è arrivato tutto, [builder]
/// riceve `null`.
class ControlloPrimaDiPartire extends StatefulWidget {
  const ControlloPrimaDiPartire({
    super.key,
    required this.viaggioId,
    required this.builder,
  });

  final String viaggioId;
  final Widget Function(BuildContext context, Controllo? controllo) builder;

  @override
  State<ControlloPrimaDiPartire> createState() =>
      _ControlloPrimaDiPartireState();
}

class _ControlloPrimaDiPartireState extends State<ControlloPrimaDiPartire> {
  final _ascolti = <StreamSubscription<Object?>>[];
  bool _avviato = false;

  Viaggio? _viaggio;
  List<Giorno>? _giorni;
  List<Tappa>? _tappe;
  List<VoceLista>? _voci;
  Set<String>? _presenti;
  List<Documento>? _documenti;
  List<TassoCambio>? _tassi;
  DateTime? _preparato;
  DateTime? _copia;
  bool _preparatoLetto = false;
  bool _copiaLetta = false;

  /// I nomi dei documenti senza file, per l'elenco controllato per ultimo.
  List<String> _mancanti = const [];
  String _controllati = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_avviato) return;
    _avviato = true;
    final servizi = Servizi.of(context);
    final archivio = servizi.archivio;
    final id = widget.viaggioId;
    void ascolta<T>(Stream<T> flusso, void Function(T valore) usa) =>
        _ascolti.add(
          flusso.listen((valore) {
            if (mounted) setState(() => usa(valore));
          }),
        );
    ascolta(archivio.osservaViaggio(id), (v) => _viaggio = v);
    ascolta(archivio.osservaGiorni(id), (g) => _giorni = g);
    ascolta(archivio.osservaTappe(id), (t) => _tappe = t);
    ascolta(archivio.osservaVoci(id), (v) => _voci = v);
    ascolta(
      archivio.osservaPartecipanti(id),
      (p) => _presenti = {for (final (x, _) in p) x.utenteId},
    );
    ascolta(archivio.osservaTassi(), (t) => _tassi = t);
    ascolta(archivio.osservaPreparato(id), (p) {
      _preparato = p;
      _preparatoLetto = true;
    });
    ascolta(archivio.osservaCopiaDelViaggio(id), (c) {
      _copia = c;
      _copiaLetta = true;
    });
    ascolta(servizi.documenti.osserva(id), (d) {
      _documenti = d;
      unawaited(_controllaFile(d));
    });
  }

  /// Guarda se i file dei documenti ci sono ancora: una volta per elenco.
  Future<void> _controllaFile(List<Documento> documenti) async {
    final chiave = [for (final d in documenti) d.id].join(',');
    if (chiave == _controllati) return;
    _controllati = chiave;
    final cartella = Servizi.of(context).documenti;
    final mancanti = <String>[];
    for (final d in documenti) {
      if (!await (await cartella.file(d)).exists()) mancanti.add(d.nome);
    }
    if (mounted && chiave == _controllati) {
      setState(() => _mancanti = mancanti);
    }
  }

  @override
  void dispose() {
    for (final a in _ascolti) {
      unawaited(a.cancel());
    }
    super.dispose();
  }

  Controllo? get _controllo {
    final (viaggio, giorni, tappe, voci, presenti, documenti, tassi) = (
      _viaggio,
      _giorni,
      _tappe,
      _voci,
      _presenti,
      _documenti,
      _tassi,
    );
    if (viaggio == null ||
        giorni == null ||
        tappe == null ||
        voci == null ||
        presenti == null ||
        documenti == null ||
        tassi == null ||
        !_preparatoLetto ||
        !_copiaLetta) {
      return null;
    }
    final io = Servizi.of(context).archivio.io ?? '';
    final ordineGiorni = {for (final (i, g) in giorni.indexed) g.id: i};
    // osservaTappe le dà già nell'ordine del giorno: qui si mettono in fila
    // i giorni, e a pari giorno resta quell'ordine.
    final senzaPosto =
        [
          for (final (i, t) in tappe.indexed)
            if (ordineGiorni.containsKey(t.giornoId) &&
                t.posto == null &&
                t.statoTappa == StatoTappa.daFare)
              (giorno: ordineGiorni[t.giornoId]!, i: i, tappa: t),
        ]..sort(
          (a, b) => a.giorno != b.giorno
              ? a.giorno.compareTo(b.giorno)
              : a.i.compareTo(b.i),
        );
    DateTime? tassiDel;
    for (final t in tassi) {
      final del = DateTime.tryParse(t.del);
      if (del != null && (tassiDel == null || del.isAfter(tassiDel))) {
        tassiDel = del;
      }
    }
    return Controllo(
      viaggio: viaggio,
      giorni: giorni,
      tappe: tappe,
      documenti: documenti,
      documentiMancanti: [
        for (final d in documenti)
          if (_mancanti.contains(d.nome)) d.nome,
      ],
      valigia: valigiaPrimaDiPartire([
        for (final v in voci)
          (
            testo: v.testo,
            spuntata: v.spuntata,
            personale: v.tipo == TipoLista.personale.codice,
            portaChi: chiLaPorta(v.assegnatoA, presenti),
            creataIl: v.creata,
          ),
      ], io: io),
      senzaPosto: [for (final x in senzaPosto) x.tappa],
      conAltri: presenti.length > 1,
      tassiDel: tassiDel,
      preparato: _preparato,
      copia: _copia,
    );
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _controllo);
}

/// L'ingresso a «Prima di partire» nel viaggio, sotto il biglietto (tela,
/// 92): da due giorni prima fino al giorno della partenza.
class IngressoPrimaDiPartire extends StatelessWidget {
  const IngressoPrimaDiPartire({
    super.key,
    required this.viaggioId,
    this.orologio = DateTime.now,
  });

  final String viaggioId;
  final DateTime Function() orologio;

  @override
  Widget build(BuildContext context) => ControlloPrimaDiPartire(
    viaggioId: viaggioId,
    builder: (context, controllo) {
      final testo = switch (controllo?.daGuardare) {
        null => 'Un giro di controllo prima della partenza.',
        0 => 'Tutto a posto: pronto anche senza rete.',
        1 => 'Un giro di controllo: una cosa da guardare.',
        final n => 'Un giro di controllo: $n cose da guardare.',
      };
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Premibile(
          onTap: () => apri<void>(
            context,
            SchermataPrimaDiPartire(viaggioId: viaggioId, orologio: orologio),
          ),
          scala: 0.98,
          etichetta: 'Prima di partire. $testo',
          child: ExcludeSemantics(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: Colori.bianco,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  _Quadretto(
                    icona: icona(
                      ios: CupertinoIcons.briefcase,
                      android: Icons.luggage_outlined,
                    ),
                    fondo: Colori.cobaltoChiaro,
                    colore: Colori.cobalto,
                    lato: 40,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Prima di partire',
                          style: Testi.evidenza.copyWith(
                            color: Colori.inchiostro,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          testo,
                          style: Testi.didascalia.copyWith(
                            color: Colori.grafite,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    icona(
                      ios: CupertinoIcons.chevron_right,
                      android: Icons.chevron_right_rounded,
                    ),
                    size: 16,
                    color: Colori.grafite,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// «Prima di partire» (09, regola 6; 02 §1; tela, 56 e 90): da due giorni
/// prima, un giro di controllo — i documenti sul telefono, la valigia, le
/// tappe senza un posto — e «Preparalo per l'uso senza rete», che scarica
/// l'ultima versione di tutto il viaggio e i tassi di cambio. Si legge anche
/// senza rete; preparare e cercare i posti la richiedono, e lo dicono prima.
class SchermataPrimaDiPartire extends StatefulWidget {
  const SchermataPrimaDiPartire({
    super.key,
    required this.viaggioId,
    this.orologio = DateTime.now,
  });

  final String viaggioId;
  final DateTime Function() orologio;

  @override
  State<SchermataPrimaDiPartire> createState() =>
      _SchermataPrimaDiPartireState();
}

class _SchermataPrimaDiPartireState extends State<SchermataPrimaDiPartire> {
  bool _inCorso = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(segnaAperturaSenzaRete(context, 'prima_di_partire'));
      }
    });
  }

  Future<void> _prepara(Controllo c) async {
    if (_inCorso) return;
    final servizi = Servizi.of(context);
    final giorni = giorniAllaPartenza(
      stato: c.viaggio.statoA(widget.orologio()),
      inizio: c.viaggio.inizio,
      oggi: widget.orologio(),
    );
    setState(() => _inCorso = true);
    try {
      await servizi.archivio.preparaViaggio(widget.viaggioId);
      await servizi.misurazione.registra(Eventi.viaggioPreparato, {
        'viaggio_id': widget.viaggioId,
        'giorni_alla_partenza': giorni,
      });
      if (!mounted) return;
      await apri<void>(
        context,
        SchermataProntoSenzaRete(
          viaggioId: widget.viaggioId,
          orologio: widget.orologio,
        ),
      );
    } on ErroreTrolley catch (e) {
      if (mounted) mostraMessaggio(context, e.messaggio, errore: true);
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) => ControlloPrimaDiPartire(
    viaggioId: widget.viaggioId,
    builder: (context, c) {
      if (c == null) {
        return const Pagina(corpo: Center(child: IndicatoreAttivita()));
      }
      final adesso = widget.orologio();
      final v = c.viaggio;
      final giorni =
          giorniAllaPartenza(
            stato: v.statoA(adesso),
            inizio: v.inizio,
            oggi: adesso,
          ) ??
          0;
      final inizio = v.inizio;
      final arrivo = v.arrivo;
      final quando = switch (giorni) {
        0 when arrivo != null => 'oggi, arrivi alle ${ora(arrivo)}',
        0 => 'oggi',
        1 when arrivo != null => 'domani, arrivi alle ${ora(arrivo)}',
        1 => 'domani',
        final n => 'fra $n giorni',
      };
      final quale = switch (giorni) {
        0 => 'oggi',
        1 => 'domani',
        _ when inizio != null => giornoDellaSettimana(inizio),
        _ => 'presto',
      };
      final righe = [
        _rigaDocumenti(context, c),
        _rigaValigia(context, c),
        if (c.tappe.isNotEmpty) _rigaTappe(context, c),
        _rigaSenzaRete(context, c),
      ];
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
                'Si parte $quale',
                sottotitolo: [
                  '${titoloViaggio(v)} · $quando.',
                  c.daGuardare == 0
                      ? 'Tutto a posto: il viaggio è pronto anche senza rete.'
                      : 'Un giro di controllo, e il viaggio è pronto anche '
                            'senza rete.',
                ].join(' '),
              ).entra(context),
              for (final (i, riga) in righe.indexed) ...[
                if (i > 0) const SizedBox(height: 8),
                riga.entra(context, ritardo: Ritmo.passo * (i + 1)),
              ],
            ],
          ),
        ),
      );
    },
  );

  Widget _rigaDocumenti(BuildContext context, Controllo c) {
    final n = c.documenti.length;
    if (n == 0) {
      return _Riga.daFare(
        icona: icona(
          ios: CupertinoIcons.doc_text,
          android: Icons.description_outlined,
        ),
        titolo: 'Documenti',
        testo:
            'Nessuno sul telefono. Biglietti, prenotazioni, assicurazione: '
            'qui si aprono anche senza rete.',
        azione: PulsantePiccolo(
          etichetta: 'Aggiungi un documento',
          onPressed: () => apriFoglio<void>(
            context,
            FoglioDocumento(viaggio: c.viaggio, giorni: c.giorni),
          ),
        ),
      );
    }
    final mancanti = c.documentiMancanti;
    if (mancanti.isNotEmpty) {
      return _Riga.problema(
        icona: icona(
          ios: CupertinoIcons.doc_text,
          android: Icons.description_outlined,
        ),
        titolo: 'Documenti',
        testo: mancanti.length == 1
            ? '«${mancanti.single}» non si apre più: il file non è su questo '
                  'telefono. Aggiungilo di nuovo.'
            : '${mancanti.length} non si aprono più: i file non sono su '
                  'questo telefono. Aggiungili di nuovo.',
        azione: PulsantePiccolo(
          etichetta: 'Apri i documenti',
          onPressed: () =>
              apri<void>(context, SchermataDocumenti(viaggioId: c.viaggio.id)),
        ),
      );
    }
    final nomi = [for (final d in c.documenti) d.nome];
    return _Riga.aPosto(
      titolo: 'Documenti',
      testo: n <= 3
          ? '${quanti(n, 'documento', 'documenti')} sul telefono: '
                '${elencoNomi(nomi)}.'
          : '$n sul telefono: ${nomi.take(2).join(', ')} e altri '
                '${n - 2}.',
    );
  }

  Widget _rigaValigia(BuildContext context, Controllo c) {
    final valigia = c.valigia;
    final apriLista = PulsantePiccolo(
      etichetta: 'Apri la lista',
      onPressed: () => apriCose(context, c.viaggio.id),
    );
    final diNessuno = valigia.diNessuno == 0
        ? null
        : valigia.diNessuno == 1
        ? 'Una voce della lista del viaggio non la porta nessuno.'
        : '${valigia.diNessuno} voci della lista del viaggio non le porta '
              'nessuno.';
    if (valigia.vuota) {
      return _Riga.daFare(
        icona: icona(
          ios: CupertinoIcons.briefcase,
          android: Icons.luggage_outlined,
        ),
        titolo: 'Cose da portare',
        testo: 'La lista è vuota: scrivi quello che non vuoi dimenticare.',
        azione: apriLista,
      );
    }
    if (valigia.fatta) {
      return _Riga.aPosto(
        titolo: 'Cose da portare',
        testo: valigia.tutte == 1
            ? 'L\'unica è in valigia.'
            : 'Tutte e ${valigia.tutte} in valigia.',
      );
    }
    final mancano = valigia.mancano;
    final quali = switch (mancano.length) {
      0 => null,
      1 => 'Manca ${mancano.single}.',
      <= 3 => 'Mancano ${elencoNomi(mancano)}.',
      final n => 'Mancano ${mancano.take(2).join(', ')} e altre ${n - 2}.',
    };
    return _Riga.daFare(
      icona: icona(ios: CupertinoIcons.clock, android: Icons.schedule_rounded),
      titolo: 'Cose da portare',
      testo: [
        if (valigia.tutte > 0)
          '${valigia.fatte} di ${valigia.tutte} in valigia.',
        ?quali,
        ?diNessuno,
      ].join(' '),
      azione: apriLista,
    );
  }

  Widget _rigaTappe(BuildContext context, Controllo c) {
    final senza = c.senzaPosto.length;
    if (senza == 0) {
      final n = c.tappe.length;
      return _Riga.aPosto(
        titolo: 'Le tappe',
        testo: n == 1
            ? 'L\'unica tappa ha un posto sulla mappa.'
            : 'Tutte e $n hanno un posto sulla mappa.',
      );
    }
    return ConLaRete(
      builder: (context, rete) => _Riga.problema(
        icona: icona(
          ios: CupertinoIcons.location,
          android: Icons.place_outlined,
        ),
        titolo: 'Tappe senza un posto',
        testo: [
          senza == 1
              ? 'Una tappa non si vedrà sulla mappa: aggiungi dov\'è.'
              : '$senza tappe non si vedranno sulla mappa: aggiungi dove '
                    'sono.',
          if (!rete) 'Per cercarlo serve la connessione.',
        ].join(' '),
        azione: PulsantePiccolo(
          etichetta: 'Sistemale',
          onPressed: rete
              ? () => apriFoglio<void>(
                  context,
                  FoglioTappeSenzaPosto(viaggioId: c.viaggio.id),
                )
              : null,
        ),
      ),
    );
  }

  Widget _rigaSenzaRete(BuildContext context, Controllo c) {
    final copia = c.copia;
    if (c.prontoSenzaRete) {
      return _Riga.aPosto(
        titolo: 'Pronto anche senza rete',
        testo: [
          if (copia != null)
            'Aggiornato ${quandoAggiornato(copia, widget.orologio())}.',
          'Con la rete si aggiorna da solo.',
        ].join(' '),
        azione: PulsantePiccolo(
          etichetta: 'Cosa c\'è sul telefono',
          onPressed: () => apri<void>(
            context,
            SchermataProntoSenzaRete(
              viaggioId: c.viaggio.id,
              orologio: widget.orologio,
            ),
          ),
        ),
      );
    }
    return ConLaRete(
      builder: (context, rete) => _Riga(
        icona: icona(
          ios: CupertinoIcons.arrow_down_to_line,
          android: Icons.download_rounded,
        ),
        fondo: Colori.cobaltoChiaro,
        colore: Colori.cobalto,
        titolo: 'Il viaggio per intero, senza rete',
        testo:
            'L\'ultima versione di tutto: i giorni, le spese, le liste, i '
            'tassi di cambio.',
        azione: PulsanteGrande(
          etichetta: 'Preparalo per l\'uso senza rete',
          colore: Colori.cobalto,
          icona: icona(
            ios: CupertinoIcons.arrow_down_to_line,
            android: Icons.download_rounded,
          ),
          inCorso: _inCorso,
          motivo: rete ? null : motivoSenzaRete,
          onPressed: () => _prepara(c),
        ),
      ),
    );
  }
}

/// Una riga del giro di controllo (tela, 56): l'icona nel suo quadretto,
/// che cosa, com'è, e se serve il gesto per sistemarla.
class _Riga extends StatelessWidget {
  const _Riga({
    required this.icona,
    required this.fondo,
    required this.colore,
    required this.titolo,
    required this.testo,
    this.azione,
  });

  /// A posto: la spunta verde.
  const _Riga.aPosto({required this.titolo, required this.testo, this.azione})
    : icona = Icons.check_rounded,
      fondo = Colori.menta,
      colore = Colori.verde;

  /// Da fare, ma non è un errore: in crema.
  const _Riga.daFare({
    required this.icona,
    required this.titolo,
    required this.testo,
    this.azione,
  }) : fondo = Colori.crema,
       colore = Colori.ocra;

  /// Qualcosa che senza rete o sulla mappa mancherà: in rosso.
  const _Riga.problema({
    required this.icona,
    required this.titolo,
    required this.testo,
    this.azione,
  }) : fondo = Colori.rosa,
       colore = Colori.pericolo;

  final IconData icona;
  final Color fondo;
  final Color colore;
  final String titolo;
  final String testo;
  final Widget? azione;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    decoration: BoxDecoration(
      color: Colori.bianco,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Quadretto(icona: icona, fondo: fondo, colore: colore),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  titolo,
                  style: Testi.evidenza.copyWith(color: Colori.inchiostro),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                testo,
                style: Testi.didascalia.copyWith(color: Colori.grafite),
              ),
              if (azione != null) ...[
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerLeft, child: azione),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

/// L'icona di una riga, nel quadretto colorato.
class _Quadretto extends StatelessWidget {
  const _Quadretto({
    required this.icona,
    required this.fondo,
    required this.colore,
    this.lato = 36,
  });

  final IconData icona;
  final Color fondo;
  final Color colore;
  final double lato;

  @override
  Widget build(BuildContext context) => Container(
    width: lato,
    height: lato,
    decoration: BoxDecoration(
      color: fondo,
      borderRadius: BorderRadius.circular(lato * 0.3),
    ),
    child: Icon(icona, size: 22, color: colore),
  );
}

/// «Tappe senza un posto» (tela, 91): quelle da fare che non si vedranno
/// sulla mappa, giorno per giorno. Toccandone una si cerca il posto in
/// «Dove?», e si salva subito; il foglio resta aperto per la prossima.
/// Cercare e salvare richiedono la rete: senza, lo dice prima.
class FoglioTappeSenzaPosto extends StatefulWidget {
  const FoglioTappeSenzaPosto({super.key, required this.viaggioId});

  final String viaggioId;

  @override
  State<FoglioTappeSenzaPosto> createState() => _FoglioTappeSenzaPostoState();
}

class _FoglioTappeSenzaPostoState extends State<FoglioTappeSenzaPosto> {
  /// La tappa che si sta salvando.
  String? _inCorso;

  Future<void> _cerca(Controllo c, Tappa tappa) async {
    if (_inCorso != null) return;
    final archivio = Servizi.of(context).archivio;
    final vicino = await centroDelViaggio(c.viaggio, c.tappe);
    if (!mounted) return;
    final scelta = await apriFoglio<SceltaLuogo>(
      context,
      FoglioLuogo(
        viaggioId: c.viaggio.id,
        iniziale: tappa.luogoNome ?? tappa.titolo,
        titolo: tappa.titolo,
        vicinoA: vicino?.centro,
        dalleTappe: vicino?.dalleTappe ?? false,
        cercaSubito: true,
      ),
    );
    if (scelta == null || !mounted) return;
    final posto = scelta.posto;
    // Senza un posto trovato non cambia niente per la mappa.
    if (posto == null) return;
    setState(() => _inCorso = tappa.id);
    try {
      await salvaOScegli(
        context,
        () => archivio.modificaTappa(tappa, {
          'luogo_nome': scelta.testo.trim().isEmpty ? null : scelta.testo,
          'lat': posto.lat,
          'lon': posto.lon,
        }),
      );
    } on ErroreTrolley catch (e) {
      if (mounted) mostraMessaggio(context, e.messaggio, errore: true);
    } finally {
      if (mounted) setState(() => _inCorso = null);
    }
  }

  @override
  Widget build(BuildContext context) => ControlloPrimaDiPartire(
    viaggioId: widget.viaggioId,
    builder: (context, c) => ConLaRete(
      builder: (context, rete) {
        final giorni = {for (final g in c?.giorni ?? const <Giorno>[]) g.id: g};
        final tappe = c?.senzaPosto ?? const <Tappa>[];
        return Foglio(
          titolo: 'Tappe senza un posto',
          children: [
            Text(
              tappe.isEmpty
                  ? 'Adesso hanno tutte un posto sulla mappa.'
                  : 'Non si vedono sulla mappa, e «Portami» non sa dove '
                        'andare. Tocca una tappa per cercare il posto.',
              style: Testi.secondario.copyWith(color: Colori.grafite),
            ),
            const SizedBox(height: 6),
            for (final t in tappe)
              _RigaSenzaPosto(
                tappa: t,
                giorno: giorni[t.giornoId]?.finestra.data,
                inCorso: _inCorso == t.id,
                onTap: rete && c != null ? () => _cerca(c, t) : null,
              ),
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                rete
                    ? 'Una tappa senza posto va bene lo stesso: resta nel '
                          'programma.'
                    : 'Una tappa senza posto va bene lo stesso: resta nel '
                          'programma. Per cercarlo serve la connessione.',
                style: Testi.didascalia.copyWith(color: Colori.grafite),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _RigaSenzaPosto extends StatelessWidget {
  const _RigaSenzaPosto({
    required this.tappa,
    required this.giorno,
    required this.inCorso,
    required this.onTap,
  });

  final Tappa tappa;
  final DateTime? giorno;
  final bool inCorso;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final g = giorno;
    final luogo = tappa.luogoNome?.trim();
    final sotto = luogo == null || luogo.isEmpty
        ? 'Nessun posto scritto'
        : '$luogo, scritto a mano';
    return Premibile(
      onTap: inCorso ? null : onTap,
      scala: 0.98,
      etichetta: [
        tappa.titolo,
        if (g != null) giornoBreve(g),
        sotto,
        'cerca dov\'è',
      ].join(', '),
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFFEEF0F4), width: 1.5),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                child: g == null
                    ? null
                    : Column(
                        children: [
                          Text(
                            '${g.day}',
                            style: Testi.numero.copyWith(
                              color: Colori.inchiostro,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            giornoDellaSettimana(g)
                                .substring(0, 3)
                                .toUpperCase(),
                            style: Testi.etichetta.copyWith(
                              color: Colori.grafite,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tappa.titolo,
                      style: Testi.evidenza.copyWith(color: Colori.inchiostro),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sotto,
                      style: Testi.didascalia.copyWith(color: Colori.grafite),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Opacity(
                opacity: onTap == null && !inCorso ? 0.4 : 1,
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colori.foschia,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: inCorso
                      ? const IndicatoreAttivita(piccolo: true)
                      : Text(
                          'Dove?',
                          style: Testi.secondario.copyWith(
                            color: Colori.cobaltoScuro,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// «Pronto anche senza rete» (tela, 57): che cosa c'è sul telefono, di
/// quando è, e che cosa resta della rete.
class SchermataProntoSenzaRete extends StatelessWidget {
  const SchermataProntoSenzaRete({
    super.key,
    required this.viaggioId,
    this.orologio = DateTime.now,
  });

  final String viaggioId;
  final DateTime Function() orologio;

  @override
  Widget build(BuildContext context) => ControlloPrimaDiPartire(
    viaggioId: viaggioId,
    builder: (context, c) {
      if (c == null) {
        return const Pagina(corpo: Center(child: IndicatoreAttivita()));
      }
      final adesso = orologio();
      final copia = c.copia;
      final g = c.giorni.length;
      final conIndirizzi = c.tappe.any(
        (t) => t.posto != null || (t.luogoNome?.trim().isNotEmpty ?? false),
      );
      final tassiDel = c.tassiDel;
      const cambio = 'tassi di cambio';
      final voci = [
        g == 1
            ? 'Il programma del giorno'
            : 'Il programma di tutti e $g i giorni',
        if (conIndirizzi) 'Gli indirizzi delle tappe',
        if (c.documenti.isNotEmpty) 'I documenti (sono già qui)',
        c.conAltri ? 'Le spese e i saldi' : 'Le spese',
        'Le cose da portare',
        if (tassiDel != null)
          'I ${quandoITassi(tassiDel, adesso).replaceFirst('tassi', cambio)}',
      ];
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
                'Pronto anche senza rete',
                sottotitolo: [
                  'Tutto il viaggio a ${titoloViaggio(c.viaggio)} è su questo '
                      'telefono',
                  if (copia != null)
                    ', aggiornato ${quandoAggiornato(copia, adesso)}',
                  '.',
                ].join(),
              ).entra(context),
              Container(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
                decoration: BoxDecoration(
                  color: Colori.bianco,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    for (final (i, voce) in voci.indexed)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: i == 0
                            ? null
                            : const BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                    color: Color(0xFFEEF0F4),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_rounded,
                              size: 20,
                              color: Colori.verde,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                voce,
                                style: Testi.secondario.copyWith(
                                  color: Colori.inchiostro,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ).entra(context, ritardo: Ritmo.passo),
              const SizedBox(height: 12),
              Avviso(
                icona: icona(
                  ios: CupertinoIcons.wifi_slash,
                  android: Icons.wifi_off_rounded,
                ),
                testo:
                    'Senza rete si legge tutto questo, e si registrano spese, '
                    'si segnano tappe, si spuntano voci, si aggiungono tappe: '
                    'partono quando torna. Con la rete la copia si aggiorna '
                    'da sola.',
              ).entra(context, ritardo: Ritmo.passo * 2),
              const SizedBox(height: 12),
              Avviso(
                icona: icona(
                  ios: CupertinoIcons.map,
                  android: Icons.map_outlined,
                ),
                testo:
                    'La mappa e la navigazione restano dalla rete: senza, si '
                    'aprono gli indirizzi nelle Mappe del telefono.',
              ).entra(context, ritardo: Ritmo.passo * 2),
            ],
          ),
        ),
      );
    },
  );
}
