import 'package:flutter/material.dart';

/// Gradient transform that stretches a gradient horizontally by [factor]
/// around its bounds' center. Was independently hand-duplicated (identical
/// matrix math) as a private `_HorizontalStretch` class in both
/// `mypage/theme/my_tokens.dart` and `auth/widgets/auth_components.dart`;
/// this is the single shared copy both now reference.
class HorizontalStretchTransform extends GradientTransform {
  const HorizontalStretchTransform(this.factor);

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

/// Gradients shared across features - each a literal copy of a gradient
/// that was previously independently hand-written in 2+ places.
class AppGradients {
  AppGradients._();

  /// The manual-input FAB's radial gradient.
  static const RadialGradient fab = RadialGradient(
    colors: [Color(0xFF00AF76), Color(0xFFBFEBDD)],
  );
}
