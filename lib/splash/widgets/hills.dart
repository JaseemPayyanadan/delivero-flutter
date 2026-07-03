import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../splash_constants.dart';

/// Rolling green hills SVG at the bottom of the landscape.
class SplashHills extends StatelessWidget {
  const SplashHills({super.key, required this.opacity});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final height = width * (180 / 600);

    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: SvgPicture.asset(
        SplashConstants.hillsAsset,
        width: width,
        height: height,
        fit: BoxFit.fitWidth,
        alignment: Alignment.bottomCenter,
      ),
    );
  }
}
