import 'package:flutter/material.dart';
import 'app_colors.dart';
import '../theme/colors.dart' hide Prediction, Tipster, PredictionStats;

class AppTheme {
  AppTheme._();

  static ThemeData get dark => _buildTheme(Brightness.dark);
  static ThemeData get light => _buildTheme(Brightness.light);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    // Get the correct palette instances for the extensions
    final appColors = isDark ? AppColors.dark : AppColors.light;
    final pitchColors = isDark ? GoalVantageColors.dark : GoalVantageColors.light;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Inter',
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: AppColors.primary,
        onPrimary: AppColors.primaryForeground,
        secondary: AppColors.secondary,
        onSecondary: AppColors.secondaryForeground,
        surface: AppColors.card,
        onSurface: AppColors.foreground,
        error: AppColors.negative,
        onError: Colors.white,
        outline: AppColors.border,
        surfaceTint: Colors.transparent,
        shadow: Colors.black,
        inverseSurface: isDark ? AppColors.foreground : AppColors.background,
        onInverseSurface: isDark ? AppColors.background : AppColors.foreground,
        primaryContainer: AppColors.primaryGlow,
        onPrimaryContainer: AppColors.primaryForeground,
        secondaryContainer: AppColors.secondaryGlow,
        onSecondaryContainer: AppColors.secondaryForeground,
        tertiary: AppColors.confidenceMedium,
        onTertiary: AppColors.primaryForeground,
        tertiaryContainer: AppColors.cardHover,
        onTertiaryContainer: AppColors.foreground,
      ),
      // Register both extensions with the correct palette instances
      extensions: [appColors, pitchColors],
      textTheme: TextTheme(
        displayLarge: TextStyle(
          color: AppColors.foreground,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.8,
        ),
        headlineLarge: TextStyle(
          color: AppColors.foreground,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          color: AppColors.foreground,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: AppColors.foreground,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: TextStyle(
          color: AppColors.foreground,
          fontSize: 14,
        ),
        bodySmall: TextStyle(
          color: AppColors.foregroundSecondary,
          fontSize: 12,
        ),
        labelSmall: TextStyle(
          color: AppColors.foregroundSecondary,
          fontSize: 11,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: AppColors.foreground),
        titleTextStyle: TextStyle(
          color: AppColors.foreground,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      dividerColor: AppColors.border,
      splashColor: AppColors.primaryGlow,
      highlightColor: AppColors.selection,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        hintStyle: TextStyle(color: AppColors.foregroundSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }
}