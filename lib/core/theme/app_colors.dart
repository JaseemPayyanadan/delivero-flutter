import 'package:flutter/material.dart';

class AppColors {
  // Primary scale (500 = logo brand purple #5A45FE)
  static const primary25 = Color(0xFFFAFAFF);
  static const primary50 = Color(0xFFF5F3FF);
  static const primary100 = Color(0xFFEBE8FF);
  static const primary200 = Color(0xFFD4CEFF);
  static const primary300 = Color(0xFFB8AFFF);
  static const primary400 = Color(0xFF8F7FFF);
  static const primary500 = Color(0xFF5A45FE);
  static const primary600 = Color(0xFF4A38D9);
  static const primary700 = Color(0xFF3D2DB8);
  static const primary800 = Color(0xFF322497);
  static const primary900 = Color(0xFF281C78);
  static const primary950 = Color(0xFF1A1252);

  // Neutral scale
  static const neutral25 = Color(0xFFFFFFFF);
  static const neutral50 = Color(0xFFF5F7FA);
  static const neutral100 = Color(0xFFF2F5F8);
  static const neutral200 = Color(0xFFE1E4EA);
  static const neutral300 = Color(0xFFCACFD8);
  static const neutral400 = Color(0xFF99A0AE);
  static const neutral500 = Color(0xFF717784);
  static const neutral600 = Color(0xFF525866);
  static const neutral700 = Color(0xFF344054);
  static const neutral800 = Color(0xFF1D2939);
  static const neutral900 = Color(0xFF101828);
  static const neutral950 = Color(0xFF0C111D);

  // Semantic aliases
  static const primary = primary500;
  static const primaryLight = primary400;
  static const primaryLighter = primary100;
  static const secondary = Color(0xFFBFE003);
  static const onSecondary = neutral900;
  static const accent = Color(0xFFF59E0B);

  static const primaryGradientStart = primary500;
  static const primaryGradientEnd = primary700;

  /// Shared purple header gradient for banner/sheet headers across the app.
  static const primaryHeaderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryGradientStart, primaryGradientEnd],
  );

  static const success = Color(0xFF059669);
  static const successDark = Color(0xFF047857);
  static const successDarker = Color(0xFF065F46);
  static const successLight = Color(0xFF34D399);
  static const successLighter = Color(0xFFD1FAE5);
  static const error = Color(0xFFDC2626);
  static const errorLighter = Color(0xFFFEE2E2);
  static const warning = Color(0xFFD97706);
  static const warningLighter = Color(0xFFFEF3C7);
  static const info = Color(0xFF0284C7);
  static const infoLighter = Color(0xFFE0F2FE);

  /// Dashboard hero gradient — dark/mid/light purple, matching the Fillo
  /// header language used across the rest of the app.
  static const dashboardHeroGradientStart = primary700;
  static const dashboardHeroGradientMid = primary500;
  static const dashboardHeroGradientEnd = primary300;

  static const backgroundPrimary = neutral25;
  static const backgroundSecondary = neutral50;
  static const backgroundTertiary = neutral100;

  static const surface = neutral25;
  static const surfaceElevated = neutral25;
  static const border = neutral200;
  static const divider = neutral100;

  static const textPrimary = neutral900;
  static const textSecondary = neutral600;
  static const textLight = neutral400;
  static const textDisabled = neutral300;

  static const shadow = Color(0x0F000000);
  static const shadowDeep = Color(0x1A000000);
}
