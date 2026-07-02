import 'package:flutter/material.dart';

import 'painter/road_painter.dart';

/// Responsive layout metrics for positioning splash layers.
class SplashLayout {
  SplashLayout(this.screenSize);

  final Size screenSize;

  double get width => screenSize.width;
  double get height => screenSize.height;

  /// Bottom landscape block height (~48% of screen).
  double get landscapeHeight => height * 0.48;

  double get landscapeTop => height - landscapeHeight;

  /// Road is drawn in the lower portion of the landscape.
  Size get roadCanvasSize => Size(width, landscapeHeight * 0.52);

  double get roadCanvasTop => landscapeTop + landscapeHeight * 0.38;

  /// Pin appears near the road destination (right side).
  Offset get pinPosition {
    final end = splashRoadSample(roadCanvasSize, 0.92);
    return Offset(
      end.position.dx - width * 0.04,
      roadCanvasTop + end.position.dy - width * 0.14,
    );
  }

  /// Shield sits slightly above the pin.
  Offset get shieldPosition {
    final pin = pinPosition;
    return Offset(pin.dx + width * 0.02, pin.dy - width * 0.12);
  }

  double get pinSize => width * 0.11;
  double get shieldSize => width * 0.13;
}
