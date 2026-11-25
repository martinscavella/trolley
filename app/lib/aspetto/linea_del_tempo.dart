/// La giornata come linea del tempo, dalle 0 alle 24 (04, «Gli orari»; tela,
/// 127–131): le ore a sinistra, le tappe come blocchi alti quanto durano, lo
/// spazio libero vuoto, la linea di adesso il giorno stesso. Prima
/// dell'arrivo e dopo la partenza la giornata è chiusa, e lo dice.
///
/// Il cerchio di un blocco segna la tappa (un tocco fatta, tenuto premuto
/// saltata); il blocco toccato si apre, tenuto premuto si trascina a passi di
/// cinque minuti. Dove non può stare diventa rosso, e lasciato lì torna al
/// suo posto. Le regole le dice chi la usa, con [LineaDelTempo.problemaA].
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'formati.dart';
import 'movimento.dart';
import 'tavolozza.dart';
import 'testi.dart';

/// Com'è una tappa sulla linea.
enum AspettoBlocco { daFare, prossima, fatta, saltata, inCoda, fuoriPosto }

class BloccoLinea {
  const BloccoLinea({
    required this.id,
    required this.inizio,
    required this.durata,
    required this.titolo,
    required this.dettaglio,
    required this.aspetto,
    required this.colore,
    required this.etichetta,
    this.proposto = false,
  });

  final String id;
  final Duration inizio;
  final Duration durata;
  final String titolo;
  final String dettaglio;
  final AspettoBlocco aspetto;

  /// Il colore del tipo, nel pallino in alto a destra.
  final Color colore;

  /// Cosa legge VoiceOver.
  final String etichetta;

  /// L'orario non l'ha scelto nessuno: il bordo è tratteggiato.
  final bool proposto;

  Duration get fine => inizio + durata;
}

class LineaDelTempo extends StatefulWidget {
  const LineaDelTempo({
    super.key,
    required this.inizioGiornata,
    required this.fineGiornata,
    required this.blocchi,
    required this.apriA,
    required this.onApri,
    this.adesso,
    this.piede,
    this.onSegna,
    this.onSalta,
    this.problemaA,
    this.onSposta,
    this.onNonSpostabile,
    this.onNuova,
  });

  /// Da quando a quando si può stare: l'arrivo e la partenza, o mezzanotte.
  final Duration inizioGiornata;
  final Duration fineGiornata;
  final List<BloccoLinea> blocchi;

  /// L'ora che si vede in cima aprendo.
  final Duration apriA;

  /// Sotto la mezzanotte, in fondo a quello che scorre: i suggerimenti, e
  /// «Svuota la giornata».
  final Widget? piede;

  /// L'ora di adesso, se è oggi.
  final Duration? adesso;

  final ValueChanged<String> onApri;

  /// Il cerchio: un tocco, e tenuto premuto. `null` se non si segna ancora.
  final ValueChanged<String>? onSegna;
  final ValueChanged<String>? onSalta;

  /// Perché [id] non può cominciare a quell'ora; `null` se può.
  final String? Function(String id, Duration inizio)? problemaA;

  /// Spostare: `null` se non si può (senza rete), e allora tenendo premuto
  /// si chiama [onNonSpostabile].
  final Future<void> Function(String id, Duration inizio)? onSposta;
  final VoidCallback? onNonSpostabile;

  /// Toccato uno spazio libero: una tappa nuova a quell'ora.
  final ValueChanged<Duration>? onNuova;

  /// Quanto è alta un'ora.
  static const ora = 64.0;

  @override
  State<LineaDelTempo> createState() => _LineaDelTempoState();
}

/// Lo spazio delle ore, a sinistra, e sopra e sotto la giornata.
const _ore = 52.0;
const _margine = 10.0;

class _LineaDelTempoState extends State<LineaDelTempo> {
  late final _scorri = ScrollController(
    initialScrollOffset: max(0, _y(widget.apriA) - 24),
  );

  /// La tappa che si sta trascinando, da dove è partita e dove sta.
  String? _preso;
  Duration _da = Duration.zero;
  Duration _a = Duration.zero;

