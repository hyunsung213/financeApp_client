import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/category/category_appearance.dart';
import '../../../data/api/category_api.dart';
import '../../../data/api/report_api.dart';
import '../utils/report_date_utils.dart';
import '../utils/report_insight_utils.dart';

int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toInt();
  if (value is String) {
    final clean = value.replaceAll(RegExp(r'[^0-9.-]'), '');
    return double.tryParse(clean)?.toInt() ?? 0;
  }
  return 0;
}

/// Selected month for every Report screen (main + monthly detail +
/// category detail all read/write this one provider so switching months in
/// one place keeps the others in sync).
class ReportMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();

  void setMonth(DateTime month) => state = DateTime(month.year, month.month, 1);
}

final reportMonthProvider = NotifierProvider<ReportMonthNotifier, DateTime>(() {
  return ReportMonthNotifier();
});

class DailyPoint {
  final int day;
  final int spent;
  const DailyPoint({required this.day, required this.spent});
}

List<DailyPoint> _toDailyPoints(List<dynamic> raw) {
  return raw.map((item) {
    final date = DateTime.tryParse((item['date'] ?? '').toString());
    return DailyPoint(day: date?.day ?? 0, spent: _toInt(item['spent']));
  }).where((p) => p.day > 0).toList()
    ..sort((a, b) => a.day.compareTo(b.day));
}

/// The report sends each row's canonical category name; the name shown is
/// the user's, looked up by the row's categoryId in [categories].
List<CategoryAmount> _toCategoryAmounts(List<dynamic> raw, CategoryDirectory categories) {
  return raw.map((item) {
    return CategoryAmount(
      name: categories.nameOf(item['categoryId']?.toString(), (item['category'] ?? '기타').toString())!,
      amount: _toInt(item['amount']),
      transactionCount: _toInt(item['transactionCount']),
      percentage: (item['percentage'] is num) ? (item['percentage'] as num).toDouble() : double.tryParse('${item['percentage']}') ?? 0,
      categoryId: item['categoryId']?.toString(),
      parentCategoryId: item['parentCategoryId']?.toString(),
    );
  }).toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));
}

/// The user's category names, or the report's own names if the category
/// list can't be loaded.
Future<CategoryDirectory> _categoryDirectory(Ref ref) async {
  try {
    return CategoryDirectory(await ref.watch(categoriesProvider.future));
  } catch (_) {
    return CategoryDirectory.empty;
  }
}

/// Everything the Report main screen (Figma 362:3635) needs, fetched and
/// derived in one place so the widget stays presentation-only.
class ReportMainData {
  final int totalExpense;
  final double? momPct;
  final List<DailyPoint> dailyPoints;
  final int? highlightDay;
  final int? highlightAmount;
  final List<CategoryAmount> categories;

  /// "이번 달 리포트 요약" rows (top 대분류 category / day / 주차) for the
  /// selected month; empty when that month has no spending.
  final List<ReportHighlight> highlights;

  const ReportMainData({
    required this.totalExpense,
    required this.momPct,
    required this.dailyPoints,
    required this.highlightDay,
    required this.highlightAmount,
    required this.categories,
    required this.highlights,
  });
}

