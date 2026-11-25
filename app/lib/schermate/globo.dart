import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../aspetto/formati.dart';
import '../aspetto/mappamondo.dart';
import '../aspetto/movimento.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../dati/database.dart';
import '../dati/destinazioni.dart';
import '../dominio/mappa.dart';
import 'passaporto.dart';

/// Il mappamondo a tutto schermo (tela, 146–149): la Terra disegnata, con
/// il giorno e la notte di adesso. Non è una pagina nuova: è lo stesso globo
/// che cresce dal suo posto. Allargando con due dita il mappamondo piccolo,
/// questo parte da dove sta quello e segue le dita; lasciato, si apre del
/// tutto o torna giù, con la velocità che avevano. Si richiude stringendo le
/// dita quando è già lontano, con la croce, o con «indietro»: scende al posto
/// del piccolo, e il piccolo ricompare.
///
/// Si gira col dito e si avvicina con due dita o con un doppio tocco; con
/// VoiceOver, scorrendo su e giù. Da vicino la Terra riempie lo schermo, e
/// un paese si sceglie tenendolo premuto: il globo ci vola, il paese si
/// accende e sotto compare la sua scheda, con i viaggi che ci hai fatto, o
/// «Non ancora». Si legge dalla copia: funziona anche senza rete.
class SchermataGlobo extends StatefulWidget {
  const SchermataGlobo({
    super.key,
    required this.globo,
    required this.apertura,
    required this.da,
    required this.onChiuso,
    required this.viaggi,
    required this.grattati,
    required this.daScoprire,
    required this.punti,
    required this.centro,
    required this.inOrdine,
    required this.quanti,
  });

  /// Il globo, che la schermata del mappamondo muove con le dita che
  /// allargano quello piccolo.
  final GlobalKey<StatoMappamondo> globo;

  /// Quanto è aperto: 0 al posto del globo piccolo, [da]; 1 a tutto schermo.
  final AnimationController apertura;
  final Disco? da;

  /// Tornato al posto del globo piccolo.
  final VoidCallback onChiuso;

  /// I viaggi del passaporto, dal più recente.
  final List<(Partecipazione, Viaggio)> viaggi;

  /// I paesi accesi sul globo.
  final Set<String> grattati;

  /// Quelli ancora sotto la patina: si grattano nel mappamondo, non qui.
  final Set<String> daScoprire;

  final Map<String, Coordinate> punti;

  /// Dove guardava il globo piccolo quando si è aperto.
  final Coordinate centro;

  /// I paesi nell'ordine in cui ci si è stati la prima volta: «il tuo 3°».
  final List<String> inOrdine;

  /// «7 paesi · 15 città».
  final String quanti;

  @override
  State<SchermataGlobo> createState() => _SchermataGloboState();
}

class _SchermataGloboState extends State<SchermataGlobo> {
  /// Il paese tenuto premuto, con la sua scheda.
  String? _scelto;

  void _scegli(String? paese) {
    if (paese == null || paese == '--') {
      setState(() => _scelto = null);
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _scelto = paese);
    widget.globo.currentState?.vola(paese);
  }

