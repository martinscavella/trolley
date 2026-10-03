import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../aspetto/elementi.dart';
import '../aspetto/formati.dart';
import '../aspetto/miniatura.dart';
import '../aspetto/movimento.dart';
import '../aspetto/pagina.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../dati/database.dart';
import '../dati/lettura.dart';
import '../dominio/documenti.dart';
import '../servizi.dart';
import 'con_la_rete.dart';
import 'documento.dart';
import 'foglio_documento.dart';

/// I documenti del viaggio (07-documenti.md, "Documenti del viaggio"; tela,
/// 11): per primi quelli di oggi, poi di domani, poi tutto il viaggio e gli
/// altri giorni, i giorni passati in fondo (regola 5).
///
/// Stanno solo su questo telefono, e qui si fa tutto anche senza rete: la rete
/// non c'entra. In un viaggio con altri lo dice, perché un elenco senza i
/// documenti dei compagni non sembri un errore (casi limite).
class SchermataDocumenti extends StatefulWidget {
  const SchermataDocumenti({super.key, required this.viaggioId});

  final String viaggioId;

  @override
  State<SchermataDocumenti> createState() => _SchermataDocumentiState();
}

class _SchermataDocumentiState extends State<SchermataDocumenti> {
  late Stream<Viaggio?> _viaggio;
  late Stream<List<Giorno>> _giorni;
  late Stream<List<Documento>> _documenti;
  late Stream<List<(Partecipazione, Utente?)>> _partecipanti;
  bool _codiceDiSblocco = true;
  bool _avviata = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_avviata) return;
    _avviata = true;
    final servizi = Servizi.of(context);
    _viaggio = servizi.archivio.osservaViaggio(widget.viaggioId);
    _giorni = servizi.archivio.osservaGiorni(widget.viaggioId);
    _documenti = servizi.documenti.osserva(widget.viaggioId);
    _partecipanti = servizi.archivio.osservaPartecipanti(widget.viaggioId);
    servizi.documenti.telefono.haCodiceDiSblocco().then((si) {
      if (mounted && !si) setState(() => _codiceDiSblocco = false);
    });
    unawaited(segnaAperturaSenzaRete(context, 'documenti'));
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<Viaggio?>(
    stream: _viaggio,
    builder: (context, viaggio) => StreamBuilder<List<Giorno>>(
      stream: _giorni,
      builder: (context, giorni) => StreamBuilder<List<Documento>>(
        stream: _documenti,
        builder: (context, documenti) =>
            StreamBuilder<List<(Partecipazione, Utente?)>>(
              stream: _partecipanti,
              builder: (context, partecipanti) {
                final (v, g, d) = (viaggio.data, giorni.data, documenti.data);
                if (v == null || g == null || d == null) {
                  return const Pagina(
                    corpo: Center(child: IndicatoreAttivita()),
                  );
                }
                return _pagina(v, g, d, partecipanti.data ?? const []);
              },
            ),
      ),
    ),
  );

  Widget _pagina(
    Viaggio viaggio,
    List<Giorno> giorni,
    List<Documento> documenti,
    List<(Partecipazione, Utente?)> partecipanti,
  ) {
    final oggi = DateTime.now();
    final gruppi = raggruppaPerElenco(documenti, giorni, oggi);
    final io = Servizi.of(context).documenti.io;
    final compagni = [
      for (final (p, u) in partecipanti)
        if (p.utenteId != io) u?.nome ?? '',
    ];
    final (inizio, fine) = (viaggio.inizio, viaggio.fine);
    final sotto = [
      titoloViaggio(viaggio),
      if (inizio != null && fine != null) intervalloDate(inizio, fine),
    ].join(' · ');

    Future<void> aggiungi() => apriFoglio<void>(
      context,
      FoglioDocumento(viaggio: viaggio, giorni: giorni),
    );

    return Pagina(
      azioni: [
        PulsanteTondo(
          icona: Icons.add_rounded,
          etichetta: 'Aggiungi un documento',
          onPressed: aggiungi,
        ),
      ],
      inBasso: PulsanteGrande(
        etichetta: 'Aggiungi un documento',
        icona: Icons.add_rounded,
        onPressed: aggiungi,
      ),
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
                      'Documenti',
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
            if (!_codiceDiSblocco)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Avviso(
                  errore: true,
                  icona: icona(
                    ios: CupertinoIcons.lock_open,
                    android: Icons.lock_open_rounded,
                  ),
                  inizio: 'Il telefono non ha un codice di sblocco.',
                  testo:
                      'Senza, chi lo trova apre anche i documenti. Si mette '
                      'da Impostazioni › Face ID e codice.',
                ),
              ),
            if (documenti.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: _Vuoto(onAggiungi: aggiungi),
              ).entra(context, ritardo: Ritmo.passo),
            for (final (i, gruppo) in gruppi.indexed) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
                child: Semantics(
                  header: true,
                  child: Text(
                    titoloGruppo(gruppo.tipo, gruppo.data),
                    style: Testi.sezione.copyWith(
                      color: gruppo.tipo == TipoGruppo.oggi
                          ? Colori.cobalto
                          : Colori.grafite,
                    ),
                  ),
                ),
              ),
              for (final (j, d) in gruppo.documenti.indexed) ...[
                if (j > 0) const SizedBox(height: 8),
                RigaDocumento(
                  documento: d,
                  giornoUscito:
                      d.giornoId != null &&
                      !giorni.any((g) => g.id == d.giornoId),
                  passato: gruppo.tipo == TipoGruppo.passato,
                ),
              ],
            ].map((w) => w.entra(context, ritardo: Ritmo.passo * (i + 1))),
            if (compagni.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Avviso(
                  icona: icona(
                    ios: CupertinoIcons.device_phone_portrait,
                    android: Icons.smartphone_rounded,
                  ),
                  inizio: 'Solo tuoi, solo su questo telefono.',
                  testo:
                      '${elencoNomi(compagni)} non li vedono, e i loro restano '
                      'sui loro telefoni.',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// I gruppi dell'elenco dai documenti e dai giorni del viaggio.
List<GruppoDocumenti<Documento>> raggruppaPerElenco(
  List<Documento> documenti,
  List<Giorno> giorni,
  DateTime oggi,
) => raggruppaDocumenti<Documento>(
  documenti: documenti,
  giornoDi: (d) => d.giornoId,
  oraDi: (d) => d.momento,
  creatoDi: (d) => d.creatoIl,
  giorni: {for (final g in giorni) g.id: g.finestra.data},
  oggi: oggi,
);

/// `Marco`, `Marco e Giulia`, `Marco, Giulia e Luca`; oltre i tre, "Gli altri
/// del viaggio".
String elencoNomi(List<String> nomi) {
  final validi = [
    for (final n in nomi)
      if (n.trim().isNotEmpty) n.trim(),
  ];
  if (validi.isEmpty || validi.length > 3) return 'Gli altri del viaggio';
  if (validi.length == 1) return validi.single;
  return '${validi.sublist(0, validi.length - 1).join(', ')} e ${validi.last}';
}

/// Apre un documento a pieno schermo.
Future<void> apriDocumento(BuildContext context, Documento documento) =>
    apriAPienoSchermo<void>(
      context,
      SchermataDocumento(
        viaggioId: documento.viaggioId,
        documentoId: documento.id,
      ),
    );

/// Un documento nell'elenco (tela, 10 e 11): la miniatura della prima pagina,
/// il nome, che cos'è, e a destra l'ora se ce l'ha. Un tocco lo apre.
class RigaDocumento extends StatelessWidget {
  const RigaDocumento({
    super.key,
    required this.documento,
    this.giornoUscito = false,
    this.passato = false,
  });

  final Documento documento;

  /// Il suo giorno non fa più parte del viaggio: le date si sono spostate.
  final bool giornoUscito;

  /// Di un giorno già passato: più chiaro.
  final bool passato;

  @override
  Widget build(BuildContext context) {
    final d = documento;
    final dettaglio = [
      dettaglioDocumento(
        formato: d.formatoDocumento,
        sorgente: d.sorgenteDocumento,
        pagine: d.pagine,
      ),
      if (giornoUscito) 'il suo giorno non c\'è più',
    ].join(' · ');
    final alle = d.momento;
    return Premibile(
      onTap: () => apriDocumento(context, d),
      scala: 0.98,
      etichetta: [d.nome, dettaglio, if (alle != null) 'alle ${ora(alle)}']
          .join(', '),
      child: ExcludeSemantics(
        child: Opacity(
          opacity: passato ? 0.6 : 1,
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
            decoration: BoxDecoration(
              color: Colori.bianco,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                AnteprimaDocumento(documento: d),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.nome,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Testi.evidenza.copyWith(
                          color: Colori.inchiostro,
                        ),
                      ),
                      Text(
                        dettaglio,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Testi.didascalia.copyWith(
                          color: Colori.grafite,
                        ),
                      ),
                    ],
                  ),
                ),
                if (alle != null) ...[
                  const SizedBox(width: 10),
                  Text(
                    ora(alle),
                    style: Testi.numero.copyWith(
                      color: Colori.inchiostro,
                      fontSize: 15,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// La prima pagina di un documento in miniatura. Un PDF lo disegna il
/// telefono, in memoria; un'immagine si legge dal file, ridotta.
class AnteprimaDocumento extends StatefulWidget {
  const AnteprimaDocumento({
    super.key,
    required this.documento,
    this.larghezza = 40,
    this.altezza = 52,
  });

  final Documento documento;
  final double larghezza;
  final double altezza;

  @override
  State<AnteprimaDocumento> createState() => _AnteprimaDocumentoState();
}

class _AnteprimaDocumentoState extends State<AnteprimaDocumento> {
  Future<ImageProvider>? _immagine;
  String? _di;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _carica();
  }

  @override
  void didUpdateWidget(AnteprimaDocumento vecchio) {
    super.didUpdateWidget(vecchio);
    _carica();
  }

  void _carica() {
    final d = widget.documento;
    if (_di == d.id) return;
    _di = d.id;
    final documenti = Servizi.of(context).documenti;
    final pixel =
        (widget.larghezza * MediaQuery.devicePixelRatioOf(context)).round();
    _immagine = d.formatoDocumento == FormatoDocumento.pdf
        ? documenti
              .anteprima(d, larghezza: pixel)
              .then<ImageProvider>((byte) => MemoryImage(byte))
        : documenti.file(d).then<ImageProvider>(
            (f) => ResizeImage(FileImage(f), width: pixel),
          );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ImageProvider>(
    future: _immagine,
    builder: (context, immagine) => MiniaturaDocumento(
      immagine: immagine.data,
      larghezza: widget.larghezza,
      altezza: widget.altezza,
    ),
  );
}

/// Un file appena arrivato, in miniatura, prima di essere un documento.
class AnteprimaFile extends StatefulWidget {
  const AnteprimaFile({
    super.key,
    required this.percorso,
    required this.formato,
    this.larghezza = 52,
    this.altezza = 68,
  });

  final String percorso;
  final FormatoDocumento formato;
  final double larghezza;
  final double altezza;

  @override
  State<AnteprimaFile> createState() => _AnteprimaFileState();
}

class _AnteprimaFileState extends State<AnteprimaFile> {
  Future<Uint8List>? _pagina;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pagina != null || widget.formato != FormatoDocumento.pdf) return;
    _pagina = Servizi.of(context).documenti.telefono.pagina(
      widget.percorso,
      indice: 0,
      larghezza: (widget.larghezza * MediaQuery.devicePixelRatioOf(context))
          .round(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pixel =
        (widget.larghezza * MediaQuery.devicePixelRatioOf(context)).round();
    if (widget.formato == FormatoDocumento.immagine) {
      return MiniaturaDocumento(
        immagine: ResizeImage(FileImage(File(widget.percorso)), width: pixel),
        larghezza: widget.larghezza,
        altezza: widget.altezza,
      );
    }
    return FutureBuilder<Uint8List>(
      future: _pagina,
      builder: (context, pagina) => MiniaturaDocumento(
        immagine: pagina.data == null ? null : MemoryImage(pagina.data!),
        larghezza: widget.larghezza,
        altezza: widget.altezza,
      ),
    );
  }
}

/// Nessun documento ancora.
class _Vuoto extends StatelessWidget {
  const _Vuoto({required this.onAggiungi});

  final VoidCallback onAggiungi;

  @override
  Widget build(BuildContext context) => Pannello(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MiniaturaDocumento(immagine: null),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            'Biglietti, prenotazioni, passaporto: tienili qui. Si aprono '
            'anche senza rete, e restano solo su questo telefono.',
            style: Testi.secondario.copyWith(color: Colori.grafite),
          ),
        ),
      ],
    ),
  );
}

/// I documenti nella schermata del viaggio (tela, 10): quelli di oggi, o i
/// prossimi, a un tocco (07, regola 6), e il passaggio all'elenco intero.
class SezioneDocumenti extends StatefulWidget {
  const SezioneDocumenti({super.key, required this.viaggio});

  final Viaggio viaggio;

  @override
  State<SezioneDocumenti> createState() => _SezioneDocumentiState();
}

class _SezioneDocumentiState extends State<SezioneDocumenti> {
  late Stream<List<Giorno>> _giorni;
  late Stream<List<Documento>> _documenti;
  bool _avviata = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_avviata) return;
    _avviata = true;
    final servizi = Servizi.of(context);
    _giorni = servizi.archivio.osservaGiorni(widget.viaggio.id);
    _documenti = servizi.documenti.osserva(widget.viaggio.id);
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Giorno>>(
    stream: _giorni,
    builder: (context, giorni) => StreamBuilder<List<Documento>>(
      stream: _documenti,
      builder: (context, documenti) {
        final elenco = documenti.data ?? const <Documento>[];
        final g = giorni.data ?? const <Giorno>[];
        final inVista = documentiDaTenereInVista(
          raggruppaPerElenco(elenco, g, DateTime.now()),
        );
        void tutti() => apri<void>(
          context,
          SchermataDocumenti(viaggioId: widget.viaggio.id),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(child: TitoloSezione('Documenti')),
                if (elenco.isNotEmpty)
                  Premibile(
                    onTap: tutti,
                    etichetta: 'Tutti i documenti, ${elenco.length}',
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 4, 8),
                      child: Text(
                        'Tutti · ${elenco.length}',
                        style: Testi.secondario.copyWith(
                          color: Colori.cobaltoScuro,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (elenco.isEmpty)
              Pannello(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Biglietti, prenotazioni, passaporto: tienili qui. Si '
                      'aprono anche senza rete.',
                      style: Testi.secondario.copyWith(color: Colori.grafite),
                    ),
                    const SizedBox(height: 10),
                    PulsantePiccolo(
                      etichetta: 'Aggiungi un documento',
                      onPressed: () => apriFoglio<void>(
                        context,
                        FoglioDocumento(viaggio: widget.viaggio, giorni: g),
                      ),
                    ),
                  ],
                ),
              )
            else
              for (final (i, d) in inVista.indexed) ...[
                if (i > 0) const SizedBox(height: 8),
                RigaDocumento(documento: d),
              ],
          ],
        );
      },
    ),
  );
}
