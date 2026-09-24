import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_client/features/calendar/widgets/spending_progress_ring.dart';

void main() {
  group('spendingRingRatio', () {
    test('no expense -> no ring, even if a ratio is somehow present', () {
      expect(spendingRingRatio(expense: 0, spendingRatioPercent: 60), isNull);
    });

    test('no ratio data -> no ring', () {
      expect(
        spendingRingRatio(expense: 5000, spendingRatioPercent: null),
        isNull,
      );
    });

    // 권장 20,000 기준 케이스들 (spendingRatioPercent = expense / recommended * 100).
    test('지출 5,000 / 권장 20,000 -> 25%', () {
      expect(spendingRingRatio(expense: 5000, spendingRatioPercent: 25), 0.25);
    });

    test('지출 10,000 / 권장 20,000 -> 50%', () {
      expect(spendingRingRatio(expense: 10000, spendingRatioPercent: 50), 0.5);
    });

    test('지출 20,000 / 권장 20,000 -> 100%', () {
      expect(spendingRingRatio(expense: 20000, spendingRatioPercent: 100), 1.0);
    });

    test('지출 30,000 / 권장 20,000 -> over 100%, ring clamps to a full lap', () {
      expect(spendingRingRatio(expense: 30000, spendingRatioPercent: 150), 1.0);
    });
  });

  // The Sep 10 - Oct 9 cycle from the emulator: cheapest spending day is the
  // 11th (7,050), priciest is the 14th (32,300).
  const minSpend = 7050.0;
  const maxSpend = 32300.0;
  final emulatorDays = <int, double>{
    11: 7050,
    10: 17300,
    13: 18100,
    15: 20000,
    17: 20000,
    12: 26900,
    14: 32300,
  };

  Color colorOf(double amount) =>
      spendIntensityColor(amount, minSpend, maxSpend);

  double hueOf(double amount) => HSLColor.fromColor(colorOf(amount)).hue;

  group('spendIntensity', () {
    test('cheapest day is 0, priciest day is 1, linear in between', () {
      expect(spendIntensity(minSpend, minSpend, maxSpend), 0);
      expect(spendIntensity(maxSpend, minSpend, maxSpend), 1);
      expect(spendIntensity(19675, minSpend, maxSpend), closeTo(0.5, 1e-9));
    });

    test('same amount -> same intensity (15th and 17th, both 20,000)', () {
      expect(
        spendIntensity(emulatorDays[15]!, minSpend, maxSpend),
        spendIntensity(emulatorDays[17]!, minSpend, maxSpend),
      );
    });

    test('out-of-range amounts clamp to 0..1', () {
      expect(spendIntensity(1000, minSpend, maxSpend), 0);
      expect(spendIntensity(99999, minSpend, maxSpend), 1);
    });

    test('no spending, a single day, or a flat range never yields NaN/inf', () {
      expect(spendIntensity(0, minSpend, maxSpend), 0);
      expect(spendIntensity(-5, minSpend, maxSpend), 0);
      expect(spendIntensity(20000, 20000, 20000), 0);
      expect(spendIntensity(20000, 0, 0), 0);
      expect(spendIntensity(20300, 20000, 20400), 0);
    });
  });

  group('spendIntensityColor', () {
    test('cheapest day is the pure safe green, priciest the danger red', () {
      expect(colorOf(minSpend), ringSafeGreen);
      expect(colorOf(maxSpend), ringDangerRed);
    });

    test('equal amounts get the identical color (15th == 17th)', () {
      expect(colorOf(emulatorDays[15]!), colorOf(emulatorDays[17]!));
    });

    test('a larger amount never gets a greener hue than a smaller one', () {
      final ordered = emulatorDays.values.toSet().toList()..sort();
      for (var i = 1; i < ordered.length; i++) {
        expect(
          hueOf(ordered[i]),
          lessThanOrEqualTo(hueOf(ordered[i - 1])),
          reason: '${ordered[i]} vs ${ordered[i - 1]}',
        );
      }
    });

    test('emulator days read green -> orange -> red as the amount grows', () {
      // 11th: greenest. 10th/13th/15th/17th: orange band (hue 20..45), not
      // yellow. 12th: clearly redder than 20k. 14th: the reddest.
      expect(hueOf(7050), greaterThan(140));
      for (final d in [17300.0, 18100.0, 20000.0]) {
        expect(hueOf(d), inInclusiveRange(20, 45), reason: '$d');
      }
      expect(hueOf(26900), lessThan(hueOf(20000)));
      expect(hueOf(32300), lessThan(hueOf(26900)));
    });

    test('flat or degenerate range falls back to the safe green', () {
      expect(spendIntensityColor(20000, 20000, 20000), ringSafeGreen);
      expect(spendIntensityColor(20000, 20500, 20000), ringSafeGreen);
      expect(spendIntensityColor(0, minSpend, maxSpend), ringSafeGreen);
    });
  });
}