  /// Spostate e non ancora tornate dalla copia: restano dove le si è lasciate.
  final _inViaggio = <String, Duration>{};

  @override
  void didUpdateWidget(LineaDelTempo vecchia) {
    super.didUpdateWidget(vecchia);
    _inViaggio.removeWhere(
      (id, inizio) =>
          widget.blocchi.any((b) => b.id == id && b.inizio == inizio) ||
          !widget.blocchi.any((b) => b.id == id),
    );
  }

  @override
  void dispose() {
    _scorri.dispose();
    super.dispose();
  }

  static double _y(Duration d) =>
      _margine + d.inMinutes / 60 * LineaDelTempo.ora;

  static Duration _ora(double y) =>
      Duration(minutes: ((y - _margine) / LineaDelTempo.ora * 60).round());

  Duration _inizioDi(BloccoLinea b) =>
      b.id == _preso ? _a : _inViaggio[b.id] ?? b.inizio;

  String? get _problema {
    final preso = _preso;
    if (preso == null || _a == _da) return null;
    return widget.problemaA?.call(preso, _a);
  }

  void _prendi(BloccoLinea b, LongPressStartDetails d) {
    if (widget.onSposta == null) {
      widget.onNonSpostabile?.call();
      return;
    }
    HapticFeedback.mediumImpact();
    final da = _inizioDi(b);
    setState(() {
      _preso = b.id;
      _da = da;
      _a = da;
    });
  }

  void _muovi(BloccoLinea b, LongPressMoveUpdateDetails d) {
    if (_preso != b.id) return;
    // La cima del blocco, nelle coordinate della giornata.
    final cima = _y(_da) + d.localOffsetFromOrigin.dy;
    final passo = 5;
    var minuti = (_ora(cima).inMinutes / passo).round() * passo;
    minuti = minuti.clamp(0, 24 * 60 - b.durata.inMinutes);
    final nuovo = Duration(minutes: minuti);
    if (nuovo != _a) {
      // Un tocco del telefono a ogni quarto d'ora attraversato.
      if (nuovo.inMinutes ~/ 15 != _a.inMinutes ~/ 15) {
        HapticFeedback.selectionClick();
      }
      setState(() => _a = nuovo);
    }
    _scorriAiBordi(d.globalPosition);
  }

  /// Vicino al bordo della finestra, la giornata scorre da sola.
  void _scorriAiBordi(Offset dito) {
    final scatola = context.findRenderObject() as RenderBox?;
    if (scatola == null || !_scorri.hasClients) return;
    final y = scatola.globalToLocal(dito).dy;
    const bordo = 48.0;
    final delta = y < bordo
        ? -12.0
        : y > scatola.size.height - bordo
        ? 12.0
        : 0.0;
    if (delta == 0) return;
    final p = _scorri.position;
    _scorri.jumpTo((p.pixels + delta).clamp(0, p.maxScrollExtent));
  }

  Future<void> _lascia(BloccoLinea b) async {
    if (_preso != b.id) return;
    final (da, a, problema) = (_da, _a, _problema);
    setState(() => _preso = null);
    if (a == da) return;
    if (problema != null) {
      HapticFeedback.heavyImpact();
      return;
    }
    HapticFeedback.lightImpact();
    setState(() => _inViaggio[b.id] = a);
    try {
      await widget.onSposta?.call(b.id, a);
    } finally {
      if (mounted) setState(() => _inViaggio.remove(b.id));
    }
  }

  void _tocca(TapUpDetails d) {
    final nuova = widget.onNuova;
    if (nuova == null) return;
    final minuti = _ora(d.localPosition.dy).inMinutes;
    if (minuti < 0 || minuti >= 24 * 60) return;
    final ora = Duration(minutes: minuti - minuti % 15);
    if (ora < widget.inizioGiornata || ora >= widget.fineGiornata) return;
    final occupata = widget.blocchi.any(
      (b) => _inizioDi(b) <= ora && b.inizio + b.durata > ora,
    );
    if (!occupata) nuova(ora);
  }

