import 'package:flutter/material.dart';
import 'report_date_utils.dart';

/// Rule-based Report insight sentences.
///
/// Every sentence here is derived from raw numbers the backend already
/// returns (`/api/reports/summary|daily|categories|monthly`) — none of this
/// is AI-generated or free text, matching docs/development-work-policy.md
/// §6 (calculation logic stays out of widgets) and the product decision to keep Report
/// insights fully deterministic. Pass this module's outputs straight into
/// presentation widgets; do not recompute any of this inline in a Widget.
class ReportInsight {
  final IconData icon;
  final String text;
  final bool positive;

  const ReportInsight({required this.icon, required this.text, required this.positive});
}

/// Percent change from [previous] to [current]. Null when [previous] is 0
/// (no meaningful percentage to report) so callers can skip the sentence
/// instead of showing a fake/undefined number.
double? momPercent(int current, int previous) {
  if (previous == 0) return null;
  return (current - previous) / previous * 100;
}

class CategoryAmount {
  final String name;
  final int amount;
  final int transactionCount;
  final double percentage;

  /// The category the amount was saved on, and its parent (null for a root /
  /// 대분류). `/api/reports/categories` returns both as metadata; they are null
  /// when talking to a backend that predates it (see [markUnspecifiedSubcategories]).
  final String? categoryId;
  final String? parentCategoryId;

  /// True for a row that is really a transaction saved directly on a 대분류
  /// which has 소분류 (legacy data), so its 소분류 list shows it as
  /// [unspecifiedSubcategoryLabel] instead of repeating the 대분류 name.
  final bool isUnspecifiedSubcategory;

  const CategoryAmount({
    required this.name,
    required this.amount,
    required this.transactionCount,
    required this.percentage,
    this.categoryId,
    this.parentCategoryId,
    this.isUnspecifiedSubcategory = false,
  });

  CategoryAmount markedUnspecifiedSubcategory() => CategoryAmount(
        name: name,
        amount: amount,
        transactionCount: transactionCount,
        percentage: percentage,
        categoryId: categoryId,
        parentCategoryId: parentCategoryId,
        isUnspecifiedSubcategory: true,
      );
}

/// What a 소분류 list calls a transaction that was saved on a 대분류 itself.
const unspecifiedSubcategoryLabel = '소분류 미지정';

/// Flags the rows that are a 대분류 total (transactions saved directly on a
/// category that has 소분류) so the 소분류 list can label them
/// [unspecifiedSubcategoryLabel]. Amounts, counts and order are untouched.
///
/// Decided from the category tree (`/api/categories`), the same rule the
/// backend enforces for new transactions: a category with child categories is
/// a 대분류 and can't be a transaction's final category. A childless root
/// (e.g. a custom category with no 소분류) is a leaf and is not flagged.
///
/// - The row's [CategoryAmount.categoryId] is used when the report provides it.
/// - Otherwise (older backend) the row name is looked up in the tree, and only
///   a name that identifies exactly one EXPENSE category is trusted; an
///   unknown or shared name is never flagged, matching [rollUpToMajorCategories].
List<CategoryAmount> markUnspecifiedSubcategories(List<CategoryAmount> rows, List<dynamic> categories) {
  final all = categories.whereType<Map>().toList();
  final parentIds = {
    for (final c in all)
      if (c['parentCategoryId'] != null) c['parentCategoryId'].toString(),
  };
  final expenseIds = {
    for (final c in all)
      if (c['type'] == 'EXPENSE') (c['id'] ?? '').toString(),
  };
  final idsByName = <String, Set<String>>{};
  for (final c in all.where((c) => c['type'] == 'EXPENSE')) {
    idsByName.putIfAbsent((c['name'] ?? '').toString(), () => <String>{}).add((c['id'] ?? '').toString());
  }

  String? categoryIdOf(CategoryAmount row) {
    if (row.categoryId != null) return row.categoryId;
    final ids = idsByName[row.name];
    return ids != null && ids.length == 1 ? ids.first : null;
  }

  return [
    for (final row in rows)
      () {
        final id = categoryIdOf(row);
        return id != null && expenseIds.contains(id) && parentIds.contains(id) ? row.markedUnspecifiedSubcategory() : row;
      }(),
  ];
}

