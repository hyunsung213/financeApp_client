import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_shadows.dart';
import '../providers/report_provider.dart';
import '../utils/report_date_utils.dart';
import '../utils/report_insight_utils.dart';
import '../utils/smooth_line_spots.dart';
import '../widgets/chart_selection_guide.dart';
import '../widgets/month_picker_sheet.dart';
import 'category_report_screen.dart';
import 'monthly_insight_detail_screens.dart';
import '../../../core/format/money_format.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/theme/wallet_glass.dart';

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

    return WalletBackground(child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent, surfaceTintColor: Colors.transparent, scrolledUnderElevation: 0,
        elevation: 0,
        foregroundColor: context.glass.textPrimary,
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
                decoration: glassDecoration(context, radius: AppRadii.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('비교안내', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: context.glass.textPrimary)),
                    const SizedBox(height: 6),
                    Text(
                      data.range.isPartial
                          ? '현재 진행 중인 월은 동일 일자(1일~${data.range.comparisonDay}일) 기준으로 지난달과 비교합니다.'
                          : '완료된 두 달 전체 기간을 기준으로 비교합니다.',
                      style: TextStyle(fontSize: 16, color: context.glass.textTertiary),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ));
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
        CategoryReportScreen.open(
          context,
          initialMonth: month,
          initialCategoryName: data.topGrowthCategory!.name,
        );
        break;
    }
  }
}

class _FlowComparisonCard extends StatefulWidget {
  final DateTime month;
  final MonthlyReportData data;
  final VoidCallback onChangeMonth;
  const _FlowComparisonCard({required this.month, required this.data, required this.onChangeMonth});

  @override
  State<_FlowComparisonCard> createState() => _FlowComparisonCardState();
}

class _FlowComparisonCardState extends State<_FlowComparisonCard> {
  static const double _maxDay = 31.0;

