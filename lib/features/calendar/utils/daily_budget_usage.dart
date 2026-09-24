/// How much of a day's recommended spending amount was actually spent, as a
/// percentage: `spent / recommended * 100`.
///
/// Not clamped - spending 150% of the recommendation is a real 150, the same
/// convention as the backend's `spendingRatio`
/// (docs/backend/calendar-daily-spending-ratio-requirements.md). Only the
/// day's expense counts; income never takes part.
///
/// Returns `null` when there is nothing to divide by: the recommended amount
/// is unknown (`null`) or `0` or negative. Callers should show a
/// "can't calculate" state then, never `0%` or infinity.
double? dailyBudgetUsagePercent({required int spent, required int? recommended}) {
  if (recommended == null || recommended <= 0) return null;
  return (spent < 0 ? 0 : spent) / recommended * 100;
}
