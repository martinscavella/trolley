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
import '../dominio/calendario.dart';
import '../dominio/spese.dart';
import '../dominio/valute.dart';
import '../servizi.dart';
import 'con_la_rete.dart';
import 'gesti_spesa.dart';
import 'scelta_valuta.dart';
import 'spese.dart';

/// Una spesa nuova, o da cambiare (06-spese.md, "Nuova spesa"; tela, 17 e 18).
///
/// Registrare costa due secondi: l'importo, e il resto è già scelto — la
/// valuta della persona, oggi, nessuna descrizione obbligatoria (regola 2).
/// Accanto alla propria valuta c'è quella del posto, e «Altra…» apre l'elenco.
/// Si registra anche senza rete; cambiarla o toglierla la richiede (regola 7).
///
/// Chi viaggia da solo tiene il conto e basta: nessuna parola sul dividere
/// (regola 3). Chi paga e chi partecipa arrivano con la divisione (2.3).
class FoglioSpesa extends StatelessWidget {
  const FoglioSpesa({super.key, required this.viaggio, this.spesa});

  final Viaggio viaggio;

  /// La spesa da cambiare; `null` per una nuova.
  final Spesa? spesa;

  @override
  Widget build(BuildContext context) => ConConto(
    viaggioId: viaggio.id,
    builder: (context, conto) => conto == null
        ? const SizedBox(
            height: 240,
            child: Center(child: IndicatoreAttivita()),
          )
        : ConLaRete(
            builder: (context, rete) => _Foglio(
              viaggio: viaggio,
              spesa: spesa,
              conto: conto,
              rete: rete,
            ),
          ),
  );
}

class _Foglio extends StatefulWidget {
  const _Foglio({
    required this.viaggio,
    required this.spesa,
    required this.conto,
    required this.rete,
  });

  final Viaggio viaggio;
  final Spesa? spesa;
  final ContoViaggio conto;
  final bool rete;

  @override
  State<_Foglio> createState() => _FoglioState();
}

class _FoglioState extends State<_Foglio> {
  late final _importo = TextEditingController(
    text: widget.spesa == null
        ? null
        : importoDaModificare(widget.spesa!.centesimi),
  );
  late final _descrizione = TextEditingController(
    text: widget.spesa?.descrizione,
  );
  late String _valuta = widget.spesa?.valuta ?? widget.conto.mia;
  late DateTime _data = widget.spesa?.giorno ?? soloData(DateTime.now());
  bool _inCorso = false;

  bool get _nuova => widget.spesa == null;

  @override
  void dispose() {
    _importo.dispose();
    _descrizione.dispose();
    super.dispose();
  }

  int? get _centesimi =>
      leggiImporto(_importo.text, decimali: valutaDi(_valuta).decimali);

  /// La propria, quella del posto, quelle già usate nel viaggio; e quella
  /// scelta dall'elenco, se non c'era.
  List<String> get _proposte {
    final usate = [for (final s in widget.conto.spese.reversed) s.valuta];
    final proposte = valuteProposte(
      mia: widget.conto.mia,
      delPosto: valutaDelPaese(widget.viaggio.destinazionePaese),
      usate: usate,
    );
    return [...proposte, if (!proposte.contains(_valuta)) _valuta];
  }

  Map<String, Object?> get _cambiamenti {
    final s = widget.spesa;
    final centesimi = _centesimi;
    if (s == null || centesimi == null) return const {};
    final descrizione = _descrizione.text.trim();
    return {
      if (centesimi != s.centesimi) 'importo': importoPerIlServer(centesimi),
      if (_valuta != s.valuta) 'valuta': _valuta,
      if (_data != s.giorno) 'data': scriviData(_data),
      if (descrizione != (s.descrizione ?? ''))
        'descrizione': descrizione.isEmpty ? null : descrizione,
    };
  }

  /// Perché non si può ancora salvare; `null` se si può.
  String? get _motivo {
    if (_centesimi == null) {
      return _importo.text.trim().isEmpty
          ? 'Scrivi quanto hai speso'
          : valutaDi(_valuta).decimali == 0
          ? 'In ${nomeCortoValuta(_valuta).toLowerCase()} non ci sono '
                'centesimi'
          : 'Questo non è un importo';
    }
    if (_nuovo) return null;
    if (widget.spesa!.inCoda) {
      return 'Parte con la rete: dopo si potrà cambiare';
    }
    if (!widget.rete) return motivoSenzaRete;
    if (_cambiamenti.isEmpty) return 'Niente da salvare';
    return null;
  }

  bool get _nuovo => _nuova;

  Future<void> _scegliValuta() async {
    final scelta = await apri<String>(
      context,
      SchermataValuta(scelta: _valuta),
      dalBasso: true,
    );
    if (scelta != null && mounted) setState(() => _valuta = scelta);
  }

