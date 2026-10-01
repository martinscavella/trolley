/// Come si muove l'app: poche durate e poche curve, così si muove in un modo solo.
///
/// Ogni movimento rispetta "Riduci movimento" (iOS) e "Rimuovi animazioni"
/// (Android): con l'impostazione attiva le cose compaiono e basta.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

bool movimentoRidotto(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

abstract final class Ritmo {
  static const breve = Duration(milliseconds: 180);
  static const medio = Duration(milliseconds: 380);
  static const lungo = Duration(milliseconds: 560);

  /// Il ritardo fra un elemento e il successivo di un elenco che entra.
  static const passo = Duration(milliseconds: 70);

  static const curva = Curves.easeOutCubic;
  static const molla = Curves.easeOutBack;
}

extension Movimento on Widget {
  /// Entra dal basso sfumando.
  Widget entra(
    BuildContext context, {
    Duration ritardo = Duration.zero,
    double da = 18,
  }) {
    if (movimentoRidotto(context)) return this;
    return animate(delay: ritardo)
        .fadeIn(duration: Ritmo.medio, curve: Ritmo.curva)
        .moveY(begin: da, end: 0, duration: Ritmo.lungo, curve: Ritmo.curva);
  }

  /// Compare crescendo con un piccolo rimbalzo: per gli elementi piccoli.
  Widget sboccia(BuildContext context, {Duration ritardo = Duration.zero}) {
    if (movimentoRidotto(context)) return this;
    return animate(delay: ritardo)
        .fadeIn(duration: Ritmo.breve)
        .scaleXY(begin: 0.6, end: 1, duration: Ritmo.medio, curve: Ritmo.molla);
  }

  /// Galleggia piano, senza fine. Solo per le illustrazioni.
  Widget galleggia(BuildContext context, {double ampiezza = 6}) {
    if (movimentoRidotto(context)) return this;
    return animate(onPlay: (c) => c.repeat(reverse: true)).moveY(
      begin: -ampiezza,
      end: ampiezza,
      duration: 2800.ms,
      curve: Curves.easeInOutSine,
    );
  }
}

/// Qualcosa che si tocca: si abbassa sotto il dito e torna su con una molla,
/// con un tocco di vibrazione.
class Premibile extends StatefulWidget {
  const Premibile({
    super.key,
    required this.onTap,
    required this.child,
    this.scala = 0.97,
    this.etichetta,
  });

  final VoidCallback? onTap;
  final Widget child;
  final double scala;

  /// Cosa legge VoiceOver.
  final String? etichetta;

  @override
  State<Premibile> createState() => _PremibileState();
}

class _PremibileState extends State<Premibile> {
  bool _premuto = false;

  void _premi(bool premuto) {
    if (widget.onTap == null || premuto == _premuto) return;
    setState(() => _premuto = premuto);
  }

  @override
  Widget build(BuildContext context) {
    final ridotto = movimentoRidotto(context);
    return Semantics(
      button: true,
      label: widget.etichetta,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _premi(true),
        onTapUp: (_) => _premi(false),
        onTapCancel: () => _premi(false),
        onTap: widget.onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                widget.onTap!();
              },
        child: AnimatedScale(
          scale: _premuto && !ridotto ? widget.scala : 1,
          duration: _premuto ? const Duration(milliseconds: 110) : Ritmo.medio,
          curve: _premuto ? Curves.easeOut : Ritmo.molla,
          child: widget.child,
        ),
      ),
    );
  }
}
