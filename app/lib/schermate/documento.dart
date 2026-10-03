import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
import '../dominio/documenti.dart';
import '../servizi.dart';
import 'con_la_rete.dart';
import 'foglio_documento.dart';

/// Un documento a pieno schermo (07-documenti.md, "Documento"; tela, 12): su
/// fondo d'inchiostro, una pagina alla volta, da allargare con due dita o con
/// un doppio tocco. Si apre anche senza rete: il file è sul telefono.
///
/// Le pagine di un PDF le disegna il telefono in memoria, e restano in memoria
/// (03, regola 3).
class SchermataDocumento extends StatefulWidget {
  const SchermataDocumento({
    super.key,
    required this.viaggioId,
    required this.documentoId,
  });

  final String viaggioId;
  final String documentoId;

  @override
  State<SchermataDocumento> createState() => _SchermataDocumentoState();
}

/// Il file del documento non c'è: tolto da fuori, o un backup arrivato a metà.
class _FileMancante implements Exception {
  const _FileMancante();
}

class _SchermataDocumentoState extends State<SchermataDocumento> {
  late Stream<Documento?> _documento;
  late Stream<Viaggio?> _viaggio;
  late Stream<List<Giorno>> _giorni;
  Future<(File, int)>? _contenuto;
  final _pagine = PageController();
  int _attuale = 0;
  bool _ingrandita = false;
  bool _uscendo = false;
  bool _avviata = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_avviata) return;
    _avviata = true;
    final servizi = Servizi.of(context);
    _documento = servizi.documenti.osservaDocumento(widget.documentoId);
    _viaggio = servizi.archivio.osservaViaggio(widget.viaggioId);
    _giorni = servizi.archivio.osservaGiorni(widget.viaggioId);
  }

  @override
  void dispose() {
    _pagine.dispose();
    super.dispose();
  }

  /// Il file e quante pagine ha: si legge una volta.
  Future<(File, int)> _carica(Documento d) => _contenuto ??= () async {
    final c = context;
    final documenti = Servizi.of(c).documenti;
    final file = await documenti.file(d);
    if (!await file.exists()) {
      if (c.mounted) {
        unawaited(segnaAperturaSenzaRete(c, 'documento', mancante: 'documento'));
      }
      throw const _FileMancante();
    }
    if (c.mounted) unawaited(segnaAperturaSenzaRete(c, 'documento'));
    final pagine = d.formatoDocumento == FormatoDocumento.immagine
        ? 1
        : d.pagine ?? await documenti.telefono.pagine(file.path);
    return (file, math.max(1, pagine));
  }();

  void _esci() {
    if (_uscendo || !mounted) return;
    _uscendo = true;
    Navigator.of(context).maybePop();
  }

  Future<void> _altro(Documento d, Viaggio? viaggio, List<Giorno> giorni) =>
      scegliAzione(context, [
        if (viaggio != null)
          AzioneMenu(
            'Cambia nome, giorno o ora',
            () => apriFoglio<void>(
              context,
              FoglioDocumento(viaggio: viaggio, giorni: giorni, documento: d),
            ),
          ),
        AzioneMenu('Elimina', () => _elimina(d), pericolo: true),
      ]);

  Future<void> _elimina(Documento d) async {
    var conferma = false;
    await AdaptiveAlertDialog.show(
      context: context,
      title: 'Eliminare «${d.nome}»?',
      message:
          'Si cancella da questo telefono, e non ce n\'è una copia da nessun '
          'altra parte.',
      actions: [
        AlertAction(
          title: 'Annulla',
          style: AlertActionStyle.cancel,
          onPressed: () {},
        ),
        AlertAction(
          title: 'Elimina',
          style: AlertActionStyle.destructive,
          onPressed: () => conferma = true,
        ),
      ],
    );
    if (!conferma || !mounted) return;
    try {
      await Servizi.of(context).documenti.elimina(d);
      HapticFeedback.mediumImpact();
      _esci();
    } on ErroreTrolley catch (e) {
      if (mounted) mostraMessaggio(context, e.messaggio, errore: true);
    }
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Scaffold(
      backgroundColor: Colori.inchiostro,
      body: StreamBuilder<Documento?>(
        stream: _documento,
        builder: (context, documento) => StreamBuilder<Viaggio?>(
          stream: _viaggio,
          builder: (context, viaggio) => StreamBuilder<List<Giorno>>(
            stream: _giorni,
            builder: (context, giorni) {
              final d = documento.data;
              if (d == null) {
                // Eliminato, qui o altrove: non c'è più niente da guardare.
                if (documento.connectionState == ConnectionState.active) {
                  WidgetsBinding.instance.addPostFrameCallback((_) => _esci());
                }
                return const SizedBox.expand();
              }
              return _pagina(d, viaggio.data, giorni.data ?? const []);
            },
          ),
        ),
      ),
    ),
  );

  Widget _pagina(Documento d, Viaggio? viaggio, List<Giorno> giorni) {
    final mq = MediaQuery.of(context);
    final data = giorni.where((g) => g.id == d.giornoId).firstOrNull;
    final quando = quandoServe(
      data: data?.finestra.data,
      alle: d.momento,
      oggi: DateTime.now(),
    );
    return FutureBuilder<(File, int)>(
      future: _carica(d),
      builder: (context, contenuto) {
        final pagine = contenuto.data?.$2 ?? 1;
        return Stack(
          children: [
            Positioned.fill(
              child: switch (contenuto) {
                AsyncSnapshot(error: _FileMancante()) => _Mancante(
                  onElimina: () => _elimina(d),
                ),
                AsyncSnapshot(:final Object error) => _Messaggio(
                  error is ErroreTrolley
                      ? error.messaggio
                      : 'Questo documento non si riesce ad aprire.',
                ),
                AsyncSnapshot(data: (final file, final quante)) =>
                  PageView.builder(
                    controller: _pagine,
                    physics: _ingrandita
                        ? const NeverScrollableScrollPhysics()
                        : const PageScrollPhysics(),
                    itemCount: quante,
                    onPageChanged: (i) => setState(() {
                      _attuale = i;
                      _ingrandita = false;
                    }),
                    itemBuilder: (context, i) => _Pagina(
                      documento: d,
                      file: file,
                      indice: i,
                      pagine: quante,
                      margini: EdgeInsets.fromLTRB(
                        20,
                        mq.padding.top + 76,
                        20,
                        mq.padding.bottom + 72,
                      ),
                      onIngrandita: (si) {
                        if (si != _ingrandita) setState(() => _ingrandita = si);
                      },
                    ),
                  ),
                _ => const Center(
                  child: IndicatoreAttivita(colore: Colori.bianco),
                ),
              },
            ),
            Positioned(
              top: mq.padding.top + 8,
              left: 20,
              right: 20,
              child: Row(
                children: [
                  _PulsanteChiaro(
                    icona: icona(
                      ios: CupertinoIcons.xmark,
                      android: Icons.close_rounded,
                    ),
                    etichetta: 'Chiudi',
                    onPressed: _esci,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            d.nome,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: Testi.evidenza.copyWith(
                              color: Colori.bianco,
                              fontSize: 17,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          quando,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: Testi.didascalia.copyWith(
                            color: Colori.bianco.withValues(alpha: 0.72),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _PulsanteChiaro(
                    icona: icona(
                      ios: CupertinoIcons.ellipsis,
                      android: Icons.more_horiz_rounded,
                    ),
                    etichetta: 'Altro: cambia o elimina',
                    onPressed: () => _altro(d, viaggio, giorni),
                  ),
                ],
              ),
            ),
            if (contenuto.hasData)
              Positioned(
                left: 20,
                right: 20,
                bottom: mq.padding.bottom + 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (pagine > 1) ...[
                      _Puntini(pagine: pagine, attuale: _attuale),
                      const SizedBox(height: 10),
                    ],
                    Text(
                      pagine > 1
                          ? 'Scorri per la pagina dopo, allarga con due dita.'
                          : 'Allarga con due dita, o con un doppio tocco.',
                      textAlign: TextAlign.center,
                      style: Testi.didascalia.copyWith(
                        color: Colori.bianco.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Una pagina, da allargare: con due dita, o con un doppio tocco dove si
/// tocca. Allargata, scorrere la sposta invece di cambiare pagina.
class _Pagina extends StatefulWidget {
  const _Pagina({
    required this.documento,
    required this.file,
    required this.indice,
    required this.pagine,
    required this.margini,
    required this.onIngrandita,
  });

  final Documento documento;
  final File file;
  final int indice;
  final int pagine;
  final EdgeInsets margini;
  final ValueChanged<bool> onIngrandita;

  @override
  State<_Pagina> createState() => _PaginaState();
}

class _PaginaState extends State<_Pagina> {
  final _trasformazione = TransformationController();
  Future<Uint8List>? _disegno;
  Offset _doppioTocco = Offset.zero;
  bool _ingrandita = false;

  /// Quanto ingrandisce il doppio tocco.
  static const _ingrandimento = 2.5;

  @override
  void initState() {
    super.initState();
    _trasformazione.addListener(() {
      final si = _trasformazione.value.getMaxScaleOnAxis() > 1.01;
      if (si == _ingrandita) return;
      _ingrandita = si;
      widget.onIngrandita(si);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_disegno != null ||
        widget.documento.formatoDocumento != FormatoDocumento.pdf) {
      return;
    }
    // Una volta e mezza lo schermo: si legge un codice anche allargando.
    final mq = MediaQuery.of(context);
    final larghezza = math.min(
      3000,
      (mq.size.width * mq.devicePixelRatio * 1.5).round(),
    );
    _disegno = Servizi.of(context).documenti.telefono.pagina(
      widget.file.path,
      indice: widget.indice,
      larghezza: larghezza,
    );
  }

  @override
  void dispose() {
    _trasformazione.dispose();
    super.dispose();
  }

  void _allargaOStringi() {
    if (_ingrandita) {
      _trasformazione.value = Matrix4.identity();
      return;
    }
    final p = _doppioTocco;
    _trasformazione.value = Matrix4.identity()
      ..translateByDouble(
        -p.dx * (_ingrandimento - 1),
        -p.dy * (_ingrandimento - 1),
        0,
        1,
      )
      ..scaleByDouble(_ingrandimento, _ingrandimento, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    final etichetta = widget.pagine > 1
        ? '${widget.documento.nome}, pagina ${widget.indice + 1} di '
              '${widget.pagine}'
        : widget.documento.nome;
    final Widget foglio = switch (widget.documento.formatoDocumento) {
      FormatoDocumento.immagine => _Foglio(
        child: Image.file(
          widget.file,
          fit: BoxFit.contain,
          semanticLabel: etichetta,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) =>
              const _Messaggio('Questa immagine non si riesce a mostrare.'),
        ),
      ),
      FormatoDocumento.pdf => FutureBuilder<Uint8List>(
        future: _disegno,
        builder: (context, pagina) => switch (pagina) {
          AsyncSnapshot(:final Uint8List data) => _Foglio(
            child: Image.memory(
              data,
              fit: BoxFit.contain,
              semanticLabel: etichetta,
              gaplessPlayback: true,
            ),
          ),
          AsyncSnapshot(hasError: true) => const _Messaggio(
            'Questa pagina non si riesce a mostrare.',
          ),
          _ => const IndicatoreAttivita(colore: Colori.bianco),
        },
      ),
    };
    return GestureDetector(
      onDoubleTapDown: (dettagli) => _doppioTocco = dettagli.localPosition,
      onDoubleTap: _allargaOStringi,
      child: InteractiveViewer(
        transformationController: _trasformazione,
        minScale: 1,
        maxScale: 6,
        child: SizedBox.expand(
          child: Padding(
            padding: widget.margini,
            child: Center(child: foglio),
          ),
        ),
      ),
    );
  }
}

/// Il foglio: gli angoli appena tondi e un'ombra, sul fondo d'inchiostro.
class _Foglio extends StatelessWidget {
  const _Foglio({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF000000).withValues(alpha: 0.35),
          blurRadius: 40,
          offset: const Offset(0, 18),
        ),
      ],
    ),
    child: ClipRRect(borderRadius: BorderRadius.circular(10), child: child),
  );
}

/// Il pulsante quadrato in alto, sul fondo d'inchiostro.
class _PulsanteChiaro extends StatelessWidget {
  const _PulsanteChiaro({
    required this.icona,
    required this.etichetta,
    required this.onPressed,
  });

  final IconData icona;
  final String etichetta;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Premibile(
    onTap: onPressed,
    scala: 0.92,
    etichetta: etichetta,
    child: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colori.bianco.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icona, size: 22, color: Colori.bianco),
    ),
  );
}

/// A che pagina si è: un trattino lungo per quella attuale. Oltre le otto
/// pagine, i numeri.
class _Puntini extends StatelessWidget {
  const _Puntini({required this.pagine, required this.attuale});

  final int pagine;
  final int attuale;

  @override
  Widget build(BuildContext context) {
    final testo = 'Pagina ${attuale + 1} di $pagine';
    if (pagine > 8) {
      return Text(
        testo,
        style: Testi.pillola.copyWith(color: Colori.bianco),
      );
    }
    return Semantics(
      label: testo,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < pagine; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            AnimatedContainer(
              duration: Ritmo.breve,
              width: i == attuale ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: Colori.bianco.withValues(
                  alpha: i == attuale ? 1 : 0.35,
                ),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Messaggio extends StatelessWidget {
  const _Messaggio(this.testo);

  final String testo;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        testo,
        textAlign: TextAlign.center,
        style: Testi.corpo.copyWith(color: Colori.bianco),
      ),
    ),
  );
}

/// Il file non c'è più: lo si dice, e si può togliere il documento
/// dall'elenco.
class _Mancante extends StatelessWidget {
  const _Mancante({required this.onElimina});

  final VoidCallback onElimina;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Il file di questo documento non è più su questo telefono.',
            textAlign: TextAlign.center,
            style: Testi.corpo.copyWith(color: Colori.bianco),
          ),
          const SizedBox(height: 20),
          PulsanteGrande(
            etichetta: 'Toglilo dall\'elenco',
            secondario: true,
            pericolo: true,
            onPressed: onElimina,
          ),
        ],
      ),
    ),
  );
}