/// Rolls `/api/reports/categories` rows up to 대분류 (major categories).
///
/// That endpoint groups by each transaction's own category - i.e. the leaf
/// (식사/배달/카페/...), never the parent. [categories] is the
/// `/api/categories` list, used to look up which major (root) category each
/// leaf belongs to (see [_majorLookup]), so 식사 + 배달 + 카페 + ... add up to
/// one 식비 row under the 대분류's display name.
///
/// - Only `EXPENSE` categories take part, matching the report itself.
/// - A row whose name matches no category, or matches several categories
///   under different majors (a user-created duplicate name), is kept under
///   its own name instead of being guessed into a major.
/// - Result is sorted by amount (desc); ties fall back to the major's own
///   `sortOrder` (the app's existing category ordering), then name, so the
///   order never depends on the response order.
/// - `percentage` is recomputed against the total, not copied from leaves.
List<CategoryAmount> rollUpToMajorCategories(List<CategoryAmount> leafAmounts, List<dynamic> categories) {
  final majorOf = _majorLookup(categories);

  final groups = <String, ({String name, int sortOrder, int amount, int count})>{};
  for (final leaf in leafAmounts) {
    final root = majorOf(leaf);
    final key = root != null ? 'id:${root['id']}' : 'name:${leaf.name}';
    final previous = groups[key];
    groups[key] = (
      name: root != null ? (root['name'] ?? leaf.name).toString() : leaf.name,
      sortOrder: root != null ? ((root['sortOrder'] as num?)?.toInt() ?? 1 << 30) : 1 << 30,
      amount: (previous?.amount ?? 0) + leaf.amount,
      count: (previous?.count ?? 0) + leaf.transactionCount,
    );
  }

  final total = groups.values.fold<int>(0, (sum, g) => sum + g.amount);
  final sorted = groups.values.toList()
    ..sort((a, b) {
      final byAmount = b.amount.compareTo(a.amount);
      if (byAmount != 0) return byAmount;
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      return byOrder != 0 ? byOrder : a.name.compareTo(b.name);
    });
  return [
    for (final g in sorted)
      CategoryAmount(
        name: g.name,
        amount: g.amount,
        transactionCount: g.count,
        percentage: total == 0 ? 0 : g.amount / total * 100,
      ),
  ];
}

/// The 대분류 name each `/api/reports/categories` row rolls up under, keyed by
/// the row's own name - the same lookup [rollUpToMajorCategories] uses, so a
/// row that stays on its own name there maps to its own name here. Lets the
/// per-leaf detail cards borrow the color of the 대분류 slice they belong to.
Map<String, String> majorNamesByLeaf(List<CategoryAmount> leafAmounts, List<dynamic> categories) {
  final majorOf = _majorLookup(categories);
  return {
    for (final leaf in leafAmounts) leaf.name: (majorOf(leaf)?['name'] ?? leaf.name).toString(),
  };
}

/// Finds the 대분류 (root EXPENSE category) a row belongs to: by its
/// categoryId when the report sends one (so a user's rename never changes the
/// grouping), else by name - null when that name is unknown or shared by
/// categories under different majors.
Map? Function(CategoryAmount row) _majorLookup(List<dynamic> categories) {
  final expense = categories.whereType<Map>().where((c) => c['type'] == 'EXPENSE').toList();
  final byId = {for (final c in expense) (c['id'] ?? '').toString(): c};

  Map rootOf(Map c) {
    var current = c;
    for (var i = 0; i < 10; i++) {
      final parent = byId[(current['parentCategoryId'] ?? '').toString()];
      if (parent == null) break;
      current = parent;
    }
    return current;
  }

  final rootIdsByName = <String, Set<String>>{};
  final rootById = <String, Map>{};
  for (final c in expense) {
    final root = rootOf(c);
    final rootId = (root['id'] ?? '').toString();
    rootById[rootId] = root;
    rootIdsByName.putIfAbsent((c['name'] ?? '').toString(), () => <String>{}).add(rootId);
  }

  return (row) {
    final byRowId = byId[row.categoryId];
    if (byRowId != null) return rootOf(byRowId);
    final rootIds = rootIdsByName[row.name];
    return rootIds != null && rootIds.length == 1 ? rootById[rootIds.first] : null;
  };
}

/// The category to headline, or null when nothing was spent (no fake 0원 Top1).
CategoryAmount? topCategory(List<CategoryAmount> categories) {
  final spent = categories.where((c) => c.amount > 0);
  return spent.isEmpty ? null : spent.first; // already sorted, ties resolved above
}

class DailyPeak {
  final DateTime date;
  final int amount;
  const DailyPeak({required this.date, required this.amount});
}

