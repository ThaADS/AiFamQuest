import 'package:flutter/material.dart';

/// App Theme Model with 6 Complete ColorSchemes
///
/// Themes:
/// - cartoony: Bright, playful colors (kids 6-10)
/// - space: Dark blues, purples, cosmic (boys 10-15)
/// - stylish: Pastels, elegant (girls 10-15)
/// - minimal: Clean greys, whites (teens 15+)
/// - classy: Warm browns, golds (parents)
/// - dark: True dark mode (all ages)
enum AppThemeType {
  cartoony,
  space,
  stylish,
  minimal,
  classy,
  dark,
}

class AppThemeData {
  final AppThemeType type;
  final String name;
  final IconData icon;
  final ThemeData themeData;

  const AppThemeData({
    required this.type,
    required this.name,
    required this.icon,
    required this.themeData,
  });

  static AppThemeData fromString(String themeId) {
    switch (themeId) {
      case 'cartoony':
        return cartoony;
      case 'space':
        return space;
      case 'stylish':
        return stylish;
      case 'minimal':
        return minimal;
      case 'classy':
        return classy;
      case 'dark':
        return dark;
      default:
        return cartoony;
    }
  }

  String get id => type.name;

  // CARTOONY THEME - Bright, playful colors (kids 6-10)
  static final cartoony = AppThemeData(
    type: AppThemeType.cartoony,
    name: 'Cartoon',
    icon: Icons.emoji_emotions,
    themeData: ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFFF6B6B), // Bright coral red
        brightness: Brightness.light,
        primary: const Color(0xFFFF6B6B),
        primaryContainer: const Color(0xFFFFD6D6),
        secondary: const Color(0xFF4ECDC4), // Bright turquoise
        secondaryContainer: const Color(0xFFB8F2EF),
        tertiary: const Color(0xFFFFA07A), // Light salmon
        surface: const Color(0xFFFFF9F0),
        surfaceContainerHighest: const Color(0xFFFFEFD6),
        error: const Color(0xFFE63946),
      ),
      cardTheme: const CardThemeData(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 2,
      ),
    ),
  );

  // SPACE THEME - Dark blues, purples, cosmic (boys 10-15)
  static final space = AppThemeData(
    type: AppThemeType.space,
    name: 'Space',
    icon: Icons.rocket_launch,
    themeData: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6366F1), // Cosmic indigo
        brightness: Brightness.dark,
        primary: const Color(0xFF6366F1),
        primaryContainer: const Color(0xFF4338CA),
        secondary: const Color(0xFF8B5CF6), // Deep purple
        secondaryContainer: const Color(0xFF6D28D9),
        tertiary: const Color(0xFF06B6D4), // Cyan accent
        surface: const Color(0xFF0F172A), // Deep space blue
        surfaceContainerHighest: const Color(0xFF1E293B),
        error: const Color(0xFFEF4444),
      ),
      cardTheme: const CardThemeData(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
    ),
  );

  // STYLISH THEME - Pastels, elegant (girls 10-15)
  static final stylish = AppThemeData(
    type: AppThemeType.stylish,
    name: 'Stylish',
    icon: Icons.auto_awesome,
    themeData: ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFF8B4D9), // Soft pink
        brightness: Brightness.light,
        primary: const Color(0xFFF8B4D9),
        primaryContainer: const Color(0xFFFFE5F1),
        secondary: const Color(0xFFB4A7D6), // Lavender
        secondaryContainer: const Color(0xFFE5E0FF),
        tertiary: const Color(0xFFFAD4C0), // Peach
        surface: const Color(0xFFFFFBFE),
        surfaceContainerHighest: const Color(0xFFFFF0F7),
        error: const Color(0xFFDB5B8C),
      ),
      cardTheme: const CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 1,
      ),
    ),
  );

  // MINIMAL THEME - Clean greys, whites (teens 15+)
  static final minimal = AppThemeData(
    type: AppThemeType.minimal,
    name: 'Minimaal',
    icon: Icons.layers_outlined,
    themeData: ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF64748B), // Slate grey
        brightness: Brightness.light,
        primary: const Color(0xFF64748B),
        primaryContainer: const Color(0xFFE2E8F0),
        secondary: const Color(0xFF94A3B8),
        secondaryContainer: const Color(0xFFF1F5F9),
        tertiary: const Color(0xFF475569),
        surface: const Color(0xFFFAFAFA),
        surfaceContainerHighest: const Color(0xFFF5F5F5),
        error: const Color(0xFFEF4444),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
    ),
  );

  // CLASSY THEME - Warm browns, golds (parents)
  static final classy = AppThemeData(
    type: AppThemeType.classy,
    name: 'Klassiek',
    icon: Icons.diamond,
    themeData: ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6B4423), // Mocha brown
        brightness: Brightness.light,
        primary: const Color(0xFF6B4423),
        primaryContainer: const Color(0xFFB08968),
        secondary: const Color(0xFFD4A574), // Gold
        secondaryContainer: const Color(0xFFF5EBE0),
        tertiary: const Color(0xFF8B6F47),
        surface: const Color(0xFFFFFBF5),
        surfaceContainerHighest: const Color(0xFFF5EBE0),
        error: const Color(0xFFC1440E),
      ),
      cardTheme: const CardThemeData(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 2,
      ),
    ),
  );

  // DARK THEME - True dark mode (all ages)
  static final dark = AppThemeData(
    type: AppThemeType.dark,
    name: 'Donker',
    icon: Icons.dark_mode,
    themeData: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1E1E1E),
        brightness: Brightness.dark,
        primary: const Color(0xFF90CAF9), // Light blue accent
        primaryContainer: const Color(0xFF1565C0),
        secondary: const Color(0xFFCE93D8), // Light purple accent
        secondaryContainer: const Color(0xFF6A1B9A),
        tertiary: const Color(0xFF80CBC4), // Teal accent
        surface: const Color(0xFF121212),
        surfaceContainerHighest: const Color(0xFF1E1E1E),
        error: const Color(0xFFCF6679),
      ),
      cardTheme: const CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
    ),
  );

  // List of all available themes
  static List<AppThemeData> get allThemes => [
        cartoony,
        space,
        stylish,
        minimal,
        classy,
        dark,
      ];
}
