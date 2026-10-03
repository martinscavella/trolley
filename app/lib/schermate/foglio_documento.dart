import 'dart:async';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../aspetto/elementi.dart';
import '../aspetto/formati.dart';
import '../aspetto/movimento.dart';
import '../aspetto/pagina.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../dati/acquisizione.dart';
import '../dati/database.dart';
import '../dati/errori.dart';
import '../dati/lettura.dart';
import '../dominio/documenti.dart';
import '../servizi.dart';
import 'documenti.dart';
import 'gesti_documento.dart';

/// Un documento nuovo, o da cambiare (07-documenti.md, "Aggiungi documento";
/// tela, 13 e 14). Prima da dove arriva — la scansione, le foto, i file —,
/// poi come si chiama e quando serve: un giorno, con l'ora se si vuole, o
/// tutto il viaggio (regola 4).
///
/// Tutto senza rete: il documento resta sul telefono. Il primo dice, una volta
/// sola, che cosa vuol dire (regola 7).
class FoglioDocumento extends StatefulWidget {
  const FoglioDocumento({
    super.key,
    required this.viaggio,
    required this.giorni,
    this.documento,
    this.giornoId,
  });

  final Viaggio viaggio;

  /// I giorni del viaggio, in ordine.
  final List<Giorno> giorni;

  /// Il documento da cambiare; `null` per uno nuovo.
  final Documento? documento;

  /// Il giorno proposto per uno nuovo; nessuno vuol dire tutto il viaggio.
  final String? giornoId;

  @override
  State<FoglioDocumento> createState() => _FoglioDocumentoState();
}

class _FoglioDocumentoState extends State<FoglioDocumento> {
  late final _nome = TextEditingController(text: widget.documento?.nome);
  late String? _giornoId = _valido(
    widget.documento?.giornoId ?? widget.giornoId,
  );
  late Duration? _ora = widget.documento?.momento;

  /// Il file appena arrivato, per un documento nuovo.
  FileAcquisito? _arrivato;
  int? _pagineArrivate;
  bool _acquisendo = false;
  bool _inCorso = false;

  /// Finché non si sa, l'avviso non compare: meglio che lampeggiare.
  bool _avvisoGiaDato = true;

  /// Qualcosa è arrivato: chiudendo, le copie temporanee si buttano.
  bool _daPulire = false;
  late Acquisizione _acquisizione;
  bool _avviato = false;

  bool get _nuovo => widget.documento == null;

