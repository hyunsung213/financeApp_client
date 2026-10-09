import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/widgets/manual_input_fab.dart' show kBottomNavBarHeight;
import '../providers/report_provider.dart';
import '../utils/report_date_utils.dart';
import '../../../core/format/money_format.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/theme/wallet_glass.dart';
import '../../../data/api/api_error.dart';

/// Monthly Total Comparison Detail (Figma frame 118, `431:6676`) and Weekly
/// Comparison Detail (Figma frame 157, `431:7759`) — separate, navigable
/// screens reached by tapping Monthly Report's first/second insight row.
///
/// Per the confirmed Prototype mapping (Frame 68 → NAVIGATE → Frame 118 /
/// Frame 157), these are real routes with their own back stack entry
/// instead of the in-place accordion this used to be. [TotalComparisonDetail]
/// and [WeeklyComparisonDetail] below are the exact same chart/table/copy
/// that used to render inline in `monthly_report_screen.dart`'s accordion —
/// only the leading divider (which only made sense directly under an
/// accordion header) was dropped; nothing about the calculations or layout
/// was re-implemented.

class MonthlyTotalComparisonDetailScreen extends StatelessWidget {
  final DateTime month;
  final MonthlyReportData data;
  const MonthlyTotalComparisonDetailScreen({super.key, required this.month, required this.data});

  @override
  Widget build(BuildContext context) {
    return WalletBackground(child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent, surfaceTintColor: Colors.transparent, scrolledUnderElevation: 0,
        elevation: 0,
        foregroundColor: context.glass.textPrimary,
        title: const Text('월 총지출 비교', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: glassDecoration(context, radius: AppRadii.md),
          child: TotalComparisonDetail(month: month, data: data),
        ),
      ),
    ));
  }
}

/// Entry point from the Report main summary's "가장 많이 쓴 주" row: loads the
/// selected month's [MonthlyReportData] (the same provider the Monthly Report
/// uses, so the weekly totals here can't drift from the ones the summary
/// showed) and shows [WeeklyComparisonDetailScreen] for it.
class WeeklyExpenseDetailScreen extends ConsumerWidget {
  final DateTime month;
  const WeeklyExpenseDetailScreen({super.key, required this.month});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(monthlyReportDataProvider(month));
    return dataAsync.when(
      data: (data) => WeeklyComparisonDetailScreen(month: month, data: data),
      loading: () => _placeholder(context, const CircularProgressIndicator()),
      error: (e, st) => _placeholder(context, Text('불러오지 못했어요\n${userErrorMessage(e)}', textAlign: TextAlign.center)),
    );
  }

  Widget _placeholder(BuildContext context, Widget child) => WalletBackground(child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent, surfaceTintColor: Colors.transparent, scrolledUnderElevation: 0,
          elevation: 0,
          foregroundColor: context.glass.textPrimary,
          title: const Text('주차별 지출 비교', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ),
        body: Center(child: child),
      ));
}

class WeeklyComparisonDetailScreen extends StatelessWidget {
  final DateTime month;
  final MonthlyReportData data;
  const WeeklyComparisonDetailScreen({super.key, required this.month, required this.data});

  @override
  Widget build(BuildContext context) {
    return WalletBackground(child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent, surfaceTintColor: Colors.transparent, scrolledUnderElevation: 0,
        elevation: 0,
        foregroundColor: context.glass.textPrimary,
        title: const Text('주차별 지출 비교', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        // The floating bottom-nav pill paints over this screen (it's pushed
        // on the tab's own navigator), so reserve its footprint or the last
        // table row can't be scrolled out from under it.
        padding: const EdgeInsets.fromLTRB(20, 20, 20, kBottomNavBarHeight + 20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: glassDecoration(context, radius: AppRadii.md),
          child: WeeklyComparisonDetail(month: month, data: data),
        ),
      ),
    ));
  }
}

class TotalComparisonDetail extends StatelessWidget {
  final DateTime month;
  final MonthlyReportData data;
  const TotalComparisonDetail({super.key, required this.month, required this.data});

