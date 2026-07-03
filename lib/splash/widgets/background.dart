import 'package:flutter/material.dart';

import '../splash_constants.dart';

/// White-to-soft-green gradient background driven by [greenFade] (0–1).
class SplashBackground extends StatelessWidget {
  const SplashBackground({super.key, required this.greenFade});

  final double greenFade;

  @override
  Widget build(BuildContext context) {
    final top = Color.lerp(
      Colors.white,
      const Color(SplashConstants.softGreenTop),
      greenFade,
    )!;
    final bottom = Color.lerp(
      Colors.white,
      const Color(SplashConstants.softGreenBottom),
      greenFade,
    )!;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ),
      ),
    );
  }
}
