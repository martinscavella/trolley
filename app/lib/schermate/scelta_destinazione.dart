import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../aspetto/elementi.dart';
import '../aspetto/formati.dart';
import '../aspetto/movimento.dart';
import '../aspetto/pagina.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../dati/destinazioni.dart';

/// Dove si va. Si cerca nell'elenco incorporato, che funziona anche senza rete
/// (ADR-005). Quello che l'elenco non conosce — una valle, un'isola, un paesino
/// — si scrive com'è, e poi si dice in che paese sta.
///
/// Con [soloElenco] si sceglie solo dall'elenco: per cercare viaggiatori per
/// meta (5.3; tela, 74), dove un nome scritto a mano non troverebbe nessuno.
class SchermataDestinazione extends StatefulWidget {
  const SchermataDestinazione({super.key, this.soloElenco = false});

  final bool soloElenco;

  @override
  State<SchermataDestinazione> createState() => _SchermataDestinazioneState();
}

class _SchermataDestinazioneState extends State<SchermataDestinazione> {
  final _testo = TextEditingController();
  final _fuoco = FocusNode();
  ElencoDestinazioni? _elenco;

  /// Il nome scritto a mano che aspetta il suo paese.
  String? _aMano;

  @override
  void initState() {
    super.initState();
    ElencoDestinazioni.carica().then((elenco) {
      if (mounted) setState(() => _elenco = elenco);
    });
  }

  @override
  void dispose() {
    _testo.dispose();
    _fuoco.dispose();
    super.dispose();
  }

  void _scegli(Destinazione d) => Navigator.of(context).pop(d);

  void _usaComEScritto(String nome) {
    setState(() => _aMano = nome.trim());
    _testo.clear();
    _fuoco.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final aMano = _aMano;
    final cercato = _testo.text.trim();
    final risultati =
        _elenco?.cerca(cercato, soloPaesi: aMano != null) ?? const [];

    final righe = <Widget>[
      for (final d in risultati)
        _RigaDestinazione(
          simbolo: _Bandiera(d.paese),
          titolo: d.nome,
          sottotitolo: d.tipo == TipoDestinazione.paese
              ? 'Paese'
              : [
                  if (_omonima(d, risultati) && d.dettaglio.isNotEmpty)
                    d.dettaglio,
                  ?d.nomePaese,
                ].join(' · '),
          onTap: () => _scegli(
            aMano == null ? d : Destinazione.aMano(aMano, paese: d.paese),
          ),
        ),
      if (aMano == null && cercato.isNotEmpty && !widget.soloElenco)
        _RigaDestinazione(
          simbolo: _Simbolo(
            icona(ios: CupertinoIcons.pencil, android: Icons.edit_outlined),
          ),
          titolo: 'Usa «$cercato»',
          sottotitolo: 'Non è nell\'elenco: poi scegli il paese',
          onTap: () => _usaComEScritto(cercato),
        ),
      if (aMano != null)
        _RigaDestinazione(
          simbolo: _Simbolo(
            icona(ios: CupertinoIcons.question, android: Icons.help_outline),
          ),
          titolo: 'Senza paese',
          sottotitolo: 'Sul mappamondo «$aMano» non comparirà',
          onTap: () => _scegli(Destinazione.aMano(aMano)),
        ),
    ];

    return Pagina(
      corpo: Builder(
        builder: (context) => Padding(
          padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Semantics(
                  header: true,
                  child: Text(
                    aMano != null
                        ? 'In che paese?'
                        : widget.soloElenco
                        ? 'Quale meta?'
                        : 'Dove?',
                    style: Testi.titoloGrande.copyWith(
                      color: Colori.inchiostro,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Campo(
                  controller: _testo,
                  fuoco: true,
                  segnaposto: aMano == null
                      ? 'Una città o un paese'
                      : 'Il paese di «$aMano»',
                  icona: icona(
                    ios: CupertinoIcons.search,
                    android: Icons.search,
                  ),
                  correzione: false,
                  maiuscole: TextCapitalization.words,
                  azione: TextInputAction.search,
                  onCambia: (_) => setState(() {}),
                  onInvio: (_) {
                    if (risultati.isNotEmpty) {
                      final primo = risultati.first;
                      _scegli(
                        aMano == null
                            ? primo
                            : Destinazione.aMano(aMano, paese: primo.paese),
                      );
                    }
                  },
                ),
              ),
              Expanded(
                child: _elenco == null
                    ? const Center(child: IndicatoreAttivita())
                    : ListView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          MediaQuery.paddingOf(context).bottom + 24,
                        ),
                        children: [
                          if (cercato.isEmpty &&
                              aMano == null &&
                              widget.soloElenco)
                            _Suggerimento(
                              'Un paese o una città: trovi chi ci è stato e '
                              'l\'ha messo sul suo profilo.',
                            )
                          else if (cercato.isEmpty && aMano == null)
                            _Suggerimento(
                              'Città e paesi, anche senza rete. Se il posto non '
                              'c\'è — una valle, un\'isola — lo scrivi com\'è.',
                            ),
                          if (cercato.isEmpty && aMano != null)
                            _Suggerimento(
                              '«$aMano» non è nell\'elenco. Col paese, sul '
                              'mappamondo conterà almeno quello.',
                            ),
                          if (righe.isNotEmpty)
                            Pannello(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              child: Column(
                                children: [
                                  for (final (i, riga) in righe.indexed) ...[
                                    if (i > 0)
                                      Divider(
                                        height: 1,
                                        thickness: 0.5,
                                        indent: 50,
                                        color: Tavolozza.of(context).separatore,
                                      ),
                                    riga,
                                  ],
                                ],
                              ),
                            ).entra(context, da: 6),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Se fra i risultati c'è un'altra destinazione con lo stesso nome nello
  /// stesso paese: solo allora serve dire la regione o la provincia.
  static bool _omonima(Destinazione d, List<Destinazione> risultati) =>
      risultati.where((r) => r.nome == d.nome && r.paese == d.paese).length > 1;
}

class _RigaDestinazione extends StatelessWidget {
  const _RigaDestinazione({
    required this.simbolo,
    required this.titolo,
    required this.sottotitolo,
    required this.onTap,
  });

  final Widget simbolo;
  final String titolo;
  final String sottotitolo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Tavolozza.of(context);
    return Premibile(
      onTap: onTap,
      scala: 0.985,
      etichetta: '$titolo, $sottotitolo',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            SizedBox(width: 36, child: Center(child: simbolo)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titolo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Testi.evidenza.copyWith(color: t.testo),
                  ),
                  if (sottotitolo.isNotEmpty)
                    Text(
                      sottotitolo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Testi.didascalia.copyWith(
                        color: t.testoSecondario,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bandiera extends StatelessWidget {
  const _Bandiera(this.paese);

  final String? paese;

  @override
  Widget build(BuildContext context) {
    final segno = bandiera(paese);
    if (segno == null) {
      return _Simbolo(icona(ios: CupertinoIcons.globe, android: Icons.public));
    }
    return Text(segno, style: const TextStyle(fontSize: 26));
  }
}

class _Simbolo extends StatelessWidget {
  const _Simbolo(this.simbolo);

  final IconData simbolo;

  @override
  Widget build(BuildContext context) =>
      Icon(simbolo, size: 22, color: Tavolozza.of(context).accento);
}

class _Suggerimento extends StatelessWidget {
  const _Suggerimento(this.testo);

  final String testo;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
    child: Text(
      testo,
      style: Testi.secondario.copyWith(
        color: Tavolozza.of(context).testoSecondario,
      ),
    ),
  );
}
