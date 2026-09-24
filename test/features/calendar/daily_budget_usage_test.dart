import 'package:flutter_test/flutter_test.dart';
import 'package:finance_client/features/calendar/utils/daily_budget_usage.dart';

void main() {
  group('dailyBudgetUsagePercent', () {
    test('25,000 recommended, 20,000 spent -> 80%', () {
      expect(dailyBudgetUsagePercent(spent: 20000, recommended: 25000), 80);
    });

    test('over the recommendation is not clamped: 30,000 / 25,000 -> 120%', () {
      expect(dailyBudgetUsagePercent(spent: 30000, recommended: 25000), 120);
    });

    test('no spending -> 0%, not null', () {
      expect(dailyBudgetUsagePercent(spent: 0, recommended: 25000), 0);
    });

    test('unknown recommended amount -> null (nothing to divide by)', () {
      expect(dailyBudgetUsagePercent(spent: 20000, recommended: null), isNull);
    });

    test('recommended amount of 0 (or below) -> null, never infinity/NaN', () {
      expect(dailyBudgetUsagePercent(spent: 20000, recommended: 0), isNull);
      expect(dailyBudgetUsagePercent(spent: 0, recommended: 0), isNull);
      expect(dailyBudgetUsagePercent(spent: 20000, recommended: -100), isNull);
    });

    test('negative spent is treated as 0', () {
      expect(dailyBudgetUsagePercent(spent: -500, recommended: 25000), 0);
    });
  });
}
