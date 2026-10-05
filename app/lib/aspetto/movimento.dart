/// Come si muove l'app: poche durate e poche curve, così si muove in un modo solo.
///
/// Ogni movimento rispetta "Riduci movimento" (iOS) e "Rimuovi animazioni"
/// (Android): con l'impostazione attiva le cose compaiono e basta.
library;

import 'package:flutter/foundation.dart';
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

// ─── Il passaggio fra le pagine ──────────────────────────────────────────────

/// Come si passa da una pagina all'altra: la nuova entra da destra, veloce
/// all'inizio e morbida alla fine; quella di prima scivola un terzo a
/// sinistra e si scurisce appena. È il passaggio delle app che si usano
/// tutti i giorni (Instagram, WhatsApp), non quello di Flutter, che parte
/// lento, accelera a metà e porta un'ombra sul bordo: sembrava di sfogliare
/// un libro. Su iOS si torna indietro trascinando dal bordo sinistro.
///
/// Con "Riduci movimento" la pagina compare sfumando, senza scorrere.
abstract final class RitmoPagine {
  static const avanti = Duration(milliseconds: 420);
  static const indietro = Duration(milliseconds: 360);

  /// Parte subito e si posa piano, come la molla di iOS.
  static const curva = Cubic(0.2, 0.9, 0.25, 1);

  /// Quanto scivola a sinistra la pagina che resta sotto.
  static const sotto = -0.3;

  /// Quanto si scurisce la pagina che resta sotto.
  static const velo = 0.08;
}

/// Una pagina dell'app, con il passaggio di [RitmoPagine].
class RottaTrolley<T> extends PageRoute<T> {
  RottaTrolley({required this.builder, this.trascinabile = true});

  final WidgetBuilder builder;

  /// Si torna indietro trascinando dal bordo sinistro (solo su iOS).
  final bool trascinabile;

  @override
  Duration get transitionDuration => RitmoPagine.avanti;

  @override
  Duration get reverseTransitionDuration => RitmoPagine.indietro;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  /// La pagina di prima, anche se non è una [RottaTrolley] (la prima
  /// dell'app), scivola e si scurisce allo stesso modo.
  @override
  DelegatedTransitionBuilder? get delegatedTransition => _sotto;

  static Widget? _sotto(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    bool allowSnapshotting,
    Widget? child,
  ) => _PaginaSotto(animazione: secondaryAnimation, child: child);

  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) {
    // Sotto un foglio a tutto schermo, che sale dal basso, la pagina resta
    // ferma.
    if (nextRoute is PageRoute && nextRoute.fullscreenDialog) return false;
    return nextRoute is RottaTrolley ||
        (nextRoute is ModalRoute && nextRoute.delegatedTransition != null);
  }

  @override
  bool canTransitionFrom(TransitionRoute<dynamic> previousRoute) =>
      previousRoute is PageRoute;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => Semantics(
    scopesRoute: true,
    explicitChildNodes: true,
    child: builder(context),
  );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (movimentoRidotto(context)) {
      return FadeTransition(opacity: animation, child: child);
    }
    // Mentre la si trascina col dito la pagina segue il dito, senza curva.
    final lineare = popGestureInProgress;
    return _PaginaSotto(
      animazione: secondaryAnimation,
      lineare: lineare,
      child: _PaginaSopra(
        animazione: animation,
        lineare: lineare,
        child: trascinabile && defaultTargetPlatform == TargetPlatform.iOS
            ? _TornaIndietro(rotta: this, child: child)
            : child,
      ),
    );
  }

  // Il trascinamento dal bordo, che sposta la pagina col dito.

  void _iniziaGesto() => navigator!.didStartUserGesture();

  void _seguiGesto(double quota) => controller!.value -= quota;

  /// [velocita] in larghezze dello schermo al secondo.
  void _finisciGesto(double velocita) {
    final avanti = !isCurrent
        ? isActive
        : velocita.abs() >= 1
        ? velocita <= 0
        : controller!.value > 0.5;
    const durata = Duration(milliseconds: 300);
    if (avanti) {
      controller!.animateTo(1, duration: durata, curve: RitmoPagine.curva);
    } else {
      if (isCurrent) navigator!.pop();
      if (controller!.isAnimating) {
        controller!.animateBack(0, duration: durata, curve: RitmoPagine.curva);
      }
    }
    final nav = navigator!;
    if (controller!.isAnimating) {
      late AnimationStatusListener fine;
      fine = (_) {
        nav.didStopUserGesture();
        controller?.removeStatusListener(fine);
      };
      controller!.addStatusListener(fine);
    } else {
      nav.didStopUserGesture();
    }
  }
}

