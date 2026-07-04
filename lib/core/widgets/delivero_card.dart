import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Standard content surface: radius-24, subtle border, soft shadow.
///
/// Consolidates the card decoration that was repeated across the app so the
/// look stays consistent as the Fillo visual language rolls out.
class DeliveroCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Clip clipBehavior;
  final double radius;

  const DeliveroCard({
    super.key,
    required this.child,
    this.padding,
    this.clipBehavior = Clip.none,
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
