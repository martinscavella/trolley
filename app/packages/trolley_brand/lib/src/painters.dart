part of '../trolley_brand.dart';

double _clamp(double n) => n.clamp(0.0, 1.0).toDouble();
Color _alpha(Color color, double opacity) =>
    color.withAlpha((_clamp(opacity) * 255).round());
Paint _stroke(Color color, double width) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

class _Segment {
  _Segment(this.path, this.bridge) : metric = path.computeMetrics().first;
  final Path path;
  final bool bridge;
  final ui.PathMetric metric;
  double get length => metric.length;
}

final double _total = _segments.fold(0.0, (sum, s) => sum + s.length);
final ui.PathMetric _innerMetric = _inner.computeMetrics().first;

void _case(Canvas canvas, Color color, Color detail, {bool itinerary = true}) {
  final fill = Paint()..color = color;
  canvas.drawPath(_handle, _stroke(color, 15));
  canvas.drawRRect(
    RRect.fromRectAndRadius(
        const Rect.fromLTWH(85, 114, 126, 138), const Radius.circular(30)),
    fill,
  );
  canvas.drawCircle(const Offset(108, 272), 12, fill);
  canvas.drawCircle(const Offset(188, 272), 12, fill);
  if (itinerary) {
    canvas.drawPath(_inner, _stroke(detail, 12));
    canvas.drawCircle(const Offset(116, 150), 13, Paint()..color = detail);
    canvas.drawCircle(const Offset(179, 232), 13, Paint()..color = detail);
  }
}

void _entrance(Canvas canvas, double time, Color color) {
  double x = 0, y = 0, rotation = 0;
  if (time < 560) {
    x = -320 + 332 * _clamp(time / 560);
    rotation = -7;
  } else if (time < 720) {
    final p = (time - 560) / 160;
    x = 12 + 13 * math.sin(p * math.pi / 2);
    rotation = -7 + 24 * math.sin(p * math.pi / 2);
    y = -4 * math.sin(p * math.pi / 2);
  } else if (time < 1200) {
    final p = (time - 720) / 480;
    final settle = math.exp(-4 * p) * math.cos(3 * math.pi * p);
    x = 25 * settle;
    rotation = 17 * settle;
    y = -4 * settle.abs();
  }
  if (time > 250 && time < 600) {
    for (final line in const [
      [25.0, 151.0, 63.0],
      [9.0, 179.0, 52.0],
      [31.0, 208.0, 66.0]
    ]) {
      canvas.drawLine(Offset(line[0] + x, line[1]),
          Offset(line[2] + x, line[1]), _stroke(_alpha(color, .5), 4));
    }
  }
  if (time >= 560 && time < 1100) {
    final paint =
        _stroke(_alpha(color, .45 * (1 - _clamp((time - 720) / 380))), 3);
    canvas.drawLine(const Offset(61, 285), const Offset(106, 285), paint);
    canvas.drawLine(const Offset(145, 285), const Offset(184, 285), paint);
  }
  canvas.save();
  canvas.translate(x + 188, y + 272);
  canvas.rotate(rotation * math.pi / 180);
  canvas.translate(-188, -272);
  _case(canvas, color, Colors.white);
  canvas.restore();
}