/// La pagina che entra da destra.
class _PaginaSopra extends StatefulWidget {
  const _PaginaSopra({
    required this.animazione,
    required this.lineare,
    required this.child,
  });

  final Animation<double> animazione;
  final bool lineare;
  final Widget child;

  @override
  State<_PaginaSopra> createState() => _PaginaSopraState();
}

class _PaginaSopraState extends State<_PaginaSopra> {
  CurvedAnimation? _curva;
  late Animation<Offset> _posizione;

  @override
  void initState() {
    super.initState();
    _prepara();
  }

  @override
  void didUpdateWidget(_PaginaSopra vecchio) {
    super.didUpdateWidget(vecchio);
    if (vecchio.animazione != widget.animazione ||
        vecchio.lineare != widget.lineare) {
      _curva?.dispose();
      _prepara();
    }
  }

  void _prepara() {
    _curva = widget.lineare
        ? null
        : CurvedAnimation(
            parent: widget.animazione,
            curve: RitmoPagine.curva,
            reverseCurve: RitmoPagine.curva.flipped,
          );
    _posizione = (_curva ?? widget.animazione).drive(
      Tween(begin: const Offset(1, 0), end: Offset.zero),
    );
  }

  @override
  void dispose() {
    _curva?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SlideTransition(
    position: _posizione,
    textDirection: Directionality.of(context),
    // Un'ombra leggera sul bordo che entra: a pagina ferma è fuori dallo
    // schermo.
    child: DecoratedBox(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(-4, 0),
          ),
        ],
      ),
      child: widget.child,
    ),
  );
}

/// La pagina che resta sotto: scivola un po' a sinistra e si scurisce.
class _PaginaSotto extends StatefulWidget {
  const _PaginaSotto({
    required this.animazione,
    required this.child,
    this.lineare = false,
  });

  final Animation<double> animazione;
  final bool lineare;
  final Widget? child;

  @override
  State<_PaginaSotto> createState() => _PaginaSottoState();
}

class _PaginaSottoState extends State<_PaginaSotto> {
  CurvedAnimation? _curva;
  late Animation<Offset> _posizione;
  late Animation<double> _velo;

  @override
  void initState() {
    super.initState();
    _prepara();
  }

  @override
  void didUpdateWidget(_PaginaSotto vecchio) {
    super.didUpdateWidget(vecchio);
    if (vecchio.animazione != widget.animazione ||
        vecchio.lineare != widget.lineare) {
      _curva?.dispose();
      _prepara();
    }
  }

  void _prepara() {
    _curva = widget.lineare
        ? null
        : CurvedAnimation(
            parent: widget.animazione,
            curve: RitmoPagine.curva,
            reverseCurve: RitmoPagine.curva.flipped,
          );
    final a = _curva ?? widget.animazione;
    _posizione = a.drive(
      Tween(begin: Offset.zero, end: const Offset(RitmoPagine.sotto, 0)),
    );
    _velo = a.drive(Tween(begin: 0, end: RitmoPagine.velo));
  }

  @override
  void dispose() {
    _curva?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SlideTransition(
    position: _posizione,
    textDirection: Directionality.of(context),
    transformHitTests: false,
    child: Stack(
      fit: StackFit.passthrough,
      children: [
        ?widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: FadeTransition(
              opacity: _velo,
              child: const ColoredBox(color: Color(0xFF000000)),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Il bordo sinistro da cui si trascina la pagina per tornare indietro.
class _TornaIndietro extends StatefulWidget {
  const _TornaIndietro({required this.rotta, required this.child});

  final RottaTrolley<dynamic> rotta;
  final Widget child;

  @override
  State<_TornaIndietro> createState() => _TornaIndietroState();
}

class _TornaIndietroState extends State<_TornaIndietro> {
  bool _attivo = false;

  double get _larghezza => context.size?.width ?? 1;

  @override
  Widget build(BuildContext context) {
    final bordo = 20 + MediaQuery.paddingOf(context).left;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        PositionedDirectional(
          start: 0,
          top: 0,
          bottom: 0,
          width: bordo,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: (_) {
              if (!widget.rotta.popGestureEnabled) return;
              _attivo = true;
              widget.rotta._iniziaGesto();
            },
            onHorizontalDragUpdate: (d) {
              if (!_attivo) return;
              widget.rotta._seguiGesto(d.primaryDelta! / _larghezza);
            },
            onHorizontalDragEnd: (d) {
              if (!_attivo) return;
              _attivo = false;
              widget.rotta._finisciGesto(
                d.velocity.pixelsPerSecond.dx / _larghezza,
              );
            },
            onHorizontalDragCancel: () {
              if (!_attivo) return;
              _attivo = false;
              widget.rotta._finisciGesto(0);
            },
          ),
        ),
      ],
    );
  }
}
