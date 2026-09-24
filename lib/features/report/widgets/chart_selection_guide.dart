import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../home/theme/home_tokens.dart';

/// Shared pieces for the daily-spending line charts' "selected day" readout:
/// the amount tooltip on top, the selected point, and the day badge below,
/// tied together by one dotted vertical guide so they read as a single axis.
///
/// All three are placed from the same [chartDayX], so their centers agree.
/// (The previous `Align(Alignment(x, 0))` placement only agreed at the middle
/// of the chart: `Align` positions a child's *edge* proportionally, so its
/// center drifted off the point by `(1 - fraction) * childWidth` elsewhere.)

/// Height of the strip above the plot area that holds the amount tooltip, so
/// the tooltip sits above the line instead of on top of it (the selected point
/// - often the month's peak, which is the default selection - would otherwise
/// be hidden behind it). Chart callers pass this as the top axis's
/// `reservedSize`.
const double kChartTooltipStrip = 54;

/// Same, for the Monthly Report's two-row (this month / last month) tooltip,
/// which is taller than the single date+amount one.
const double kChartCompareTooltipStrip = 68;

/// Clear space between the tooltip's bottom edge and the plot area's top; the
/// tooltip is pinned this far above the plot, and the guide starts there.
const double kChartTooltipGap = 6;

/// Height of the strip under the plot area that holds the day badge. Chart
/// callers pass this as the bottom axis's `reservedSize` so the plot area
/// itself keeps its own height and the badge gets clear space below the line.
const double kChartDayBadgeStrip = 44;

/// Height of [ChartDayBadge] (fixed, so the guide can end exactly where the
/// badge begins instead of depending on the font's line height).
const double kChartDayBadgeHeight = 28;

/// Pixel x of [day] on a chart whose x domain is `1..maxDay` spanning the full
/// [width] (the charts hide their left/right axis titles, so fl_chart reserves
/// no inset on either side).
double chartDayX(int day, int maxDay, double width) {
  if (maxDay <= 1) return 0;
  return ((day - 1) / (maxDay - 1)).clamp(0.0, 1.0) * width;
}

/// The small "which day" pill under the selected point.
class ChartDayBadge extends StatelessWidget {
  final int day;
  const ChartDayBadge({super.key, required this.day});

  @override
  Widget build(BuildContext context) {
    // A fixed `height` with no `alignment`: an `alignment` (or Center) would
    // make the Container expand to the full bounded width, turning the pill
    // into a bar. The min-size Row centers the text vertically instead, and
    // the pill shrink-wraps horizontally.
    return Container(
      height: kChartDayBadgeHeight,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        // The same mint tint as before, but opaque (composited over the white
        // card) so the guide line can never show through the pill.
        color: Color.alphaBlend(HomeTokens.accent.withValues(alpha: 0.10), Colors.white),
        borderRadius: BorderRadius.circular(kChartDayBadgeHeight / 2),
        border: Border.all(color: HomeTokens.accent.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$day', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: HomeTokens.accentDark)),
        ],
      ),
    );
  }
}

/// A subtle dotted vertical line that fills the box it is given (place it with
/// `Positioned(left: x - width / 2, top: ..., bottom: ..., width: ...)`).
class DottedVerticalGuide extends StatelessWidget {
  final Color color;
  const DottedVerticalGuide({super.key, this.color = HomeTokens.accent});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _DottedLinePainter(color.withValues(alpha: 0.5)));
  }
}

class _DottedLinePainter extends CustomPainter {
  final Color color;
  _DottedLinePainter(this.color);

  static const _dash = 1.5;
  static const _gap = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final x = size.width / 2;
    for (var y = 0.0; y < size.height; y += _dash + _gap) {
      canvas.drawLine(Offset(x, y), Offset(x, math.min(y + _dash, size.height)), paint);
    }
  }

  @override
  bool shouldRepaint(_DottedLinePainter old) => old.color != color;
}

/// Lays [child] out so its horizontal center sits on [anchorX] (pixels from
/// the left of the box it fills). Wrap it in `Positioned.fill` inside the
/// chart's `Stack`.
///
/// - [clampToChart]: keep the child inside the box, so a wide tooltip near
///   either end is shifted inward instead of being cut off. The guide line
///   still passes through the true point, which stays under the tooltip.
/// - [overhang]: with [clampToChart], how far (px) the child may still stick
///   out past either edge. The narrow day badge uses a little of it so it stays
///   centered under the point up to the very first/last day without touching
///   the card's border.
/// - [alignBottom]: pin the child to the box's bottom edge instead of the top.
class AnchoredChartLabel extends StatelessWidget {
  final double anchorX;
  final bool clampToChart;
  final double overhang;
  final bool alignBottom;
  final Widget child;

  const AnchoredChartLabel({
    super.key,
    required this.anchorX,
    required this.child,
    this.clampToChart = false,
    this.overhang = 0,
    this.alignBottom = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomSingleChildLayout(
      delegate: _AnchorDelegate(anchorX: anchorX, clampToChart: clampToChart, overhang: overhang, alignBottom: alignBottom),
      child: child,
    );
  }
}

class _AnchorDelegate extends SingleChildLayoutDelegate {
  final double anchorX;
  final bool clampToChart;
  final double overhang;
  final bool alignBottom;

  _AnchorDelegate({required this.anchorX, required this.clampToChart, required this.overhang, required this.alignBottom});

  @override
  // Loose in both axes, and unbounded in height: a label taller than the box it
  // is pinned in (e.g. under a larger text scale) should stick out of it, not
  // overflow-error.
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) => BoxConstraints(maxWidth: constraints.maxWidth);

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    var dx = anchorX - childSize.width / 2;
    if (clampToChart) dx = dx.clamp(-overhang, math.max(0.0, size.width - childSize.width) + overhang);
    return Offset(dx, alignBottom ? size.height - childSize.height : 0);
  }

  @override
  bool shouldRelayout(_AnchorDelegate old) =>
      old.anchorX != anchorX || old.clampToChart != clampToChart || old.overhang != overhang || old.alignBottom != alignBottom;
}
