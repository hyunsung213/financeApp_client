import 'package:fl_chart/fl_chart.dart';

/// Turns a daily line chart's data points into a densely sampled, smoothly
/// connected path through those same points - a presentation-only change: every
/// original spot is kept exactly (same x, same y) and the line never goes above
/// or below the two data points it runs between.
///
/// Why not just `LineChartBarData.isCurved`? fl_chart's curve is a plain
/// Catmull-Rom-style spline, so next to a 0원 stretch it swings under the 0
/// baseline (measured: ~7px of a 150px plot on a real month), and its
/// `preventCurveOverShooting` switch only flattens the tangent where the next
/// value is higher, keyed off a pixel threshold - so a rising run turns into a
/// staircase of S-curves, and the shape changes with the chart's width.
///
/// This uses monotone cubic Hermite interpolation (Fritsch-Butland tangents,
/// the same idea as d3's `curveMonotoneX`): the tangent at a peak, a valley or
/// a flat 0원 stretch is 0, and everywhere else it is a weighted harmonic mean
/// of the two neighbouring slopes. That gives
/// - no overshoot: between two data points the curve stays within their range,
///   so a spike is never drawn taller than it is and the line never dips below
///   0 next to a 0원 day;
/// - flat stays flat: two equal neighbours are joined by an exactly level line;
/// - a soft ease in/out where spending starts or stops, and a continuous rise
///   through a run of increasing days (no stair-stepped S-curves).
///
/// [spots] must be sorted by x with strictly increasing x. Fewer than 3 spots
/// are returned unchanged (nothing to smooth). [stepsPerInterval] samples are
/// generated between each pair of neighbouring data points.
List<FlSpot> smoothLineSpots(List<FlSpot> spots, {int stepsPerInterval = 8}) {
  final n = spots.length;
  if (n < 3 || stepsPerInterval < 2) return spots;

  // Interval widths and secant slopes.
  final h = List<double>.generate(n - 1, (i) => spots[i + 1].x - spots[i].x);
  final delta = List<double>.generate(n - 1, (i) => (spots[i + 1].y - spots[i].y) / h[i]);

  // Tangent (slope) at every data point.
  final m = List<double>.filled(n, 0);
  m[0] = delta[0];
  m[n - 1] = delta[n - 2];
  for (var k = 1; k < n - 1; k++) {
    final d0 = delta[k - 1];
    final d1 = delta[k];
    // A peak, a valley, or a flat side: keep the tangent level so the curve
    // can't overshoot there.
    if (d0 == 0 || d1 == 0 || (d0 > 0) != (d1 > 0)) {
      m[k] = 0;
    } else {
      final w0 = 2 * h[k] + h[k - 1];
      final w1 = h[k] + 2 * h[k - 1];
      m[k] = (w0 + w1) / (w0 / d0 + w1 / d1);
    }
  }

  final result = <FlSpot>[spots.first];
  for (var i = 0; i < n - 1; i++) {
    final p0 = spots[i];
    final p1 = spots[i + 1];
    final lo = p0.y < p1.y ? p0.y : p1.y;
    final hi = p0.y < p1.y ? p1.y : p0.y;
    for (var s = 1; s < stepsPerInterval; s++) {
      final t = s / stepsPerInterval;
      final t2 = t * t;
      final t3 = t2 * t;
      final y =
          (2 * t3 - 3 * t2 + 1) * p0.y +
          (t3 - 2 * t2 + t) * h[i] * m[i] +
          (-2 * t3 + 3 * t2) * p1.y +
          (t3 - t2) * h[i] * m[i + 1];
      // Belt and braces: the math above already stays in range, this only
      // absorbs floating-point noise so the plot's min/max never move.
      result.add(FlSpot(p0.x + h[i] * t, y.clamp(lo, hi)));
    }
    result.add(p1);
  }
  return result;
}
