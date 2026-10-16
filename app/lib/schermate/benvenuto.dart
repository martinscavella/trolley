import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../aspetto/elementi.dart';
import '../aspetto/marchio.dart';
import '../aspetto/movimento.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';

/// L'impaginazione dell'accesso, come "1 · Accesso" della tela: la testata
/// cobalto con il logo in bianco e il percorso a puntini, e una scheda bianca
/// con i campi che le sale sopra. Sotto, una nota.
class LayoutBenvenuto extends StatelessWidget {
  const LayoutBenvenuto({super.key, this.scheda, this.nota});

  final Widget? scheda;

  /// In fondo, piccola e centrata.
  final String? nota;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Colori.nebbia,
            body: LayoutBuilder(
              builder: (context, vincoli) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: vincoli.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _Testata(),
                        if (scheda != null)
                          Transform.translate(
                            offset: const Offset(0, -36),
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                24,
                                20,
                                24,
                              ),
                              decoration: BoxDecoration(
                                color: Colori.bianco,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colori.inchiostro.withValues(
                                      alpha: 0.12,
                                    ),
                                    blurRadius: 40,
                                    offset: const Offset(0, 16),
                                  ),
                                ],
                              ),
                              child: scheda!,
                            ),
                          ).entra(context, ritardo: Ritmo.passo * 3, da: 40),
                        const Spacer(),
                        if (nota != null)
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              36,
                              24,
                              36,
                              MediaQuery.paddingOf(context).bottom + 24,
                            ),
                            child: Text(
                              nota!,
                              textAlign: TextAlign.center,
                              style: Testi.didascalia.copyWith(
                                color: Colori.grafite,
                              ),
                            ),
                          ).entra(context, ritardo: Ritmo.passo * 4),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Il logo, la frase e il percorso a puntini, sul cobalto.
class _Testata extends StatelessWidget {
  const _Testata();

  @override
  Widget build(BuildContext context) {
    final sopra = MediaQuery.paddingOf(context).top;
    return Container(
      height: 340 + sopra - 20,
      color: Colori.cobalto,
      child: Stack(
        children: [
          Positioned.fill(
            top: sopra - 20,
            child: const CustomPaint(painter: _Percorso()),
          ),
          Padding(
            // Il logo è più alto della scritta della tela: parte un po' più
            // su, e la frase resta dov'era.
            padding: EdgeInsets.fromLTRB(28, sopra + 46, 28, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Marchio().entra(context, da: 10),
                const SizedBox(height: 12),
                const SizedBox(height: 2),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 250),
                  child: Text(
                    'Dall\'idea al ritorno, con chi viaggia con te.',
                    style: Testi.corpo.copyWith(
                      color: Colori.bianco.withValues(alpha: 0.92),
                      fontSize: 17,
                      height: 1.4,
                    ),
                  ),
                ).entra(context, ritardo: Ritmo.passo),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Il percorso a puntini della tela, su 390×340: parte da un punto giallo,
/// quello dell'idea, e passa per due tappe bianche.
class _Percorso extends CustomPainter {
  const _Percorso();

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 390;
    final sy = size.height / 340;
    Offset p(double x, double y) => Offset(x * sx, y * sy);
    final a = p(-10, 290);
    final percorso = Path()
      ..moveTo(a.dx, a.dy)
      ..cubicTo(60 * sx, 230 * sy, 110 * sx, 300 * sy, 190 * sx, 250 * sy)
      // La "S" della tela: il primo punto di controllo è il riflesso del
      // precedente.
      ..cubicTo(270 * sx, 200 * sy, 320 * sx, 170 * sy, 410 * sx, 215 * sy);
    final tratto = Paint()
      ..color = Colori.bianco.withValues(alpha: 0.6)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (final metrica in percorso.computeMetrics()) {
      for (var d = 0.0; d < metrica.length; d += 12) {
        final punto = metrica.getTangentForOffset(d)?.position;
        if (punto != null) {
          canvas.drawLine(punto, punto.translate(0.01, 0), tratto);
        }
      }
    }
    canvas
      ..drawCircle(p(78, 262), 9, Paint()..color = Colori.sole)
      ..drawCircle(p(214, 236), 7, Paint()..color = Colori.bianco)
      ..drawCircle(p(330, 192), 7, Paint()..color = Colori.bianco);
  }

  @override
  bool shouldRepaint(_Percorso vecchio) => false;
}

/// Il primo istante: l'avvio animato del marchio, sul bianco, mentre si
/// capisce se c'è già un accesso. Si va avanti quando sono finiti tutti e due;
/// se l'app ci mette più dell'animazione, sotto il logo aspetta la valigia.
class SchermataAvvio extends StatefulWidget {
  const SchermataAvvio({
    super.key,
    this.pronta = false,
    this.onAnimazioneFinita,
  });

  /// L'app sa già dove andare: a fine animazione non serve la valigia.
  final bool pronta;

  final VoidCallback? onAnimazioneFinita;

  @override
  State<SchermataAvvio> createState() => _SchermataAvvioState();
}

class _SchermataAvvioState extends State<SchermataAvvio> {
  static const _valigia = 72.0;

  bool _finita = false;

  void _fine() {
    setState(() => _finita = true);
    widget.onAnimazioneFinita?.call();
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark,
    child: ColoredBox(
      color: Colori.bianco,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sopra lo stesso spazio della valigia, così il logo resta al
                // centro e non salta quando lei compare.
                const SizedBox(height: _valigia + 16),
                AvvioAnimato(onFinito: _fine),
                const SizedBox(height: 16),
                SizedBox.square(
                  dimension: _valigia,
                  child: _finita && !widget.pronta
                      ? const ValigiaCheAspetta(dimensione: _valigia)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Primo ingresso su questo telefono, e manca la rete per sapere chi sei.
class SchermataSenzaRete extends StatelessWidget {
  const SchermataSenzaRete({super.key, required this.onRiprova});

  final VoidCallback onRiprova;

  @override
  Widget build(BuildContext context) => LayoutBenvenuto(
    scheda: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Serve la connessione',
          style: Testi.titoloSezione.copyWith(color: Colori.inchiostro),
        ),
        const SizedBox(height: 8),
        Text(
          'È la prima volta che entri da questo telefono: per scaricare i tuoi '
          'viaggi serve la rete. Dopo, li potrai leggere anche offline.',
          style: Testi.corpo.copyWith(color: Colori.grafite),
        ),
        const SizedBox(height: 16),
        Avviso(
          icona: icona(ios: CupertinoIcons.wifi_slash, android: Icons.wifi_off),
          inizio: 'Sei offline.',
          testo: 'Controlla il Wi-Fi o i dati, poi riprova.',
        ),
        const SizedBox(height: 20),
        PulsanteGrande(etichetta: 'Riprova', onPressed: onRiprova),
      ],
    ),
  );
}
