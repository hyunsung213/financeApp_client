import 'package:flutter/material.dart';

/// Design tokens scoped to the Home screen and the bottom navigation bar,
/// sourced from Figma node 335:8091 (home_main_final).
///
/// These are intentionally kept separate from `core/theme.dart`'s
/// `AppColors` so that Calendar / Report / Policy / MyPage — which have not
/// been re-designed against this Figma file yet — are not affected.
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

  static const Color accent = Color(0xFF00AE76);
  static const Color accentDark = Color(0xFF007C4F);
  static const Color textOnHero = Color(0xFFD6F3E8);
  static const Color negative = Color(0xFFEF6C4C);

  static const Color textDark = Color(0xFF2F2F2F);
  static const Color textMuted = Color(0xFFADADAD);
  static const Color textFaint = Color(0xFF6B7280);

  static const Color chipActiveBg = Color(0xFFE9FFEF);
  static const Color chipActiveBorder = Color(0xFF9CD1A9);
  static const Color chipInactiveBg = Color(0xFFFCFCFC);
  static const Color chipInactiveBorder = Color(0xFFE4E4E4);

  static const Color cardSurface = Color(0xFFFCFCFC);
  static const Color pageBackground = Color(0xFFF8FAF9);

  static const Color navInactive = Color(0xFFA0AFA4);
  static const Color navActiveBg = Color(0xFFD6F3E8);
  static const Color navActiveText = Color(0xFF007C4F);
}