  @override
  Widget build(BuildContext context) {
    final alto = _y(const Duration(hours: 24)) + _margine;
    // È la sola cosa che scorre nella giornata: una linea che scorre dentro
    // una pagina che scorre ruberebbe il dito alla pagina.
    return SingleChildScrollView(
      controller: _scorri,
      physics: _preso == null
          ? const AlwaysScrollableScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: ColoredBox(
              color: Colori.bianco,
              child: LayoutBuilder(
                builder: (context, vincoli) => SizedBox(
                  height: alto,
                  child: _giornata(context, vincoli.maxWidth),
                ),
              ),
            ),
          ),
          ?widget.piede,
        ],
      ),
    );
  }

  Widget _giornata(BuildContext context, double larghezza) {
    final area = larghezza - _ore - 10;
    final colonne = _colonne([
      for (final b in widget.blocchi) (b.id, _inizioDi(b), b.durata),
    ], escluso: _preso);
    final ridotto = movimentoRidotto(context);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapUp: _tocca,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var h = 0; h <= 24; h++) ...[
            Positioned(
              left: _ore,
              right: 0,
              top: _y(Duration(hours: h)),
              height: 1,
              child: const ColoredBox(color: Color(0xFFEEF0F5)),
            ),
            if (h < 24)
              Positioned(
                left: 10,
                top: _y(Duration(hours: h)) - 7,
                child: ExcludeSemantics(
                  child: Text(
                    ora(Duration(hours: h)),
                    style: Testi.titoli(
                      10,
                      peso: 600,
                      spaziatura: 0,
                    ).copyWith(color: const Color(0xFF8A90A2)),
                  ),
                ),
              ),
          ],
          if (widget.inizioGiornata > Duration.zero)
            _chiuso(
              da: Duration.zero,
              a: widget.inizioGiornata,
              testo: 'Arrivi alle ${ora(widget.inizioGiornata)}',
              sopra: true,
            ),
          if (widget.fineGiornata < const Duration(hours: 24))
            _chiuso(
              da: widget.fineGiornata,
              a: const Duration(hours: 24),
              testo: 'Riparti alle ${ora(widget.fineGiornata)}',
              sopra: false,
            ),
          for (final b in widget.blocchi)
            if (b.id != _preso) _posizionato(b, colonne[b.id]!, area, ridotto),
          // Quella che si trascina sta sopra tutte, a larghezza piena.
          for (final b in widget.blocchi)
            if (b.id == _preso) _posizionato(b, (0, 1), area, ridotto),
          if (widget.adesso case final adesso?) ..._adesso(adesso),
        ],
      ),
    );
  }

  Widget _chiuso({
    required Duration da,
    required Duration a,
    required String testo,
    required bool sopra,
  }) => Positioned(
    left: _ore,
    right: 8,
    top: _y(da),
    height: _y(a) - _y(da),
    child: CustomPaint(
      painter: const _Tratteggio(),
      child: Align(
        alignment: sopra ? Alignment.bottomCenter : Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            testo,
            style: Testi.didascalia.copyWith(
              color: Colori.ardesia,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    ),
  );

  List<Widget> _adesso(Duration adesso) {
    final y = _y(adesso);
    return [
      Positioned(
        left: _ore - 6,
        right: 0,
        top: y - 1,
        height: 2,
        child: const ColoredBox(color: Colori.pericolo),
      ),
      Positioned(
        left: _ore - 11,
        top: y - 5,
        child: Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: Colori.pericolo,
            shape: BoxShape.circle,
          ),
        ),
      ),
      Positioned(
        left: 4,
        top: y - 9,
        child: Semantics(
          label: 'Adesso, ${ora(adesso)}',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colori.pericolo,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              ora(adesso),
              style: Testi.titoli(
                9,
                peso: 600,
                spaziatura: 0,
              ).copyWith(color: Colori.bianco),
            ),
          ),
        ),
      ),
    ];
  }

  Widget _posizionato(
    BloccoLinea b,
    (int, int) colonna,
    double area,
    bool ridotto,
  ) {
    final preso = b.id == _preso;
    final inizio = _inizioDi(b);
    final (indice, quante) = colonna;
    final largo = area / quante;
    final top = _y(inizio) + 1.5;
    final alto = max(b.durata.inMinutes / 60 * LineaDelTempo.ora - 3, 14.0);
    final problema = preso ? _problema : null;
    return AnimatedPositioned(
      key: ValueKey(b.id),
      duration: preso || ridotto ? Duration.zero : Ritmo.medio,
      curve: Ritmo.molla,
      left: _ore + 8 + indice * largo,
      width: largo - (quante > 1 ? 4 : 0),
      top: top,
      height: alto,
      child: AnimatedScale(
        scale: preso && !ridotto ? 1.03 : 1,
        duration: Ritmo.breve,
        child: _Blocco(
          blocco: b,
          inizio: inizio,
          preso: preso,
          problema: problema,
          rosso: problema != null || b.aspetto == AspettoBlocco.fuoriPosto,
          onApri: () => widget.onApri(b.id),
          onSegna: widget.onSegna == null ? null : () => widget.onSegna!(b.id),
          onSalta: widget.onSalta == null ? null : () => widget.onSalta!(b.id),
          onPrendi: (d) => _prendi(b, d),
          onMuovi: (d) => _muovi(b, d),
          onLascia: () => unawaited(_lascia(b)),
          onSpostaDi: widget.onSposta == null
              ? null
              : (delta) {
                  final a = inizio + delta;
                  if (widget.problemaA?.call(b.id, a) != null) return;
                  unawaited(widget.onSposta!(b.id, a));
                },
        ),
      ),
    );
  }

  /// Le tappe che si sovrappongono stanno affiancate: per ognuna, in quale
  /// colonna e su quante.
  static Map<String, (int, int)> _colonne(
    List<(String, Duration, Duration)> blocchi, {
    String? escluso,
  }) {
    final ordinati = [
      for (final b in blocchi)
        if (b.$1 != escluso) b,
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    final dove = <String, (int, int)>{};
    var gruppo = <(String, Duration, Duration)>[];
    var fineGruppo = Duration.zero;
    void chiudi() {
      final fini = <Duration>[];
      final colonna = <String, int>{};
      for (final b in gruppo) {
        var c = fini.indexWhere((f) => f <= b.$2);
        if (c < 0) {
          fini.add(Duration.zero);
          c = fini.length - 1;
        }
        fini[c] = b.$2 + b.$3;
        colonna[b.$1] = c;
      }
      for (final b in gruppo) {
        dove[b.$1] = (colonna[b.$1]!, fini.length);
      }
      gruppo = [];
    }

    for (final b in ordinati) {
      if (gruppo.isNotEmpty && b.$2 >= fineGruppo) chiudi();
      gruppo.add(b);
      final fine = b.$2 + b.$3;
      if (gruppo.length == 1 || fine > fineGruppo) fineGruppo = fine;
    }
    if (gruppo.isNotEmpty) chiudi();
    for (final b in blocchi) {
      dove.putIfAbsent(b.$1, () => (0, 1));
    }
    return dove;
  }
}

