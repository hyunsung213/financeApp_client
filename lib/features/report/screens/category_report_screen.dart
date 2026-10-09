import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_shadows.dart';
import '../../transaction/screens/transaction_list_screen.dart';
import '../../../data/api/category_api.dart';
import '../providers/report_provider.dart';
import '../utils/report_insight_utils.dart';
import '../widgets/category_share_bar.dart';
import '../widgets/month_picker_sheet.dart';
import '../../../core/format/money_format.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/theme/wallet_glass.dart';
import '../../../data/api/api_error.dart';

/// Category Report detail (Figma frames 114:5192 / 397:5357): donut +
/// one card per 대분류 (the same roll-up the donut is drawn from), each showing
/// its spent amount and share of all spending, expandable into 금액/전체 지출
/// 중 비율/지난달 대비/거래 건수/소분류 내역/거래내역 보기.
///
/// Budget is deliberately absent: the backend has no category budget, and real
/// budgets will be scoped to the salary-cycle BudgetCycle rather than this
/// screen's calendar month. See [CategoryShareBar] for where a real
/// `budgetAmount` (and the 초과 badge) would plug in later. Reuses [monthlyReportDataProvider]
/// (already fetches this month + last month's `/api/reports/categories`)
/// instead of a new provider, since the "지난달(1일-N일) 대비" figure it
/// needs is exactly what that provider already computes for the Monthly
/// Report screen's category-growth insight.
///
/// [initialCategoryName] lets a caller (Monthly Report's "~증가 영향이
/// 컸어요" category insight) deep-link straight into this screen with that
/// category already expanded/selected, per the product rule that a
/// category-impact insight should land here instead of only explaining
/// itself in place. Matched by name (not id) because `/api/reports/categories`
/// still doesn't return a stable `categoryId` (see
/// docs/backend/report-backend-requirements.md #6) — this reuses the same
/// name-based lookup pattern already used by this screen's own "거래 내역
/// 보기" button below.
class CategoryReportScreen extends ConsumerStatefulWidget {
  final DateTime initialMonth;
  final String? initialCategoryName;
  const CategoryReportScreen({super.key, required this.initialMonth, this.initialCategoryName});

  /// The one way to open this screen. It goes onto the *root* Navigator, above
  /// the tab shell, so it is a full-screen detail page: the shell's floating
  /// Bottom Navigation (`ScaffoldWithNavBar` in `lib/core/router.dart`) sits
  /// underneath it and is not part of this route's layout at all, instead of
  /// being drawn over the last cards. Back returns to the screen that opened
  /// it, with the Bottom Navigation showing again.
  static Future<void> open(BuildContext context, {required DateTime initialMonth, String? initialCategoryName}) {
    return Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
      builder: (_) => CategoryReportScreen(initialMonth: initialMonth, initialCategoryName: initialCategoryName),
    ));
  }

  @override
  ConsumerState<CategoryReportScreen> createState() => _CategoryReportScreenState();
}

class _CategoryReportScreenState extends ConsumerState<CategoryReportScreen> {
  // A name from a caller's deep link is a leaf name (e.g. the growth insight's
  // category); build() resolves it to the 대분류 card it belongs to.
  late String? _expandedCategory = widget.initialCategoryName;

  static const _colors = [
    AppColorTokens.accent,
    Color(0xFF64B5F6),
    Color(0xFFFFCA28),
    Color(0xFFCDDC39),
    Color(0xFF9E9E9E),
    Color(0xFFBA68C8),
    // Appended so up to 11 대분류 (10 built-in + a user-made one) each keep a
    // distinct color now that the legend lists all of them; the first six
    // are unchanged.
    Color(0xFFFF8A65),
    Color(0xFF7986CB),
    Color(0xFFF06292),
    Color(0xFF8D6E63),
    Color(0xFF26A69A),
  ];

