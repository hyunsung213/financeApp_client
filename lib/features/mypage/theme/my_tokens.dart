import 'package:flutter/material.dart';

/// Visual tokens for the My (설정) area, sourced from Figma section
/// FINAL_MY_SCREENS (537:1173).
///
/// Only values that differ from — or are missing in — `HomeTokens` live here,
/// so Home / Calendar keep their own chip and background colors untouched.
class MyTokens {
  MyTokens._();

  static const Color pageBackground = Color(0xFFF7F7F7);
  static const Color cardSurface = Color(0xFFFCFCFC);

  static const Color accent = Color(0xFF00AE76);
  static const Color accentDark = Color(0xFF007C4F);
  static const Color accentSoftBg = Color(0xFFD6F3E8);
  static const Color accentSoftBorder = Color(0xFFA9E1CF);
  static const Color negative = Color(0xFFEF6C4C);

  static const Color textPrimary = Color(0xFF2F2F2F);
  static const Color textMuted = Color(0xFFADADAD);
  static const Color placeholder = Color(0xFFA0AFA4);
  static const Color borderNeutral = Color(0xFFE4E4E4);

  /// Figma illustration placeholder: rgba(217,217,217,0.58).
  static const Color illustrationPlaceholder = Color(0x94D9D9D9);

  static const double cardRadius = 6;
  static const double buttonRadius = 16;
  static const double chipRadius = 30;
  static const double inputRadius = 6;

  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1)),
  ];

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
    transform: _HorizontalStretch(2.58),
  );
}

class _HorizontalStretch extends GradientTransform {
  const _HorizontalStretch(this.factor);

  final double factor;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final cx = bounds.center.dx;
    return Matrix4(
      factor,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      1,
      0,
      cx * (1 - factor),
      0,
      0,
      1,
    );
  }
}
