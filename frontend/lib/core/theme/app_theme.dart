import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData light() => _build(AppPalette.light, Brightness.light);

  static ThemeData dark() => _build(AppPalette.dark, Brightness.dark);

  static ThemeData _build(AppPalette c, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
    ).copyWith(
      primary: c.primary,
      onPrimary: Colors.white,
      surface: c.surface,
      onSurface: c.onSurface,
      onSurfaceVariant: c.onSurfaceVariant,
      outline: c.outline,
      outlineVariant: c.outlineVariant,
      error: c.error,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.surface,
      extensions: [c],
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceLowest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.error),
        ),
        labelStyle: TextStyle(color: c.onSurfaceVariant),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      // White text on every SnackBar, also the red error ones; dark grey background in dark mode
      snackBarTheme: SnackBarThemeData(
        backgroundColor: brightness == Brightness.dark ? const Color(0xFF2A3633) : null,
        contentTextStyle: const TextStyle(color: Colors.white),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.surfaceLowest,
        foregroundColor: c.onSurface,
        elevation: 0.5,
        // Stay white when content scrolls under (Material 3 tints it grey-green by default)
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
      ),
    );
  }
}
