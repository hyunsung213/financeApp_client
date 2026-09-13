import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../home/theme/home_tokens.dart';
import '../../transaction/screens/transaction_list_screen.dart';
import '../../../data/api/category_api.dart';
import '../providers/report_provider.dart';
import '../utils/report_insight_utils.dart';
import '../widgets/budget_usage_bar.dart';
import '../widgets/month_picker_sheet.dart';

/// Category Report detail (Figma frames 114:5192 / 397:5357): donut +
/// per-category rows, each expandable into 금액/비율/지난달 대비/거래
/// 건수/예산 사용률/거래내역 보기. Reuses [monthlyReportDataProvider]
/// (already fetches this month + last month's `/api/reports/categories`)
/// instead of a new provider, since the "지난달(1일-N일) 대비" figure it
/// needs is exactly what that provider already computes for the Monthly
/// Report screen's category-growth insight.
class CategoryReportScreen extends ConsumerStatefulWidget {
  final DateTime initialMonth;
  const CategoryReportScreen({super.key, required this.initialMonth});

  @override
  ConsumerState<CategoryReportScreen> createState() => _CategoryReportScreenState();
}

class _CategoryReportScreenState extends ConsumerState<CategoryReportScreen> {
  String? _expandedCategory;

  static const _colors = [
    HomeTokens.accent,
    Color(0xFF64B5F6),
    Color(0xFFFFCA28),
    Color(0xFFCDDC39),
    Color(0xFF9E9E9E),
    Color(0xFFBA68C8),
  ];

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
        title: const Text('카테고리별 지출', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('불러오지 못했어요\n$e', textAlign: TextAlign.center)),
        data: (data) {
          final categories = data.currentCategories;
          final total = categories.fold<int>(0, (sum, c) => sum + c.amount);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
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
                        const Text('카테고리 별 지출', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: HomeTokens.textDark)),
                        InkWell(
                          onTap: () async {
                            final picked = await MonthPickerSheet.show(context, month);
                            if (picked != null) ref.read(reportMonthProvider.notifier).setMonth(picked);
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: HomeTokens.cardSurface,
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))],
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Text('${month.month}월', style: const TextStyle(fontWeight: FontWeight.bold, color: HomeTokens.textDark)),
                              const Icon(Icons.keyboard_arrow_down, size: 18, color: HomeTokens.textMuted),
                            ]),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (categories.isEmpty)
                      const SizedBox(height: 80, child: Center(child: Text('이번 달 지출 카테고리가 아직 없어요', style: TextStyle(color: HomeTokens.textMuted))))
                    else
                      Builder(builder: (context) {
                        final shown = categories.take(4).toList();
                        final restCount = categories.length - shown.length;
                        return SizedBox(
                          height: 180,
                          child: Row(
                            children: [
                              Expanded(
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    PieChart(PieChartData(
                                      sectionsSpace: 0,
                                      centerSpaceRadius: 50,
                                      sections: List.generate(categories.length, (i) => PieChartSectionData(color: _colors[i % _colors.length], value: categories[i].amount.toDouble(), title: '', radius: 25)),
                                    )),
                                    Column(mainAxisSize: MainAxisSize.min, children: [
                                      const Text('합계', style: TextStyle(fontSize: 12, color: HomeTokens.textMuted)),
                                      Text(formatWon(total), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                    ]),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (var i = 0; i < shown.length; i++)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        child: Row(children: [
                                          Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: _colors[i % _colors.length])),
                                          const SizedBox(width: 8),
                                          Expanded(child: Text(shown[i].name, style: const TextStyle(color: HomeTokens.textDark, fontSize: 13))),
                                          Text('${shown[i].percentage.round()}%', style: TextStyle(color: _colors[i % _colors.length], fontWeight: FontWeight.bold, fontSize: 13)),
                                        ]),
                                      ),
                                    if (restCount > 0)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        child: Row(children: [
                                          const SizedBox(width: 16),
                                          const Icon(Icons.more_horiz, size: 16, color: HomeTokens.textMuted),
                                          const SizedBox(width: 4),
                                          Text('외 $restCount건', style: const TextStyle(color: HomeTokens.textMuted, fontSize: 12)),
                                        ]),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < categories.length; i++) ...[
                _CategoryRow(
                  category: categories[i],
                  color: _colors[i % _colors.length],
                  previousAmount: data.previousCategories.where((c) => c.name == categories[i].name).map((c) => c.amount).firstOrNull,
                  comparisonDayLabel: data.range.isPartial ? '1일-${data.range.comparisonDay}일' : null,
                  expanded: _expandedCategory == categories[i].name,
                  onTap: () => setState(() => _expandedCategory = _expandedCategory == categories[i].name ? null : categories[i].name),
                ),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _CategoryRow extends ConsumerWidget {
  final CategoryAmount category;
  final Color color;
  final int? previousAmount;
  final String? comparisonDayLabel;
  final bool expanded;
  final VoidCallback onTap;

  const _CategoryRow({
    required this.category,
    required this.color,
    required this.previousAmount,
    required this.comparisonDayLabel,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: BudgetUsageBar(
                      categoryName: category.name,
                      categoryColor: color,
                      spentAmount: category.amount,
                      budgetAmount: null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more, color: HomeTokens.textMuted),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  _kv(Icons.payments_outlined, '금액', formatWon(category.amount)),
                  _kv(Icons.percent_rounded, '비율', '${category.percentage.round()}%'),
                  if (previousAmount != null)
                    _kv(
                      Icons.cached_rounded,
                      comparisonDayLabel == null ? '지난달' : '지난달 ($comparisonDayLabel)',
                      '${formatWon(previousAmount!)} (${_pctLabel(category.amount, previousAmount!)})',
                    ),
                  _kv(Icons.swap_vert_rounded, '거래 건수', '${category.transactionCount}건'),
                  Builder(builder: (context) {
                    final previewBudget = BudgetUsageBar.previewBudgetFor(category.amount, null);
                    final value = previewBudget == null
                        ? '예산 미설정'
                        : '${(category.amount / previewBudget * 100).round()}% (${formatWon(previewBudget)} 중)';
                    return _kv(Icons.event_busy_outlined, '예산 사용률', value);
                  }),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () async {
                      final categories = await ref.read(categoriesProvider.future);
                      final match = categories.whereType<Map>().where((c) => c['name'] == category.name).firstOrNull;
                      if (!context.mounted) return;
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => TransactionListScreen(initialCategoryId: match?['id']?.toString()),
                      ));
                    },
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44), side: const BorderSide(color: HomeTokens.chipInactiveBorder)),
                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('거래 내역 보기'), SizedBox(width: 4), Icon(Icons.chevron_right, size: 18)]),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _pctLabel(int current, int previous) {
    final pct = momPercent(current, previous);
    if (pct == null) return '-';
    return '${pct <= 0 ? '' : '+'}${pct.round()}%';
  }

  Widget _kv(IconData icon, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(icon, size: 15, color: HomeTokens.textMuted),
          const SizedBox(width: 8),
          Expanded(child: Text(k, style: const TextStyle(fontSize: 13, color: HomeTokens.textMuted))),
          Text(v, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: HomeTokens.textDark)),
        ]),
      );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
