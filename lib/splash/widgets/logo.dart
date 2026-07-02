import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../splash_constants.dart';

/// Delivro logo fade + scale entrance at the end of the sequence.
class SplashLogo extends StatelessWidget {
  const SplashLogo({
    super.key,
    required this.opacity,
    required this.scale,
  });

  final double opacity;
  final double scale;

  @override
  Widget build(BuildContext context) {
    if (opacity <= 0) return const SizedBox.shrink();

    final width = MediaQuery.sizeOf(context).width * 0.52;

    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: scale.clamp(0.0, 1.0),
        child: SvgPicture.asset(
          SplashConstants.logoAsset,
          width: width,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
