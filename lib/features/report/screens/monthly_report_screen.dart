import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../home/theme/home_tokens.dart';
import '../providers/report_provider.dart';
import '../utils/report_insight_utils.dart';
import '../widgets/month_picker_sheet.dart';
import 'category_report_screen.dart';
import 'monthly_insight_detail_screens.dart';

/// Monthly Report detail: 소비 흐름 비교 + 월별 총지출 비교 + 주차별 비교
/// (Figma frames 114:5143, 431:6676, 431:7759). The three insight rows from
/// the summary card each navigate to their own screen — matching the
/// confirmed Prototype mapping (Frame 68 → NAVIGATE → Frame 118 / Frame
/// 157) — instead of expanding in place:
/// - MoM% row → [MonthlyTotalComparisonDetailScreen] (Frame 118)
/// - 주차 row → [WeeklyComparisonDetailScreen] (Frame 157)
/// - category-growth row ("~증가 영향이 컸어요") → [CategoryReportScreen]
///   with that category already expanded/selected, per the product rule
///   that a category-impact insight belongs on the Category Report, not
///   on a standalone explanation card.
///
/// All built from [monthlyReportDataProvider] (`report_provider.dart`),
/// which itself only combines existing `/api/reports/daily|categories`
/// calls — no new backend endpoint.
class MonthlyReportScreen extends ConsumerWidget {
  final DateTime initialMonth;
  const MonthlyReportScreen({super.key, required this.initialMonth});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(reportMonthProvider);
    final dataAsync = ref.watch(monthlyReportDataProvider(month));

    return Scaffold(
      backgroundColor: HomeTokens.pageBackground,
      appBar: AppBar(
        backgroundColor: HomeTokens.pageBackground,
        elevation: 0,
        foregroundColor: HomeTokens.textDark,
        title: const Text('월간 리포트', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('불러오지 못했어요\n$e', textAlign: TextAlign.center)),
        data: (data) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _FlowComparisonCard(
                month: month,
                data: data,
                onChangeMonth: () async {
                  final picked = await MonthPickerSheet.show(context, month);
                  if (picked != null) ref.read(reportMonthProvider.notifier).setMonth(picked);
                },
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < data.insights.length; i++) ...[
                _InsightRow(
                  insight: data.insights[i],
                  onTap: () => _handleInsightTap(context, i, month, data),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2, offset: const Offset(0, 1))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('비교안내', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: HomeTokens.textDark)),
                    const SizedBox(height: 6),
                    Text(
                      data.range.isPartial
                          ? '현재 진행 중인 월은 동일 일자(1일~${data.range.comparisonDay}일) 기준으로 지난달과 비교합니다.'
                          : '완료된 두 달 전체 기간을 기준으로 비교합니다.',
                      style: const TextStyle(fontSize: 16, color: HomeTokens.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _handleInsightTap(BuildContext context, int index, DateTime month, MonthlyReportData data) {
    // Row order matches buildMonthlyInsights(): MoM% -> 주차 -> 카테고리 증가.
    final rowKinds = <String>[
      if (data.momPct != null) 'mom',
      if (data.topWeekIndex != null) 'week',
      if (data.topGrowthCategory != null) 'category',
    ];
    if (index >= rowKinds.length) return;
    switch (rowKinds[index]) {
      case 'mom':
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => MonthlyTotalComparisonDetailScreen(month: month, data: data),
        ));
        break;
      case 'week':
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => WeeklyComparisonDetailScreen(month: month, data: data),
        ));
        break;
      case 'category':
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => CategoryReportScreen(
            initialMonth: month,
            initialCategoryName: data.topGrowthCategory!.name,
          ),
        ));
        break;
    }
  }
}

class _FlowComparisonCard extends StatelessWidget {
  final DateTime month;
  final MonthlyReportData data;
  final VoidCallback onChangeMonth;
  const _FlowComparisonCard({required this.month, required this.data, required this.onChangeMonth});

  static const List<int> _axisMarks = [1, 10, 15, 20, 31];