  @override
  Widget build(BuildContext context) {
    final month = ref.watch(reportMonthProvider);
    final dataAsync = ref.watch(monthlyReportDataProvider(month));

    return WalletBackground(child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent, surfaceTintColor: Colors.transparent, scrolledUnderElevation: 0,
        elevation: 0,
        foregroundColor: context.glass.textPrimary,
        title: const Text('카테고리별 지출', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('불러오지 못했어요\n${userErrorMessage(e)}', textAlign: TextAlign.center)),
        data: (data) {
          // Donut, legend, and the cards below all read this one 대분류 roll-up,
          // so a card's amount, percentage and color always match its slice.
          // The per-leaf rows the endpoint returns only feed each card's
          // 소분류 breakdown.
          final majors = data.currentMajorCategories;
          final expandedMajor = _expandedCategory == null ? null : data.majorNameByCategoryName[_expandedCategory] ?? _expandedCategory;
          final total = majors.fold<int>(0, (sum, c) => sum + c.amount);
          final majorColors = {for (var i = 0; i < majors.length; i++) majors[i].name: _colors[i % _colors.length]};

          return ListView(
            // No Bottom Navigation on this detail page, so the only bottom
            // inset to respect is the device's own (gesture bar) one.
            padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.paddingOf(context).bottom),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: glassDecoration(context, radius: AppRadii.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('카테고리 별 지출', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: context.glass.textPrimary)),
                        InkWell(
                          onTap: () async {
                            final picked = await MonthPickerSheet.show(context, month);
                            if (picked != null) ref.read(reportMonthProvider.notifier).setMonth(picked);
                          },
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: context.glass.cardFill,
                              borderRadius: BorderRadius.circular(AppRadii.md),
                              boxShadow: AppShadows.elevatedStrong,
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Text('${month.month}월', style: TextStyle(fontWeight: FontWeight.bold, color: context.glass.textPrimary)),
                              Icon(Icons.keyboard_arrow_down, size: 18, color: context.glass.textTertiary),
                            ]),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (majors.isEmpty)
                      SizedBox(height: 80, child: Center(child: Text('이번 달 지출 카테고리가 아직 없어요', style: TextStyle(color: context.glass.textTertiary))))
                    else
                      SizedBox(
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
                                    sections: List.generate(majors.length, (i) => PieChartSectionData(color: _colors[i % _colors.length], value: majors[i].amount.toDouble(), title: '', radius: 25)),
                                  )),
                                  Column(mainAxisSize: MainAxisSize.min, children: [
                                    Text('합계', style: TextStyle(fontSize: 12, color: context.glass.textTertiary)),
                                    Text(context.formatWon(total), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  ]),
                                ],
                              ),
                            ),
                            Expanded(
                              // Keyed by month so switching months starts the legend back at the top.
                              child: _CategoryLegend(
                                key: ValueKey(month),
                                categories: majors,
                                colors: [for (var i = 0; i < majors.length; i++) _colors[i % _colors.length]],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < majors.length; i++) ...[
                _CategoryRow(
                  month: month,
                  category: majors[i],
                  color: majorColors[majors[i].name] ?? _colors[i % _colors.length],
                  previousAmount: data.previousMajorCategories.where((c) => c.name == majors[i].name).map((c) => c.amount).firstOrNull,
                  comparisonDayLabel: data.range.isPartial ? '1일-${data.range.comparisonDay}일' : null,
                  subCategories: data.currentCategories.where((c) => data.majorNameByCategoryName[c.name] == majors[i].name).toList()
                    ..sort((a, b) => b.amount.compareTo(a.amount)),
                  expanded: expandedMajor == majors[i].name,
                  onTap: () => setState(() => _expandedCategory = expandedMajor == majors[i].name ? null : majors[i].name),
                ),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    ));
  }
}

/// Donut legend: color dot, 대분류 name, percentage per row. The list hugs its
/// content (so a short legend stays vertically centered next to the donut) up
/// to the donut's height, then scrolls on its own - the page itself doesn't.
class _CategoryLegend extends StatefulWidget {
  final List<CategoryAmount> categories;
  final List<Color> colors;

  const _CategoryLegend({super.key, required this.categories, required this.colors});

  @override
  State<_CategoryLegend> createState() => _CategoryLegendState();
}

class _CategoryLegendState extends State<_CategoryLegend> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _controller,
      thumbVisibility: true,
      child: ListView.builder(
        controller: _controller,
        shrinkWrap: true,
        // Room on the right so the scrollbar thumb doesn't sit on the percentage.
        padding: const EdgeInsets.only(right: 10),
        itemCount: widget.categories.length,
        itemBuilder: (context, i) {
          final color = widget.colors[i];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
              const SizedBox(width: 8),
              Expanded(child: Text(widget.categories[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.glass.textPrimary, fontSize: 13))),
              const SizedBox(width: 8),
              Text('${widget.categories[i].percentage.round()}%', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
            ]),
          );
        },
      ),
    );
  }
}

class _CategoryRow extends ConsumerWidget {
  final DateTime month;
  final CategoryAmount category;
  final Color color;
  final int? previousAmount;
  final String? comparisonDayLabel;

  /// The per-leaf rows (as `/api/reports/categories` returns them) that make up
  /// this 대분류, largest first.
  final List<CategoryAmount> subCategories;
  final bool expanded;
  final VoidCallback onTap;

