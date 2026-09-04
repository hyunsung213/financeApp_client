import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../../data/api/report_api.dart';

class ReportMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();
  
  void setMonth(DateTime month) => state = month;
}

final reportMonthProvider = NotifierProvider<ReportMonthNotifier, DateTime>(() {
  return ReportMonthNotifier();
});

final reportDataProvider = FutureProvider.family<Map<String, dynamic>, DateTime>((ref, month) async {
  final api = ref.watch(reportApiProvider);
  
  final startDate = DateTime(month.year, month.month, 1);
  final endDate = DateTime(month.year, month.month + 1, 0); // Last day
  final startStr = DateFormat('yyyy-MM-dd').format(startDate);
  final endStr = DateFormat('yyyy-MM-dd').format(endDate);
  
  final summary = await api.getSummary(startDate: startStr, endDate: endStr);
  final daily = await api.getDaily(startDate: startStr, endDate: endStr);
  final categories = await api.getCategories(startDate: startStr, endDate: endStr);
  
  return {
    'summary': summary,
    'daily': daily,
    'categories': categories,
  };
});

class ReportScreen extends ConsumerWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMonth = ref.watch(reportMonthProvider);
    final reportAsync = ref.watch(reportDataProvider(currentMonth));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background Gradient
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 300,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFD4F7D4), // Soft green from mockup
                    AppColors.background,
                  ],
                ),
              ),
            ),
          ),
          
          SafeArea(
            child: reportAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
              data: (data) {
                final summary = data['summary'];
                final daily = data['daily'] as List<dynamic>;
                final categories = data['categories'] as List<dynamic>;
                
                final totalSpent = summary['totalSpent'] ?? 0;
                
                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '이번 달 소비,\n잘 관리하고 있어요.',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.notifications_none, size: 28),
                          onPressed: () {},
                        )
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Summary Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              style: Theme.of(context).textTheme.bodyLarge,
                              children: [
                                const TextSpan(text: '이번 달 지출은 '),
                                TextSpan(
                                  text: '${NumberFormat('#,###').format(totalSpent)}원',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  )
                                ),
                                const TextSpan(text: ' 이에요.'),
                              ]
                            )
                          ),
                          const SizedBox(height: 8),
                          RichText(
                            text: TextSpan(
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                              children: const [
                                TextSpan(text: '지난 달 보다 '),
                                TextSpan(
                                  text: '8% 적게', // Mock data
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  )
                                ),
                                TextSpan(text: ' 사용하셨네요!'),
                              ]
                            )
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Month Selector
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: () {
                              ref.read(reportMonthProvider.notifier).setMonth(DateTime(currentMonth.year, currentMonth.month - 1));
                            },
                          ),
                          Expanded(
                            child: Text(
                              '${currentMonth.month}월',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: () {
                              ref.read(reportMonthProvider.notifier).setMonth(DateTime(currentMonth.year, currentMonth.month + 1));
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Area Chart Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('이번 달 소비 흐름 (일별)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              Text('더보기', style: TextStyle(color: AppColors.textSecondary.withOpacity(0.5))),
                            ],
                          ),
                          const SizedBox(height: 30),
                          SizedBox(
                            height: 180,
                            child: _buildAreaChart(daily),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Donut Chart Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('카테고리 별 지출', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              Text('더보기', style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5))),
                            ],
                          ),
                          const SizedBox(height: 24),
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
                                          sections: _buildPieChartSections(categories),
                                        ),
                                      ),
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text('합계', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                          Text(
                                            '${NumberFormat('#,###').format(totalSpent)}원',
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ],
                                  )
                                ),
                                Expanded(
                                  flex: 1,
                                  child: _buildCategoryLegend(categories),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAreaChart(List<dynamic> daily) {
    List<FlSpot> spots = [];
    if (daily.isEmpty) {
      // Mock data for empty state
      spots = [
        const FlSpot(1, 1), const FlSpot(10, 3), const FlSpot(15, 2), 
        const FlSpot(17, 5), const FlSpot(20, 6), const FlSpot(31, 8)
      ];
    } else {
      for (var item in daily) {
        final date = DateTime.parse(item['date']);
        spots.add(FlSpot(date.day.toDouble(), double.parse(item['spent'].toString())));
      }
    }

    // Mock last month data
    List<FlSpot> lastMonthSpots = [
      const FlSpot(1, 0.5), const FlSpot(10, 2.5), const FlSpot(15, 1.5), 
      const FlSpot(17, 3.5), const FlSpot(20, 4.5), const FlSpot(31, 6.5)
    ];

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
                if ([1, 10, 15, 17, 20, 31].contains(day)) {
                  bool isToday = day == 17; // Mock today
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
        maxX: 31,
        minY: 0,
        lineBarsData: [
          // Last Month Line
          LineChartBarData(
            spots: lastMonthSpots,
            isCurved: false,
            color: AppColors.primary.withValues(alpha: 0.3),
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
          ),
          // This Month Line
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: AppColors.primary,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                if (spot.x == 17) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: Colors.white,
                    strokeWidth: 2,
                    strokeColor: AppColors.primary,
                  );
                }
                return FlDotCirclePainter(radius: 0, color: Colors.transparent);
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.4),
                  AppColors.primary.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections(List<dynamic> categories) {
    final colors = [
      AppColors.primary,
      const Color(0xFF64B5F6), // Light Blue
      const Color(0xFFFFCA28), // Amber
      const Color(0xFFCDDC39), // Lime
      const Color(0xFF9E9E9E), // Grey
    ];

    if (categories.isEmpty) {
      // Mock Data
      return [
        PieChartSectionData(color: colors[0], value: 50, title: '', radius: 25),
        PieChartSectionData(color: colors[1], value: 30, title: '', radius: 25),
        PieChartSectionData(color: colors[2], value: 10, title: '', radius: 25),
        PieChartSectionData(color: colors[3], value: 10, title: '', radius: 25),
      ];
    }

    return List.generate(categories.length > 5 ? 5 : categories.length, (i) {
      final cat = categories[i];
      return PieChartSectionData(
        color: colors[i % colors.length],
        value: double.parse(cat['percentage']?.toString() ?? '1'),
        title: '',
        radius: 25,
      );
    });
  }

  Widget _buildCategoryLegend(List<dynamic> categories) {
    final colors = [
      AppColors.primary,
      const Color(0xFF64B5F6),
      const Color(0xFFFFCA28),
      const Color(0xFFCDDC39),
      const Color(0xFF9E9E9E),
    ];

    final mockNames = ['식비', '교통비', '카페', '카드', '기타'];
    final mockPercents = [50, 30, 10, 10, 0];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (i) {
        String name = mockNames[i];
        int percent = mockPercents[i];
        
        if (i < categories.length) {
          name = categories[i]['name'] ?? name;
          percent = (double.parse(categories[i]['percentage']?.toString() ?? '0')).round();
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: colors[i])),
              const SizedBox(width: 8),
              Expanded(child: Text(name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13))),
              Text('$percent%', style: TextStyle(color: colors[i], fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        );
      })..add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(width: 16),
              Text('... 외 6건', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        )
      ),
    );
  }
}
