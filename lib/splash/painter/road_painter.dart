import 'package:flutter/material.dart';

import '../splash_constants.dart';

/// Builds the curved road [Path] mapped from the SVG viewBox into [size].
Path buildSplashRoadPath(Size size) {
  final w = SplashConstants.roadViewBoxWidth;
  final h = SplashConstants.roadViewBoxHeight;

  double x(double svgX) => svgX / w * size.width;
  double y(double svgY) => svgY / h * size.height;

  return Path()
    ..moveTo(x(20), y(150))
    ..cubicTo(x(180), y(80), x(360), y(90), x(580), y(130));
}

/// Returns position and tangent angle (radians) for [t] along the road (0–1).
({Offset position, double angle}) splashRoadSample(Size size, double t) {
  final path = buildSplashRoadPath(size);
  final metric = path.computeMetrics().first;
  final clamped = t.clamp(0.0, 1.0);
  final tangent = metric.getTangentForOffset(metric.length * clamped);
  if (tangent == null) {
    return (position: Offset.zero, angle: 0);
  }
  return (position: tangent.position, angle: tangent.angle);
}

/// Draws the road stroke progressively using [PathMetric.extractPath].
class RoadPainter extends CustomPainter {
  RoadPainter({
    required this.progress,
    required this.strokeWidth,
    this.color = Colors.white,
  });

  final double progress;
  final double strokeWidth;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final path = buildSplashRoadPath(size);
    final metrics = path.computeMetrics();
    if (metrics.isEmpty) return;

    final metric = metrics.first;
    final drawLength = metric.length * progress.clamp(0.0, 1.0);
    final extracted = metric.extractPath(0, drawLength);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Subtle shadow beneath the road for depth.
    canvas.drawPath(
      extracted,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 4
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    canvas.drawPath(extracted, paint);
  }

  @override
  bool shouldRepaint(covariant RoadPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.color != color;
  }
}
