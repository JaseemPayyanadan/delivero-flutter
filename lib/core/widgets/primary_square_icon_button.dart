import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

class PrimarySquareIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color color;
  final bool useHaptics;

  const PrimarySquareIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.color = AppColors.primary,
    this.useHaptics = true,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {
        if (useHaptics) HapticFeedback.mediumImpact();
        onPressed();
      },
      icon: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppRadii.md),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 12,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: Theme.of(context).colorScheme.onPrimary,
          size: 22,
        ),
      ),
    );
  }
}
