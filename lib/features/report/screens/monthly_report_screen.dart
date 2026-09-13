import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../home/theme/home_tokens.dart';
import '../providers/report_provider.dart';
import '../utils/report_insight_utils.dart';
import '../widgets/month_picker_sheet.dart';

/// Monthly Report detail: 소비 흐름 비교 + 월별 총지출 비교 + 주차별 비교
/// (Figma frames 114:5143, 431:6676, 431:7759). The three insight rows from
/// the summary card are accordions — expanding one reveals the matching
/// Figma detail (bar chart + table + rule-based insight sentence), all
/// built from [monthlyReportDataProvider] (`report_provider.dart`), which
/// itself only combines existing `/api/reports/daily|categories` calls —
/// no new backend endpoint.
class MonthlyReportScreen extends ConsumerStatefulWidget {
  final DateTime initialMonth;
  const MonthlyReportScreen({super.key, required this.initialMonth});

  @override
  ConsumerState<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends ConsumerState<MonthlyReportScreen> {
  int? _expandedIndex;

  @override
  Widget build(BuildContext context) {
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
                _InsightAccordion(
                  insight: data.insights[i],
                  expanded: _expandedIndex == i,
                  onTap: () => setState(() => _expandedIndex = _expandedIndex == i ? null : i),
                  detail: _detailFor(i, month, data),
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

  Widget? _detailFor(int index, DateTime month, MonthlyReportData data) {
    // Row order matches buildMonthlyInsights(): MoM% -> 주차 -> 카테고리 증가.
    final rowKinds = <String>[
      if (data.momPct != null) 'mom',
      if (data.topWeekIndex != null) 'week',
      if (data.topGrowthCategory != null) 'category',
    ];
    if (index >= rowKinds.length) return null;
    switch (rowKinds[index]) {
      case 'mom':
        return _TotalComparisonDetail(month: month, data: data);
      case 'week':
        return _WeeklyComparisonDetail(month: month, data: data);
      case 'category':
        return _CategoryGrowthDetail(data: data);
    }
    return null;
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

class _InsightAccordion extends StatelessWidget {
  final ReportInsight insight;
  final bool expanded;
  final VoidCallback onTap;
  final Widget? detail;

  const _InsightAccordion({required this.insight, required this.expanded, required this.onTap, required this.detail});

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
      child: Column(
        children: [
          InkWell(
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
                  Icon(expanded ? Icons.expand_less : Icons.chevron_right, size: 20, color: HomeTokens.textMuted),
                ],
              ),
            ),
          ),
          if (expanded && detail != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: detail!,
            ),
        ],
      ),
    );
  }
}

class _TotalComparisonDetail extends StatelessWidget {
  final DateTime month;
  final MonthlyReportData data;
  const _TotalComparisonDetail({required this.month, required this.data});

  @override
  Widget build(BuildContext context) {
    final previousMonth = DateTime(month.year, month.month - 1, 1);
    final diff = data.currentTotal - data.previousTotal;
    final pct = data.momPct ?? 0;
    final maxVal = [data.previousTotal, data.currentTotal].reduce((a, b) => a > b ? a : b).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1),
        const SizedBox(height: 16),
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

class _WeeklyComparisonDetail extends StatelessWidget {
  final DateTime month;
  final MonthlyReportData data;
  const _WeeklyComparisonDetail({required this.month, required this.data});

  @override
  Widget build(BuildContext context) {
    final previousMonth = DateTime(month.year, month.month - 1, 1);
    final maxVal = [...data.currentWeekly, ...data.previousWeekly].fold<int>(0, (a, b) => a > b ? a : b).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1),
        const SizedBox(height: 16),
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

class _CategoryGrowthDetail extends StatelessWidget {
  final MonthlyReportData data;
  const _CategoryGrowthDetail({required this.data});

  @override
  Widget build(BuildContext context) {
    final top = data.topGrowthCategory!;
    final previous = data.previousCategories.where((c) => c.name == top.name).map((c) => c.amount).firstOrNull ?? 0;
    final growth = top.amount - previous;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1),
        const SizedBox(height: 16),
        Text('${top.name} 지출 변화', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('지난달', style: const TextStyle(fontSize: 13, color: HomeTokens.textMuted)),
          Text(formatWon(previous), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('이번달', style: const TextStyle(fontSize: 13, color: HomeTokens.textMuted)),
          Text(formatWon(top.amount), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFFFF1E8), borderRadius: BorderRadius.circular(10)),
          child: Text('${top.name} 지출이 지난달보다 ${formatWon(growth)} 늘어서 이번 달 총지출 증가에 가장 큰 영향을 줬어요.', style: const TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
