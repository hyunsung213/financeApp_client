import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/widgets/manual_input_fab.dart' show kBottomNavBarHeight;
import '../../home/theme/home_tokens.dart';
import '../providers/report_provider.dart';
import '../utils/report_date_utils.dart';
import '../utils/report_insight_utils.dart';
import '../widgets/month_picker_sheet.dart';
import 'monthly_report_screen.dart';
import 'category_report_screen.dart';

/// Report main screen (Figma FINAL_REPORT_SCREENS frame 362:3635).
///
/// All numbers here come from [reportMainDataProvider], which fetches
/// `/api/reports/summary|daily|categories` and derives MoM%/top
/// category/peak day in `report_provider.dart` + `report_insight_utils.dart`
/// — nothing is computed inline in this widget, and nothing here is
/// hardcoded/mock (see docs/backend/report-backend-requirements.md for the
/// one still-open backend gap: per-category budget usage, handled on the
/// Category Report screen instead).
///
/// Visual structure was cross-checked against the real Figma export (not
/// just the screenshot): the total/MoM sentence and month button sit
/// directly on a dark-green rounded-bottom hero panel in white/green (not
/// inside their own white card), and the category legend colors below use
/// Figma's exact hex values.
class ReportScreen extends ConsumerWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMonth = ref.watch(reportMonthProvider);
    final dataAsync = ref.watch(reportMainDataProvider(currentMonth));

    return Scaffold(
      backgroundColor: HomeTokens.pageBackground,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 220,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [HomeTokens.heroGradient.last, HomeTokens.pageBackground],
                ),
              ),
            ),
          ),
          SafeArea(
            child: dataAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('리포트를 불러오지 못했어요\n$e', textAlign: TextAlign.center)),
              data: (data) {
                return ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              style: const TextStyle(fontSize: 20, height: 1.3, color: HomeTokens.textDark),
                              children: const [
                                TextSpan(text: '이번 달 소비,\n', style: TextStyle(fontWeight: FontWeight.bold)),
                                TextSpan(text: '잘 관리하고 있어요.', style: TextStyle(fontWeight: FontWeight.normal)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.notifications_none, size: 24, color: HomeTokens.textDark),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      child: _HeroSummaryPanel(
                        totalExpense: data.totalExpense,
                        momPct: data.momPct,
                        month: currentMonth,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: _DailyFlowCard(
                        month: currentMonth,
                        points: data.dailyPoints,
                        highlightDay: data.highlightDay,
                        highlightAmount: data.highlightAmount,
                        onMore: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => MonthlyReportScreen(initialMonth: currentMonth)),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: _CategoryCard(
                        totalExpense: data.totalExpense,
                        categories: data.categories,
                        onMore: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => CategoryReportScreen(initialMonth: currentMonth)),
                        ),
                      ),
                    ),
                    if (data.insights.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        child: _InsightSummaryCard(
                          insights: data.insights,
                          onMore: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => MonthlyReportScreen(initialMonth: currentMonth)),
                          ),
                        ),
                      ),
                    // Report's own ListView paints *under* the floating
                    // bottom-nav pill from ScaffoldWithNavBar (a separate
                    // Stack layer in router.dart, not Scaffold.bottomNavigationBar),
                    // so scroll content needs to reserve that pill's own
                    // footprint or the last card ends up hidden behind it.
                    // The enclosing SafeArea above already reserves the
                    // device's own bottom inset (system nav/gesture area),
                    // so only the pill's height + a little breathing room is
                    // added here - adding MediaQuery's bottom inset again
                    // here too would double-count it.
                    const SizedBox(height: kBottomNavBarHeight + 20),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The dark-green rounded-bottom panel holding the total/MoM sentence
