import 'package:flutter/material.dart';

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

  const CategoryAmount({
    required this.name,
    required this.amount,
    required this.transactionCount,
    required this.percentage,
  });
}

CategoryAmount? topCategory(List<CategoryAmount> categories) {
  if (categories.isEmpty) return null;
  return categories.reduce((a, b) => a.amount >= b.amount ? a : b);
}

class DailyPeak {
  final DateTime date;
  final int amount;
  const DailyPeak({required this.date, required this.amount});
}

DailyPeak? maxDailyRow(List<Map<String, dynamic>> dailyRows) {
  DailyPeak? peak;
  for (final row in dailyRows) {
    final date = DateTime.tryParse((row['date'] ?? '').toString());
    if (date == null) continue;
    final spent = (row['spent'] is num) ? (row['spent'] as num).toInt() : int.tryParse('${row['spent']}') ?? 0;
    if (peak == null || spent > peak.amount) peak = DailyPeak(date: date, amount: spent);
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

/// Builds the "이번 달 리포트 요약" insight rows for the Report main screen
/// (Figma frame 362:3635). Only includes a row when its underlying data is
/// actually available — no placeholder sentence is ever fabricated.
List<ReportInsight> buildMainInsights({
  required double? momPct,
  required CategoryAmount? top,
  required DailyPeak? peak,
}) {
  final insights = <ReportInsight>[];

  if (momPct != null) {
    final decreased = momPct <= 0;
    final rounded = momPct.abs().round();
    insights.add(ReportInsight(
      icon: decreased ? Icons.thumb_up_alt_outlined : Icons.trending_up,
      text: '저번보다 $rounded% ${decreased ? '적게' : '많이'} 썼어요',
      positive: decreased,
    ));
  }

  if (top != null) {
    insights.add(ReportInsight(
      icon: Icons.priority_high_rounded,
      text: '${top.name}에 가장 많이 썼어요',
      positive: false,
    ));
  }

  if (peak != null) {
    insights.add(ReportInsight(
      icon: Icons.priority_high_rounded,
      text: '하루에 가장 많이 쓴 금액은 ${_formatWon(peak.amount)}',
      positive: false,
    ));
  }

  return insights;
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
