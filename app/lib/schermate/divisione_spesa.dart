import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../aspetto/elementi.dart';
import '../aspetto/movimento.dart';
import '../aspetto/pagina.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../dominio/divisione.dart';
import '../dominio/valute.dart';
import 'spese.dart';

/// Chi ha pagato e per chi, nel foglio di una spesa (tela, 38): già scelti —
/// chi la registra, per tutti, in parti uguali — e si cambiano solo se serve,
/// così registrare resta un gesto da due secondi (06, regola 2). Da soli non
/// compare: non si parla di dividere (regola 3).
class SezioneDivisione extends StatelessWidget {
  const SezioneDivisione({
    super.key,
    required this.conto,
    required this.paganti,
    required this.persone,
    required this.pagante,
    required this.perChi,
    required this.uguali,
    required this.importi,
    required this.centesimi,
    required this.valuta,
    required this.onPagante,
    required this.onPerChi,
    required this.onUguali,
    required this.onImportiDiversi,
  });

  final ContoViaggio conto;

  /// Chi può aver pagato, e per chi può essere: chi è nel viaggio, più chi
  /// era già nella spesa anche se ne è uscito.
  final List<String> paganti;
  final List<String> persone;
  final String pagante;
  final Set<String> perChi;
  final bool uguali;

  /// Gli importi diversi, se si sono scritti.
  final Map<String, int>? importi;
  final int? centesimi;
  final String valuta;
  final ValueChanged<String> onPagante;
  final ValueChanged<String> onPerChi;
  final ValueChanged<bool> onUguali;
  final VoidCallback onImportiDiversi;

  String _chi(String id) => id == conto.io ? 'Tu' : conto.nomi[id] ?? '?';