  Future<void> _scegliData() async {
    final oggi = soloData(DateTime.now());
    final minima = DateTime(oggi.year - 2, oggi.month, oggi.day);
    final iniziale = _data.isAfter(oggi) ? oggi : _data;
    final scelta = await AdaptiveDatePicker.show(
      context: context,
      initialDate: DateTime(iniziale.year, iniziale.month, iniziale.day),
      firstDate: _data.isBefore(minima)
          ? DateTime(_data.year, _data.month, _data.day)
          : minima,
      lastDate: DateTime(oggi.year, oggi.month, oggi.day),
    );
    if (scelta != null && mounted) setState(() => _data = soloData(scelta));
  }

  Future<void> _salva() async {
    final centesimi = _centesimi;
    if (centesimi == null) return;
    setState(() => _inCorso = true);
    try {
      if (_nuova) {
        await registraLaSpesa(
          context,
          viaggio: widget.viaggio,
          centesimi: centesimi,
          valuta: _valuta,
          data: _data,
          descrizione: _descrizione.text,
        );
      } else {
        await Servizi.of(context).archivio
            .modificaSpesa(widget.spesa!, _cambiamenti);
        HapticFeedback.lightImpact();
      }
      if (mounted) Navigator.of(context).pop();
    } on ErroreTrolley catch (e) {
      if (mounted) mostraMessaggio(context, e.messaggio, errore: true);
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  Future<void> _togli() async {
    final spesa = widget.spesa!;
    var conferma = false;
    await AdaptiveAlertDialog.show(
      context: context,
      title: 'Eliminare questa spesa?',
      message: [
        spesa.descrizione == null
            ? scriviImporto(spesa.centesimi, spesa.valuta)
            : '«${spesa.descrizione}», '
                  '${scriviImporto(spesa.centesimi, spesa.valuta)}.',
        if (widget.conto.nomi.length > 1)
          'Sparisce per tutti quelli del viaggio.',
      ].join(' '),
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
    setState(() => _inCorso = true);
    try {
      await Servizi.of(context).archivio.togliSpesa(spesa);
      if (mounted) Navigator.of(context).pop();
    } on ErroreTrolley catch (e) {
      if (mounted) mostraMessaggio(context, e.messaggio, errore: true);
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final motivo = _motivo;
    final spesa = widget.spesa;
    final oggi = soloData(DateTime.now());
    final ieri = oggi.subtract(const Duration(days: 1));
    final altroGiorno = _data != oggi && _data != ieri;
    return Foglio(
      titolo: _nuova ? 'Nuova spesa' : 'La spesa',
      inBasso: AzioniFoglio(
        motivo: motivo,
        azione: PulsanteGrande(
          etichetta: 'Salva',
          inCorso: _inCorso,
          onPressed: motivo == null ? _salva : null,
        ),
      ),
      children: [
        const _Etichetta('Quanto?'),
        _CampoImporto(
          controller: _importo,
          valuta: _valuta,
          fuoco: _nuova,
          onCambia: () => setState(() {}),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final codice in _proposte)
              Gettone(
                etichetta: _etichettaValuta(codice),
                scelto: codice == _valuta,
                onTap: () => setState(() => _valuta = codice),
              ),
            Gettone(etichetta: 'Altra…', scelto: false, onTap: _scegliValuta),
          ],
        ),
        AnimatedSize(
          duration: Ritmo.medio,
          curve: Ritmo.curva,
          alignment: Alignment.topCenter,
          child: _valuta == widget.conto.mia
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _Conversione(
                    centesimi: _centesimi,
                    valuta: _valuta,
                    conto: widget.conto,
                  ),
                ),
        ),
        const SizedBox(height: 16),
        Campo(
          controller: _descrizione,
          etichetta: 'Per cosa? · facoltativo',
          segnaposto: 'Taxi, mercato, cena…',
          maiuscole: TextCapitalization.sentences,
          onCambia: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        const _Etichetta('Quando?'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Gettone(
              etichetta: 'Oggi',
              scelto: _data == oggi,
              onTap: () => setState(() => _data = oggi),
            ),
            Gettone(
              etichetta: 'Ieri',
              scelto: _data == ieri,
              onTap: () => setState(() => _data = ieri),
            ),
            Gettone(
              etichetta: altroGiorno
                  ? '${giornoCorto(_data)} ${meseBreve(_data)}'
                  : 'Un altro giorno',
              scelto: altroGiorno,
              onTap: _scegliData,
            ),
          ],
        ),
        if (_nuova && !widget.rete) ...[
          const SizedBox(height: 16),
          Avviso(
            fondo: Colori.foschia,
            icona: icona(
              ios: CupertinoIcons.wifi_slash,
              android: Icons.wifi_off_rounded,
            ),
            inizio: 'Sei offline.',
            testo:
                'La spesa si salva adesso e parte quando torna la rete. Per '
                'cambiarla dopo, la rete serve.',
          ),
        ],
        if (spesa != null) ...[
          if (spesa.paganteId != widget.conto.io) ...[
            const SizedBox(height: 16),
            Text(
              'Pagata da ${widget.conto.nomi[spesa.paganteId] ?? 'chi è uscito dal viaggio'}.',
              style: Testi.didascalia.copyWith(color: Colori.grafite),
            ),
          ],
          const SizedBox(height: 20),
          PulsanteGrande(
            etichetta: 'Elimina la spesa',
            secondario: true,
            pericolo: true,
            motivo: spesa.inCoda
                ? 'Parte con la rete: dopo si potrà eliminare'
                : widget.rete
                ? null
                : motivoSenzaRete,
            onPressed: _inCorso || spesa.inCoda || !widget.rete ? null : _togli,
          ),
        ],
      ],
    );
  }

  String _etichettaValuta(String codice) {
    final nome = '${simboloValuta(codice)} ${nomeCortoValuta(codice)}';
    if (codice == widget.conto.mia) return '$nome · tua';
    if (codice == valutaDelPaese(widget.viaggio.destinazionePaese)) {
      return '$nome · del posto';
    }
    return nome;
  }
}

/// Quanto fa nella valuta della persona, e con che tasso (tela, 17). Senza
/// tasso lo dice, e la spesa resta nella sua valuta (tela, 18).
class _Conversione extends StatelessWidget {
  const _Conversione({
    required this.centesimi,
    required this.valuta,
    required this.conto,
  });