class _Blocco extends StatelessWidget {
  const _Blocco({
    required this.blocco,
    required this.inizio,
    required this.preso,
    required this.problema,
    required this.rosso,
    required this.onApri,
    required this.onSegna,
    required this.onSalta,
    required this.onPrendi,
    required this.onMuovi,
    required this.onLascia,
    required this.onSpostaDi,
  });

  final BloccoLinea blocco;
  final Duration inizio;
  final bool preso;
  final String? problema;
  final bool rosso;
  final VoidCallback onApri;
  final VoidCallback? onSegna;
  final VoidCallback? onSalta;
  final GestureLongPressStartCallback onPrendi;
  final GestureLongPressMoveUpdateCallback onMuovi;
  final VoidCallback onLascia;
  final ValueChanged<Duration>? onSpostaDi;

  @override
  Widget build(BuildContext context) {
    final b = blocco;
    final aspetto = rosso ? AspettoBlocco.fuoriPosto : b.aspetto;
    final prossima = aspetto == AspettoBlocco.prossima;
    final (fondo, bordo, testo, dettaglio) = switch (aspetto) {
      AspettoBlocco.prossima => (
        Colori.cobalto,
        Colori.cobalto,
        Colori.bianco,
        Colori.bianco.withValues(alpha: 0.85),
      ),
      AspettoBlocco.fatta => (
        Colori.menta,
        Colori.menta,
        Colori.inchiostro,
        const Color(0xFF2F5A49),
      ),
      AspettoBlocco.saltata => (
        Colori.foschia,
        Colori.foschia,
        Colori.grafite,
        Colori.grafite,
      ),
      AspettoBlocco.fuoriPosto => (
        Colori.rosa,
        Colori.pericolo,
        Colori.inchiostro,
        Colori.pericolo,
      ),
      AspettoBlocco.daFare || AspettoBlocco.inCoda => (
        const Color(0xFFF4F6FB),
        Colori.cenere,
        Colori.inchiostro,
        Colori.grafite,
      ),
    };
    final tratteggiato =
        !rosso && (b.aspetto == AspettoBlocco.inCoda || b.proposto);
    final quando = '${ora(inizio)}–${ora(inizio + b.durata)}';
    final descrizione = preso ? [quando, ?problema].join(' · ') : b.dettaglio;
    final corto = b.durata < const Duration(minutes: 45);

    return Semantics(
      button: true,
      label: preso ? '${b.etichetta}, $descrizione' : b.etichetta,
      onTapHint: 'aprirla',
      customSemanticsActions: {
        CustomSemanticsAction(
          label: b.aspetto == AspettoBlocco.fatta
              ? 'Riportala da fare'
              : 'Segnala fatta',
        ): ?onSegna,
        const CustomSemanticsAction(label: 'Saltala'): ?onSalta,
        if (onSpostaDi != null) ...{
          const CustomSemanticsAction(label: 'Un quarto d\'ora prima'): () =>
              onSpostaDi!(const Duration(minutes: -15)),
          const CustomSemanticsAction(label: 'Un quarto d\'ora dopo'): () =>
              onSpostaDi!(const Duration(minutes: 15)),
        },
      },
      child: GestureDetector(
        onTap: onApri,
        onLongPressStart: onPrendi,
        onLongPressMoveUpdate: onMuovi,
        onLongPressEnd: (_) => onLascia(),
        onLongPressCancel: onLascia,
        child: CustomPaint(
          foregroundPainter: tratteggiato
              ? _BordoTratteggiato(b.proposto ? Colori.cobalto : Colori.grafite)
              : null,
          child: AnimatedContainer(
            duration: Ritmo.breve,
            padding: EdgeInsets.symmetric(
              horizontal: 8,
              vertical: corto ? 0 : 6,
            ),
            decoration: BoxDecoration(
              color: fondo,
              borderRadius: BorderRadius.circular(14),
              border: tratteggiato ? null : Border.all(color: bordo, width: 2),
              boxShadow: preso
                  ? [
                      BoxShadow(
                        color: Colori.inchiostro.withValues(alpha: 0.28),
                        blurRadius: 28,
                        offset: const Offset(0, 14),
                      ),
                    ]
                  : null,
            ),
            child: ExcludeSemantics(
              child: Row(
                crossAxisAlignment: corto
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  _Cerchio(
                    aspetto: aspetto,
                    fatta: b.aspetto == AspettoBlocco.fatta,
                    saltata: b.aspetto == AspettoBlocco.saltata,
                    piccolo: corto,
                    onSegna: onSegna,
                    onSalta: onSalta,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    // Quante righe stanno nell'altezza della tappa: il
                    // titolo su due se c'è posto, il dettaglio se ne resta.
                    child: LayoutBuilder(
                      builder: (context, vincoli) {
                        final scala = MediaQuery.textScalerOf(context);
                        final riga = scala.scale(14) * 1.2;
                        final sotto = scala.scale(12) * 1.4;
                        final alto = vincoli.maxHeight;
                        final conSotto = !corto && alto >= riga + sotto;
                        final righe = ((alto - (conSotto ? sotto : 0)) / riga)
                            .floor()
                            .clamp(1, 2);
                        return ClipRect(
                          child: OverflowBox(
                            alignment: corto
                                ? Alignment.centerLeft
                                : Alignment.topLeft,
                            maxHeight: double.infinity,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  b.titolo,
                                  maxLines: righe,
                                  overflow: TextOverflow.ellipsis,
                                  style: Testi.evidenza.copyWith(
                                    color: testo,
                                    fontSize: 14,
                                    height: 1.2,
                                    decoration:
                                        b.aspetto == AspettoBlocco.saltata
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                if (conSotto)
                                  Text(
                                    descrizione,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Testi.didascalia.copyWith(
                                      color: preso && problema != null
                                          ? Colori.pericolo
                                          : dettaglio,
                                      fontSize: 12,
                                      fontWeight: preso || rosso
                                          ? FontWeight.w600
                                          : null,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: corto ? 0 : 4),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: prossima ? Colori.bianco : b.colore,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Il cerchio che segna: vuoto da fare, verde con la spunta fatta, grigio
/// con il trattino saltata.
class _Cerchio extends StatelessWidget {
  const _Cerchio({
    required this.aspetto,
    required this.fatta,
    required this.saltata,
    required this.piccolo,
    required this.onSegna,
    required this.onSalta,
  });

  final AspettoBlocco aspetto;
  final bool fatta;
  final bool saltata;
  final bool piccolo;
  final VoidCallback? onSegna;
  final VoidCallback? onSalta;

  @override
  Widget build(BuildContext context) {
    final lato = piccolo ? 20.0 : 26.0;
    final prossima = aspetto == AspettoBlocco.prossima;
    final cerchio = Container(
      width: lato,
      height: lato,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fatta
            ? Colori.verde
            : saltata
            ? Colori.piombo
            : prossima
            ? Colori.bianco.withValues(alpha: 0.15)
            : Colori.bianco,
        border: fatta || saltata
            ? null
            : Border.all(
                color: prossima ? Colori.bianco : Colori.inchiostro,
                width: 2.5,
              ),
      ),
      child: fatta
          ? Icon(Icons.check_rounded, size: lato * 0.6, color: Colori.bianco)
          : saltata
          ? Icon(Icons.remove_rounded, size: lato * 0.6, color: Colori.bianco)
          : null,
    );
    if (onSegna == null) return cerchio;
    // Più largo del cerchio, perché si prenda col dito.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onSegna,
      onLongPress: onSalta,
      child: Padding(padding: const EdgeInsets.all(4), child: cerchio),
    );
  }
}

/// Il bordo di una tappa in coda, o con l'orario proposto.
class _BordoTratteggiato extends CustomPainter {
  const _BordoTratteggiato(this.colore);

  final Color colore;

  @override
  void paint(Canvas canvas, Size size) {
    final forma = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(1),
          const Radius.circular(14),
        ),
      );
    final pennello = Paint()
      ..color = colore
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final m in forma.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 9) {
        canvas.drawPath(m.extractPath(d, min(d + 5, m.length)), pennello);
      }
    }
  }

  @override
  bool shouldRepaint(_BordoTratteggiato vecchio) => vecchio.colore != colore;
}

/// La giornata chiusa, prima dell'arrivo e dopo la partenza.
class _Tratteggio extends CustomPainter {
  const _Tratteggio();

  @override
  void paint(Canvas canvas, Size size) {
    final forma = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(12),
    );
    canvas
      ..save()
      ..clipRRect(forma)
      ..drawRRect(forma, Paint()..color = const Color(0xFFF4F5F8));
    final righe = Paint()
      ..color = const Color(0xFFE3E6EE)
      ..strokeWidth = 4;
    for (var d = -size.height; d < size.width; d += 12) {
      canvas.drawLine(
        Offset(d, size.height),
        Offset(d + size.height, 0),
        righe,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Tratteggio vecchio) => false;
}