final reportMainDataProvider = FutureProvider.autoDispose.family<ReportMainData, DateTime>((ref, month) async {
  final api = ref.watch(reportApiProvider);
  final range = monthComparisonRange(month);

  final fullMonth = DateOnlyRange(startOfMonth(month), endOfMonth(month));
  final currentSummary = await api.getSummary(startDate: range.current.startStr, endDate: range.current.endStr);
  // getDaily() returns the full {period, summary, daily} envelope
  // (API_SPEC.md's GET /api/reports/daily) - unwrap `daily` here.
  final dailyEnvelope = await api.getDaily(startDate: fullMonth.startStr, endDate: fullMonth.endStr);
  final dailyRaw = dailyEnvelope['daily'] as List<dynamic>? ?? const [];
  final categoriesRaw = await api.getCategories(startDate: range.current.startStr, endDate: range.current.endStr);

  int previousExpense = 0;
  try {
    final previousSummary = await api.getSummary(startDate: range.previous.startStr, endDate: range.previous.endStr);
    previousExpense = _toInt(previousSummary['expense']);
  } catch (_) {
    // Previous month may not exist yet for a brand-new account; MoM is
    // simply omitted below (momPercent already returns null for 0).
  }

  final now = DateTime.now();
  final isCurrentMonth = month.year == now.year && month.month == now.month;
  // Backend fills every day of the queried range, including future days
  // (as spent: 0), so without this cutoff the chart would draw a flat
  // zero-line through dates that haven't happened yet.
  final lastValidDay = isCurrentMonth ? now.day.clamp(1, daysInMonth(month)) : daysInMonth(month);

  final totalExpense = _toInt(currentSummary['expense']);
  final dailyPoints = _toDailyPoints(dailyRaw).where((p) => p.day <= lastValidDay).toList();
  final categories = _toCategoryAmounts(categoriesRaw, await _categoryDirectory(ref));
  final momPct = momPercent(totalExpense, previousExpense);
  final dailyRows = dailyRaw.cast<Map<String, dynamic>>();
  final peak = peakSpendingDay(dailyRows);

  // The report endpoint groups by leaf category name; the summary headline is
  // about 대분류, so roll it up using the category tree. If the category list
  // can't be loaded, fall back to the leaf names rather than hiding the row.
  var majorCategories = categories;
  try {
    majorCategories = rollUpToMajorCategories(categories, await ref.watch(categoriesProvider.future));
  } catch (_) {}

  final highlightDay = isCurrentMonth ? now.day : peak?.date.day;
  final highlightAmount = highlightDay == null
      ? null
      : dailyPoints.where((p) => p.day == highlightDay).map((p) => p.spent).firstOrNull;

  return ReportMainData(
    totalExpense: totalExpense,
    momPct: momPct,
    dailyPoints: dailyPoints,
    highlightDay: highlightDay,
    highlightAmount: highlightAmount,
    categories: categories,
    highlights: buildMainHighlights(
      month: month,
      topMajorCategory: topCategory(majorCategories),
      peakDay: peak,
      weeklyTotals: weeklyTotalsFromDaily(dailyRows),
    ),
  );
});

/// Everything the Monthly Report detail screens (Figma 114:5143 / 431:6676 /
/// 431:7759) need: this month + previous month daily rows (same-day-range
/// aware), plus the derived weekly buckets and category-growth comparison.
class MonthlyReportData {
  final MonthComparisonRange range;
  final List<Map<String, dynamic>> currentDaily;
  final List<Map<String, dynamic>> previousDaily;
  final int currentTotal;
  final int previousTotal;
  final double? momPct;
  final List<int> currentWeekly;
  final List<int> previousWeekly;
  final int? topWeekIndex;
  final List<CategoryAmount> currentCategories;
  final List<CategoryAmount> previousCategories;

  /// [currentCategories] (per-leaf, as the endpoint returns them) rolled up to
  /// 대분류, sorted by amount. The Category Report donut, its legend, and the
  /// percentages all read this one list so they can never disagree.
  final List<CategoryAmount> currentMajorCategories;

  /// [previousCategories] rolled up the same way, for the per-대분류 "지난달"
  /// comparison on the Category Report cards.
  final List<CategoryAmount> previousMajorCategories;

  /// Leaf name -> the 대분류 name it rolls up under, so per-leaf cards can
  /// take the color of their 대분류 slice.
  final Map<String, String> majorNameByCategoryName;
  final CategoryAmount? topGrowthCategory;
  final List<ReportInsight> insights;

  const MonthlyReportData({
    required this.range,
    required this.currentDaily,
    required this.previousDaily,
    required this.currentTotal,
    required this.previousTotal,
    required this.momPct,
    required this.currentWeekly,
    required this.previousWeekly,
    required this.topWeekIndex,
    required this.currentCategories,
    required this.previousCategories,
    required this.currentMajorCategories,
    required this.previousMajorCategories,
    required this.majorNameByCategoryName,
    required this.topGrowthCategory,
    required this.insights,
  });
}