  final int? centesimi;
  final String valuta;
  final ContoViaggio conto;

  @override
  Widget build(BuildContext context) {
    final tasso = tassoInParole(
      mia: conto.mia,
      altra: valuta,
      perEuro: conto.perEuro,
    );
    if (tasso == null) {
      return Avviso(
        fondo: Colori.foschia,
        icona: icona(
          ios: CupertinoIcons.arrow_right_arrow_left,
          android: Icons.swap_horiz_rounded,
        ),
        inizio: 'Conversione non disponibile.',
        testo:
            'Su questo telefono non è ancora arrivato il tasso '
            '${_della(valuta)}: la spesa resta in $valuta, e si converte '
            'quando arriva.',
      );
    }
    final c = centesimi;
    final convertita = c == null
        ? null
        : converti(c, da: valuta, a: conto.mia, perEuro: conto.perEuro);
    final quando = quandoITassi(
      conto.giornoTassi,
      DateTime.now(),
    ).replaceFirst('tassi ', '');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colori.foschia,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            convertita == null
                ? '≈ –'
                : '≈ ${scriviImporto(convertita, conto.mia)}',
            style: Testi.numero.copyWith(
              color: Colori.inchiostro,
              fontSize: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$tasso · $quando',
              textAlign: TextAlign.right,
              style: Testi.didascalia.copyWith(color: Colori.grafite),
            ),
          ),
        ],
      ),
    );
  }

  /// `del dirham`, `dello yen`, `dell'euro`.
  static String _della(String codice) {
    final nome = nomeCortoValuta(codice).toLowerCase();
    if (RegExp('^[aeiou]').hasMatch(nome)) return 'dell\'$nome';
    if (RegExp('^(y|z|s[^aeiou]|gn|ps)').hasMatch(nome)) return 'dello $nome';
    return 'del $nome';
  }
}

/// L'importo grande, come nella tela: le cifre in Unbounded, la valuta a
/// destra, il bordo cobalto.
class _CampoImporto extends StatelessWidget {
  const _CampoImporto({
    required this.controller,
    required this.valuta,
    required this.fuoco,
    required this.onCambia,
  });

  final TextEditingController controller;
  final String valuta;
  final bool fuoco;
  final VoidCallback onCambia;

  @override
  Widget build(BuildContext context) {
    final stile = Testi.titoli(
      34,
      spaziatura: 0,
      altezza: 1.1,
    ).copyWith(color: Colori.inchiostro);
    const tastiera = TextInputType.numberWithOptions(decimal: true);
    final formattatori = [
      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\s]')),
      LengthLimitingTextInputFormatter(16),
    ];
    final campo = suIOS
        ? CupertinoTextField(
            controller: controller,
            autofocus: fuoco,
            keyboardType: tastiera,
            inputFormatters: formattatori,
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
            autofocus: fuoco,
            keyboardType: tastiera,
            inputFormatters: formattatori,
            style: stile,
            cursorColor: Colori.cobalto,
            decoration: InputDecoration.collapsed(
              hintText: '0',
              hintStyle: stile.copyWith(color: Colori.cenere),
            ),
            onChanged: (_) => onCambia(),
          );
    return Semantics(
      label: 'Importo in ${valutaDi(valuta).nome}',
      child: Container(
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colori.cobalto, width: 2),
        ),
        child: Row(
          children: [
            Expanded(child: campo),
            const SizedBox(width: 10),
            Text(
              simboloValuta(valuta),
              style: Testi.titoli(
                18,
                spaziatura: 0,
                peso: 600,
              ).copyWith(color: Colori.grafite),
            ),
          ],
        ),
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
