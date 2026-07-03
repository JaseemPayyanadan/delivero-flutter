import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../splash_constants.dart';

/// City skyline SVG that fades in and slides upward.
class SplashCity extends StatelessWidget {
  const SplashCity({
    super.key,
    required this.opacity,
    required this.slideOffset,
  });

  final double opacity;

  /// 0 = resting position, 1 = fully slid up from below.
  final double slideOffset;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final height = width * (140 / 600);

    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, (1 - slideOffset) * height * 0.35),
        child: SvgPicture.asset(
          SplashConstants.cityAsset,
          width: width,
          height: height,
          fit: BoxFit.fitWidth,
          alignment: Alignment.bottomCenter,
        ),
      ),
    );
  }
}
