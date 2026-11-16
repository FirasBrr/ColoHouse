import 'package:flutter/material.dart';

/// Light palette values. Widgets use `context.colors` (below) so they follow
/// the current theme; these constants are the light defaults.
class AppColors {
  static const primary = Color(0xFF2E7D6B);
  static const primaryDark = Color(0xFF076453);
  static const secondary = Color(0xFF35675A);
  static const secondaryContainer = Color(0xFFB6EBDA);
  static const surface = Color(0xFFECFDF8);
  static const surfaceLow = Color(0xFFE6F7F2);
  static const surfaceLowest = Color(0xFFFFFFFF);
  static const onSurface = Color(0xFF0F1E1C);
  static const onSurfaceVariant = Color(0xFF3F4945);
  static const outline = Color(0xFF6F7975);
  static const outlineVariant = Color(0xFFBEC9C4);
  static const error = Color(0xFFBA1A1A);
  static const errorContainer = Color(0xFFFFDAD6);
  static const tertiaryFixed = Color(0xFFFFDDB5);
  static const tertiary = Color(0xFF7B4F00);
}

/// The app colors for the current theme (light or dark), same names as AppColors.
/// Use it in widgets with `context.colors.surface`.
class AppPalette extends ThemeExtension<AppPalette> {
  final Color primary;
  final Color primaryDark;
  final Color secondary;
  final Color secondaryContainer;
  final Color surface;
  final Color surfaceLow;
  final Color surfaceLowest;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color outline;
  final Color outlineVariant;
  final Color error;
  final Color errorContainer;
  final Color tertiaryFixed;
  final Color tertiary;

  const AppPalette({
    required this.primary,
    required this.primaryDark,
    required this.secondary,
    required this.secondaryContainer,
    required this.surface,
    required this.surfaceLow,
    required this.surfaceLowest,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outline,
    required this.outlineVariant,
    required this.error,
    required this.errorContainer,
    required this.tertiaryFixed,
    required this.tertiary,
  });

  static const light = AppPalette(
    primary: AppColors.primary,
    primaryDark: AppColors.primaryDark,
    secondary: AppColors.secondary,
    secondaryContainer: AppColors.secondaryContainer,
    surface: AppColors.surface,
    surfaceLow: AppColors.surfaceLow,
    surfaceLowest: AppColors.surfaceLowest,
    onSurface: AppColors.onSurface,
    onSurfaceVariant: AppColors.onSurfaceVariant,
    outline: AppColors.outline,
    outlineVariant: AppColors.outlineVariant,
    error: AppColors.error,
    errorContainer: AppColors.errorContainer,
    tertiaryFixed: AppColors.tertiaryFixed,
    tertiary: AppColors.tertiary,
  );

  // Dark green-grey surfaces; primary stays readable with white text on buttons
  static const dark = AppPalette(
    primary: Color(0xFF3D9A84),
    primaryDark: Color(0xFF8AD9C4),
    secondary: Color(0xFF9CD1C1),
    secondaryContainer: Color(0xFF1F4A40),
    surface: Color(0xFF0E1715),
    surfaceLow: Color(0xFF16211F),
    surfaceLowest: Color(0xFF1C2826),
    onSurface: Color(0xFFE2EEEA),
    onSurfaceVariant: Color(0xFFBEC9C4),
    outline: Color(0xFF89938F),
    outlineVariant: Color(0xFF3F4945),
    error: Color(0xFFE5534B),
    errorContainer: Color(0xFF311311), // a bit darker so the red error text on it reads well (4.6:1)
    tertiaryFixed: Color(0xFF4A3410),
    tertiary: Color(0xFFFFC56B),
  );

  @override
  AppPalette copyWith({
    Color? primary,
    Color? primaryDark,
    Color? secondary,
    Color? secondaryContainer,
    Color? surface,
    Color? surfaceLow,
    Color? surfaceLowest,
    Color? onSurface,
    Color? onSurfaceVariant,
    Color? outline,
    Color? outlineVariant,
    Color? error,
    Color? errorContainer,
    Color? tertiaryFixed,
    Color? tertiary,
  }) {
    return AppPalette(
      primary: primary ?? this.primary,
      primaryDark: primaryDark ?? this.primaryDark,
      secondary: secondary ?? this.secondary,
      secondaryContainer: secondaryContainer ?? this.secondaryContainer,
      surface: surface ?? this.surface,
      surfaceLow: surfaceLow ?? this.surfaceLow,
      surfaceLowest: surfaceLowest ?? this.surfaceLowest,
      onSurface: onSurface ?? this.onSurface,
      onSurfaceVariant: onSurfaceVariant ?? this.onSurfaceVariant,
      outline: outline ?? this.outline,
      outlineVariant: outlineVariant ?? this.outlineVariant,
      error: error ?? this.error,
      errorContainer: errorContainer ?? this.errorContainer,
      tertiaryFixed: tertiaryFixed ?? this.tertiaryFixed,
      tertiary: tertiary ?? this.tertiary,
    );
  }

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    return AppPalette(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      secondaryContainer: Color.lerp(secondaryContainer, other.secondaryContainer, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceLow: Color.lerp(surfaceLow, other.surfaceLow, t)!,
      surfaceLowest: Color.lerp(surfaceLowest, other.surfaceLowest, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      onSurfaceVariant: Color.lerp(onSurfaceVariant, other.onSurfaceVariant, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      outlineVariant: Color.lerp(outlineVariant, other.outlineVariant, t)!,
      error: Color.lerp(error, other.error, t)!,
      errorContainer: Color.lerp(errorContainer, other.errorContainer, t)!,
      tertiaryFixed: Color.lerp(tertiaryFixed, other.tertiaryFixed, t)!,
      tertiary: Color.lerp(tertiary, other.tertiary, t)!,
    );
  }
}

extension AppPaletteContext on BuildContext {
  /// Colors of the current theme: `context.colors.surface`
  AppPalette get colors => Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}
