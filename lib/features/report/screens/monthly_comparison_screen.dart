import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';

num _toNum(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value;
  return num.tryParse(value.toString()) ?? 0;
}

/// Compares this month against last month: total spend, and a per-week
/// breakdown derived from the same daily rows the main report chart uses.
/// Everything here comes from real daily/monthly report data — no mock rows.
class MonthlyComparisonScreen extends StatelessWidget {
  final DateTime month;
  final int thisMonthExpense;
  final int? lastMonthExpense;
  final List<Map<String, dynamic>> dailyThisMonth;
  final List<Map<String, dynamic>> dailyLastMonth;

  const MonthlyComparisonScreen({
    super.key,
    required this.month,
    required this.thisMonthExpense,
    required this.lastMonthExpense,
    required this.dailyThisMonth,
    required this.dailyLastMonth,
  });

  List<int> _weeklyTotals(List<Map<String, dynamic>> rows, int weekCount) {
    final totals = List<int>.filled(weekCount, 0);
    for (final row in rows) {
      final date = DateTime.tryParse(row['date']?.toString() ?? '');
      if (date == null) continue;
      final weekIndex = ((date.day - 1) ~/ 7).clamp(0, weekCount - 1);
      totals[weekIndex] += _toNum(row['expense']).toInt();
    }
    return totals;
  }

  @override
  Widget build(BuildContext context) {
    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0).day;
    final weekCount = (lastDayOfMonth / 7).ceil();
    final weeklyThis = _weeklyTotals(dailyThisMonth, weekCount);
    final weeklyLast = _weeklyTotals(dailyLastMonth, weekCount);

    var maxWeekIndex = 0;
    for (var i = 1; i < weeklyThis.length; i++) {
      if (weeklyThis[i] > weeklyThis[maxWeekIndex]) maxWeekIndex = i;
    }
    final hasWeeklySpend = weeklyThis[maxWeekIndex] > 0;

    final diff = lastMonthExpense == null ? null : thisMonthExpense - lastMonthExpense!;
    final diffPercent = (lastMonthExpense == null || lastMonthExpense == 0)
        ? null
        : (diff! / lastMonthExpense! * 100);

    final prevMonth = DateTime(month.year, month.month - 1, 1);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text('${month.month}월 소비 흐름 비교'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (hasWeeklySpend)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(12)),
              child: Text(
                '${maxWeekIndex + 1}주차 지출이 가장 많았어요',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
            ),

          // Monthly total comparison
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('월별 총 지출 비교', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                SizedBox(
                  height: 160,
                  child: lastMonthExpense == null
                      ? const Center(child: Text('지난달 데이터가 없어요.', style: TextStyle(color: AppColors.textSecondary)))
                      : BarChart(
                          BarChartData(
                            gridData: const FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) => Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(value == 0 ? '${prevMonth.month}월' : '${month.month}월'),
                                  ),
                                ),
                              ),
                            ),
                            barGroups: [
                              BarChartGroupData(x: 0, barRods: [
                                BarChartRodData(toY: lastMonthExpense!.toDouble(), color: AppColors.primary.withValues(alpha: 0.35), width: 32, borderRadius: BorderRadius.circular(6)),
                              ]),
                              BarChartGroupData(x: 1, barRods: [
                                BarChartRodData(toY: thisMonthExpense.toDouble(), color: AppColors.primary, width: 32, borderRadius: BorderRadius.circular(6)),
                              ]),
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: 20),
                _statRow('${prevMonth.month}월 총 지출', lastMonthExpense == null ? '데이터 없음' : '${NumberFormat('#,###').format(lastMonthExpense)}원'),
                _statRow('${month.month}월 총 지출', '${NumberFormat('#,###').format(thisMonthExpense)}원'),
                if (diff != null) _statRow('차이', '${diff >= 0 ? '+' : ''}${NumberFormat('#,###').format(diff)}원'),
                if (diffPercent != null) _statRow('변화율', '${diffPercent >= 0 ? '+' : ''}${diffPercent.round()}%'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Weekly comparison
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('주별 총 지출 비교', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                SizedBox(
                  height: 160,
                  child: BarChart(
                    BarChartData(
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) => Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text('${value.toInt() + 1}주'),
                            ),
                          ),
                        ),
                      ),
                      barGroups: List.generate(weekCount, (i) {
                        return BarChartGroupData(x: i, barRods: [
                          BarChartRodData(toY: weeklyLast[i].toDouble(), color: AppColors.primary.withValues(alpha: 0.35), width: 10, borderRadius: BorderRadius.circular(4)),
                          BarChartRodData(toY: weeklyThis[i].toDouble(), color: AppColors.primary, width: 10, borderRadius: BorderRadius.circular(4)),
                        ]);
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Table(
                  columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(1.3), 2: FlexColumnWidth(1.3)},
                  children: [
                    TableRow(children: [
                      const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('주차', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('${prevMonth.month}월', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('${month.month}월', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    ]),
                    for (var i = 0; i < weekCount; i++)
                      TableRow(children: [
                        Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('${i + 1}주차', style: const TextStyle(fontSize: 13))),
                        Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('${NumberFormat('#,###').format(weeklyLast[i])}원', style: const TextStyle(fontSize: 13))),
                        Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('${NumberFormat('#,###').format(weeklyThis[i])}원', style: const TextStyle(fontSize: 13))),
                      ]),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}
