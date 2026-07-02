import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../splash_constants.dart';

/// Orange location pin with elastic bounce entrance.
class SplashLocationPin extends StatelessWidget {
  const SplashLocationPin({
    super.key,
    required this.bounceProgress,
    required this.opacity,
    required this.size,
  });

  /// Elastic scale progress (0–1).
  final double bounceProgress;
  final double opacity;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (opacity <= 0 && bounceProgress <= 0) {
      return const SizedBox.shrink();
    }

    final scale = bounceProgress.clamp(0.0, 1.2);

    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: scale,
        child: SvgPicture.asset(
          SplashConstants.pinAsset,
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