  @override
  Widget build(BuildContext context) {
    final scelti = [
      for (final p in persone)
        if (perChi.contains(p)) p,
    ];
    final c = centesimi;
    final String? quanto;
    if (scelti.isEmpty || c == null) {
      quanto = null;
    } else if (!uguali) {
      final parti = importi ?? const {};
      quanto = [
        for (final p in scelti)
          '${_chi(p)} ${scriviImporto(parti[p] ?? 0, valuta)}',
      ].join(' · ');
    } else if (scelti.length == 1) {
      quanto = scelti.single == conto.io
          ? 'Tutta per te.'
          : 'Tutta per ${_chi(scelti.single)}.';
    } else {
      final parti = partiUguali(c, scelti);
      final a = scriviImporto(parti[scelti.last]!, valuta);
      quanto = parti.values.toSet().length == 1
          ? '$a a testa.'
          : 'Circa $a a testa.';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Etichetta('Ha pagato'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in paganti)
              Gettone(
                etichetta: _chi(p),
                scelto: p == pagante,
                onTap: () => onPagante(p),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const _Etichetta('Per chi'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in persone)
              Gettone(
                etichetta: _chi(p),
                scelto: perChi.contains(p),
                spunta: true,
                onTap: () => onPerChi(p),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _DueScelte(
          sinistra: 'In parti uguali',
          destra: 'Importi diversi',
          aSinistra: uguali,
          onSinistra: () => onUguali(true),
          onDestra: onImportiDiversi,
        ),
        AnimatedSize(
          duration: Ritmo.medio,
          curve: Ritmo.curva,
          alignment: Alignment.topCenter,
          child: quanto == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          quanto,
                          style: Testi.evidenza.copyWith(
                            fontSize: 15,
                            color: Colori.inchiostro,
                          ),
                        ),
                      ),
                      if (!uguali)
                        PulsantePiccolo(
                          etichetta: 'Cambia',
                          onPressed: onImportiDiversi,
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

/// Due scelte affiancate, una sola accesa (tela, 38).
class _DueScelte extends StatelessWidget {
  const _DueScelte({
    required this.sinistra,
    required this.destra,
    required this.aSinistra,
    required this.onSinistra,
    required this.onDestra,
  });

  final String sinistra;
  final String destra;
  final bool aSinistra;
  final VoidCallback onSinistra;
  final VoidCallback onDestra;

  @override
  Widget build(BuildContext context) {
    Widget scelta(String testo, bool accesa, VoidCallback onTap) => Expanded(
      child: Semantics(
        selected: accesa,
        child: Premibile(
          onTap: onTap,
          scala: 0.97,
          etichetta: testo,
          child: AnimatedContainer(
            duration: Ritmo.breve,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accesa ? Colori.inchiostro : const Color(0x00000000),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              testo,
              style: Testi.secondario.copyWith(
                fontWeight: accesa ? FontWeight.w700 : FontWeight.w600,
                color: accesa ? Colori.bianco : Colori.ardesia,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colori.foschia,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          scelta(sinistra, aSinistra, onSinistra),
          const SizedBox(width: 4),
          scelta(destra, !aSinistra, onDestra),
        ],
      ),
    );
  }
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

/// Importi diversi (tela, 39): quanto è di ognuno. Si vede quanto manca, e il
/// pulsante si accende quando le parti fanno l'importo pagato. Restituisce
/// le parti; «Indietro» non cambia niente.
class FoglioImportiDiversi extends StatefulWidget {
  const FoglioImportiDiversi({
    super.key,
    required this.conto,
    required this.sottotitolo,
    required this.persone,
    required this.centesimi,
    required this.valuta,
    required this.conferma,
    this.iniziali,
  });

  final ContoViaggio conto;

  /// «Cena da Cantinho · 42,00 € pagati da te».
  final String sottotitolo;
  final List<String> persone;
  final int centesimi;
  final String valuta;

  /// «Registra» per una spesa nuova, «Salva» per una da cambiare.
  final String conferma;
  final Map<String, int>? iniziali;

  @override
  State<FoglioImportiDiversi> createState() => _FoglioImportiDiversiState();
}

class _FoglioImportiDiversiState extends State<FoglioImportiDiversi> {
  late final _campi = {
    for (final p in widget.persone)
      p: TextEditingController(
        text: switch (widget.iniziali?[p]) {
          final c? => importoDaModificare(c),
          null => '',
        },
      ),
  };

  @override
  void dispose() {
    for (final c in _campi.values) {
      c.dispose();
    }
    super.dispose();
  }

  int get _decimali => valutaDi(widget.valuta).decimali;

  Map<String, int> get _parti => {
    for (final MapEntry(key: p, value: c) in _campi.entries)
      p: c.text.trim().isEmpty
          ? 0
          : leggiImporto(c.text, decimali: _decimali) ?? 0,
  };

  bool get _leggibili => _campi.values.every(
    (c) =>
        c.text.trim().isEmpty ||
        leggiImporto(c.text, decimali: _decimali) != null,
  );

  @override
  Widget build(BuildContext context) {
    final manca = mancaAlleParti(widget.centesimi, _parti.values);
    final totale = scriviImporto(widget.centesimi, widget.valuta);
    final pronto = _leggibili && manca == 0;
    return Foglio(
      titolo: 'Importi diversi',
      inBasso: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: PulsanteGrande(
                  etichetta: 'Indietro',
                  secondario: true,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PulsanteGrande(
                  etichetta: widget.conferma,
                  onPressed: pronto
                      ? () => Navigator.of(context).pop({
                          for (final MapEntry(key: p, value: c)
                              in _parti.entries)
                            if (c > 0) p: c,
                        })
                      : null,
                ),
              ),
            ],
          ),
          if (!pronto) ...[
            const SizedBox(height: 10),
            Text(
              'Le parti devono fare $totale, l\'importo pagato.',
              textAlign: TextAlign.center,
              style: Testi.didascalia.copyWith(color: Colori.grafite),
            ),
          ],
        ],
      ),
      children: [
        Text(
          widget.sottotitolo,
          style: Testi.secondario.copyWith(color: Colori.grafite),
        ),
        for (final p in widget.persone) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Avatar(nome: widget.conto.nomi[p] ?? '?', dimensione: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  p == widget.conto.io ? 'Tu' : widget.conto.nomi[p] ?? '?',
                  style: Testi.evidenza.copyWith(color: Colori.inchiostro),
                ),
              ),
              SizedBox(
                width: 120,
                child: _CampoParte(
                  controller: _campi[p]!,
                  etichetta:
                      'Parte di ${p == widget.conto.io ? 'te' : widget.conto.nomi[p] ?? '?'}',
                  onCambia: () => setState(() {}),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        AnimatedSize(
          duration: Ritmo.medio,
          curve: Ritmo.curva,
          alignment: Alignment.topCenter,
          child: manca == 0
              ? const SizedBox(width: double.infinity)
              : Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colori.rosa,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: manca > 0
                              ? 'Mancano ${scriviImporto(manca, widget.valuta)}'
                              : 'Avanzano ${scriviImporto(-manca, widget.valuta)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(text: ' per arrivare a $totale.'),
                      ],
                    ),
                    style: Testi.corpo.copyWith(
                      fontSize: 15,
                      color: Colori.inchiostro,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

/// Il campo di una parte: a destra, con le cifre della tela.
class _CampoParte extends StatelessWidget {
  const _CampoParte({
    required this.controller,
    required this.etichetta,
    required this.onCambia,
  });

  final TextEditingController controller;
  final String etichetta;
  final VoidCallback onCambia;

  @override
  Widget build(BuildContext context) {
    final stile = Testi.numero.copyWith(color: Colori.inchiostro, fontSize: 16);
    const tastiera = TextInputType.numberWithOptions(decimal: true);
    final formattatori = [
      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\s]')),
      LengthLimitingTextInputFormatter(12),
    ];
    return Semantics(
      label: etichetta,
      textField: true,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colori.cenere, width: 2),
        ),
        child: suIOS
            ? CupertinoTextField(
                controller: controller,
                keyboardType: tastiera,
                inputFormatters: formattatori,
                textAlign: TextAlign.right,
                style: stile,
                placeholder: '0',
                placeholderStyle: stile.copyWith(color: Colori.cenere),
                cursorColor: Colori.cobalto,
                padding: EdgeInsets.zero,
                decoration: null,
                onChanged: (_) => onCambia(),
              )
            : TextField(
                controller: controller,
                keyboardType: tastiera,
                inputFormatters: formattatori,
                textAlign: TextAlign.right,
                style: stile,
                cursorColor: Colori.cobalto,
                decoration: InputDecoration.collapsed(
                  hintText: '0',
                  hintStyle: stile.copyWith(color: Colori.cenere),
                ),
                onChanged: (_) => onCambia(),
              ),
      ),
    );
  }
}
