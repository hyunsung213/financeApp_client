import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_shadows.dart';
import '../../home/theme/home_tokens.dart';
import '../providers/report_provider.dart';
import '../utils/report_insight_utils.dart';

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
    return Scaffold(
      backgroundColor: HomeTokens.pageBackground,
      appBar: AppBar(
        backgroundColor: HomeTokens.pageBackground,
        elevation: 0,
        foregroundColor: HomeTokens.textDark,
        title: const Text('월 총지출 비교', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.compactInput),
            boxShadow: AppShadows.card,
          ),
          child: TotalComparisonDetail(month: month, data: data),
        ),
      ),
    );
  }
}

class WeeklyComparisonDetailScreen extends StatelessWidget {
  final DateTime month;
  final MonthlyReportData data;
  const WeeklyComparisonDetailScreen({super.key, required this.month, required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeTokens.pageBackground,
      appBar: AppBar(
        backgroundColor: HomeTokens.pageBackground,
        elevation: 0,
        foregroundColor: HomeTokens.textDark,
        title: const Text('주차별 지출 비교', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.compactInput),
            boxShadow: AppShadows.card,
          ),
          child: WeeklyComparisonDetail(month: month, data: data),
        ),
      ),
    );
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
            Expanded(child: Text(formatWon(data.previousTotal), textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: HomeTokens.textMuted))),
            Expanded(child: Text(formatWon(data.currentTotal), textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: HomeTokens.accent))),
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
                BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: data.previousTotal.toDouble(), color: HomeTokens.accent.withValues(alpha: 0.35), width: 36, borderRadius: BorderRadius.circular(6))]),
                BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: data.currentTotal.toDouble(), color: HomeTokens.accent, width: 36, borderRadius: BorderRadius.circular(6))]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _kvDot(HomeTokens.accent.withValues(alpha: 0.35), '${previousMonth.month}월 총 지출', formatWon(data.previousTotal)),
        _kvDot(HomeTokens.accent, '${month.month}월 총 지출', formatWon(data.currentTotal)),
        _kv(Icons.remove_circle_outline, '차이', '${diff <= 0 ? '' : '+'}${formatWon(diff)}', valueColor: diff <= 0 ? HomeTokens.accent : HomeTokens.negative),
        _kv(Icons.percent_rounded, '변화율 비율', '${pct <= 0 ? '' : '+'}${pct.round()}%', valueColor: pct <= 0 ? HomeTokens.accent : HomeTokens.negative),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: HomeTokens.chipActiveBg, borderRadius: BorderRadius.circular(10)),
          child: Text(
            '${month.month}월의 총 지출은 ${formatWon(data.currentTotal)}으로 지난달 대비 ${formatWon(diff.abs())}(${pct.abs().round()}%) ${pct <= 0 ? '적게' : '많이'} 사용했어요.',
            style: const TextStyle(fontSize: 12, color: HomeTokens.textDark),
          ),
        ),
      ],
    );
  }

  Widget _kv(IconData icon, String k, String v, {Color valueColor = HomeTokens.textDark}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(icon, size: 18, color: HomeTokens.textDark),
          const SizedBox(width: 6),
          Expanded(child: Text(k, style: const TextStyle(fontSize: 14, color: HomeTokens.textDark))),
          Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: valueColor)),
        ]),
      );

  Widget _kvDot(Color color, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 8),
          Expanded(child: Text(k, style: const TextStyle(fontSize: 14, color: HomeTokens.textDark))),
          Text(v, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: HomeTokens.textDark)),
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
                  Text(formatWon(data.previousWeekly[i]), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: HomeTokens.textMuted)),
                  Text(formatWon(data.currentWeekly[i]), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: HomeTokens.accent)),
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
                  BarChartRodData(toY: data.previousWeekly[i].toDouble(), color: HomeTokens.accent.withValues(alpha: 0.35), width: 12, borderRadius: BorderRadius.circular(4)),
                  BarChartRodData(toY: data.currentWeekly[i].toDouble(), color: HomeTokens.accent, width: 12, borderRadius: BorderRadius.circular(4)),
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
              Text('${previousMonth.month}월', textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, color: HomeTokens.textMuted)),
              Text('${month.month}월', textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, color: HomeTokens.textMuted)),
            ]),
            for (var i = 0; i < 4; i++)
              TableRow(children: [
                Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('${i + 1}주차', style: const TextStyle(fontSize: 13))),
                Text(formatWon(data.previousWeekly[i]), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13)),
                Text(formatWon(data.currentWeekly[i]), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ]),
          ],
        ),
      ],
    );
  }
}
