import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Light-only legacy tokens from Home (Figma 335:8091). Restyled screens read
/// the theme-aware `context.glass` (core/theme/wallet_glass.dart) instead;
/// these remain for the screens that still use them.
///
/// Values shared with other features delegate to `core/theme/app_colors.dart`
/// (see `AppColorTokens`); Calendar/Report/Policy already reuse many of the
/// fields below directly (despite this file's original scope being just
/// Home), so this is no longer Home-exclusive in practice.
class HomeTokens {
  HomeTokens._();

  static const Color accent = AppColorTokens.accent;
  static const Color accentDark = AppColorTokens.accentDark;
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
}
