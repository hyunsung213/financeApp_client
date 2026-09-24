import 'package:finance_client/data/api/category_api.dart';
import 'package:finance_client/features/report/providers/report_provider.dart';
import 'package:finance_client/features/report/screens/category_report_screen.dart';
import 'package:finance_client/features/report/utils/report_date_utils.dart';
import 'package:finance_client/features/report/utils/report_insight_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _cat(String id, String name, {String? parent}) =>
    {'id': id, 'name': name, 'parentCategoryId': parent, 'type': 'EXPENSE', 'sortOrder': 0};

class _FixedMonth extends ReportMonthNotifier {
  final DateTime month;
  _FixedMonth(this.month);

  @override
  DateTime build() => month;
}

/// The live shape that motivated "소분류 미지정": 식비 has 식사 64,000 (5건) and
/// 카페 14,500 (2건), plus one legacy 20,000 transaction saved on 식비 itself.
void main() {
  final month = DateTime(2026, 9, 1);
  final tree = [
    _cat('core.expense.food', '식비'),
    _cat('core.expense.food.meal', '식사', parent: 'core.expense.food'),
    _cat('core.expense.food.cafe', '카페', parent: 'core.expense.food'),
  ];
  final rows = [
    const CategoryAmount(name: '식사', amount: 64000, transactionCount: 5, percentage: 0, categoryId: 'core.expense.food.meal', parentCategoryId: 'core.expense.food'),
    const CategoryAmount(name: '식비', amount: 20000, transactionCount: 1, percentage: 0, categoryId: 'core.expense.food'),
    const CategoryAmount(name: '카페', amount: 14500, transactionCount: 2, percentage: 0, categoryId: 'core.expense.food.cafe', parentCategoryId: 'core.expense.food'),
  ];

  MonthlyReportData dataFor(List<CategoryAmount> currentRows) => MonthlyReportData(
        range: monthComparisonRange(month),
        currentDaily: const [],
        previousDaily: const [],
        currentTotal: 98500,
        previousTotal: 0,
        momPct: null,
        currentWeekly: const [],
        previousWeekly: const [],
        topWeekIndex: null,
        currentCategories: currentRows,
        previousCategories: const [],
        currentMajorCategories: rollUpToMajorCategories(currentRows, tree),
        previousMajorCategories: const [],
        majorNameByCategoryName: majorNamesByLeaf(currentRows, tree),
        topGrowthCategory: null,
        insights: const [],
      );

  Future<void> pumpScreen(WidgetTester tester, MonthlyReportData data) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        reportMonthProvider.overrideWith(() => _FixedMonth(month)),
        monthlyReportDataProvider(month).overrideWith((ref) async => data),
        categoriesProvider.overrideWith((ref) async => tree),
      ],
      child: MaterialApp(home: CategoryReportScreen(initialMonth: month, initialCategoryName: '식비')),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('a transaction saved on the 대분류 itself is listed as "소분류 미지정", totals unchanged', (tester) async {
    await pumpScreen(tester, dataFor(markUnspecifiedSubcategories(rows, tree)));

    // 소분류 list, largest first: 식사 64,000 / 소분류 미지정 20,000 / 카페 14,500.
    double y(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(find.text('소분류 미지정'), findsOneWidget);
    expect(find.text('식사'), findsOneWidget);
    expect(find.text('카페'), findsOneWidget);
    expect(y('식사') < y('소분류 미지정') && y('소분류 미지정') < y('카페'), isTrue);
    expect(find.text('64,000원'), findsOneWidget);
    expect(find.text('20,000원'), findsOneWidget);
    expect(find.text('14,500원'), findsOneWidget);

    // The 대분류 card still shows the untouched 98,500원 / 8건.
    expect(find.text('98,500원'), findsWidgets);
    expect(find.text('8건'), findsOneWidget);
  });

  testWidgets('without the flag the row keeps its own name (no hierarchy info, no guessing)', (tester) async {
    await pumpScreen(tester, dataFor(rows));

    expect(find.text('소분류 미지정'), findsNothing);
    expect(find.text('20,000원'), findsOneWidget);
    expect(find.text('8건'), findsOneWidget);
  });
}
