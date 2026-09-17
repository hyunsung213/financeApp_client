import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_shadows.dart';

/// Visual tokens for the My (설정) area, sourced from Figma section
/// FINAL_MY_SCREENS (537:1173).
///
/// Values shared with other features delegate to `core/theme/`; only values
/// that differ from - or are missing in - the shared tokens/`HomeTokens`
/// live here as their own literal.
class MyTokens {
  MyTokens._();

  static const Color pageBackground = AppColorTokens.pageBackgroundMy;
  static const Color cardSurface = AppColorTokens.surfaceOffWhite;

  static const Color accent = AppColorTokens.accent;
  static const Color accentDark = AppColorTokens.accentDark;
  static const Color accentSoftBg = AppColorTokens.softGreenTint;
  static const Color accentSoftBorder = AppColorTokens.softGreenBorder;
  static const Color negative = AppColorTokens.negativeAccent;

  static const Color textPrimary = Color(0xFF2F2F2F);
  static const Color textMuted = Color(0xFFADADAD);
  static const Color placeholder = Color(0xFFA0AFA4);
  static const Color borderNeutral = AppColorTokens.borderNeutral;

  /// Figma illustration placeholder: rgba(217,217,217,0.58).
  static const Color illustrationPlaceholder = Color(0x94D9D9D9);

  static const double cardRadius = AppRadii.compactInput;
  static const double buttonRadius = AppRadii.button;
  static const double chipRadius = AppRadii.pill;
  static const double inputRadius = AppRadii.compactInput;

  static const List<BoxShadow> cardShadow = AppShadows.card;

  static const List<Color> progressGradient = [accent, accentSoftBorder];

  /// Figma "저장" / "이전화면으로 돌아가기" radial gradient. The Figma ellipse is
  /// ~2.58x wider than tall, so the circle is stretched horizontally.
  static const RadialGradient primaryGradient = RadialGradient(
    radius: 1.42,
    colors: [
      Color(0xFF00AF76),
      Color(0xFF10B47F),
      Color(0xFF20B987),
      Color(0xFF40C398),
      Color(0xFF60CDA9),
      Color(0xFF80D7BA),
    ],
    stops: [0.2596, 0.3522, 0.4447, 0.6298, 0.8149, 1.0],
    transform: HorizontalStretchTransform(2.58),
  );
}
