library;

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

part 'src/paths.dart';
part 'src/painters.dart';

const trolleyBlue = Color(0xFF3049D3);
const trolleyRouteBlue = Color(0xFF7185E5);

/// The approved entrance, brake and itinerary lettering. Runs once.
/// Completion is visual only: the host app must also wait for its own startup.
class TrolleySplash extends StatefulWidget {
  const TrolleySplash({
    super.key,
    this.onCompleted,
    this.duration = const Duration(milliseconds: 4800),
    this.color = trolleyBlue,
    this.routeColor = trolleyRouteBlue,
    this.label = 'Trolley',
  });
  final VoidCallback? onCompleted;
  final Duration duration;
  final Color color;
  final Color routeColor;
  final String label;
  @override
  State<TrolleySplash> createState() => _TrolleySplashState();
}

class _TrolleySplashState extends State<TrolleySplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _started = false;
  bool _completed = false;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_completed) {
        _completed = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onCompleted?.call();
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _started = true;
      _controller.value = 1;
    } else if (!_started) {
      _started = true;
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(TrolleySplash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        label: widget.label,
        image: true,
        child: RepaintBoundary(
          child: AspectRatio(
            aspectRatio: 800 / 340,
            child: CustomPaint(
              painter:
                  _SplashPainter(_controller, widget.color, widget.routeColor),
            ),
          ),
        ),
      );
}

enum TrolleyLoaderStyle { rolling, bounce, route }

/// An indeterminate loader: remove it when the actual task completes.
class TrolleyLoader extends StatefulWidget {
  const TrolleyLoader({
    super.key,
    this.style = TrolleyLoaderStyle.route,
    this.size = 72,
    this.color = trolleyBlue,
    this.detailColor = Colors.white,
    this.label = 'Caricamento in corso',
  });
  final TrolleyLoaderStyle style;
  final double size;
  final Color color;
  final Color detailColor;
  final String label;
  @override
  State<TrolleyLoader> createState() => _TrolleyLoaderState();
}

class _TrolleyLoaderState extends State<TrolleyLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Duration get _duration => Duration(
        milliseconds: const [1600, 1200, 1800][widget.style.index],
      );
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration);
  }

  void _syncMotion() {
    if (MediaQuery.of(context).disableAnimations) {
      _controller.stop();
      _controller.value = .5;
    } else {
      _controller.repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(TrolleyLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.style != widget.style) {
      _controller.duration = _duration;
      _syncMotion();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        label: widget.label,
        image: true,
        child: RepaintBoundary(
          child: SizedBox.square(
            dimension: widget.size,
            child: CustomPaint(
              painter: _LoaderPainter(
                _controller,
                widget.style,
                widget.color,
                widget.detailColor,
              ),
            ),
          ),
        ),
      );
}

/// Static vector logo, suitable for headers and screens at any pixel density.
class TrolleyLogo extends StatelessWidget {
  const TrolleyLogo(
      {super.key, this.color = trolleyBlue, this.symbolOnly = false});
  final Color color;
  final bool symbolOnly;
  @override
  Widget build(BuildContext context) => Semantics(
        image: true,
        label: 'Trolley',
        child: AspectRatio(
          aspectRatio: symbolOnly ? 160 / 230 : 650 / 230,
          child: CustomPaint(painter: _LogoPainter(color, symbolOnly)),
        ),
      );
}