  const _CategoryRow({
    required this.month,
    required this.category,
    required this.color,
    required this.previousAmount,
    required this.comparisonDayLabel,
    required this.subCategories,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: glassDecoration(context, radius: AppRadii.md),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadii.md),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: CategoryShareBar(
                      categoryName: category.name,
                      categoryColor: color,
                      spentAmount: category.amount,
                      sharePercent: category.percentage,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more, color: context.glass.textTertiary),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: !expanded
                ? const SizedBox(width: double.infinity, height: 0)
                : Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  _kv(context, Icons.payments_outlined, '금액', context.formatWon(category.amount)),
                  _kv(context, Icons.percent_rounded, '전체 지출 중', '${category.percentage.round()}%'),
                  if (previousAmount != null)
                    _kv(
                      context,
                      Icons.cached_rounded,
                      comparisonDayLabel == null ? '지난달' : '지난달 ($comparisonDayLabel)',
                      '${context.formatWon(previousAmount!)} (${_pctLabel(category.amount, previousAmount!)})',
                    ),
                  _kv(context, Icons.swap_vert_rounded, '거래 건수', '${category.transactionCount}건'),
                  // A lone leaf that just repeats the 대분류 name adds nothing - unless
                  // it is really "소분류 미지정" (saved on a 대분류 that has 소분류).
                  if (subCategories.length > 1 ||
                      (subCategories.isNotEmpty && (subCategories.first.isUnspecifiedSubcategory || subCategories.first.name != category.name))) ...[
                    const SizedBox(height: 8),
                    Text('소분류', style: TextStyle(fontSize: 12, color: context.glass.textTertiary)),
                    for (final sub in subCategories) _subRow(context, ref, sub),
                  ],
                  // `GET /api/transactions` matches `categoryId` exactly (a 대분류
                  // id does not include its 소분류's transactions), so a 대분류
                  // with several 소분류 would list far fewer rows than its card
                  // shows. Those open per 소분류 from the rows above instead.
                  if (subCategories.length <= 1) ...[
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => _openTransactions(context, ref, subCategories.firstOrNull?.name ?? category.name, categoryId: subCategories.firstOrNull?.categoryId),
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44), side: BorderSide(color: context.glass.chipBorder)),
                      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('거래 내역 보기'), SizedBox(width: 4), Icon(Icons.chevron_right, size: 18)]),
                    ),
                  ],
                ],
              ),
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

  Widget _subRow(BuildContext context, WidgetRef ref, CategoryAmount sub) => InkWell(
        onTap: () => _openTransactions(context, ref, sub.name, categoryId: sub.categoryId),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            const SizedBox(width: 23),
            Expanded(
              child: Text(
                sub.isUnspecifiedSubcategory ? unspecifiedSubcategoryLabel : sub.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: sub.isUnspecifiedSubcategory ? context.glass.textTertiary : context.glass.textPrimary),
              ),
            ),
            const SizedBox(width: 8),
            Text(context.formatWon(sub.amount), style: TextStyle(fontSize: 13, color: context.glass.textPrimary)),
            Icon(Icons.chevron_right, size: 16, color: context.glass.textTertiary),
          ]),
        ),
      );

  /// Opens the month's transactions filtered to one expense category: the row's
  /// own [categoryId] when the report provided it, else the category called
  /// [name] (older backends have no id). When the name is shared, the one under
  /// this card's 대분류 wins.
  Future<void> _openTransactions(BuildContext context, WidgetRef ref, String name, {String? categoryId}) async {
    if (categoryId != null) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TransactionListScreen(initialMonth: month, initialCategoryId: categoryId),
      ));
      return;
    }
    final categories = (await ref.read(categoriesProvider.future)).whereType<Map>().toList();
    if (!context.mounted) return;
    final named = categories.where((c) => c['name'] == name && c['type'] == 'EXPENSE').toList();
    final byId = {for (final c in categories) (c['id'] ?? '').toString(): c};
    bool underThisMajor(Map c) => (byId[(c['parentCategoryId'] ?? '').toString()] ?? c)['name'] == category.name;
    final match = named.length <= 1 ? named.firstOrNull : named.where(underThisMajor).firstOrNull ?? named.first;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TransactionListScreen(initialMonth: month, initialCategoryId: match?['id']?.toString()),
    ));
  }

  Widget _kv(BuildContext context, IconData icon, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(icon, size: 15, color: context.glass.textTertiary),
          const SizedBox(width: 8),
          Expanded(child: Text(k, style: TextStyle(fontSize: 13, color: context.glass.textTertiary))),
          Text(v, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: context.glass.textPrimary)),
        ]),
      );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
