import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Tone options for [DeliveroStatusChip], each mapping to an existing
/// [AppColors] tint/text pair.
enum StatusChipTone { neutral, success, info, warning, primary }

/// A small tinted pill used for status/label badges (e.g. Driver, Available,
/// Off duty). Part of the Fillo visual language.
class DeliveroStatusChip extends StatelessWidget {
  final String label;
  final StatusChipTone tone;

  const DeliveroStatusChip({
    super.key,
    required this.label,
    this.tone = StatusChipTone.neutral,
  });

  ({Color fill, Color border, Color text}) get _colors {
    switch (tone) {
      case StatusChipTone.success:
        return (
          fill: AppColors.successLighter,
          border: AppColors.success.withValues(alpha: 0.22),
          text: AppColors.success,
        );
      case StatusChipTone.info:
        return (
          fill: AppColors.infoLighter,
          border: AppColors.info.withValues(alpha: 0.22),
          text: AppColors.info,
        );
      case StatusChipTone.warning:
        return (
          fill: AppColors.warningLighter,
          border: AppColors.warning.withValues(alpha: 0.22),
          text: AppColors.warning,
        );
      case StatusChipTone.primary:
        return (
          fill: AppColors.primaryLighter,
          border: AppColors.primary.withValues(alpha: 0.2),
          text: AppColors.primary,
        );
      case StatusChipTone.neutral:
        return (
          fill: AppColors.backgroundTertiary,
          border: AppColors.border,
          text: AppColors.textSecondary,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: c.fill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.35,
          height: 1.1,
          color: c.text,
        ),
      ),
    );
  }
}
