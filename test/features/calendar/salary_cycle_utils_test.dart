import 'package:flutter_test/flutter_test.dart';
import 'package:finance_client/features/calendar/utils/salary_cycle_utils.dart';

void main() {
  group('salaryCycleContaining', () {
    test(
      'salary day 25: a date after the 25th falls in this month\'s cycle',
      () {
        final cycle = salaryCycleContaining(DateTime(2026, 8, 10), 25);
        expect(cycle.start, DateTime(2026, 7, 25));
        expect(cycle.end, DateTime(2026, 8, 24));
      },
    );

    test('salary day 25: the salary day itself starts a new cycle', () {
      final cycle = salaryCycleContaining(DateTime(2026, 7, 25), 25);
      expect(cycle.start, DateTime(2026, 7, 25));
      expect(cycle.end, DateTime(2026, 8, 24));
    });

    test('year rollover: December cycle crosses into January', () {
      final cycle = salaryCycleContaining(DateTime(2026, 12, 30), 25);
      expect(cycle.start, DateTime(2026, 12, 25));
      expect(cycle.end, DateTime(2027, 1, 24));
    });

    test('leap year: salary day 31 clamps to Feb 28/29 without drifting', () {
      // 2028 is a leap year.
      final cycle = salaryCycleContaining(DateTime(2028, 2, 20), 31);
      expect(cycle.start, DateTime(2028, 1, 31));
      expect(cycle.end, DateTime(2028, 2, 28));

      final leapCycle = salaryCycleContaining(DateTime(2028, 3, 1), 31);
      expect(leapCycle.start, DateTime(2028, 2, 29));
      expect(leapCycle.end, DateTime(2028, 3, 30));
    });
  });

  group('shiftSalaryCycle', () {
    test('previous and next cycle for salary day 25', () {
      final current = salaryCycleContaining(DateTime(2026, 8, 10), 25);

      final previous = shiftSalaryCycle(current, -1, 25);
      expect(previous.start, DateTime(2026, 6, 25));
      expect(previous.end, DateTime(2026, 7, 24));

      final next = shiftSalaryCycle(current, 1, 25);
      expect(next.start, DateTime(2026, 8, 25));
      expect(next.end, DateTime(2026, 9, 24));
    });

    test('does not drift after repeated shifts through a clamped month', () {
      final start = salaryCycleContaining(DateTime(2026, 1, 31), 31);
      var cycle = start;
      for (var i = 0; i < 12; i++) {
        cycle = shiftSalaryCycle(cycle, 1, 31);
      }
      // Back to the same calendar month a year later, still anchored on 31.
      expect(cycle.start.day, 31);
      expect(cycle.start.month, start.start.month);
      expect(cycle.start.year, start.start.year + 1);
    });
  });

  group('salaryCycleGridDays', () {
    test('always returns a multiple of 7 and covers the whole cycle', () {
      final cycle = salaryCycleContaining(DateTime(2026, 8, 10), 25);
      final days = salaryCycleGridDays(cycle);

      expect(days.length % 7, 0);
      expect(days.contains(cycle.start), isTrue);
      expect(days.contains(cycle.end), isTrue);
      expect(days.first.weekday % 7, 0); // grid starts on a Sunday
    });
  });
}
