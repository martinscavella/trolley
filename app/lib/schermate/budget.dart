/// Il budget (06-spese.md, regole 12–17; tela, 134–136): quello del viaggio,
/// che vedono tutti, e quello di ciascuno, che sta solo sul suo telefono. Il
/// pannello nelle spese dice a che punto si è; il foglio lo mette, lo cambia
/// e lo toglie; nell'idea è il budget di massima.
library;

import 'dart:async';

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
import '../dominio/budget.dart';
import '../dominio/valute.dart';
import '../misurazione/misurazione.dart';
import '../servizi.dart';
import 'con_la_rete.dart';
import 'scelta_valuta.dart';
import 'spese.dart';

/// Nelle spese: il budget del viaggio, o il proprio (tela, 134). Senza
/// budget, la riga per metterlo.
class PannelloBudget extends StatefulWidget {
  const PannelloBudget({super.key, required this.viaggio, required this.conto});

  final Viaggio viaggio;
  final ContoViaggio conto;

  @override
  State<PannelloBudget> createState() => _PannelloBudgetState();
}

class _PannelloBudgetState extends State<PannelloBudget> {
  /// Il proprio, invece di quello del viaggio. Da soli non c'è la scelta.
  bool _mio = false;
  late Stream<Budget?> _personale;
  bool _avviato = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_avviato) return;
    _avviato = true;
    _personale = Servizi.of(context).archivio
        .osservaBudgetPersonale(widget.viaggio.id);
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<Budget?>(
    stream: _personale,
    builder: (context, personale) {
      final conto = widget.conto;
      final diviso = conto.diviso;
      final mio = diviso && _mio;
      final budget = mio ? personale.data : widget.viaggio.budget;
      void metti() => apriFoglio<void>(
        context,
        FoglioBudget(
          viaggio: widget.viaggio,
          mia: conto.mia,
          personale: mio,
          diviso: diviso,
          delViaggio: widget.viaggio.budget,
          mioDiPrima: personale.data,
          laMiaParte: conto.laMiaParte.centesimi,
        ),
      );
      final scelta = diviso
          ? _Scelta(mio: mio, onCambio: (m) => setState(() => _mio = m))
          : null;
      if (budget == null) {
        return _SenzaBudget(
          testo: mio
              ? 'Metti il tuo budget: lo vedi solo tu, contro la tua parte.'
              : 'Metti un budget: quanto pensate di spendere, in tutto.',
          scelta: scelta,
          onMetti: metti,
        );
      }
      return _ConBudget(
        viaggio: widget.viaggio,
        conto: conto,
        budget: budget,
        mio: mio,
        diviso: diviso,
        scelta: scelta,
        onCambia: metti,
      );
    },
  );
}

/// Del viaggio · Il tuo.
class _Scelta extends StatelessWidget {
  const _Scelta({required this.mio, required this.onCambio});

  final bool mio;
  final ValueChanged<bool> onCambio;

  @override
  Widget build(BuildContext context) {
    Widget voce(String nome, bool scelta, bool valore) => Semantics(
      selected: scelta,
      child: Premibile(
        onTap: () => onCambio(valore),
        scala: 0.96,
        etichetta: nome,
        child: AnimatedContainer(
          duration: movimentoRidotto(context) ? Duration.zero : Ritmo.breve,
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scelta ? Colori.bianco : Colori.cenere,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            nome,
            style: Testi.didascalia.copyWith(
              color: scelta ? Colori.inchiostro : Colori.ardesia,
              fontWeight: scelta ? FontWeight.w700 : FontWeight.w600,
              height: 1,
            ),
          ),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colori.cenere,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          voce('Del viaggio', !mio, false),
          const SizedBox(width: 2),
          voce('Il tuo', mio, true),
        ],
      ),
    );
  }
}

class _Intestazione extends StatelessWidget {
  const _Intestazione({required this.scelta});

  final Widget? scelta;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          'BUDGET',
          style: Testi.sezione.copyWith(color: Colori.grafite, fontSize: 11),
        ),
      ),
      ?scelta,
    ],
  );
}

class _SenzaBudget extends StatelessWidget {
  const _SenzaBudget({
    required this.testo,
    required this.scelta,
    required this.onMetti,
  });

  final String testo;
  final Widget? scelta;
  final VoidCallback onMetti;