/// (white text) and the month-select pill (Figma nodes 378:5082/378:5086 +
/// 470:9473) — not a white card, matching the real Figma export rather than
/// the screenshot's first impression.
class _HeroSummaryPanel extends ConsumerWidget {
  final int totalExpense;
  final double? momPct;
  final DateTime month;
  const _HeroSummaryPanel({required this.totalExpense, required this.momPct, required this.month});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        gradient: AppGradients.heroHeader,
        borderRadius: BorderRadius.circular(AppRadii.button),
      ),
      child: Column(
        children: [
          Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 16, color: Colors.white),
              children: [
                const TextSpan(text: '이번 달 지출은 '),
                TextSpan(text: formatWon(totalExpense), style: const TextStyle(fontWeight: FontWeight.bold)),
                const TextSpan(text: ' 이에요.'),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          if (momPct != null) ...[
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(
                style: const TextStyle(fontSize: 16, color: Colors.white),
                children: [
                  const TextSpan(text: '지난 달 보다 '),
                  TextSpan(
                    text: '${momPct!.abs().round()}% ${momPct! <= 0 ? '적게' : '많이'}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: ' 사용하셨네요!'),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 16),
          InkWell(
            borderRadius: BorderRadius.circular(AppRadii.compactInput),
            onTap: () async {
              final picked = await MonthPickerSheet.show(context, month);
              if (picked != null) ref.read(reportMonthProvider.notifier).setMonth(picked);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF4ACB9A),
                borderRadius: BorderRadius.circular(AppRadii.compactInput),
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${month.month}월', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white)),
                  const Icon(Icons.keyboard_arrow_down, size: 20, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final VoidCallback? onMore;
  final Widget child;
  const _SectionCard({required this.title, required this.child, this.onMore});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.button),
        boxShadow: AppShadows.elevatedSurface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: HomeTokens.textDark)),
              if (onMore != null)
                GestureDetector(
                  onTap: onMore,
                  child: const Text('더보기', style: TextStyle(color: HomeTokens.textMuted, fontSize: 13)),
                ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _DailyFlowCard extends StatefulWidget {
  final DateTime month;
  final List<DailyPoint> points;
  final int? highlightDay;
  final int? highlightAmount;
  final VoidCallback onMore;

  const _DailyFlowCard({required this.month, required this.points, required this.highlightDay, required this.highlightAmount, required this.onMore});

  @override
  State<_DailyFlowCard> createState() => _DailyFlowCardState();
}

class _DailyFlowCardState extends State<_DailyFlowCard> {
  // Single source of truth for the selected point, the tooltip and the
  // bottom day badge - starts at [highlightDay] (today for the in-progress
  // month, else that month's peak-spend day, per reportMainDataProvider) and
  // moves only in response to a tap/scrub, never automatically.
  int? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.highlightDay;
  }

  @override
  void didUpdateWidget(covariant _DailyFlowCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.month != widget.month) _selectedDay = widget.highlightDay;
  }

  // `points` is already the same future-cutoff-filtered list the line itself
  // is drawn from (reportMainDataProvider clamps out days after "today" for
  // an in-progress month), so its own max day is the correct "don't select a
  // day with nothing plotted" cutoff without re-deriving "today" here.
  int get _lastValidDay => widget.points.isEmpty ? 1 : widget.points.map((p) => p.day).reduce((a, b) => a > b ? a : b);

  int? _amountForDay(int day) {
    for (final p in widget.points) {
      if (p.day == day) return p.spent;
    }
    return null;
  }

  void _updateSelectedDayFromLocalX(double dx, double width) {
    if (width <= 0 || widget.points.isEmpty) return;
    final maxDay = daysInMonth(widget.month).toDouble();
    final t = (dx / width).clamp(0.0, 1.0);
    final day = (1 + t * (maxDay - 1)).round().clamp(1, _lastValidDay);
    if (day != _selectedDay) setState(() => _selectedDay = day);
  }

  @override
  Widget build(BuildContext context) {
    final month = widget.month;
    final points = widget.points;
    final selectedDay = _selectedDay;
    final selectedAmount = selectedDay == null ? null : _amountForDay(selectedDay);

    return _SectionCard(
      title: '이번 달 소비 흐름 (일별)',
      onMore: widget.onMore,
      child: SizedBox(
        height: 190,
        child: points.isEmpty
            ? const Center(child: Text('이번 달 거래 내역이 아직 없어요', style: TextStyle(color: HomeTokens.textMuted)))
            : LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final maxDay = daysInMonth(month).toDouble();
                  final dayAlignmentX = selectedDay == null
                      ? 0.0
                      : (((selectedDay - 1) / (maxDay - 1).clamp(1, 999)) * 2 - 1).clamp(-1.0, 1.0);
                  return Stack(
                    children: [
                      LineChart(
                        LineChartData(
                          gridData: const FlGridData(show: false),
                          titlesData: FlTitlesData(
                            show: true,
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            // No static day numbers anymore - `showTitles: true`
                            // is kept only so fl_chart still reserves the 30px
                            // bottom strip (which the plot area's height
                            // assumes); getTitlesWidget always returns an empty
                            // box so nothing is actually drawn there. The
                            // selected day is shown by the floating badge below
                            // instead, positioned from the same selectedDay/
                            // width math as the tooltip and the dot highlight
                            // above so all three always agree.
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 30,
                                getTitlesWidget: (value, meta) => const SizedBox.shrink(),
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          minX: 1,
                          maxX: maxDay,
                          minY: 0,
                          lineBarsData: [
                            LineChartBarData(
                              spots: points.map((p) => FlSpot(p.day.toDouble(), p.spent.toDouble())).toList(),
                              isCurved: false,
                              color: HomeTokens.accent,
                              barWidth: 2,
                              isStrokeCapRound: true,
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, barData, index) {
                                  if (spot.x.toInt() == selectedDay) {
                                    return FlDotCirclePainter(radius: 4, color: Colors.white, strokeWidth: 2, strokeColor: HomeTokens.accent);
                                  }
                                  return FlDotCirclePainter(radius: 0, color: Colors.transparent);
                                },
                              ),
                              belowBarData: BarAreaData(show: false),
                            ),
                          ],
                        ),
                      ),
                      if (selectedDay != null)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: 30,
                          child: IgnorePointer(
                            child: Align(
                              alignment: Alignment(dayAlignmentX, 0),
                              // No `height`/`alignment`/`Center` here: any of
                              // those make this expand to fill the bounded
                              // width the outer Align hands it (Container
                              // with alignment set, and Align/Center as a
                              // child, both size themselves to fill bounded
                              // parent constraints per their own docs) - which
                              // silently turned this into a full-width bar
                              // instead of a small pill. Sizing purely from
                              // padding shrink-wraps to the Text in both
                              // axes; the outer Align's y:0 already centers
                              // it vertically within the reserved strip.
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                                decoration: BoxDecoration(
                                  color: HomeTokens.accent.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(color: HomeTokens.accent.withValues(alpha: 0.35), width: 1),
                                ),
                                child: Text(
                                  '$selectedDay',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: HomeTokens.accentDark),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (selectedDay != null && selectedAmount != null)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: IgnorePointer(
                            child: Align(
                              alignment: Alignment(dayAlignmentX, 0),
                              // Figma's callout stacks "8월 17일" (bold) above the
                              // amount on its own line, not one run-on sentence.
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(color: HomeTokens.accentDark, borderRadius: BorderRadius.circular(AppRadii.compactInput)),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('${month.month}월 $selectedDay일', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                    Text(formatWon(selectedAmount), style: const TextStyle(color: Colors.white, fontSize: 11)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      // Topmost so it always wins the gesture arena over
                      // fl_chart's own touch handling; onHorizontalDragUpdate
                      // (not a plain pan) so a vertical swipe that merely
                      // starts over the chart still scrolls the page, matching
                      // the interactive Monthly Report chart's approach.
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
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final int totalExpense;
  final List<CategoryAmount> categories;
  final VoidCallback onMore;

  const _CategoryCard({required this.totalExpense, required this.categories, required this.onMore});

  // Exact hex values from the Figma export (378:5057/5060/5063/5067).
  static const _colors = [
    Color(0xFF00AE76),
    Color(0xFF42B7FD),
    Color(0xFFFFB702),
    Color(0xFFBDD527),
    Color(0xFF9E9E9E),
  ];

  @override
  Widget build(BuildContext context) {
    final shown = categories.take(4).toList();
    final restCount = categories.length - shown.length;

    return _SectionCard(
      title: '카테고리 별 지출',
      onMore: onMore,
      child: categories.isEmpty
          ? const SizedBox(height: 80, child: Center(child: Text('이번 달 지출 카테고리가 아직 없어요', style: TextStyle(color: HomeTokens.textMuted))))
          : SizedBox(
              height: 200,
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            sectionsSpace: 0,
                            centerSpaceRadius: 50,
                            sections: List.generate(
                              categories.length,
                              (i) => PieChartSectionData(color: _colors[i % _colors.length], value: categories[i].amount.toDouble(), title: '', radius: 25),
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('합계', style: TextStyle(fontSize: 12, color: HomeTokens.textMuted)),
                            Text(formatWon(totalExpense), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: HomeTokens.textDark)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ...List.generate(shown.length, (i) {
                          final c = shown[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: _colors[i % _colors.length])),
                                const SizedBox(width: 8),
                                Expanded(child: Text(c.name, style: const TextStyle(color: HomeTokens.textDark, fontSize: 13))),
                                Text('${c.percentage.round()}%', style: TextStyle(color: _colors[i % _colors.length], fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                          );
                        }),
                        if (restCount > 0)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                const SizedBox(width: 16),
                                const Icon(Icons.more_horiz, size: 16, color: HomeTokens.textMuted),
                                const SizedBox(width: 4),
                                Text('외 $restCount건', style: const TextStyle(color: HomeTokens.textMuted, fontSize: 12)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _InsightSummaryCard extends StatelessWidget {
  final List<ReportInsight> insights;
  final VoidCallback onMore;
  const _InsightSummaryCard({required this.insights, required this.onMore});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '이번 달 리포트 요약',
      onMore: onMore,
      child: Column(
        children: insights
            .map((insight) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: onMore,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: insight.positive ? HomeTokens.chipActiveBg : AppColorTokens.negativeSoftBg,
                        borderRadius: BorderRadius.circular(AppRadii.input),
                      ),
                      child: Row(
                        children: [
                          Icon(insight.icon, size: 18, color: insight.positive ? HomeTokens.accentDark : AppColors.warning),
                          const SizedBox(width: 10),
                          Expanded(child: Text(insight.text, style: const TextStyle(fontSize: 13, color: HomeTokens.textDark, fontWeight: FontWeight.w600))),
                          const Icon(Icons.chevron_right, size: 18, color: HomeTokens.textMuted),
                        ],
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}
