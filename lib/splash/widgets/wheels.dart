import 'package:flutter/material.dart';

/// Rotating wheel overlay aligned to truck SVG wheel positions.
class SplashWheel extends StatelessWidget {
  const SplashWheel({
    super.key,
    required this.rotation,
    required this.diameter,
  });

  final double rotation;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation,
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF333333),
          border: Border.all(color: const Color(0xFF555555), width: 1.5),
        ),
        child: Center(
          child: Container(
            width: diameter * 0.35,
            height: diameter * 0.35,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF666666),
            ),
          ),
        ),
      ),
    );
  }
}
