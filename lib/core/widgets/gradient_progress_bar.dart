import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A linear progress bar whose filled portion is a gradient instead of a
/// flat color. `LinearProgressIndicator.valueColor` only accepts a single
/// color, so this builds the fill with a plain gradient-decorated box sized
/// by `value` instead.
class GradientProgressBar extends StatelessWidget {
  final double value;
  final double height;
  final List<Color> colors;
  final Color backgroundColor;
  final BorderRadius? borderRadius;

  const GradientProgressBar({
    super.key,
    required this.value,
    required this.colors,
    this.height = 6,
    this.backgroundColor = AppColorTokens.dividerTrack,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(height / 2);
    return ClipRRect(
      borderRadius: radius,
      child: Container(
        height: height,
        color: backgroundColor,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors, begin: Alignment.centerLeft, end: Alignment.centerRight),
            ),
          ),
        ),
      ),
    );
  }
}
