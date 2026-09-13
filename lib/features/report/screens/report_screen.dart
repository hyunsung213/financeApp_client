import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../data/api/report_api.dart';
import 'category_report_detail_screen.dart';
import 'monthly_comparison_screen.dart';

num _toNum(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value;
  return num.tryParse(value.toString()) ?? 0;
}

int _toInt(dynamic value) => _toNum(value).toInt();

const _weekdayNames = ['월', '화', '수', '목', '금', '토', '일'];

class ReportMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();

  void setMonth(DateTime month) => state = month;
}

final reportMonthProvider = NotifierProvider<ReportMonthNotifier, DateTime>(() {
  return ReportMonthNotifier();
});

class ReportPageData {
  final int totalIncome;
  final int totalExpense;
  final int? lastMonthExpense;
  final List<Map<String, dynamic>> dailyThisMonth;
  final List<Map<String, dynamic>> dailyLastMonth;
  final List<Map<String, dynamic>> categories;

  ReportPageData({
    required this.totalIncome,
    required this.totalExpense,
    required this.lastMonthExpense,
    required this.dailyThisMonth,
    required this.dailyLastMonth,
    required this.categories,
  });

  /// Category with the highest spend this month, or null if nothing was spent.
  Map<String, dynamic>? get topCategory => categories.isEmpty ? null : categories.first;

  /// (weekday name, total spent) for the weekday with the highest spend this month, or null.
  (String, int)? get topWeekday {
    final byWeekday = List<int>.filled(7, 0);
    for (final row in dailyThisMonth) {
      final date = DateTime.tryParse(row['date']?.toString() ?? '');
      if (date == null) continue;
      byWeekday[date.weekday - 1] += _toInt(row['expense']);
    }
    var maxIndex = 0;
    for (var i = 1; i < 7; i++) {
      if (byWeekday[i] > byWeekday[maxIndex]) maxIndex = i;
    }
    if (byWeekday[maxIndex] <= 0) return null;
    return (_weekdayNames[maxIndex], byWeekday[maxIndex]);
  }

  /// Month-over-month % change (positive = spent more), or null if last month has no data.
  double? get momChangePercent {
    if (lastMonthExpense == null || lastMonthExpense == 0) return null;
    return (totalExpense - lastMonthExpense!) / lastMonthExpense! * 100;
  }
}

