/// Salary-cycle date math shared by the Calendar screen.
///
/// A cycle runs from the user's salary day (inclusive) through the day
/// before the next occurrence of that salary day - e.g. salaryDay=25 gives
/// 2026-07-25 ~ 2026-08-24. This reuses the same `salaryDay` setting
/// Home/MyPage already fetch (`FinanceApi.getSetting()`); it only adds the
/// pure date arithmetic needed to page the Calendar grid by cycle, since
/// Home's own `daysUntilSalary` is relative-to-today only and can't be
/// shifted to arbitrary past/future cycles.
class SalaryCycle {
  final DateTime start;
  final DateTime end; // inclusive

  const SalaryCycle(this.start, this.end);

  bool contains(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return !d.isBefore(start) && !d.isAfter(end);
  }
}

/// Clamps [day] to the last valid day of [year]/[month], so a salary day of
/// 31 safely falls back to Feb 28/29, Apr/Jun/Sep/Nov 30, etc.
DateTime clampedMonthDay(int year, int month, int day) {
  final firstOfMonth = DateTime(year, month, 1);
  final lastDay = DateTime(firstOfMonth.year, firstOfMonth.month + 1, 0).day;
  return DateTime(
    firstOfMonth.year,
    firstOfMonth.month,
    day > lastDay ? lastDay : day,
  );
}

/// The salary cycle that [date] falls in, for a user whose salary lands on
/// [salaryDay] of each month.
SalaryCycle salaryCycleContaining(DateTime date, int salaryDay) {
  final day = DateTime(date.year, date.month, date.day);
  final thisMonthPayday = clampedMonthDay(day.year, day.month, salaryDay);
  final start = day.isBefore(thisMonthPayday)
      ? clampedMonthDay(day.year, day.month - 1, salaryDay)
      : thisMonthPayday;
  final nextStart = clampedMonthDay(start.year, start.month + 1, salaryDay);
  return SalaryCycle(start, nextStart.subtract(const Duration(days: 1)));
}

/// The cycle [offset] cycles away from [cycle] (negative = earlier), for the
/// same [salaryDay].
SalaryCycle shiftSalaryCycle(SalaryCycle cycle, int offset, int salaryDay) {
  final newStart = clampedMonthDay(
    cycle.start.year,
    cycle.start.month + offset,
    salaryDay,
  );
  final nextStart = clampedMonthDay(
    newStart.year,
    newStart.month + 1,
    salaryDay,
  );
  return SalaryCycle(newStart, nextStart.subtract(const Duration(days: 1)));
}

/// Sunday-aligned grid days spanning [cycle], padded with the previous/next
/// cycle's overflow days so every week row has exactly 7 days (shown muted),
/// and the total is always a multiple of 7 - never absolute-positioned, just
/// a flat day list a 7-column grid can chunk into rows.
List<DateTime> salaryCycleGridDays(SalaryCycle cycle) {
  final leading = cycle.start.weekday % 7; // Dart: Mon=1..Sun=7 -> Sun=0
  final gridStart = cycle.start.subtract(Duration(days: leading));
  final cycleLength = cycle.end.difference(cycle.start).inDays + 1;
  final daysBeforeTrailing = leading + cycleLength;
  final trailing = (7 - daysBeforeTrailing % 7) % 7;
  final total = daysBeforeTrailing + trailing;
  return List.generate(total, (i) => gridStart.add(Duration(days: i)));
}
