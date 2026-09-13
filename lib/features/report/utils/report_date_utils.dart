import 'package:intl/intl.dart';

/// Date-range math shared by every Report screen.
///
/// Centralized here (instead of inline in widgets) because the "동일 일자
/// 기준 비교" rule from Figma FINAL_REPORT_SCREENS (node 470:9711 area) has
/// to stay identical across the main Report screen and every Monthly Report
/// detail screen: "진행 중인 달은 동일 일자(1일~N일) 기준으로 지난달과
/// 비교하고, 완료된 과거 달끼리는 전체 기간으로 비교한다."
class DateOnlyRange {
  final DateTime start;
  final DateTime end;
  const DateOnlyRange(this.start, this.end);

  String get startStr => formatDateOnly(start);
  String get endStr => formatDateOnly(end);
}

/// A same-period comparison between a month and the month before it.
class MonthComparisonRange {
  final DateOnlyRange current;
  final DateOnlyRange previous;

  /// True when [current] is the in-progress calendar month (so both ranges
  /// are clamped to the same day-of-month instead of full months).
  final bool isPartial;

  /// Last day-of-month included in both ranges when [isPartial] is true.
  final int? comparisonDay;

  const MonthComparisonRange({
    required this.current,
    required this.previous,
    required this.isPartial,
    this.comparisonDay,
  });
}

String formatDateOnly(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

String monthKey(DateTime d) => DateFormat('yyyy-MM').format(d);

DateTime startOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

/// Last calendar day of [d]'s month. Using day 0 of the following month is
/// the safe way to get this in Dart/`DateTime` regardless of month length or
/// leap years (Feb 28 vs 29 falls out automatically).
DateTime endOfMonth(DateTime d) => DateTime(d.year, d.month + 1, 0);

int daysInMonth(DateTime d) => endOfMonth(d).day;

DateTime addMonths(DateTime d, int delta) => DateTime(d.year, d.month + delta, 1);

/// Builds the current-vs-previous-month comparison range for [month],
/// evaluated against [today].
///
/// - If [month] is the calendar month [today] falls in, both ranges are
///   clamped to day 1..min(today.day, lengthOfThatMonth) so a still-in-progress
///   month is never unfairly compared against a previous month's full total.
///   The previous month's end day is clamped to its own length (e.g. Aug 31
///   compares against Feb 28/29, not an invalid Feb 31).
/// - Otherwise [month] is a completed month, so both ranges use the full
///   month.
MonthComparisonRange monthComparisonRange(DateTime month, {DateTime? today}) {
  final now = today ?? DateTime.now();
  final previousMonth = addMonths(month, -1);
  final isCurrentCalendarMonth = month.year == now.year && month.month == now.month;

  if (!isCurrentCalendarMonth) {
    return MonthComparisonRange(
      current: DateOnlyRange(startOfMonth(month), endOfMonth(month)),
      previous: DateOnlyRange(startOfMonth(previousMonth), endOfMonth(previousMonth)),
      isPartial: false,
    );
  }

  final comparisonDay = now.day.clamp(1, daysInMonth(month));
  final previousComparisonDay = comparisonDay.clamp(1, daysInMonth(previousMonth));
  return MonthComparisonRange(
    current: DateOnlyRange(startOfMonth(month), DateTime(month.year, month.month, comparisonDay)),
    previous: DateOnlyRange(
      startOfMonth(previousMonth),
      DateTime(previousMonth.year, previousMonth.month, previousComparisonDay),
    ),
    isPartial: true,
    comparisonDay: comparisonDay,
  );
}

/// Groups a month's `/api/reports/daily` rows into "주차" (week-of-month)
/// buckets the way Figma's weekly-comparison screens do: week N covers days
/// `(N-1)*7 + 1` .. `N*7`, and any day past day 28 (the 29th/30th/31st, when
/// present) folds into week 4 so every month always shows exactly 4 weeks.
///
/// This is a deterministic, documented business rule invented on the
/// frontend because no backend endpoint defines "주차" — see
/// docs/backend/report-backend-requirements.md.
List<int> weeklyTotalsFromDaily(List<Map<String, dynamic>> dailyRows) {
  final totals = List<int>.filled(4, 0);
  for (final row in dailyRows) {
    final date = DateTime.tryParse((row['date'] ?? '').toString());
    if (date == null) continue;
    final spent = (row['spent'] is num) ? (row['spent'] as num).toInt() : int.tryParse('${row['spent']}') ?? 0;
    final weekIndex = ((date.day - 1) ~/ 7).clamp(0, 3);
    totals[weekIndex] += spent;
  }
  return totals;
}