  void _chiudi() {
    setState(() => _scelto = null);
    widget.globo.currentState?.chiudi();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: BlockSemantics(
        child: AnimatedBuilder(
          animation: widget.apertura,
          builder: (context, globo) {
            final t = widget.apertura.value.clamp(0.0, 1.0);
            // La croce, i numeri e le parole arrivano alla fine, e se ne
            // vanno per primi.
            final sopra = const Interval(0.65, 1).transform(t);
            final scelto = _scelto;
            return Stack(
              children: [
                // La notte sale da sotto il globo e copre tutto, barra
                // compresa.
                Positioned.fill(
                  child: IgnorePointer(
                    child: ColoredBox(
                      color: Colori.inchiostro.withValues(alpha: t),
                    ),
                  ),
                ),
                Positioned.fill(child: globo!),
                Positioned(
                  top: mq.padding.top + 8,
                  left: 20,
                  right: 20,
                  child: IgnorePointer(
                    ignoring: sopra < 1,
                    child: Opacity(
                      opacity: sopra,
                      child: Row(
                        children: [
                          _Tondo(
                            etichetta: 'Chiudi',
                            onTap: _chiudi,
                            child: Icon(
                              icona(
                                ios: CupertinoIcons.xmark,
                                android: Icons.close_rounded,
                              ),
                              size: 22,
                              color: Colori.bianco,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            widget.quanti,
                            style: Testi.titoli(15)
                                .copyWith(color: Colori.bianco),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (scelto == null)
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: mq.padding.bottom + 28,
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: sopra,
                        child: Text(
                          'Giralo col dito, avvicinati con due dita o con un '
                          'doppio tocco. Tieni premuto un paese per vederne i '
                          'viaggi; stringi le dita per tornare.',
                          textAlign: TextAlign.center,
                          style: Testi.secondario.copyWith(
                            color: Colori.bianco.withValues(alpha: 0.65),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: mq.padding.bottom + 12,
                    child: _SchedaPaese(
                      key: ValueKey(scelto),
                      paese: scelto,
                      viaggi: [
                        for (final pv in widget.viaggi)
                          if (pv.$2.destinazionePaese == scelto) pv,
                      ],
                      daGrattare: widget.daScoprire.contains(scelto),
                      numero: widget.inOrdine.indexOf(scelto) + 1,
                      altezzaMassima: mq.size.height * 0.42,
                      onChiudi: () => setState(() => _scelto = null),
                    ).entra(context, da: 60),
                  ),
              ],
            );
          },
          // Da vicino la Terra riempie lo schermo, senza il contorno del
          // globo (tela, 147).
          child: Mappamondo(
            key: widget.globo,
            grattati: widget.grattati,
            centro: widget.centro,
            punti: widget.punti,
            avvicinabile: true,
            pienoSchermo: true,
            giraDaSolo: true,
            apertura: widget.apertura,
            da: widget.da,
            onChiuso: widget.onChiuso,
            scelto: _scelto,
            // Un paese si sceglie tenendolo premuto; un tocco chiude la sua
            // scheda.
            onTieniPremuto: _scegli,
            onTocca: (_) {
              if (_scelto != null) setState(() => _scelto = null);
            },
            latoMassimo: mq.size.width,
            etichetta:
                'Mappamondo a tutto schermo: ${widget.quanti}. '
                'Tieni premuto un paese per vederne i viaggi.',
          ),
        ),
      ),
    );
  }
}

/// Un pulsante tondo e velato sulla notte.
class _Tondo extends StatelessWidget {
  const _Tondo({
    required this.etichetta,
    required this.onTap,
    required this.child,
  });

  final String etichetta;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Premibile(
    onTap: onTap,
    scala: 0.9,
    etichetta: etichetta,
    child: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colori.bianco.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Center(child: child),
    ),
  );
}

/// La scheda di un paese toccato (tela, 147–148): il timbro del codice, il
/// nome, e i biglietti dei viaggi che ci hai fatto; per un paese mai visto,
/// il timbro tratteggiato e «Non ancora». Si chiude trascinandola giù.
class _SchedaPaese extends StatelessWidget {
  const _SchedaPaese({
    super.key,
    required this.paese,
    required this.viaggi,
    required this.daGrattare,
    required this.numero,
    required this.altezzaMassima,
    required this.onChiudi,
  });

  final String paese;
  final List<(Partecipazione, Viaggio)> viaggi;
  final bool daGrattare;

  /// Il suo posto fra i paesi visti; 0 se non ci sei stato.
  final int numero;
  final double altezzaMassima;
  final VoidCallback onChiudi;

  @override
  Widget build(BuildContext context) {
    final visto = viaggi.isNotEmpty;
    final citta = {for (final (_, v) in viaggi) ?v.destinazioneCitta};
    final sotto = !visto
        ? 'Non ancora: si accende con il primo viaggio chiuso qui.'
        : daGrattare
        ? 'Un paese nuovo: grattalo sul mappamondo.'
        : [
            if (numero > 0) 'Il tuo $numero° paese',
            quanti(viaggi.length, 'viaggio', 'viaggi'),
            if (citta.isNotEmpty) citta.join(', '),
          ].join(' · ');
    return GestureDetector(
      onVerticalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) > 200) onChiudi();
      },
      child: Container(
        constraints: BoxConstraints(maxHeight: altezzaMassima),
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        decoration: BoxDecoration(
          color: Colori.bianco,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colori.cenere,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              label: '${nomeDelPaese(paese) ?? paese}. $sotto',
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    _TimbroPaese(codice: paese, visto: visto),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nomeDelPaese(paese) ?? paese,
                            style: Testi.titoli(20)
                                .copyWith(color: Colori.inchiostro),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            sotto,
                            style: Testi.secondario.copyWith(
                              color: Colori.grafite,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (visto) ...[
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: [
                    for (final (p, v) in viaggi)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: v.importato
                            ? PaginaPassata(viaggio: v)
                            : PaginaPassaporto(
                                viaggio: v,
                                verificato: p.verificato == true,
                              ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Il codice del paese in un timbro tondo, un po' storto: cobalto se ci sei
/// stato, grigio e tratteggiato se no.
class _TimbroPaese extends StatelessWidget {
  const _TimbroPaese({required this.codice, required this.visto});

  final String codice;
  final bool visto;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: -0.1,
    child: CustomPaint(
      painter: _Cerchio(visto ? Colori.cobalto : Colori.piombo, visto),
      child: SizedBox.square(
        dimension: 54,
        child: Center(
          child: Text(
            codice,
            style: Testi.codice(17)
                .copyWith(color: visto ? Colori.cobalto : Colori.grafite),
          ),
        ),
      ),
    ),
  );
}

class _Cerchio extends CustomPainter {
  const _Cerchio(this.colore, this.pieno);

  final Color colore;
  final bool pieno;

  @override
  void paint(Canvas canvas, Size size) {
    final tratto = Paint()
      ..color = colore
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    final r = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.shortestSide / 2 - 1.5,
    );
    if (pieno) {
      canvas.drawOval(r, tratto);
      return;
    }
    // Tratteggiato: 18 trattini.
    const trattini = 18;
    for (var i = 0; i < trattini; i++) {
      canvas.drawArc(r, i * 2 * pi / trattini, pi / trattini, false, tratto);
    }
  }

  @override
  bool shouldRepaint(_Cerchio vecchio) =>
      vecchio.colore != colore || vecchio.pieno != pieno;
}
