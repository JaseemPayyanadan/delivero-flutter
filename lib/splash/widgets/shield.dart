import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../splash_constants.dart';

/// Green shield with scale, fade, and soft glow.
class SplashShield extends StatelessWidget {
  const SplashShield({
    super.key,
    required this.scale,
    required this.opacity,
    required this.glowStrength,
    required this.size,
  });

  final double scale;
  final double opacity;
  final double glowStrength;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (opacity <= 0 && scale <= 0) {
      return const SizedBox.shrink();
    }

    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: scale.clamp(0.0, 1.0),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(SplashConstants.shieldGreen)
                    .withValues(alpha: 0.35 * glowStrength),
                blurRadius: 24 * glowStrength,
                spreadRadius: 4 * glowStrength,
              ),
            ],
          ),
          child: SvgPicture.asset(
            SplashConstants.shieldAsset,
            width: size,
            height: size,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
