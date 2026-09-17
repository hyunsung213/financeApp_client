import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Design tokens scoped to the Home screen and the bottom navigation bar,
/// sourced from Figma node 335:8091 (home_main_final).
///
/// Values shared with other features delegate to `core/theme/app_colors.dart`
/// (see `AppColorTokens`); Calendar/Report/Policy already reuse many of the
/// fields below directly (despite this file's original scope being just
/// Home), so this is no longer Home-exclusive in practice.
class HomeTokens {
  HomeTokens._();

  // Hero gradient (top rounded panel behind the greeting/amount/D-Day card).
  static const List<Color> heroGradient = [
    Color(0xFF00AF76),
    Color(0xFF00AE76),
    Color(0xFF6DD9AB),
    Color(0xFFCDFFDA),
  ];
  static const List<double> heroGradientStops = [0.0, 0.14, 0.63, 1.0];

  static const Color accent = AppColorTokens.accent;
  static const Color accentDark = AppColorTokens.accentDark;
  static const Color textOnHero = AppColorTokens.softGreenTint;
  static const Color negative = AppColorTokens.negativeAccent;

  static const Color textDark = Color(0xFF2F2F2F);
  static const Color textMuted = Color(0xFFADADAD);
  static const Color textFaint = Color(0xFF6B7280);

  static const Color chipActiveBg = AppColorTokens.softGreenTint;
  static const Color chipActiveBorder = Color(0xFF9CD1A9);
  static const Color chipInactiveBg = AppColorTokens.surfaceOffWhite;
  static const Color chipInactiveBorder = AppColorTokens.borderNeutral;

  static const Color cardSurface = AppColorTokens.surfaceOffWhite;
  static const Color pageBackground = AppColorTokens.pageBackgroundHome;

  // D-Day summary card (hero panel). Opaque-enough surface + solid track so
  // the card's right edge and the gauge's fill-end stay legible even where
  // the hero gradient behind them has already faded to near-white.
  static const Color heroCardSurface = Color(0xFFFFFFFF);
  static const double heroCardSurfaceOpacity = 0.94;
  static const Color heroCardBorder = Color(0xFFFFFFFF);
  static const Color gaugeTrack = Color(0xFFE3F2EA);

  static const Color navInactive = Color(0xFFA0AFA4);
  static const Color navActiveBg = AppColorTokens.softGreenTint;
  static const Color navActiveText = AppColorTokens.accentDark;
}