  @override
  Widget build(BuildContext context) => Pannello(
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Intestazione(scelta: scelta),
        const SizedBox(height: 8),
        Text(testo, style: Testi.secondario.copyWith(color: Colori.grafite)),
        const SizedBox(height: 10),
        PulsantePiccolo(etichetta: 'Metti un budget', onPressed: onMetti),
      ],
    ),
  );
}

class _ConBudget extends StatelessWidget {
  const _ConBudget({
    required this.viaggio,
    required this.conto,
    required this.budget,
    required this.mio,
    required this.diviso,
    required this.scelta,
    required this.onCambia,
  });

  final Viaggio viaggio;
  final ContoViaggio conto;
  final Budget budget;
  final bool mio;
  final bool diviso;
  final Widget? scelta;
  final VoidCallback onCambia;

  @override
  Widget build(BuildContext context) {
    final mia = conto.mia;
    final (inizio, fine) = (viaggio.inizio, viaggio.fine);
    final nelBudget = converti(
      budget.centesimi,
      da: budget.valuta,
      a: mia,
      perEuro: conto.perEuro,
    );
    // Il viaggio contro il totale, ciascuno contro la propria parte (06,
    // regola 14). Le spese senza tasso restano fuori, e lo si dice.
    final spese = <SpesaPerBudget>[];
    var senzaTasso = 0;
    for (final s in conto.spese) {
      final quanto = mio ? conto.quoteDi(s)[conto.io] : s.centesimi;
      if (quanto == null || quanto == 0) continue;
      final convertita = converti(
        quanto,
        da: s.valuta,
        a: mia,
        perEuro: conto.perEuro,
      );
      if (convertita == null) {
        senzaTasso++;
      } else {
        spese.add((data: s.giorno, centesimi: convertita));
      }
    }
    String soldi(int c) => scriviImporto(c, mia);
    if (nelBudget == null || inizio == null || fine == null) {
      return Pannello(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Intestazione(scelta: scelta),
            const SizedBox(height: 8),
            Text(
              scriviImporto(budget.centesimi, budget.valuta),
              style: Testi.titoli(28).copyWith(color: Colori.inchiostro),
            ),
            const SizedBox(height: 6),
            Text(
              nelBudget == null
                  ? 'Il budget è in ${budget.valuta} e manca il tasso per '
                        'confrontarlo con le spese: arriva con la rete.'
                  : 'Quando il viaggio avrà le date, si vedrà giorno per '
                        'giorno.',
              style: Testi.secondario.copyWith(color: Colori.grafite),
            ),
            const SizedBox(height: 10),
            PulsantePiccolo(etichetta: 'Cambia', onPressed: onCambia),
          ],
        ),
      );
    }
    final a = andamentoBudget(
      budget: nelBudget,
      spese: spese,
      inizio: inizio,
      fine: fine,
      oggi: DateTime.now(),
    );
    final voi = mio || !diviso;
    final frase = [
      if (a.oltre)
        'Oltre il budget di ${soldi(-a.restano)}.'
      else
        switch (a.fase) {
          FaseBudget.dopo =>
            'Finito: ${voi ? 'hai' : 'avete'} speso ${soldi(a.restano)} meno '
                'del budget.',
          _ when a.alGiorno == null => 'Il budget è finito.',
          FaseBudget.prima =>
            'Restano ${soldi(a.restano)}: ${soldi(a.alGiorno!)} al giorno '
                'per i ${a.giorniRestanti} giorni del viaggio.',
          FaseBudget.durante =>
            'Restano ${soldi(a.restano)}: ${soldi(a.alGiorno!)} al giorno '
                '${switch (a.giorniRestanti) {
                  1 => 'per oggi',
                  2 => 'per oggi e domani',
                  final n => 'per i $n giorni che restano',
                }}.',
        },
      if (a.fase == FaseBudget.durante && !a.oltre && a.rispettoAlRitmo != 0)
        a.rispettoAlRitmo < 0
            ? '${voi ? 'Sei' : 'Siete'} sotto il ritmo di '
                  '${soldi(-a.rispettoAlRitmo)}.'
            : '${voi ? 'Sei' : 'Siete'} sopra il ritmo di '
                  '${soldi(a.rispettoAlRitmo)}.',
      if (senzaTasso > 0)
        senzaTasso == 1
            ? 'Una spesa senza tasso non è contata.'
            : '$senzaTasso spese senza tasso non sono contate.',
    ].join(' ');
    return Pannello(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Intestazione(scelta: scelta),
          const SizedBox(height: 10),
          Semantics(
            label: '${soldi(a.speso)} spesi su un budget di ${soldi(a.budget)}',
            child: ExcludeSemantics(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: 8,
                children: [
                  Text(
                    soldi(a.speso),
                    style: Testi.titoli(28).copyWith(
                      color: a.oltre ? Colori.pericolo : Colori.inchiostro,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      'di ${soldi(a.budget)}',
                      style: Testi.evidenza.copyWith(color: Colori.grafite),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _Barra(andamento: a, etichetta: 'oggi · ${soldi(a.ritmo)}'),
          const SizedBox(height: 8),
          Text(
            frase,
            style: Testi.secondario.copyWith(
              color: a.oltre ? Colori.pericolo : Colori.ardesia,
              fontWeight: a.oltre ? FontWeight.w600 : null,
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFEEF0F4)),
          const SizedBox(height: 12),
          _Colonne(andamento: a, soldi: soldi),
          const SizedBox(height: 8),
          Text(
            'La linea è la quota del giorno: ${soldi(a.quotaDelGiorno)}. '
            'Le spese di prima di partire contano subito.',
            style: Testi.didascalia.copyWith(color: Colori.grafite),
          ),
          const SizedBox(height: 8),
          PulsantePiccolo(etichetta: 'Cambia il budget', onPressed: onCambia),
        ],
      ),
    );
  }
}

/// Quanto è speso sul budget, con la tacca di oggi. Rossa oltre il budget.
class _Barra extends StatelessWidget {
  const _Barra({required this.andamento, required this.etichetta});

  final AndamentoBudget andamento;
  final String etichetta;

  @override
  Widget build(BuildContext context) {
    final a = andamento;
    final conTacca = a.fase == FaseBudget.durante && a.ritmo > 0;
    final ridotto = movimentoRidotto(context);
    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, vincoli) {
          final largo = vincoli.maxWidth;
          final tacca = a.tacca * largo;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 28,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 5,
                      height: 18,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colori.foschia,
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: 5,
                      height: 18,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: a.pieno.clamp(0.0, 1.0)),
                        duration: ridotto ? Duration.zero : Ritmo.lungo,
                        curve: Ritmo.curva,
                        builder: (context, t, _) => Container(
                          width: largo * t,
                          decoration: BoxDecoration(
                            color: a.oltre ? Colori.pericolo : Colori.cobalto,
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                      ),
                    ),
                    if (conTacca)
                      Positioned(
                        left: tacca - 1.5,
                        top: 0,
                        width: 3,
                        height: 28,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colori.inchiostro,
                            borderRadius: BorderRadius.all(Radius.circular(2)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (conTacca)
                Align(
                  alignment: Alignment((a.tacca * 2 - 1).clamp(-1.0, 1.0), 0),
                  child: Text(
                    etichetta,
                    style: Testi.didascalia.copyWith(
                      color: Colori.ardesia,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Una colonna per giorno contro la quota del giorno; le spese di prima di
/// partire tutte insieme, in testa.
class _Colonne extends StatelessWidget {
  const _Colonne({required this.andamento, required this.soldi});

  final AndamentoBudget andamento;
  final String Function(int) soldi;

  @override
  Widget build(BuildContext context) {
    final a = andamento;
    const alto = 84.0;
    final massimo = [
      a.quotaDelGiorno,
      for (final c in a.colonne) c.speso,
    ].reduce((x, y) => x > y ? x : y).clamp(1, 1 << 62);
    double h(int c) => c / massimo * alto;
    // Tante colonne in un viaggio lungo: si scorrono di lato.
    final colonne = [
      for (final c in a.colonne)
        Semantics(
          label:
              '${c.data == null ? 'Prima di partire' : giornoBreve(c.data!)}: '
              '${c.speso == 0 ? 'niente' : soldi(c.speso)}',
          child: ExcludeSemantics(
            child: SizedBox(
              width: 64,
              child: Column(
                children: [
                  Text(
                    c.speso == 0 ? '—' : _corto(c.speso),
                    style: Testi.titoli(
                      11,
                      peso: 600,
                      spaziatura: 0,
                    ).copyWith(color: Colori.inchiostro),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 34,
                    height: alto,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.bottomCenter,
                      children: [
                        if (c.futura)
                          Container(
                            height: 12,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colori.cenere,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          )
                        else
                          Container(
                            height: h(c.speso).clamp(4, alto),
                            decoration: BoxDecoration(
                              color:
                                  c.data != null && c.speso > a.quotaDelGiorno
                                  ? Colori.pericolo
                                  : Colori.cobalto,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        if (c.data != null)
                          Positioned(
                            left: -4,
                            right: -4,
                            bottom: h(a.quotaDelGiorno),
                            height: 2,
                            child: const ColoredBox(color: Colori.inchiostro),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    c.data == null
                        ? 'PRIMA'
                        : giornoCorto(c.data!).toUpperCase(),
                    style: Testi.sezione.copyWith(
                      color: Colori.grafite,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: colonne),
    );
  }

  /// `132 €` sopra una colonna: senza centesimi, c'è poco posto.
  String _corto(int centesimi) {
    final intero = scriviImporto((centesimi / 100).round() * 100, 'EUR');
    return intero.replaceAll(',00', '').replaceAll(' €', '');
  }
}

/// Il budget: del viaggio, o il proprio (tela, 135). Quello del viaggio
/// richiede la rete; il proprio sta sul telefono, e si mette anche senza.
class FoglioBudget extends StatefulWidget {
  const FoglioBudget({
    super.key,
    required this.viaggio,
    required this.mia,
    required this.personale,
    required this.diviso,
    required this.delViaggio,
    required this.mioDiPrima,
    this.laMiaParte,
  });

  final Viaggio viaggio;

  /// La valuta della persona: quella con cui si comincia.
  final String mia;
  final bool personale;

  /// Nel viaggio c'è qualcun altro: c'è la scelta fra i due.
  final bool diviso;
  final Budget? delViaggio;
  final Budget? mioDiPrima;

  /// La propria parte delle spese fin qui, nella valuta della persona.
  final int? laMiaParte;

  @override
  State<FoglioBudget> createState() => _FoglioBudgetState();
}

class _FoglioBudgetState extends State<FoglioBudget> {
  late bool _personale = widget.personale && widget.diviso;
  late final _importo = TextEditingController(text: _testoDi(_diPrima));
  late String _valuta = _diPrima?.valuta ?? widget.mia;
  bool _inCorso = false;

  Budget? get _diPrima => _personale ? widget.mioDiPrima : widget.delViaggio;

  String _testoDi(Budget? b) =>
      b == null ? '' : importoDaModificare(b.centesimi);

  @override
  void dispose() {
    _importo.dispose();
    super.dispose();
  }

  int? get _centesimi =>
      leggiImporto(_importo.text, decimali: valutaDi(_valuta).decimali);

  void _scegli(bool personale) => setState(() {
    _personale = personale;
    _importo.text = _testoDi(_diPrima);
    _valuta = _diPrima?.valuta ?? widget.mia;
  });

  Future<void> _scegliValuta() async {
    final scelta = await apri<String>(
      context,
      SchermataValuta(scelta: _valuta),
      dalBasso: true,
    );
    if (scelta != null && mounted) setState(() => _valuta = scelta);
  }

  /// Mette o toglie, con il suo evento (07): di chi, e in che stato era il
  /// viaggio. Mai l'importo.
  Future<void> _salva(Budget? budget) async {
    final servizi = Servizi.of(context);
    setState(() => _inCorso = true);
    try {
      if (_personale) {
        await servizi.archivio.mettiBudgetPersonale(widget.viaggio.id, budget);
      } else {
        await servizi.archivio.cambiaBudget(widget.viaggio.id, budget);
      }
      unawaited(
        servizi.misurazione.registra(Eventi.budgetImpostato, {
          'di': _personale ? 'personale' : 'viaggio',
          'stato': widget.viaggio.statoA(DateTime.now()).name,
          'tolto': budget == null,
        }),
      );
      if (mounted) Navigator.of(context).pop();
    } on ErroreTrolley catch (e) {
      if (mounted) mostraMessaggio(context, e.messaggio, errore: true);
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) => ConLaRete(
    builder: (context, rete) {
      final centesimi = _centesimi;
      final motivo = centesimi == null || centesimi <= 0
          ? 'Scrivi quanto'
          : !_personale && !rete
          ? motivoSenzaRete
          : null;
      final idea = !widget.viaggio.statoA(DateTime.now()).haGiorni;
      final parte = widget.laMiaParte;
      return Foglio(
        titolo: idea ? 'Budget di massima' : 'Budget',
        inBasso: AzioniFoglio(
          motivo: motivo,
          azione: PulsanteGrande(
            etichetta: 'Salva',
            inCorso: _inCorso,
            onPressed: motivo == null
                ? () => _salva(Budget(centesimi!, _valuta))
                : null,
          ),
        ),
        children: [
          if (widget.diviso) ...[
            _Scelta(mio: _personale, onCambio: _scegli),
            const SizedBox(height: 16),
          ],
          Campo(
            controller: _importo,
            etichetta: _personale
                ? 'Quanto vuoi spendere tu?'
                : idea
                ? 'Quanto pensate di spendere, più o meno?'
                : 'Quanto pensate di spendere, in tutto?',
            segnaposto: 'Es. 900',
            tastiera: const TextInputType.numberWithOptions(decimal: true),
            fuoco: _diPrima == null,
            onCambia: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          CampoScelta(
            etichetta: 'In che valuta?',
            simbolo: Icons.currency_exchange_rounded,
            segnaposto: 'Scegli la valuta',
            valore: '${valutaDi(_valuta).nome} · $_valuta',
            onTap: _scegliValuta,
          ),
          const SizedBox(height: 14),
          Avviso(
            fondo: Colori.foschia,
            icona: Icons.info_outline_rounded,
            testo: _personale
                ? 'Lo vedi solo tu, ed è solo su questo telefono. Si confronta '
                      'con la tua parte delle spese'
                      '${parte == null ? '' : ': ora sono ${scriviImporto(parte, widget.mia)}'}'
                      '. Quello del viaggio lo vedono tutti, e si confronta '
                      'con il totale.'
                : idea
                ? 'Quando il viaggio avrà le date diventa il metro delle '
                      'spese: si vedrà quanto ne resta, giorno per giorno.'
                : widget.diviso
                ? 'Lo vedono tutti quelli del viaggio, e si confronta con il '
                      'totale delle spese. Il tuo lo vedi solo tu.'
                : 'Si confronta con il totale delle spese, giorno per giorno.',
          ),
          if (_diPrima != null) ...[
            const SizedBox(height: 16),
            PulsanteGrande(
              etichetta: _personale ? 'Togli il tuo budget' : 'Togli il budget',
              secondario: true,
              pericolo: true,
              motivo: !_personale && !rete ? motivoSenzaRete : null,
              onPressed: _inCorso ? null : () => _salva(null),
            ),
          ],
        ],
      );
    },
  );
}

/// Nell'idea, il budget di massima (tela, 136): l'importo, o la riga per
/// metterlo.
class SezioneBudgetIdea extends StatelessWidget {
  const SezioneBudgetIdea({super.key, required this.viaggio});

  final Viaggio viaggio;

  @override
  Widget build(BuildContext context) => ConConto(
    viaggioId: viaggio.id,
    builder: (context, conto) {
      final budget = viaggio.budget;
      final mia = conto?.mia ?? valutaIniziale;
      final diviso = conto?.diviso ?? false;
      void metti() => apriFoglio<void>(
        context,
        FoglioBudget(
          viaggio: viaggio,
          mia: mia,
          personale: false,
          diviso: false,
          delViaggio: budget,
          mioDiPrima: null,
        ),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: TitoloSezione('Budget di massima')),
              if (budget != null)
                PulsantePiccolo(etichetta: 'Cambia', onPressed: metti),
            ],
          ),
          if (budget == null)
            _Aggiungi(onTap: metti)
          else
            Pannello(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    children: [
                      Text(
                        scriviImporto(budget.centesimi, budget.valuta),
                        style: Testi.titoli(26)
                            .copyWith(color: Colori.inchiostro),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          diviso
                              ? 'per tutto il viaggio, insieme'
                              : 'per tutto il viaggio',
                          style: Testi.secondario.copyWith(
                            color: Colori.grafite,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Quando avrà le date diventa il metro delle spese: si '
                    'vedrà quanto ne resta, giorno per giorno.',
                    style: Testi.secondario.copyWith(color: Colori.ardesia),
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
}

/// «Aggiungi un budget di massima», quando non c'è (tela, 136).
class _Aggiungi extends StatelessWidget {
  const _Aggiungi({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Premibile(
    onTap: onTap,
    scala: 0.98,
    etichetta: 'Aggiungi un budget di massima',
    child: ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colori.cenere, width: 2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colori.foschia,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 22,
                color: Colori.inchiostro,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aggiungi un budget di massima',
                    style: Testi.evidenza.copyWith(color: Colori.inchiostro),
                  ),
                  Text(
                    'Quanto pensate di spendere, più o meno',
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
