import 'package:flutter/material.dart';

class AppColors {
  // Brand
  static const primary = Color(0xFF1296DB);
  static const primaryDark = Color(0xFF0E7AB5);
  static const primaryLight = Color(0xFF3DABE8);
  static const accent = Color(0xFF00C9A7);
  static const accentGlow = Color(0x6600C9A7);
  static const purple = Color(0xFF7C3AED);

  // Background
  static const background = Color(0xFF0B0D17);
  static const surface = Color(0xFF1A1D2A);
  static const surfaceLight = Color(0xFF222633);
  static const cardBg = Color(0x0AFFFFFF);
  static const cardHover = Color(0x14FFFFFF);

  // Text
  static const text = Color(0xFFE8ECF4);
  static const textSecondary = Color(0xFF8892A8);
  static const textMuted = Color(0xFF5A6178);

  // Status
  static const success = Color(0xFF22C55E);
  static const danger = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);

  // Border
  static const border = Color(0x0FFFFFFF);

  AppColors._();
}

class AppTextStyles {
  // Base sizes (compact / 1.0x scale)
  // Colors intentionally omitted — they inherit from the theme's textTheme
  static const TextStyle display = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle heading = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle subheading = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
  );

  static const TextStyle bodyBold = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
  );

  static const TextStyle small = TextStyle(
    fontSize: 10,
  );

  /// Return a copy of [style] with font size scaled by [scale]
  static TextStyle scaled(TextStyle style, double scale) {
    return style.copyWith(fontSize: (style.fontSize! * scale).roundToDouble());
  }

  AppTextStyles._();
}

/// Light-mode color overrides for structural (non-brand) colors
class AppLightColors {
  static const background = Color(0xFFF5F6FA);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceLight = Color(0xFFF0F0F5);
  static const cardBg = Color(0xFFFFFFFF);
  static const cardHover = Color(0xFFF5F5F5);

  static const text = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF6B7280);
  static const textMuted = Color(0xFF9CA3AF);

  static const border = Color(0x1A000000);

  AppLightColors._();
}

class AppTheme {
  static ThemeData get darkTheme {
    final colorScheme = const ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.surface,
      error: AppColors.danger,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.text,
      onError: Colors.white,
    );

    return _buildTheme(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBg: AppColors.background,
      appBarBg: AppColors.background,
      surfaceBg: AppColors.surface,
      surfaceLightBg: AppColors.surfaceLight,
      cardBg: AppColors.cardBg,
      borderColor: AppColors.border,
      textColor: AppColors.text,
      textSecondaryColor: AppColors.textSecondary,
      textMutedColor: AppColors.textMuted,
      iconColor: AppColors.text,
      unselectedItemColor: AppColors.textMuted,
      hintStyle: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
    );
  }

  static ThemeData get lightTheme {
    final colorScheme = const ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppLightColors.surface,
      error: AppColors.danger,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppLightColors.text,
      onError: Colors.white,
    );

    return _buildTheme(
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBg: AppLightColors.background,
      appBarBg: AppLightColors.background,
      surfaceBg: AppLightColors.surface,
      surfaceLightBg: AppLightColors.surfaceLight,
      cardBg: AppLightColors.cardBg,
      borderColor: AppLightColors.border,
      textColor: AppLightColors.text,
      textSecondaryColor: AppLightColors.textSecondary,
      textMutedColor: AppLightColors.textMuted,
      iconColor: AppLightColors.text,
      unselectedItemColor: AppLightColors.textMuted,
      hintStyle: AppTextStyles.caption.copyWith(color: AppLightColors.textSecondary),
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required ColorScheme colorScheme,
    required Color scaffoldBg,
    required Color appBarBg,
    required Color surfaceBg,
    required Color surfaceLightBg,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
    required Color textSecondaryColor,
    required Color textMutedColor,
    required Color iconColor,
    required Color unselectedItemColor,
    required TextStyle hintStyle,
  }) {
    return ThemeData(
      brightness: brightness,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: scaffoldBg,
      colorScheme: colorScheme,
      textTheme: TextTheme(
        displayLarge: AppTextStyles.display.copyWith(color: textColor),
        titleLarge: AppTextStyles.heading.copyWith(color: textColor),
        titleMedium: AppTextStyles.subheading.copyWith(color: textColor),
        bodyMedium: AppTextStyles.body.copyWith(color: textColor),
        bodySmall: AppTextStyles.caption.copyWith(color: textSecondaryColor),
        labelSmall: AppTextStyles.small.copyWith(color: textMutedColor),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBg,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTextStyles.subheading.copyWith(color: textColor),
        iconTheme: IconThemeData(color: iconColor),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surfaceBg,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: unselectedItemColor,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: AppTextStyles.small.copyWith(color: AppColors.primary),
        unselectedLabelStyle: AppTextStyles.small.copyWith(color: unselectedItemColor),
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor),
        ),
      ),
      iconTheme: IconThemeData(color: iconColor),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLightBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        hintStyle: hintStyle,
        labelStyle: hintStyle,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: AppTextStyles.bodyBold.copyWith(color: Colors.white),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cardBg,
        selectedColor: AppColors.primary.withAlpha(51),
        labelStyle: AppTextStyles.caption.copyWith(color: textColor),
        secondaryLabelStyle: AppTextStyles.caption.copyWith(color: textSecondaryColor),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: borderColor),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: borderColor,
        thickness: 1,
      ),
    );
  }

  AppTheme._();
}
