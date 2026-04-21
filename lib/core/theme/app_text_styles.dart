import 'package:flutter/material.dart';

import 'app_colors.dart';

@immutable
class AppTextStyles extends ThemeExtension<AppTextStyles> {
  final TextStyle appBarTitle;
  final TextStyle sliverTitle;
  final TextStyle sliverSubtitle;
  final TextStyle sectionHeader;
  final TextStyle body;
  final TextStyle caption;
  final TextStyle buttonLabel;

  const AppTextStyles({
    required this.appBarTitle,
    required this.sliverTitle,
    required this.sliverSubtitle,
    required this.sectionHeader,
    required this.body,
    required this.caption,
    required this.buttonLabel,
  });

  factory AppTextStyles.light(TextTheme base) {
    return AppTextStyles(
      appBarTitle: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.5,
      ),
      sliverTitle: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 24,
        fontWeight: FontWeight.w900,
        letterSpacing: -1,
      ),
      sliverSubtitle: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      sectionHeader: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w900,
        color: AppColors.textPrimary,
        letterSpacing: -0.2,
      ),
      body:
          base.bodyMedium?.copyWith(color: AppColors.textSecondary) ??
          const TextStyle(color: AppColors.textSecondary),
      caption: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textLight,
        height: 1.4,
      ),
      buttonLabel: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
      ),
    );
  }

  @override
  AppTextStyles copyWith({
    TextStyle? appBarTitle,
    TextStyle? sliverTitle,
    TextStyle? sliverSubtitle,
    TextStyle? sectionHeader,
    TextStyle? body,
    TextStyle? caption,
    TextStyle? buttonLabel,
  }) {
    return AppTextStyles(
      appBarTitle: appBarTitle ?? this.appBarTitle,
      sliverTitle: sliverTitle ?? this.sliverTitle,
      sliverSubtitle: sliverSubtitle ?? this.sliverSubtitle,
      sectionHeader: sectionHeader ?? this.sectionHeader,
      body: body ?? this.body,
      caption: caption ?? this.caption,
      buttonLabel: buttonLabel ?? this.buttonLabel,
    );
  }

  @override
  AppTextStyles lerp(ThemeExtension<AppTextStyles>? other, double t) {
    if (other is! AppTextStyles) return this;
    return AppTextStyles(
      appBarTitle: TextStyle.lerp(appBarTitle, other.appBarTitle, t)!,
      sliverTitle: TextStyle.lerp(sliverTitle, other.sliverTitle, t)!,
      sliverSubtitle: TextStyle.lerp(sliverSubtitle, other.sliverSubtitle, t)!,
      sectionHeader: TextStyle.lerp(sectionHeader, other.sectionHeader, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
      caption: TextStyle.lerp(caption, other.caption, t)!,
      buttonLabel: TextStyle.lerp(buttonLabel, other.buttonLabel, t)!,
    );
  }
}

extension AppTextStylesX on BuildContext {
  AppTextStyles get appTextStyles =>
      Theme.of(this).extension<AppTextStyles>() ??
      AppTextStyles.light(Theme.of(this).textTheme);
}