  @override
  Widget build(BuildContext context) {
    final previousMonth = DateTime(month.year, month.month - 1, 1);
    final diff = data.currentTotal - data.previousTotal;
    final pct = data.momPct ?? 0;
    final maxVal = [data.previousTotal, data.currentTotal].reduce((a, b) => a > b ? a : b).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('월별 총 지출 비교', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: Text(context.formatWon(data.previousTotal), textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: context.glass.textTertiary))),
            Expanded(child: Text(context.formatWon(data.currentTotal), textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: context.glass.accentText))),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 140,
          child: BarChart(
            BarChartData(
              maxY: maxVal == 0 ? 1 : maxVal * 1.2,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) => Text(value == 0 ? '${previousMonth.month}월' : '${month.month}월', style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ),
              barGroups: [
                BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: data.previousTotal.toDouble(), color: context.glass.accentText.withValues(alpha: 0.35), width: 36, borderRadius: BorderRadius.circular(6))]),
                BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: data.currentTotal.toDouble(), color: context.glass.accentText, width: 36, borderRadius: BorderRadius.circular(6))]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _kvDot(context, context.glass.accentText.withValues(alpha: 0.35), '${previousMonth.month}월 총 지출', context.formatWon(data.previousTotal)),
        _kvDot(context, context.glass.accentText, '${month.month}월 총 지출', context.formatWon(data.currentTotal)),
        _kv(context, Icons.remove_circle_outline, '차이', '${diff <= 0 ? '' : '+'}${context.formatWon(diff)}', valueColor: diff <= 0 ? context.glass.accentText : context.glass.negative),
        _kv(context, Icons.percent_rounded, '변화율 비율', '${pct <= 0 ? '' : '+'}${pct.round()}%', valueColor: pct <= 0 ? context.glass.accentText : context.glass.negative),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: context.glass.accentSoft, borderRadius: BorderRadius.circular(10)),
          child: Text(
            '${month.month}월의 총 지출은 ${context.formatWon(data.currentTotal)}으로 지난달 대비 ${context.formatWon(diff.abs())}(${pct.abs().round()}%) ${pct <= 0 ? '적게' : '많이'} 사용했어요.',
            style: TextStyle(fontSize: 12, color: context.glass.textPrimary),
          ),
        ),
      ],
    );
  }

  Widget _kv(BuildContext context, IconData icon, String k, String v, {Color? valueColor}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(icon, size: 18, color: context.glass.textPrimary),
          const SizedBox(width: 6),
          Expanded(child: Text(k, style: TextStyle(fontSize: 14, color: context.glass.textPrimary))),
          Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: valueColor ?? context.glass.textPrimary)),
        ]),
      );

  Widget _kvDot(BuildContext context, Color color, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 8),
          Expanded(child: Text(k, style: TextStyle(fontSize: 14, color: context.glass.textPrimary))),
          Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.glass.textPrimary)),
        ]),
      );
}

class WeeklyComparisonDetail extends StatelessWidget {
  final DateTime month;
  final MonthlyReportData data;
  const WeeklyComparisonDetail({super.key, required this.month, required this.data});