  String? _valido(String? id) =>
      widget.giorni.any((g) => g.id == id) ? id : null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_avviato) return;
    _avviato = true;
    final servizi = Servizi.of(context);
    _acquisizione = servizi.acquisizione;
    if (_nuovo) {
      servizi.documenti.avvisoGiaDato().then((gia) {
        if (mounted && gia != _avvisoGiaDato) {
          setState(() => _avvisoGiaDato = gia);
        }
      });
    }
  }

  @override
  void dispose() {
    _nome.dispose();
    if (_daPulire) unawaited(_acquisizione.pulisci());
    super.dispose();
  }

  Future<void> _acquisisci(Sorgente sorgente) async {
    if (_acquisendo) return;
    final telefono = Servizi.of(context).documenti.telefono;
    setState(() => _acquisendo = true);
    try {
      final arrivato = await _acquisizione.acquisisci(sorgente);
      _daPulire = true;
      if (arrivato == null || !mounted) return;
      final formato = arrivato.formato;
      if (formato == null) {
        throw const ErroreTrolley(
          'Questo file non si può aggiungere: servono un PDF o un\'immagine.',
        );
      }
      // Un PDF con la password si scopre adesso, non dopo aver scritto il nome.
      final pagine = formato == FormatoDocumento.pdf
          ? await telefono.pagine(arrivato.percorso)
          : null;
      if (!mounted) return;
      setState(() {
        _arrivato = arrivato;
        _pagineArrivate = pagine;
        if (_nome.text.trim().isEmpty) {
          _nome.text = nomeProposto(arrivato.nome) ?? '';
        }
      });
    } on ErroreTrolley catch (e) {
      if (mounted) mostraMessaggio(context, e.messaggio, errore: true);
    } finally {
      if (mounted) setState(() => _acquisendo = false);
    }
  }

  Future<void> _scegliOra() async {
    final attuale = _ora ?? const Duration(hours: 9);
    final scelta = await AdaptiveTimePicker.show(
      context: context,
      initialTime: TimeOfDay(
        hour: attuale.inHours % 24,
        minute: attuale.inMinutes % 60,
      ),
      use24HourFormat: true,
      minuteInterval: 5,
    );
    if (scelta != null && mounted) {
      setState(
        () => _ora = Duration(hours: scelta.hour, minutes: scelta.minute),
      );
    }
  }

  /// Perché non si può ancora salvare; `null` se si può.
  String? get _motivo =>
      _nome.text.trim().isEmpty ? 'Dagli un nome, per ritrovarlo' : null;

  Future<void> _salva() async {
    final nome = _nome.text.trim();
    final giornoId = _giornoId;
    final alle = giornoId == null ? null : _ora;
    setState(() => _inCorso = true);
    try {
      final documento = widget.documento;
      if (documento == null) {
        await aggiungiIlDocumento(
          context,
          viaggio: widget.viaggio,
          giornoId: giornoId,
          ora: alle,
          nome: nome,
          sorgente: _arrivato!,
        );
      } else {
        await Servizi.of(
          context,
        ).documenti.modifica(documento, nome: nome, giornoId: giornoId, ora: alle);
      }
      if (mounted) Navigator.of(context).pop();
    } on ErroreTrolley catch (e) {
      if (mounted) mostraMessaggio(context, e.messaggio, errore: true);
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dettagli = !_nuovo || _arrivato != null;
    final motivo = _motivo;
    return Foglio(
      titolo: _nuovo ? 'Nuovo documento' : 'Il documento',
      inBasso: dettagli
          ? AzioniFoglio(
              motivo: motivo,
              azione: PulsanteGrande(
                etichetta: 'Salva',
                inCorso: _inCorso,
                onPressed: motivo == null ? _salva : null,
              ),
            )
          : const PulsanteAnnulla(),
      children: dettagli ? _dettagli() : _sorgenti(),
    );
  }

  List<Widget> _sorgenti() => [
    Text(
      'Resta solo su questo telefono, e si apre anche senza rete.',
      style: Testi.corpo.copyWith(color: Colori.grafite, fontSize: 15),
    ),
    const SizedBox(height: 16),
    _Sorgente(
      icona: icona(
        ios: CupertinoIcons.doc_text_viewfinder,
        android: Icons.document_scanner_outlined,
      ),
      titolo: 'Scansiona',
      testo: 'Con la fotocamera: il foglio si raddrizza da solo.',
      onTap: _acquisendo ? null : () => _acquisisci(Sorgente.scansione),
    ),
    const SizedBox(height: 10),
    _Sorgente(
      icona: icona(ios: CupertinoIcons.photo, android: Icons.photo_outlined),
      titolo: 'Dalle foto',
      testo: 'Lo screenshot di un biglietto, la foto di un documento.',
      onTap: _acquisendo ? null : () => _acquisisci(Sorgente.foto),
    ),
    const SizedBox(height: 10),
    _Sorgente(
      icona: icona(
        ios: CupertinoIcons.folder,
        android: Icons.folder_open_outlined,
      ),
      titolo: 'Dai file',
      testo: 'Un PDF arrivato per email o salvato in File.',
      onTap: _acquisendo ? null : () => _acquisisci(Sorgente.file),
    ),
  ];

  List<Widget> _dettagli() {
    final documento = widget.documento;
    final arrivato = _arrivato;
    final Widget anteprima;
    final String cosa;
    final String sotto;
    if (documento != null) {
      anteprima = AnteprimaDocumento(
        documento: documento,
        larghezza: 52,
        altezza: 68,
      );
      cosa = dettaglioDocumento(
        formato: documento.formatoDocumento,
        sorgente: documento.sorgenteDocumento,
        pagine: documento.pagine,
      );
      sotto =
          'Su questo telefono dal ${dataEstesa(documento.creatoIl.toLocal())}';
    } else {
      final formato = arrivato!.formato!;
      anteprima = AnteprimaFile(percorso: arrivato.percorso, formato: formato);
      cosa = dettaglioDocumento(
        formato: formato,
        sorgente: arrivato.sorgente,
        pagine: _pagineArrivate,
      );
      sotto = arrivato.sorgente == Sorgente.scansione
          ? 'Appena fatta, raddrizzata'
          : arrivato.nome ?? '';
    }
    return [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colori.foschia,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            anteprima,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cosa,
                    style: Testi.evidenza.copyWith(color: Colori.inchiostro),
                  ),
                  if (sotto.isNotEmpty)
                    Text(
                      sotto,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Testi.didascalia.copyWith(color: Colori.grafite),
                    ),
                ],
              ),
            ),
            if (documento == null) ...[
              const SizedBox(width: 8),
              PulsantePiccolo(
                etichetta: arrivato?.sorgente == Sorgente.scansione
                    ? 'Rifai'
                    : 'Cambia',
                onPressed: _inCorso
                    ? null
                    : () => setState(() => _arrivato = null),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 16),
      Campo(
        controller: _nome,
        etichetta: 'Come lo chiami?',
        segnaposto: 'Es. Carta d\'imbarco',
        maiuscole: TextCapitalization.sentences,
        fuoco: _nuovo && _nome.text.isEmpty,
        onCambia: (_) => setState(() {}),
      ),
      const SizedBox(height: 16),
      const _Etichetta('Quando serve?'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          Gettone(
            etichetta: 'Tutto il viaggio',
            scelto: _giornoId == null,
            onTap: () => setState(() => _giornoId = null),
          ),
          for (final g in widget.giorni)
            Gettone(
              etichetta: giornoCorto(g.finestra.data),
              scelto: g.id == _giornoId,
              onTap: () => setState(() => _giornoId = g.id),
            ),
        ],
      ),
      AnimatedSize(
        duration: Ritmo.medio,
        curve: Ritmo.curva,
        alignment: Alignment.topCenter,
        child: _giornoId == null
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.only(top: 16),
                child: CampoScelta(
                  etichetta: 'A che ora?',
                  simbolo: icona(
                    ios: CupertinoIcons.clock,
                    android: Icons.schedule_rounded,
                  ),
                  segnaposto: 'Facoltativa',
                  valore: _ora == null ? null : ora(_ora!),
                  onTap: _scegliOra,
                  onCancella: () => setState(() => _ora = null),
                ),
              ),
      ),
      if (_nuovo && !_avvisoGiaDato) ...[
        const SizedBox(height: 16),
        Avviso(
          fondo: Colori.foschia,
          icona: icona(
            ios: CupertinoIcons.device_phone_portrait,
            android: Icons.smartphone_rounded,
          ),
          inizio: 'Resta solo su questo telefono.',
          testo:
              '${suIOS ? 'Il backup di iCloud' : 'Il backup del telefono'} lo '
              'porta su quello nuovo; senza backup, se perdi il telefono lo '
              'perdi. E se disinstalli Trolley se ne va con l\'app.',
        ),
      ],
    ];
  }
}

/// Una sorgente (tela, 13): l'icona in un quadrato bianco, il nome, una riga
/// che dice cosa aspettarsi.
class _Sorgente extends StatelessWidget {
  const _Sorgente({
    required this.icona,
    required this.titolo,
    required this.testo,
    required this.onTap,
  });

  final IconData icona;
  final String titolo;
  final String testo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Premibile(
    onTap: onTap,
    scala: 0.98,
    etichetta: '$titolo. $testo',
    child: ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colori.foschia,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colori.bianco,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icona, size: 24, color: Colori.cobalto),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titolo,
                    style: Testi.evidenza.copyWith(color: Colori.inchiostro),
                  ),
                  Text(
                    testo,
                    style: Testi.didascalia.copyWith(color: Colori.grafite),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Etichetta extends StatelessWidget {
  const _Etichetta(this.testo);

  final String testo;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 2, bottom: 8),
    child: Text(testo, style: Testi.etichetta.copyWith(color: Colori.ardesia)),
  );
}