  @override
  Widget build(BuildContext context) {
    final previousMonth = DateTime(month.year, month.month - 1, 1);
    const maxDay = 31.0;
    // Figma only overlays a day highlight (dual tooltip + badge) for the
    // in-progress-month comparison, matching the same rule the 비교안내
    // card explains below -- a completed-month comparison has no single
    // "today" to highlight.
    final highlightDay = data.range.isPartial ? data.range.comparisonDay : null;
    final currentHighlight = highlightDay == null ? null : _amountForDay(data.currentDaily, highlightDay);
    final previousHighlight = highlightDay == null ? null : _amountForDay(data.previousDaily, highlightDay);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2, offset: const Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('이번 달 소비 흐름 (일별)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: HomeTokens.textDark)),
              InkWell(
                onTap: onChangeMonth,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: HomeTokens.cardSurface,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _LegendDot(color: HomeTokens.accent.withValues(alpha: 0.35), label: '${previousMonth.month}월'),
                      const SizedBox(width: 8),
                      _LegendDot(color: HomeTokens.accent, label: '${month.month}월'),
                      const Icon(Icons.keyboard_arrow_down, size: 18, color: HomeTokens.textMuted),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: Stack(
              children: [
                LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            final day = value.toInt();
                            if (!_axisMarks.contains(day) && day != highlightDay) return const SizedBox.shrink();
                            final isHighlight = day == highlightDay;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Container(
                                padding: isHighlight ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2) : EdgeInsets.zero,
                                decoration: isHighlight ? BoxDecoration(color: HomeTokens.accent, borderRadius: BorderRadius.circular(20)) : null,
                                child: Text(
                                  '$day',
                                  style: TextStyle(
                                    color: isHighlight ? Colors.white : HomeTokens.textMuted,
                                    fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minX: 1,
                    maxX: maxDay,
                    minY: 0,
                    lineBarsData: [
                      LineChartBarData(
                        spots: _spotsFor(data.previousDaily),
                        isCurved: false,
                        color: HomeTokens.accent.withValues(alpha: 0.35),
                        barWidth: 2,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            if (spot.x.toInt() == highlightDay) {
                              return FlDotCirclePainter(radius: 4, color: Colors.white, strokeWidth: 2, strokeColor: HomeTokens.accent.withValues(alpha: 0.35));
                            }
                            return FlDotCirclePainter(radius: 0, color: Colors.transparent);
                          },
                        ),
                      ),
                      LineChartBarData(
                        spots: _spotsFor(data.currentDaily),
                        isCurved: false,
                        color: HomeTokens.accent,
                        barWidth: 2,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            if (spot.x.toInt() == highlightDay) {
                              return FlDotCirclePainter(radius: 4, color: Colors.white, strokeWidth: 2, strokeColor: HomeTokens.accent);
                            }
                            return FlDotCirclePainter(radius: 0, color: Colors.transparent);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                if (highlightDay != null && (currentHighlight != null || previousHighlight != null))
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Align(
                      alignment: Alignment(((highlightDay - 1) / (maxDay - 1)) * 2 - 1, 0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (previousHighlight != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: HomeTokens.accent.withValues(alpha: 0.5)),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(formatWon(previousHighlight), style: const TextStyle(color: HomeTokens.accentDark, fontSize: 11, fontWeight: FontWeight.w600)),
                            ),
                          if (currentHighlight != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: HomeTokens.accent, borderRadius: BorderRadius.circular(20)),
                              child: Text(formatWon(currentHighlight), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<FlSpot> _spotsFor(List<Map<String, dynamic>> rows) {
    return rows.map((row) {
      final date = DateTime.tryParse((row['date'] ?? '').toString());
      final spent = row['spent'];
      final amount = spent is num ? spent.toDouble() : double.tryParse('$spent') ?? 0;
      return FlSpot((date?.day ?? 0).toDouble(), amount);
    }).where((s) => s.x > 0).toList()
      ..sort((a, b) => a.x.compareTo(b.x));
  }

  int? _amountForDay(List<Map<String, dynamic>> rows, int day) {
    for (final row in rows) {
      final date = DateTime.tryParse((row['date'] ?? '').toString());
      if (date?.day == day) {
        final spent = row['spent'];
        return spent is num ? spent.toInt() : int.tryParse('$spent');
      }
    }
    return null;
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: HomeTokens.textDark)),
      ],
    );
  }
}

class _InsightRow extends StatelessWidget {
  final ReportInsight insight;
  final VoidCallback onTap;

  const _InsightRow({required this.insight, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Figma highlights only the savings/positive row with a light-green
    // background (114:5143 node 431:6649); the other rows stay plain white.
    final headerBg = insight.positive ? HomeTokens.chipActiveBg : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2, offset: const Offset(0, 1))],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: headerBg, borderRadius: BorderRadius.circular(6)),
          child: Row(
            children: [
              Icon(insight.icon, size: 18, color: HomeTokens.accentDark),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(text: insight.text, style: const TextStyle(fontSize: 16, color: HomeTokens.textDark)),
                ),
              ),
              const Icon(Icons.chevron_right, size: 20, color: HomeTokens.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