  @override
  Widget build(BuildContext context) {
    final previousMonth = DateTime(month.year, month.month - 1, 1);
    final maxVal = [...data.currentWeekly, ...data.previousWeekly].fold<int>(0, (a, b) => a > b ? a : b).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WeeklyExpenseBars(month: month, weekly: data.currentWeekly),
        const SizedBox(height: 20),
        const Divider(height: 1),
        const SizedBox(height: 20),
        // Kept as "주차별" (not Figma's literal, reused-frame label
        // "월별 총 지출 비교") since this card is genuinely about weekly
        // buckets -- see QA notes on frame 431:7759 for why the copy wasn't
        // copied verbatim.
        const Text('주차별 총 지출 비교', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 12),
        Row(
          children: List.generate(4, (i) {
            return Expanded(
              child: Column(
                children: [
                  Text(context.formatWon(data.previousWeekly[i]), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: context.glass.textTertiary)),
                  Text(context.formatWon(data.currentWeekly[i]), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: context.glass.accentText)),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 160,
          child: BarChart(
            BarChartData(
              maxY: maxVal == 0 ? 1 : maxVal * 1.2,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) => Text('${value.toInt() + 1}주차', style: const TextStyle(fontSize: 11)),
                  ),
                ),
              ),
              barGroups: List.generate(4, (i) {
                return BarChartGroupData(x: i, barRods: [
                  BarChartRodData(toY: data.previousWeekly[i].toDouble(), color: context.glass.accentText.withValues(alpha: 0.35), width: 12, borderRadius: BorderRadius.circular(4)),
                  BarChartRodData(toY: data.currentWeekly[i].toDouble(), color: context.glass.accentText, width: 12, borderRadius: BorderRadius.circular(4)),
                ], barsSpace: 4);
              }),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Table(
          columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1)},
          children: [
            TableRow(children: [
              const SizedBox(),
              Text('${previousMonth.month}월', textAlign: TextAlign.right, style: TextStyle(fontSize: 13, color: context.glass.textTertiary)),
              Text('${month.month}월', textAlign: TextAlign.right, style: TextStyle(fontSize: 13, color: context.glass.textTertiary)),
            ]),
            for (var i = 0; i < 4; i++)
              TableRow(children: [
                Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('${i + 1}주차', style: const TextStyle(fontSize: 13))),
                Text(context.formatWon(data.previousWeekly[i]), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13)),
                Text(context.formatWon(data.currentWeekly[i]), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ]),
          ],
        ),
      ],
    );
  }
}

/// The selected month's per-주차 totals as compact horizontal bars, largest
/// week highlighted in the primary green and the rest in soft mint, so the
/// weeks can be compared at a glance. Uses the same week boundaries
/// ([weekDayRange]/[weekIndexForDay]) and the same top-week rule
/// ([topWeekIndexOf]) as the Report main summary's "가장 많이 쓴 주".
class _WeeklyExpenseBars extends StatelessWidget {
  final DateTime month;
  final List<int> weekly;
  const _WeeklyExpenseBars({required this.month, required this.weekly});

  @override
  Widget build(BuildContext context) {
    final top = topWeekIndexOf(weekly);
    final maxValue = weekly.fold<int>(0, (a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${month.month}월 주차별 지출', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 4),
        Text(
          top == null ? '이번 달 지출 내역이 없어요' : '가장 많이 쓴 주 · ${top + 1}주차 ${context.formatWon(weekly[top])}',
          style: TextStyle(fontSize: 13, color: top == null ? context.glass.textTertiary : context.glass.chipSelectedText, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < weekly.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _bar(context, i, isTop: i == top, maxValue: maxValue),
          ),
      ],
    );
  }

  Widget _bar(BuildContext context, int index, {required bool isTop, required int maxValue}) {
    final (startDay, endDay) = weekDayRange(index, month);
    final fraction = maxValue == 0 ? 0.0 : weekly[index] / maxValue;
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${index + 1}주차', style: TextStyle(fontSize: 13, fontWeight: isTop ? FontWeight.bold : FontWeight.w500, color: context.glass.textPrimary)),
              Text('$startDay~$endDay일', style: TextStyle(fontSize: 11, color: context.glass.textTertiary)),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: [
                Container(height: 14, decoration: BoxDecoration(color: context.glass.chipFill, borderRadius: BorderRadius.circular(7))),
                Container(
                  height: 14,
                  width: constraints.maxWidth * fraction,
                  decoration: BoxDecoration(
                    color: isTop ? context.glass.accentText : context.glass.accentText.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 82,
          child: Text(
            context.formatWon(weekly[index]),
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 13, fontWeight: isTop ? FontWeight.bold : FontWeight.w500, color: isTop ? context.glass.chipSelectedText : context.glass.textPrimary),
          ),
        ),
      ],
    );
  }
}
