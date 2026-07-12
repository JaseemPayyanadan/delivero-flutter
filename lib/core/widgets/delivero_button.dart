import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

class DeliveroButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double borderRadius;
  final bool useHaptics;
  final double? height;

  const DeliveroButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
    this.backgroundColor,
    this.foregroundColor,
    this.borderRadius = 8,
    this.useHaptics = true,
    this.height,
  });

  /// Lime pill CTA from the Fillo visual language: [AppColors.secondary] fill
  /// with dark [AppColors.onSecondary] text and a fully rounded shape.
  const DeliveroButton.lime({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
    this.useHaptics = true,
    this.height,
  }) : backgroundColor = AppColors.secondary,
       foregroundColor = AppColors.onSecondary,
       borderRadius = 999;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget content = isLoading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: foregroundColor ?? theme.colorScheme.onPrimary,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          );

    final minWidth = isFullWidth ? double.infinity : 0.0;
    final buttonHeight = height ?? 48;

    final buttonStyle =
        FilledButton.styleFrom(
          backgroundColor: backgroundColor ?? AppColors.primary,
          foregroundColor: foregroundColor ?? theme.colorScheme.onPrimary,
          minimumSize: Size(minWidth, buttonHeight),
          padding: EdgeInsets.symmetric(
            vertical: 12,
            horizontal: isFullWidth ? 20 : 28,
          ),
          tapTargetSize: isFullWidth ? null : MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          elevation: 0,
        ).merge(
          ButtonStyle(
            minimumSize: WidgetStateProperty.all(Size(minWidth, buttonHeight)),
          ),
        );

    Widget button = FilledButton(
      onPressed: isLoading || onPressed == null
          ? null
          : () {
              if (useHaptics) {
                try {
                  HapticFeedback.mediumImpact();
                } catch (_) {}
              }
              onPressed?.call();
            },
      style: buttonStyle,
      child: content,
    );

    if (isFullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return IntrinsicWidth(child: button);
  }
}
