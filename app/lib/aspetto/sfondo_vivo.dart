import 'dart:math';

import 'package:flutter/widgets.dart';

import 'movimento.dart';

/// Uno sfondo che respira: macchie di colore che si spostano piano, come una
/// luce che cambia. Per le schermate d'ingresso, dove non c'è ancora niente
/// di tuo da mostrare. Con "Riduci movimento" resta fermo.
class SfondoVivo extends StatefulWidget {
  const SfondoVivo({super.key});

  @override
  State<SfondoVivo> createState() => _SfondoVivoState();
}

class _SfondoVivoState extends State<SfondoVivo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tempo = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 26),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (movimentoRidotto(context)) {
      _tempo.stop();
    } else if (!_tempo.isAnimating) {
      _tempo.repeat();
    }
  }

  @override
  void dispose() {
    _tempo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scuro = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    return RepaintBoundary(
      child: CustomPaint(
        painter: _Aurora(_tempo, scuro: scuro),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _Macchia {
  const _Macchia(this.colore, this.x, this.y, this.raggio, this.fase);

  final Color colore;

  /// Centro, in frazioni della superficie.
  final double x;
  final double y;

  /// In frazioni del lato più lungo.
  final double raggio;
  final double fase;
}

const _macchie = [
  _Macchia(Color(0xFFFF8A65), 0.88, 0.12, 0.55, 0),
  _Macchia(Color(0xFF4FC3F7), 0.08, 0.32, 0.60, 2.1),
  _Macchia(Color(0xFF7CF3C4), 0.62, 0.70, 0.50, 4.2),
  _Macchia(Color(0xFF9575CD), 0.18, 0.92, 0.45, 1.3),
];

class _Aurora extends CustomPainter {
  _Aurora(this.tempo, {required this.scuro}) : super(repaint: tempo);

  final Animation<double> tempo;
  final bool scuro;

  @override
  void paint(Canvas canvas, Size size) {
    final area = Offset.zero & size;
    canvas.drawRect(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: scuro
              ? const [Color(0xFF04261D), Color(0xFF0B1B36)]
              : const [Color(0xFF0E9A6F), Color(0xFF1D5FAE)],
        ).createShader(area),
    );

    final angolo = tempo.value * 2 * pi;
    for (final m in _macchie) {
      final centro = Offset(
        size.width * (m.x + 0.09 * sin(angolo + m.fase)),
        size.height * (m.y + 0.06 * cos(angolo * 2 + m.fase)),
      );
      final raggio = size.longestSide * m.raggio;
      final intensita = scuro ? 0.45 : 0.7;
      canvas.drawCircle(
        centro,
        raggio,
        Paint()
          ..shader = RadialGradient(
            colors: [
              m.colore.withValues(alpha: intensita),
              m.colore.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: centro, radius: raggio)),
      );
    }
  }

  @override
  bool shouldRepaint(_Aurora vecchio) => vecchio.scuro != scuro;
}
