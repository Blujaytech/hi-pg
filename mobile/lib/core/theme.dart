import 'package:flutter/material.dart';

/// Single source of truth for app-wide look & feel. Mirrors the visual spec
/// in the HTML prototype (dark + light, enterprise-grade) -- see the
/// technical plan §1. Swap the seed color / fonts here, not per-screen.
class AppTheme {
  AppTheme._();

  static const Color seed = Color(0xFF2F6FED);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(backgroundColor: scheme.surface, foregroundColor: scheme.onSurface, elevation: 0),
      inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder(), filled: false),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
      ),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(backgroundColor: scheme.surface, foregroundColor: scheme.onSurface, elevation: 0),
      inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder(), filled: false),
    );
  }
}
