import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Pure ring-ratio rule used by Calendar's day cells: no expense means no
/// ring at all (`null`), not a 0%-filled one; otherwise the spending
/// percentage clamped to 0..1 so 100%+ spending still shows a full ring,
/// never more than one lap. `spendingRatioPercent` is the backend's raw,
/// unclamped percent (100+ allowed) - only the ring's fill is clamped here,
/// the percentage label itself should keep showing the true value.
double? spendingRingRatio({
  required int expense,
  required double? spendingRatioPercent,
}) {
  if (expense <= 0 || spendingRatioPercent == null) return null;
  return (spendingRatioPercent / 100).clamp(0.0, 1.0);
}

// Continuous green -> yellow -> red ramp for the ring's *color* - a signal
// kept separate from the ring's *length* (spendingRingRatio above, which
// clamps at one lap past 100%). 0-50% stays green, 50-75% interpolates
// green->yellow, 75%+ interpolates yellow->red, so the color never jumps
// abruptly at the 50%/75% boundaries the way a plain 3-way switch would.
const Color ringSafeGreen = Color(0xFF00B67A);
const Color ringWarningYellow = Color(0xFFF4C542);
const Color ringDangerRed = Color(0xFFFF5A47);

Color spendingRingColor(double spendingRatioPercent) {
  if (spendingRatioPercent <= 50) return ringSafeGreen;
  if (spendingRatioPercent <= 75) {
    final t = (spendingRatioPercent - 50) / 25;
    return Color.lerp(ringSafeGreen, ringWarningYellow, t)!;
  }
  final t = ((spendingRatioPercent - 75) / 25).clamp(0.0, 1.0);
  return Color.lerp(ringWarningYellow, ringDangerRed, t)!;
}

/// Draws the "실제 지출 / 하루 권장 사용액" ring around a Calendar date cell.
///
/// Starts at 12 o'clock and sweeps clockwise. [ratio] must already be
/// clamped to 0..1 by the caller (spending over 100% still shows a full
/// ring, never more than one lap) - the unclamped percentage stays available
/// separately for the "125%" text label.
class SpendingProgressRing extends StatelessWidget {
  final double ratio;
  final Color color;
  final double size;
  final double strokeWidth;

  const SpendingProgressRing({
    super.key,
    required this.ratio,
    required this.color,
    this.size = 34,
    this.strokeWidth = 2.5,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _RingPainter(
        ratio: ratio.clamp(0, 1),
        color: color,
        strokeWidth: strokeWidth,
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double ratio;
  final Color color;
  final double strokeWidth;

  _RingPainter({
    required this.ratio,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (ratio <= 0) return;
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * ratio, false, paint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.ratio != ratio ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}
