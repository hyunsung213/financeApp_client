import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_client/features/report/utils/smooth_line_spots.dart';

List<FlSpot> _daily(List<num> values) => [
  for (var i = 0; i < values.length; i++) FlSpot(i + 1.0, values[i].toDouble()),
];

void main() {
  // A real month: a 0원 stretch, a jump, ups and downs, a 20000 -> 0 -> 20000
  // dip, then 0원 again.
  final realMonth = _daily([0, 0, 0, 0, 0, 0, 0, 13550, 23400, 17300, 7050, 26900, 18100, 32300, 20000, 0, 20000, 0, 0, 0]);

  group('smoothLineSpots', () {
    test('keeps every original data point exactly (same x and y)', () {
      final smooth = smoothLineSpots(realMonth);
      for (final spot in realMonth) {
        expect(smooth.any((s) => s.x == spot.x && s.y == spot.y), isTrue, reason: 'day ${spot.x}');
      }
    });

    test('is sorted by x and adds only points between the originals', () {
      final smooth = smoothLineSpots(realMonth);
      for (var i = 1; i < smooth.length; i++) {
        expect(smooth[i].x, greaterThan(smooth[i - 1].x));
      }
      expect(smooth.first.x, realMonth.first.x);
      expect(smooth.last.x, realMonth.last.x);
    });

    test('never overshoots: between two data points the curve stays in their range', () {
      final smooth = smoothLineSpots(realMonth);
      for (final s in smooth) {
        final left = realMonth.lastWhere((p) => p.x <= s.x);
        final right = realMonth.firstWhere((p) => p.x >= s.x);
        final lo = left.y < right.y ? left.y : right.y;
        final hi = left.y < right.y ? right.y : left.y;
        expect(s.y, inInclusiveRange(lo, hi), reason: 'x=${s.x}');
      }
    });

    test('plot range is unchanged: no point above the max or below 0', () {
      final smooth = smoothLineSpots(realMonth);
      expect(smooth.map((s) => s.y).reduce((a, b) => a > b ? a : b), 32300);
      expect(smooth.map((s) => s.y).reduce((a, b) => a < b ? a : b), 0);
    });

    test('0원 stretch stays exactly level - nothing is interpolated up or down', () {
      final smooth = smoothLineSpots(realMonth);
      // Days 1..7 are all 0원.
      for (final s in smooth.where((s) => s.x <= 7)) {
        expect(s.y, 0, reason: 'x=${s.x}');
      }
      // ...and so is the 0원 tail, days 18..20.
      for (final s in smooth.where((s) => s.x >= 18)) {
        expect(s.y, 0, reason: 'x=${s.x}');
      }
    });

    test('entering spending eases in: the step from 0원 to a value is a rise, never a dip', () {
      final smooth = smoothLineSpots(realMonth);
      final ramp = smooth.where((s) => s.x >= 7 && s.x <= 8).toList();
      for (var i = 1; i < ramp.length; i++) {
        expect(ramp[i].y, greaterThanOrEqualTo(ramp[i - 1].y));
      }
      // Softer than a straight line: the first sample after 0원 is well below
      // the straight-line value.
      final straightFirst = 13550 / 8;
      expect(ramp[1].y, lessThan(straightFirst));
    });

    test('a rising run is a continuous rise, not a stair of flat spots', () {
      final smooth = smoothLineSpots(_daily([0, 10, 20, 30, 40]));
      // Interior tangents follow the slope, so the midpoint of the middle
      // interval is right on the straight line.
      final mid = smooth.firstWhere((s) => s.x == 3.5);
      expect(mid.y, closeTo(25, 1e-9));
    });

    test('a peak keeps its exact height and a valley its exact depth', () {
      final smooth = smoothLineSpots(_daily([0, 50, 100, 50, 0, 40, 0]));
      expect(smooth.map((s) => s.y).reduce((a, b) => a > b ? a : b), 100);
      expect(smooth.map((s) => s.y).reduce((a, b) => a < b ? a : b), 0);
    });

    test('an all-zero series stays all zero', () {
      final smooth = smoothLineSpots(_daily(List.filled(20, 0)));
      expect(smooth.every((s) => s.y == 0), isTrue);
    });

    test('fewer than 3 points are returned unchanged', () {
      expect(smoothLineSpots(const []), isEmpty);
      final one = [const FlSpot(1, 5)];
      expect(smoothLineSpots(one), one);
      final two = [const FlSpot(1, 5), const FlSpot(2, 9)];
      expect(smoothLineSpots(two), two);
    });

    test('handles gaps in the x axis (a missing day) without going out of range', () {
      final spots = [const FlSpot(1, 0), const FlSpot(2, 100), const FlSpot(5, 20), const FlSpot(6, 20), const FlSpot(7, 90)];
      final smooth = smoothLineSpots(spots);
      for (final s in smooth) {
        expect(s.y, inInclusiveRange(0, 100));
      }
      for (final s in smooth.where((s) => s.x >= 5 && s.x <= 6)) {
        expect(s.y, 20);
      }
    });
  });
}