  int? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _defaultDayFor(widget.data);
  }

  @override
  void didUpdateWidget(covariant _FlowComparisonCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.month != widget.month) {
      _selectedDay = _defaultDayFor(widget.data);
    }
  }

  // Matches the 비교안내 card's rule: an in-progress month defaults its
  // highlight to "today" (comparisonDay). A completed month has no single
  // "today" either, but it still needs *some* default so the axis badge is
  // never empty on first render - it uses that month's last calendar day,
  // since a completed month is always compared over its full range (see
  // monthComparisonRange's "완료된 과거 달끼리는 전체 기간으로 비교" rule),
  // never a hardcoded day.
  int? _defaultDayFor(MonthlyReportData data) => data.range.isPartial ? data.range.comparisonDay : daysInMonth(widget.month);

  // The last day that can actually carry data for the month being viewed: for
  // the in-progress month that's "today" (comparisonDay, the same cutoff the
  // fetch itself already clamps to - see monthlyReportDataProvider), otherwise
  // the month's own last calendar day. Scrubbing/tapping past this point
  // (e.g. into the empty-looking future-day area of an in-progress month)
  // must not select a day that has no line to show.
  int get _lastValidDay => widget.data.range.isPartial ? (widget.data.range.comparisonDay ?? daysInMonth(widget.month)) : daysInMonth(widget.month);

  // fl_chart's own touch layer (LineTouchData) registers a plain
  // (omnidirectional) PanGestureRecognizer, which competes with the page's
  // vertical ListView scroll in the same gesture arena and tends to win it
  // outright regardless of drag direction. Driving selection from our own
  // GestureDetector instead - onTapDown for an immediate single tap,
  // onHorizontalDragUpdate for scrubbing - uses Flutter's axis-aware
  // HorizontalDragGestureRecognizer, which yields to a vertical drag instead
  // of racing it, so a vertical swipe that merely starts over the chart still
  // scrolls the page. The left/right chart titles are hidden (`showTitles:
  // false`), so fl_chart reserves 0px on those sides and the plotted 1..31
  // x-domain maps linearly across the chart's full width - no extra inset to
  // account for.
  void _updateSelectedDayFromLocalX(double dx, double width) {
    if (width <= 0) return;
    final t = (dx / width).clamp(0.0, 1.0);
    // The raw touch->day mapping still spans the fixed 31-wide domain (so a
    // short month's chart isn't stretched relative to a long month's), but
    // the day it resolves to is then clamped to _lastValidDay so touching the
    // empty right edge of the chart can never select a future/nonexistent day.
    final day = (1 + t * (_maxDay - 1)).round().clamp(1, _lastValidDay);
    if (day != _selectedDay) setState(() => _selectedDay = day);
  }

  @override
  Widget build(BuildContext context) {
    final month = widget.month;
    final data = widget.data;
    final previousMonth = DateTime(month.year, month.month - 1, 1);
    final selectedDay = _selectedDay;
    final currentSelected = selectedDay == null ? null : _amountForDay(data.currentDaily, selectedDay);
    final previousSelected = selectedDay == null ? null : _amountForDay(data.previousDaily, selectedDay);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: glassDecoration(context, radius: AppRadii.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('이번 달 소비 흐름 (일별)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: context.glass.textPrimary)),
              InkWell(
                onTap: widget.onChangeMonth,
                borderRadius: BorderRadius.circular(AppRadii.md),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.glass.cardFill,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    boxShadow: AppShadows.hairline,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _LegendDot(color: context.glass.accentText.withValues(alpha: 0.35), label: '${previousMonth.month}월'),
                      const SizedBox(width: 6),
                      _LegendDot(color: context.glass.accentText, label: '${month.month}월'),
                      Icon(Icons.keyboard_arrow_down, size: 15, color: context.glass.textTertiary),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            // Tooltip strip above + 150px plot + badge strip below.
            height: kChartCompareTooltipStrip + 150 + kChartDayBadgeStrip,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                // One x for the guide, the dots, the tooltip and the badge.
                final pointX = selectedDay == null ? 0.0 : chartDayX(selectedDay, _maxDay.toInt(), width);
                return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      if (selectedDay != null)
                        Positioned(
                          left: pointX - 1,
                          top: kChartCompareTooltipStrip - kChartTooltipGap,
                          bottom: kChartDayBadgeStrip - kChartDayBadgeHeight,
                          width: 2,
                          child: const IgnorePointer(child: DottedVerticalGuide()),
                        ),
                      LineChart(
                        LineChartData(
                          gridData: const FlGridData(show: false),
                          titlesData: FlTitlesData(
                            show: true,
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            // Empty on purpose: only reserves the strip the
                            // tooltip is drawn into (see kChartCompareTooltipStrip).
                            topTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: kChartCompareTooltipStrip,
                                getTitlesWidget: (value, meta) => const SizedBox.shrink(),
                              ),
                            ),
                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            // No static day numbers along the axis anymore -
                            // `showTitles: true` is kept only so fl_chart still
                            // reserves the 30px bottom strip (which the plot
                            // area's height and the guide line's bottom inset
                            // below both assume); `getTitlesWidget` always
                            // returns an empty box so nothing is actually drawn
                            // into that strip. The selected day is instead
                            // shown by the floating ChartDayBadge below, positioned
                            // from the exact same selectedDay/width math as the
                            // vertical guide line and the tooltip so all three
                            // always agree.
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: kChartDayBadgeStrip,
                                getTitlesWidget: (value, meta) => const SizedBox.shrink(),
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          minX: 1,
                          maxX: _maxDay,
                          minY: 0,
                          // Selection is driven entirely by the GestureDetector
                          // above (see _updateSelectedDayFromLocalX) rather than
                          // fl_chart's own LineTouchData, so this chart doesn't
                          // register its own omnidirectional pan recognizer that
                          // would fight the page's vertical scroll.
                          lineBarsData: [
                            // Both lines are drawn through smoothLineSpots (the
                            // same data points, connected by a monotone curve:
                            // no overshoot past a spike, no dip under a 0원
                            // stretch) rather than fl_chart's own `isCurved`,
                            // which does both. Because that path is densely
                            // sampled, the selected-day dot is picked out by
                            // exact x (checkToShowDot) - not `x.toInt()`, which
                            // would match every sample inside that day.
                            LineChartBarData(
                              spots: smoothLineSpots(_spotsFor(data.previousDaily)),
                              isCurved: false,
                              color: context.glass.accentText.withValues(alpha: 0.35),
                              barWidth: 1.6,
                              isStrokeCapRound: true,
                              isStrokeJoinRound: true,
                              dotData: FlDotData(
                                show: true,
                                checkToShowDot: (spot, barData) => selectedDay != null && spot.x == selectedDay.toDouble(),
                                getDotPainter: (spot, percent, barData, index) =>
                                    FlDotCirclePainter(radius: 5, color: context.glass.surfaceFill, strokeWidth: 1.5, strokeColor: context.glass.accentText.withValues(alpha: 0.35)),
                              ),
                            ),
                            LineChartBarData(
                              spots: smoothLineSpots(_spotsFor(data.currentDaily)),
                              isCurved: false,
                              color: context.glass.accentText,
                              barWidth: 2.0,
                              isStrokeCapRound: true,
                              isStrokeJoinRound: true,
                              dotData: FlDotData(
                                show: true,
                                checkToShowDot: (spot, barData) => selectedDay != null && spot.x == selectedDay.toDouble(),
                                getDotPainter: (spot, percent, barData, index) =>
                                    FlDotCirclePainter(radius: 5, color: context.glass.surfaceFill, strokeWidth: 1.5, strokeColor: context.glass.accentText),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (selectedDay != null)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: kChartDayBadgeStrip,
                          child: IgnorePointer(
                            child: AnchoredChartLabel(anchorX: pointX, clampToChart: true, overhang: 8, alignBottom: true, child: ChartDayBadge(day: selectedDay)),
                          ),
                        ),
                      if (selectedDay != null && (currentSelected != null || previousSelected != null))
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          height: kChartCompareTooltipStrip - kChartTooltipGap,
                          child: IgnorePointer(
                            // Centered on the point, pinned just above the plot,
                            // and clamped so it is never cut off near day 1 /
                            // the last day.
                            child: AnchoredChartLabel(
                              anchorX: pointX,
                              clampToChart: true,
                              alignBottom: true,
                              child: _ComparisonTooltip(
                                currentLabel: '${month.month}월',
                                currentAmount: currentSelected,
                                currentColor: context.glass.accentText,
                                previousLabel: '${previousMonth.month}월',
                                previousAmount: previousSelected,
                                previousColor: context.glass.accentText.withValues(alpha: 0.35),
                              ),
                            ),
                          ),
                        ),
                      // A Positioned.fill gesture layer as the topmost Stack
                      // child (rather than a GestureDetector wrapping the
                      // whole Stack) so it's guaranteed to span the Stack's
                      // full box exactly, regardless of how LineChart sizes
                      // itself internally. A childless GestureDetector does
                      // NOT reliably claim its whole advertised hit-test area
                      // even under tight Positioned.fill constraints (verified
                      // empirically - taps above roughly the box's vertical
                      // midpoint were silently dropped until an actual child
                      // was given), so SizedBox.expand() gives it one.
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (details) => _updateSelectedDayFromLocalX(details.localPosition.dx, width),
                          onHorizontalDragStart: (details) => _updateSelectedDayFromLocalX(details.localPosition.dx, width),
                          onHorizontalDragUpdate: (details) => _updateSelectedDayFromLocalX(details.localPosition.dx, width),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ],
                );
              },
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

/// The single compact card shown above a selected day - two rows (this
/// month / last month) instead of the two separate solid-fill pills this
/// replaced, so the comparison reads at a glance and the light background
/// keeps the amount text legible.
class _ComparisonTooltip extends StatelessWidget {
  final String currentLabel;
  final int? currentAmount;
  final Color currentColor;
  final String previousLabel;
  final int? previousAmount;
  final Color previousColor;

  const _ComparisonTooltip({
    required this.currentLabel,
    required this.currentAmount,
    required this.currentColor,
    required this.previousLabel,
    required this.previousAmount,
    required this.previousColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        // Chart tooltip: opaque so the plot never shows through the numbers.
        color: context.glass.surfaceFill,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: context.glass.accentText.withValues(alpha: 0.25)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (currentAmount != null) _row(context, currentLabel, currentAmount!, currentColor),
          if (currentAmount != null && previousAmount != null) const SizedBox(height: 3),
          if (previousAmount != null) _row(context, previousLabel, previousAmount!, previousColor),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, int amount, Color dotColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor)),
        const SizedBox(width: 5),
        // Wide enough for a two-digit month ("10월") on one line.
        ConstrainedBox(constraints: const BoxConstraints(minWidth: 22), child: Text(label, maxLines: 1, softWrap: false, style: TextStyle(fontSize: 11, color: context.glass.textTertiary))),
        const SizedBox(width: 4),
        Text(context.formatWon(amount), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.glass.textPrimary)),
      ],
    );
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
        Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: context.glass.textPrimary)),
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
    final headerBg = insight.positive ? context.glass.accentSoft : Colors.transparent;

    return Container(
      decoration: glassDecoration(context, radius: AppRadii.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: headerBg, borderRadius: BorderRadius.circular(AppRadii.md)),
          child: Row(
            children: [
              Icon(insight.icon, size: 18, color: context.glass.chipSelectedText),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(text: insight.text, style: TextStyle(fontSize: 16, color: context.glass.textPrimary)),
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: context.glass.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