final reportDataProvider = FutureProvider.family<ReportPageData, DateTime>((ref, month) async {
  final api = ref.watch(reportApiProvider);
  final fmt = DateFormat('yyyy-MM-dd');

  final start = DateTime(month.year, month.month, 1);
  final end = DateTime(month.year, month.month + 1, 0);
  final prevMonth = DateTime(month.year, month.month - 1, 1);
  final prevStart = DateTime(prevMonth.year, prevMonth.month, 1);
  final prevEnd = DateTime(prevMonth.year, prevMonth.month + 1, 0);

  final results = await Future.wait([
    api.getSummary(startDate: fmt.format(start), endDate: fmt.format(end)),
    api.getDaily(startDate: fmt.format(start), endDate: fmt.format(end)),
    api.getDaily(startDate: fmt.format(prevStart), endDate: fmt.format(prevEnd)),
    api.getCategories(startDate: fmt.format(start), endDate: fmt.format(end)),
    api.getMonthly(),
  ]);

  final summary = results[0] as Map<String, dynamic>;
  final dailyThisRaw = results[1] as Map<String, dynamic>;
  final dailyLastRaw = results[2] as Map<String, dynamic>;
  final categoriesRaw = results[3] as List<dynamic>;
  final monthly = results[4] as List<dynamic>;

  final categories = categoriesRaw.whereType<Map>().map((c) => Map<String, dynamic>.from(c)).toList()
    ..sort((a, b) => _toNum(b['amount']).compareTo(_toNum(a['amount'])));

  final prevMonthKey = DateFormat('yyyy-MM').format(prevStart);
  Map<String, dynamic>? prevMonthEntry;
  for (final m in monthly) {
    if (m is Map && m['month'] == prevMonthKey) {
      prevMonthEntry = Map<String, dynamic>.from(m);
      break;
    }
  }

  return ReportPageData(
    totalIncome: _toInt(summary['income']),
    totalExpense: _toInt(summary['expense']),
    lastMonthExpense: prevMonthEntry != null ? _toInt(prevMonthEntry['expense']) : null,
    dailyThisMonth: (dailyThisRaw['daily'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(),
    dailyLastMonth: (dailyLastRaw['daily'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(),
    categories: categories,
  );
});

class ReportScreen extends ConsumerWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMonth = ref.watch(reportMonthProvider);
    final reportAsync = ref.watch(reportDataProvider(currentMonth));

    return Scaffold(
      backgroundColor: Colors.white,
      body: reportAsync.when(
        loading: () => const ReportSkeleton(),
        error: (e, st) => Center(child: Text('불러오지 못했어요: $e', style: const TextStyle(color: AppColors.textSecondary))),
        data: (data) {
          final momPercent = data.momChangePercent;
          final topCategory = data.topCategory;
          final topWeekday = data.topWeekday;

          return Column(
            children: [
              // Hero: header + spend summary + month pill, all on the gradient.
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF00C875), Color(0xFF10B981)],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '이번 달 소비,\n잘 관리하고 있어요.',
                              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, height: 1.3),
                            ),
                            IconButton(
                              icon: const Icon(Icons.notifications_none, color: Colors.white, size: 26),
                              onPressed: () {},
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                            children: [
                              const TextSpan(text: '이번 달 지출은 '),
                              TextSpan(
                                text: '${NumberFormat('#,###').format(data.totalExpense)}원',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const TextSpan(text: ' 이에요.'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          momPercent == null
                              ? '지난달 같은 기간 데이터가 없어서 비교할 수 없어요.'
                              : momPercent <= 0
                                  ? '지난달 보다 ${momPercent.abs().round()}% 적게 사용하셨네요!'
                                  : '지난달 보다 ${momPercent.round()}% 많이 사용했어요.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        const SizedBox(height: 20),
                        InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _showMonthPicker(context, ref, currentMonth),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('${currentMonth.month}월', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 4),
                                const Icon(Icons.expand_more, size: 20, color: Colors.white),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Body: chart / donut / insight sections on one continuous white sheet.
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('이번 달 소비 흐름 (일별)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        InkWell(
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => MonthlyComparisonScreen(
                              month: currentMonth,
                              thisMonthExpense: data.totalExpense,
                              lastMonthExpense: data.lastMonthExpense,
                              dailyThisMonth: data.dailyThisMonth,
                              dailyLastMonth: data.dailyLastMonth,
                            ),
                          )),
                          child: Text('더보기', style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.7))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 180,
                      child: _buildAreaChart(currentMonth, data.dailyThisMonth, data.dailyLastMonth),
                    ),
                    const SizedBox(height: 32),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('카테고리 별 지출', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        if (data.categories.isNotEmpty)
                          InkWell(
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => CategoryReportDetailScreen(
                                month: currentMonth,
                                totalExpense: data.totalExpense,
                                categories: data.categories,
                              ),
                            )),
                            child: Text('더보기', style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.7))),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (data.categories.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: Text('이번 달 지출 내역이 없어요.', style: TextStyle(color: AppColors.textSecondary))),
                      )
                    else
                      SizedBox(
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
                                      sections: _buildPieChartSections(data.categories),
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('합계', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                      Text(
                                        '${NumberFormat('#,###').format(data.totalExpense)}원',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: _buildCategoryLegend(data.categories),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 32),

                    Text('이번 달 리포트 요약', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    momPercent == null
                        ? _insightRow(positive: true, spans: const [TextSpan(text: '지난달과 비교할 데이터가 없어요')])
                        : _insightRow(
                            positive: momPercent <= 0,
                            spans: [
                              const TextSpan(text: '저번보다 '),
                              TextSpan(
                                text: '${momPercent.abs().round()}%',
                                style: TextStyle(fontWeight: FontWeight.bold, color: momPercent <= 0 ? AppColors.primary : AppColors.danger),
                              ),
                              TextSpan(text: momPercent <= 0 ? ' 적게 썼어요' : ' 많이 썼어요'),
                            ],
                          ),
                    topCategory == null
                        ? _insightRow(positive: false, spans: const [TextSpan(text: '이번 달 지출 내역이 아직 없어요')])
                        : _insightRow(
                            positive: false,
                            spans: [
                              TextSpan(text: '${topCategory['category']}에', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.danger)),
                              const TextSpan(text: ' 가장 많이 썼어요'),
                            ],
                          ),
                    topWeekday == null
                        ? _insightRow(positive: false, spans: const [TextSpan(text: '요일별 지출 데이터가 아직 없어요')])
                        : _insightRow(
                            positive: false,
                            spans: [
                              TextSpan(text: '${topWeekday.$1}요일'),
                              const TextSpan(text: '에 가장 많은 금액 '),
                              TextSpan(
                                text: '${NumberFormat('#,###').format(topWeekday.$2)}원',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.danger),
                              ),
                            ],
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

  void _showMonthPicker(BuildContext context, WidgetRef ref, DateTime currentMonth) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text('${currentMonth.year}년', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.6,
                children: List.generate(12, (i) {
                  final month = i + 1;
                  final isSelected = month == currentMonth.month;
                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      ref.read(reportMonthProvider.notifier).setMonth(DateTime(currentMonth.year, month));
                      Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$month월',
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  /// One "이번 달 리포트 요약" row: green/thumbs-up for a good signal, red/thumbs-down
  /// for a spend-concentration flag (matches the design's sentiment coding).
  Widget _insightRow({required bool positive, required List<InlineSpan> spans}) {
    final bg = positive ? AppColors.primaryLight : AppColors.dangerLight;
    final accent = positive ? AppColors.primary : AppColors.danger;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(positive ? Icons.thumb_up_alt_outlined : Icons.thumb_down_alt_outlined, size: 18, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(style: const TextStyle(fontSize: 14, color: AppColors.textPrimary), children: spans),
            ),
          ),
          Icon(Icons.expand_more, size: 18, color: accent),
        ],
      ),
    );
  }

  Widget _buildAreaChart(DateTime month, List<Map<String, dynamic>> dailyThisMonth, List<Map<String, dynamic>> dailyLastMonth) {
    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0).day;
    final now = DateTime.now();
    final isCurrentMonth = now.year == month.year && now.month == month.month;

    List<FlSpot> toSpots(List<Map<String, dynamic>> rows) => rows.map((row) {
          final date = DateTime.tryParse(row['date']?.toString() ?? '');
          final day = date?.day ?? 0;
          return FlSpot(day.toDouble(), _toNum(row['expense']).toDouble());
        }).toList();

    final spots = toSpots(dailyThisMonth);
    final lastMonthSpots = toSpots(dailyLastMonth);

    final labelDays = <int>{1, (lastDayOfMonth / 2).round(), lastDayOfMonth};
    if (isCurrentMonth) labelDays.add(now.day);

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final day = value.toInt();
                if (labelDays.contains(day)) {
                  final isToday = isCurrentMonth && day == now.day;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      day.toString(),
                      style: TextStyle(
                        color: isToday ? AppColors.primary : AppColors.textSecondary,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 1,
        maxX: lastDayOfMonth.toDouble(),
        minY: 0,
        lineBarsData: [
          if (lastMonthSpots.isNotEmpty)
            LineChartBarData(
              spots: lastMonthSpots,
              isCurved: false,
              color: AppColors.primary.withValues(alpha: 0.3),
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: FlDotData(show: false),
            ),
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: AppColors.primary,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                if (isCurrentMonth && spot.x == now.day) {
                  return FlDotCirclePainter(radius: 4, color: Colors.white, strokeWidth: 2, strokeColor: AppColors.primary);
                }
                return FlDotCirclePainter(radius: 0, color: Colors.transparent);
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [AppColors.primary.withValues(alpha: 0.4), AppColors.primary.withValues(alpha: 0.0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _pieColors = [
    AppColors.primary,
    Color(0xFF64B5F6),
    Color(0xFFFFCA28),
    Color(0xFFCDDC39),
    Color(0xFF9E9E9E),
  ];

  List<PieChartSectionData> _buildPieChartSections(List<Map<String, dynamic>> categories) {
    final shown = categories.length > 5 ? categories.sublist(0, 5) : categories;
    return List.generate(shown.length, (i) {
      return PieChartSectionData(
        color: _pieColors[i % _pieColors.length],
        value: _toNum(shown[i]['percentage']).toDouble(),
        title: '',
        radius: 25,
      );
    });
  }

  Widget _buildCategoryLegend(List<Map<String, dynamic>> categories) {
    final shown = categories.length > 4 ? categories.sublist(0, 4) : categories;
    final remaining = categories.length - shown.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(shown.length, (i) {
          final name = (shown[i]['category'] ?? '기타').toString();
          final percent = _toNum(shown[i]['percentage']).round();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: _pieColors[i % _pieColors.length])),
                const SizedBox(width: 8),
                Expanded(child: Text(name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
                Text('$percent%', style: TextStyle(color: _pieColors[i % _pieColors.length], fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          );
        }),
        if (remaining > 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Text('... 외 $remaining건', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
      ],
    );
  }
}
