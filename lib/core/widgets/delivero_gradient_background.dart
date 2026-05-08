import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class DeliveroGradientBackground extends StatelessWidget {
  final Widget child;
  final double glowTop;

  const DeliveroGradientBackground({
    super.key,
    required this.child,
    this.glowTop = 180,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final topPadding = media.padding.top;

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primaryGradientStart,
                  AppColors.primaryGradientEnd,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: topPadding + glowTop,
          left: -120,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          bottom: -140,
          right: -120,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
          ),
        ),
        child,
      ],
    );
  }
}