final monthlyReportDataProvider = FutureProvider.autoDispose.family<MonthlyReportData, DateTime>((ref, month) async {
  final api = ref.watch(reportApiProvider);
  final range = monthComparisonRange(month);

  // The current period must succeed (it drives the whole screen). The
  // previous period is best-effort: a brand-new account may not have a
  // budget cycle far enough back yet, and that should degrade to "no
  // comparison data" rather than failing the whole screen (see
  // docs/development-work-policy.md §7 - Backend gap safely disabled, not
  // a broken page).
  // getDaily() returns the full {period, summary, daily} envelope
  // (API_SPEC.md's GET /api/reports/daily) - unwrap `daily` here.
  final currentDailyEnvelope = await api.getDaily(startDate: range.current.startStr, endDate: range.current.endStr);
  final currentDailyRaw = currentDailyEnvelope['daily'] as List<dynamic>? ?? const [];
  final currentCategoriesRaw = await api.getCategories(startDate: range.current.startStr, endDate: range.current.endStr);

  List<dynamic> previousDailyRaw = const [];
  List<dynamic> previousCategoriesRaw = const [];
  try {
    final previousDailyEnvelope = await api.getDaily(startDate: range.previous.startStr, endDate: range.previous.endStr);
    previousDailyRaw = previousDailyEnvelope['daily'] as List<dynamic>? ?? const [];
    previousCategoriesRaw = await api.getCategories(startDate: range.previous.startStr, endDate: range.previous.endStr);
  } catch (_) {
    // Keep defaults above; momPercent/topGrowthCategory already handle an
    // all-zero previous period by omitting that insight instead of faking one.
  }

  final currentDaily = currentDailyRaw.cast<Map<String, dynamic>>();
  final previousDaily = previousDailyRaw.cast<Map<String, dynamic>>();
  final directory = await _categoryDirectory(ref);
  var currentCategories = _toCategoryAmounts(currentCategoriesRaw, directory);
  final previousCategories = _toCategoryAmounts(previousCategoriesRaw, directory);

  // The endpoint groups by leaf category name; the donut/legend are about
  // 대분류, so roll up with the category tree. If the tree can't be loaded,
  // fall back to the leaf rows rather than hiding the chart.
  var currentMajorCategories = currentCategories;
  var previousMajorCategories = previousCategories;
  var majorNameByCategoryName = {for (final c in currentCategories) c.name: c.name};
  try {
    final tree = await ref.watch(categoriesProvider.future);
    currentMajorCategories = rollUpToMajorCategories(currentCategories, tree);
    previousMajorCategories = rollUpToMajorCategories(previousCategories, tree);
    majorNameByCategoryName = majorNamesByLeaf(currentCategories, tree);
    // Rows saved directly on a 대분류 are shown as "소분류 미지정" in the 소분류
    // list; without the tree they simply keep their own name.
    currentCategories = markUnspecifiedSubcategories(currentCategories, tree);
  } catch (_) {}

  final currentTotal = currentDaily.fold<int>(0, (sum, row) => sum + _toInt(row['spent']));
  final previousTotal = previousDaily.fold<int>(0, (sum, row) => sum + _toInt(row['spent']));
  final momPct = momPercent(currentTotal, previousTotal);

  final currentWeekly = weeklyTotalsFromDaily(currentDaily);
  final previousWeekly = weeklyTotalsFromDaily(previousDaily);
  final topWeekIndex = topWeekIndexOf(currentWeekly);

  CategoryAmount? topGrowthCategory;
  double bestGrowth = 0;
  for (final current in currentCategories) {
    final previous = previousCategories.where((c) => c.name == current.name).firstOrNull;
    final growth = current.amount - (previous?.amount ?? 0);
    if (growth > 0 && growth > bestGrowth) {
      bestGrowth = growth.toDouble();
      topGrowthCategory = current;
    }
  }

  return MonthlyReportData(
    range: range,
    currentDaily: currentDaily,
    previousDaily: previousDaily,
    currentTotal: currentTotal,
    previousTotal: previousTotal,
    momPct: momPct,
    currentWeekly: currentWeekly,
    previousWeekly: previousWeekly,
    topWeekIndex: topWeekIndex,
    currentCategories: currentCategories,
    previousCategories: previousCategories,
    currentMajorCategories: currentMajorCategories,
    previousMajorCategories: previousMajorCategories,
    majorNameByCategoryName: majorNameByCategoryName,
    topGrowthCategory: topGrowthCategory,
    insights: buildMonthlyInsights(momPct: momPct, topWeekIndex: topWeekIndex, topGrowthCategory: topGrowthCategory),
  );
});

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

/// This exact month's total expense (full calendar month), used by the
/// "전체 거래내역" screen's month-group subtotal header (Figma 470:9780:
/// "이번 달 소비 1,500,000원"). Keyed by month so Riverpod caches one
/// result per month instead of resumming from whatever page of the
/// transaction list happens to be loaded so far.
final monthTotalExpenseProvider = FutureProvider.autoDispose.family<int, DateTime>((ref, month) async {
  final api = ref.watch(reportApiProvider);
  final range = DateOnlyRange(startOfMonth(month), endOfMonth(month));
  final summary = await api.getSummary(startDate: range.startStr, endDate: range.endStr);
  return _toInt(summary['expense']);
});
