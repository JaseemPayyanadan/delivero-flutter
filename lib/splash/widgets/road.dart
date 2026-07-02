import 'package:flutter/material.dart';

import '../painter/road_painter.dart';

/// Progressively draws the curved road using [RoadPainter].
class SplashRoad extends StatelessWidget {
  const SplashRoad({
    super.key,
    required this.progress,
    required this.canvasSize,
  });

  final double progress;
  final Size canvasSize;

  @override
  Widget build(BuildContext context) {
    final strokeWidth = canvasSize.width * 0.03;

    return RepaintBoundary(
      child: CustomPaint(
        size: canvasSize,
        painter: RoadPainter(
          progress: progress,
          strokeWidth: strokeWidth.clamp(8.0, 22.0),
        ),
      ),
    );
  }
}
