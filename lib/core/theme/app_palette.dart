import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Brightness-dependent surface/text colors, registered on both `appTheme`
/// and `appDarkTheme` (core/theme.dart).
///
/// Most screens still use const light tokens (`MyTokens`, `HomeTokens`, ...)
/// and do not follow dark mode yet. A screen becomes dark-ready by reading
/// these through `context.palette` instead of those constants.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color pageBackground;
  final Color cardSurface;
  final Color textPrimary;
  final Color textMuted;
  final Color border;
  final Color accent;

  const AppPalette({
    required this.pageBackground,
    required this.cardSurface,
    required this.textPrimary,
    required this.textMuted,
    required this.border,
    required this.accent,
  });

  /// Same values as `MyTokens` (Figma FINAL_MY_SCREENS).
  static const AppPalette light = AppPalette(
    pageBackground: AppColorTokens.pageBackgroundMy,
    cardSurface: AppColorTokens.surfaceOffWhite,
    textPrimary: Color(0xFF2F2F2F),
    textMuted: Color(0xFFADADAD),
    border: AppColorTokens.borderNeutral,
    accent: AppColorTokens.accent,
  );

  /// No Figma dark spec exists; neutral greys picked to keep the light
  /// theme's contrast relationships, with the same brand green.
  static const AppPalette dark = AppPalette(
    pageBackground: Color(0xFF121413),
    cardSurface: Color(0xFF1E2120),
    textPrimary: Color(0xFFECEEED),
    textMuted: Color(0xFF8A908D),
    border: Color(0xFF353B38),
    accent: AppColorTokens.accent,
  );

  @override
  AppPalette copyWith({
    Color? pageBackground,
    Color? cardSurface,
    Color? textPrimary,
    Color? textMuted,
    Color? border,
    Color? accent,
  }) {
    return AppPalette(
      pageBackground: pageBackground ?? this.pageBackground,
      cardSurface: cardSurface ?? this.cardSurface,
      textPrimary: textPrimary ?? this.textPrimary,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
      accent: accent ?? this.accent,
    );
  }

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    return AppPalette(
      pageBackground: Color.lerp(pageBackground, other.pageBackground, t)!,
      cardSurface: Color.lerp(cardSurface, other.cardSurface, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
    );
  }
}

extension AppPaletteContext on BuildContext {
  /// Falls back to [AppPalette.light] when a test pumps a bare `MaterialApp`
  /// without the app themes.
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}