class _SplashPainter extends CustomPainter {
  _SplashPainter(this.animation, this.color, this.routeColor)
      : super(repaint: animation);
  final Animation<double> animation;
  final Color color, routeColor;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(size.width / 800, size.height / 340);
    final time = animation.value * 4800;
    _entrance(canvas, time, color);
    final distance = _clamp((time - 1280) / 2600) * _total;
    double start = 0;
    Offset? tip;
    for (final segment in _segments) {
      final travelled =
          (distance - start).clamp(0.0, segment.length).toDouble();
      final passed = 1280 + (start + segment.length) / _total * 2600;
      final opacity = segment.bridge ? 1 - _clamp((time - passed) / 750) : 1.0;
      if (travelled > 0 && opacity > 0) {
        canvas.drawPath(segment.metric.extractPath(0, travelled),
            _stroke(_alpha(segment.bridge ? routeColor : color, opacity), 22));
      }
      if (distance >= start && distance <= start + segment.length) {
        tip = segment.metric.getTangentForOffset(travelled)?.position;
      }
      start += segment.length;
    }
    final stopFade = 1 - _clamp((time - 4000) / 600);
    for (final spec in const [
      [0, 0.0],
      [0, .42],
      [4, .5],
      [6, .5],
      [12, .55]
    ]) {
      final index = spec[0].toInt();
      final segment = _segments[index];
      final localDistance = segment.length * spec[1];
      final before =
          _segments.take(index).fold(0.0, (sum, s) => sum + s.length);
      final reached = 1280 + (before + localDistance) / _total * 2600;
      final opacity = _clamp((time - reached) / 100) * stopFade;
      final point = segment.metric.getTangentForOffset(localDistance)?.position;
      if (opacity > 0 && point != null) {
        // Draw on a temporary layer so fill and white outline fade together.
        canvas.saveLayer(Rect.fromCircle(center: point, radius: 18),
            Paint()..color = _alpha(Colors.white, opacity));
        canvas.drawCircle(point, 16, Paint()..color = routeColor);
        canvas.drawCircle(point, 14, _stroke(Colors.white, 4));
        canvas.restore();
      }
    }
    if (time >= 1280 && time < 4030 && tip != null) {
      canvas.drawCircle(tip, 11,
          Paint()..color = _alpha(routeColor, 1 - _clamp((time - 3880) / 150)));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SplashPainter old) =>
      old.animation != animation ||
      old.color != color ||
      old.routeColor != routeColor;
}

class _LoaderPainter extends CustomPainter {
  _LoaderPainter(this.animation, this.style, this.color, this.detail)
      : super(repaint: animation);
  final Animation<double> animation;
  final TrolleyLoaderStyle style;
  final Color color, detail;
  @override
  void paint(Canvas canvas, Size size) {
    final p = animation.value;
    final phase = 2 * math.pi * p;
    double dx = 0, dy = 0, angle = 0;
    switch (style) {
      case TrolleyLoaderStyle.rolling:
        dx = 12 * math.sin(phase);
        angle = 5 * math.sin(phase);
        break;
      case TrolleyLoaderStyle.bounce:
        dy = -14 * math.pow(math.sin(math.pi * p), 2).toDouble();
        angle = 5 * math.sin(phase);
        break;
      case TrolleyLoaderStyle.route:
        angle = 2 * math.sin(phase);
        break;
    }
    canvas.save();
    canvas.scale(size.width / 256, size.height / 256);
    canvas.translate(128 + dx, 128 + dy);
    canvas.rotate(angle * math.pi / 180);
    canvas.scale(.7);
    canvas.translate(-148, -182);
    _case(canvas, color, detail, itinerary: style != TrolleyLoaderStyle.route);
    if (style == TrolleyLoaderStyle.route) {
      final progress = _clamp(p / .78);
      final opacity = 1 - _clamp((p - .85) / .15);
      final paint = _stroke(_alpha(detail, opacity), 12);
      if (progress > 0) {
        canvas.drawPath(
            _innerMetric.extractPath(0, _innerMetric.length * progress), paint);
      }
      canvas.drawCircle(const Offset(116, 150), 13, Paint()..color = detail);
      final point = _innerMetric
          .getTangentForOffset(_innerMetric.length * progress)
          ?.position;
      if (point != null) {
        canvas.drawCircle(point, 8, Paint()..color = _alpha(detail, opacity));
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LoaderPainter old) =>
      old.animation != animation ||
      old.style != style ||
      old.color != color ||
      old.detail != detail;
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.color, this.symbolOnly);
  final Color color;
  final bool symbolOnly;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / (symbolOnly ? 160 : 650), size.height / 230);
    canvas.translate(-70, -65);
    canvas.saveLayer(const Rect.fromLTWH(70, 65, 160, 230), Paint());
    _case(canvas, color, Colors.white, itinerary: false);
    final cut = _stroke(Colors.white, 12)..blendMode = BlendMode.clear;
    canvas.drawPath(_inner, cut);
    final clear = Paint()..blendMode = BlendMode.clear;
    canvas.drawCircle(const Offset(116, 150), 13, clear);
    canvas.drawCircle(const Offset(179, 232), 13, clear);
    canvas.restore();
    if (!symbolOnly) {
      for (final segment in _segments.where((s) => !s.bridge)) {
        canvas.drawPath(segment.path, _stroke(color, 22));
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LogoPainter old) =>
      old.color != color || old.symbolOnly != symbolOnly;
}