/// The day with the highest total spending, or null when no day has any
/// spending. On a tie the later date wins (deterministic, and matches the
/// "most recent first" tie rule of the top week).
DailyPeak? peakSpendingDay(List<Map<String, dynamic>> dailyRows) {
  DailyPeak? peak;
  for (final row in dailyRows) {
    final date = DateTime.tryParse((row['date'] ?? '').toString());
    if (date == null) continue;
    final spent = (row['spent'] is num) ? (row['spent'] as num).toInt() : int.tryParse('${row['spent']}') ?? 0;
    if (spent <= 0) continue;
    if (peak == null || spent > peak.amount || (spent == peak.amount && date.isAfter(peak.date))) {
      peak = DailyPeak(date: date, amount: spent);
    }
  }
  return peak;
}

String _formatWon(int amount) {
  final s = amount.abs().toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return '${amount < 0 ? '-' : ''}${buf.toString()}원';
}

/// Which detail screen a Report main summary row leads to.
enum ReportHighlightKind { topCategory, topDay, topWeek }

/// One row of the Report main "이번 달 리포트 요약" card: the month's top
/// 대분류 category, top spending day, and top spending 주차.
class ReportHighlight {
  final ReportHighlightKind kind;
  final IconData icon;
  final String label;
  final String value;

  /// The day itself for [ReportHighlightKind.topDay], so navigation can
  /// hand the exact date to the Calendar instead of re-deriving it from text.
  final DateTime? date;

  const ReportHighlight({required this.kind, required this.icon, required this.label, required this.value, this.date});
}

/// Builds the "이번 달 리포트 요약" rows for the Report main screen. All
/// three come from the same selected month's expense data (categories,
/// daily totals, and the weekly buckets summed from those daily totals).
/// A row is only included when its data exists - a month with no spending
/// yields an empty list, never a fabricated 0원 top item.
List<ReportHighlight> buildMainHighlights({
  required DateTime month,
  required CategoryAmount? topMajorCategory,
  required DailyPeak? peakDay,
  required List<int> weeklyTotals,
}) {
  final topWeek = topWeekIndexOf(weeklyTotals);
  return [
    if (topMajorCategory != null)
      ReportHighlight(
        kind: ReportHighlightKind.topCategory,
        icon: Icons.pie_chart_outline_rounded,
        label: '가장 많이 쓴 카테고리',
        value: '${topMajorCategory.name} · ${_formatWon(topMajorCategory.amount)}',
      ),
    if (peakDay != null)
      ReportHighlight(
        kind: ReportHighlightKind.topDay,
        icon: Icons.event_outlined,
        label: '가장 많이 쓴 날',
        value: '${peakDay.date.month}월 ${peakDay.date.day}일 · ${_formatWon(peakDay.amount)}',
        date: DateTime(peakDay.date.year, peakDay.date.month, peakDay.date.day),
      ),
    if (topWeek != null)
      ReportHighlight(
        kind: ReportHighlightKind.topWeek,
        icon: Icons.bar_chart_rounded,
        label: '가장 많이 쓴 주',
        value: '${topWeek + 1}주차 · ${_formatWon(weeklyTotals[topWeek])}',
      ),
  ];
}

/// Insight rows for the Monthly Report detail screen (Figma frame
/// 114:5143): MoM %, which 주차 spent the most, and which category grew the
/// most. Each argument is nullable/independent so a missing piece of data
/// just omits that one row instead of blocking the others.
List<ReportInsight> buildMonthlyInsights({
  required double? momPct,
  required int? topWeekIndex, // 0-based
  required CategoryAmount? topGrowthCategory,
}) {
  final insights = <ReportInsight>[];

  if (momPct != null) {
    final decreased = momPct <= 0;
    final rounded = momPct.abs().round();
    insights.add(ReportInsight(
      icon: Icons.show_chart_rounded,
      text: '지난달보다 $rounded% ${decreased ? '적게' : '많이'} 썼어요',
      positive: decreased,
    ));
  }

  if (topWeekIndex != null) {
    insights.add(ReportInsight(
      icon: Icons.calendar_month_outlined,
      text: '${topWeekIndex + 1}주차 지출이 가장 컸어요',
      positive: false,
    ));
  }

  if (topGrowthCategory != null) {
    insights.add(ReportInsight(
      icon: Icons.restaurant_outlined,
      text: '${topGrowthCategory.name} 증가 영향이 컸어요',
      positive: false,
    ));
  }

  return insights;
}

String formatWon(int amount) => _formatWon(amount);
