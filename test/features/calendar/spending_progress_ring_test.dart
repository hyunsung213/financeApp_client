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

  group('spendingRingColor', () {
    test('0-50% stays pure safe green', () {
      expect(spendingRingColor(25), ringSafeGreen);
      expect(spendingRingColor(50), ringSafeGreen);
    });

    test('60% is an interpolated green-yellow tone, not a hard switch', () {
      final color = spendingRingColor(60);
      expect(color, isNot(ringSafeGreen));
      expect(color, isNot(ringWarningYellow));
    });

    test('75% lands exactly on pure warning yellow', () {
      expect(spendingRingColor(75), ringWarningYellow);
    });

    test('90% is an interpolated yellow-red tone, not a hard switch', () {
      final color = spendingRingColor(90);
      expect(color, isNot(ringWarningYellow));
      expect(color, isNot(ringDangerRed));
    });

    test('100%+ (including well over) stays pure danger red', () {
      expect(spendingRingColor(100), ringDangerRed);
      expect(spendingRingColor(110), ringDangerRed);
      expect(spendingRingColor(200), ringDangerRed);
    });

    test(
      'color shifts monotonically warmer as usage rises (no jumps back)',
      () {
        const samples = [0.0, 25.0, 50.0, 60.0, 75.0, 85.0, 90.0, 100.0, 110.0];
        for (var i = 1; i < samples.length; i++) {
          final prevRed = spendingRingColor(samples[i - 1]).r;
          final nextRed = spendingRingColor(samples[i]).r;
          expect(
            nextRed,
            greaterThanOrEqualTo(prevRed),
            reason: 'at ${samples[i]}%',
          );
        }
      },
    );
  });
}
