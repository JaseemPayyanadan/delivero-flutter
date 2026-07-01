import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  static const SystemUiOverlayStyle systemOverlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.surface,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarDividerColor: Colors.transparent,
  );

  static ThemeData light() {
    final baseTextTheme = ThemeData(useMaterial3: true).textTheme;
    final textTheme = GoogleFonts.figtreeTextTheme(baseTextTheme);
    final appText = AppTextStyles.light(textTheme);
    final figtree = GoogleFonts.figtree();
    return ThemeData(
      useMaterial3: true,
      fontFamily: figtree.fontFamily,
      fontFamilyFallback: figtree.fontFamilyFallback,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        error: AppColors.error,
        onPrimary: AppColors.surface,
        onSecondary: AppColors.onSecondary,
        onSurface: AppColors.textPrimary,
        onError: AppColors.surface,
        outline: AppColors.border,
        surfaceContainerHighest: AppColors.backgroundSecondary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: systemOverlayStyle,
        iconTheme: const IconThemeData(color: AppColors.textPrimary, size: 22),
        titleTextStyle: appText.appBarTitle,
      ),
      textTheme: textTheme.copyWith(
        displayLarge: textTheme.displayLarge?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: textTheme.headlineMedium?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          color: AppColors.textPrimary,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border, width: 1.3),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border, width: 1.3),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.7),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1.3),
        ),
        hintStyle: const TextStyle(
          color: AppColors.textLight,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.surface,
          minimumSize: const Size(double.infinity, 48),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.surface,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(double.infinity, 48),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          side: const BorderSide(color: AppColors.primary, width: 2),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.backgroundSecondary,
        selectedColor: AppColors.primary,
        secondarySelectedColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        secondaryLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.surface,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide.none,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textLight,
        textColor: AppColors.textPrimary,
        contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        minLeadingWidth: 40,
        horizontalTitleGap: 12,
        dense: false,
        minVerticalPadding: 10,
        visualDensity: VisualDensity.standard,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: appText.sectionHeader,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
          height: 1.5,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        splashFactory: NoSplash.splashFactory,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 13,
          letterSpacing: 0.4,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          letterSpacing: 0.2,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary.withValues(alpha: 0.1),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 52,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? AppColors.primary : AppColors.textLight,
            letterSpacing: 0.5,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: isSelected ? AppColors.primary : AppColors.textLight,
          );
        }),
      ),
      extensions: <ThemeExtension<dynamic>>[appText],
    );
  }
}
