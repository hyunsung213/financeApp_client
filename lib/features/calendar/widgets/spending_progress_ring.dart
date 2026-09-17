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

// The three stops of the ring's color heat-scale - soft, desaturated tones
// (not the original saturated 0xFF00B67A/0xFFF4C542/0xFFFF5A47) so the scale
// reads as mint/apricot/coral rather than a hard flourescent outline.
const Color ringSafeGreen = Color(0xFF4FC994);
const Color ringMidOrange = Color(0xFFF3A65E);
const Color ringDangerRed = Color(0xFFF37E6B);

/// Colors a Calendar day's ring by how big `amount` is relative to this
/// cycle's spending days, as one continuous green -> orange -> red gradient
/// rather than sorting each day into a fixed green/orange/red bucket.
///
/// Two things that matter here:
///
/// 1. Normalization is against `minAmount`..`maxAmount` (the cycle's
///    smallest and biggest spending days - see `_expenseRangeInCycle` in
///    calendar_screen.dart), not `0`..`maxAmount`. Anchoring the low end to
///    the actual cheapest spending day (rather than 0) keeps every day's `t`
///    spread across the full 0..1 range instead of bunching every ordinary
///    day into the bottom fifth of it, so a day that's only a little pricier
///    than the cycle's cheapest one doesn't get pushed further up the scale
///    than it should.
/// 2. The two half-segments (`low`->`mid`, `mid`->`high`) are interpolated
///    in HSL space (via [HSLColor.lerp]), not component-wise RGB (the old
///    plain `Color.lerp`). RGB-lerping a green and an orange averages their
///    channels directly, and because green is G-heavy/B-mid while orange is
///    R-heavy/B-low, the midpoint of that average lands on R≈G with low B -
///    literally khaki/olive, with saturation collapsing from ~0.86 down to
///    ~0.3 at the worst point. HSL-lerp instead moves hue/saturation/
///    lightness independently, so the transition sweeps through the actual
///    green->yellow->orange hue path at consistently high saturation
///    instead of cutting across the RGB cube through its dull center.
Color spendIntensityColor(double amount, double minAmount, double maxAmount) {
  if (amount <= 0) return ringSafeGreen;
  if (maxAmount <= minAmount) return ringSafeGreen;
  final t = ((amount - minAmount) / (maxAmount - minAmount)).clamp(0.0, 1.0);
  final low = HSLColor.fromColor(ringSafeGreen);
  final mid = HSLColor.fromColor(ringMidOrange);
  final high = HSLColor.fromColor(ringDangerRed);
  final hsl = t <= 0.5
      ? HSLColor.lerp(low, mid, t / 0.5)!
      : HSLColor.lerp(mid, high, (t - 0.5) / 0.5)!;
  return hsl.toColor();
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
    // A soft solid stroke reads as a hard, flat outline at this size, so the
    // ring sweeps between a lighter and a slightly deeper shade of the same
    // color instead - just enough tonal drift to feel gently drawn rather
    // than a stamped-on ring, without changing what the color itself means.
    final hsl = HSLColor.fromColor(color);
    final startColor = hsl
        .withLightness((hsl.lightness + 0.12).clamp(0.0, 1.0))
        .toColor();
    final endColor = hsl
        .withLightness((hsl.lightness - 0.08).clamp(0.0, 1.0))
        .toColor();
    final paint = Paint()
      ..shader = SweepGradient(
        colors: [startColor, endColor],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect)
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
