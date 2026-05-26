import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

// -------------------------------------------------------
// Theme persistence
// -------------------------------------------------------
class ThemeScope extends InheritedWidget {
  final bool isDark;
  final VoidCallback toggle;

  const ThemeScope({
    super.key,
    required this.isDark,
    required this.toggle,
    required super.child,
  });

  static ThemeScope of(BuildContext context) {
    final result = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    assert(result != null, 'No ThemeScope found in context');
    return result!;
  }

  static Future<bool> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('theme_dark') ?? true;
  }

  static Future<void> saveToPrefs(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('theme_dark', isDark);
  }

  @override
  bool updateShouldNotify(ThemeScope oldWidget) => isDark != oldWidget.isDark;
}

// -------------------------------------------------------
// Theme-aware colors
// -------------------------------------------------------
class AppColors {
  final bool isDark;
  const AppColors({required this.isDark});

  // Brand (same in both modes)
  static const primary = Color(0xFF1296DB);
  static const primaryDark = Color(0xFF0E7AB5);
  static const primaryLight = Color(0xFF3DABE8);
  static const accent = Color(0xFF00C9A7);
  static const accentGlow = Color(0x6600C9A7);
  static const purple = Color(0xFF7C3AED);

  // Background
  Color get background => isDark ? const Color(0xFF0B0D17) : const Color(0xFFF5F6FA);
  Color get surface => isDark ? const Color(0xFF1A1D2A) : const Color(0xFFFFFFFF);
  Color get surfaceLight => isDark ? const Color(0xFF222633) : const Color(0xFFF0F0F5);
  Color get cardBg => isDark ? const Color(0x0AFFFFFF) : const Color(0xFFFFFFFF);

  // Text
  Color get text => isDark ? const Color(0xFFE8ECF4) : const Color(0xFF1A1A1A);
  Color get textSecondary => isDark ? const Color(0xFF8892A8) : const Color(0xFF6B7280);
  Color get textMuted => isDark ? const Color(0xFF5A6178) : const Color(0xFF9CA3AF);

  // Status
  static const success = Color(0xFF22C55E);
  static const danger = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);

  // Border
  Color get border => isDark ? const Color(0x0FFFFFFF) : const Color(0x1A000000);
}

extension AppColorsExtension on BuildContext {
  AppColors get appColors => AppColors(isDark: ThemeScope.of(this).isDark);
}

// -------------------------------------------------------
// Text styles
// -------------------------------------------------------
class AppTextStyles {
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

  static TextStyle scaled(TextStyle style, double scale) {
    return style.copyWith(fontSize: (style.fontSize! * scale).roundToDouble());
  }

  AppTextStyles._();
}
