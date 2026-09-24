import 'package:flutter_test/flutter_test.dart';
import 'package:finance_client/features/report/utils/report_date_utils.dart';
import 'package:finance_client/features/report/utils/report_insight_utils.dart';

CategoryAmount leaf(String name, int amount, {int count = 1}) =>
    CategoryAmount(name: name, amount: amount, transactionCount: count, percentage: 0);

Map<String, dynamic> cat(String id, String name, {String? parent, String type = 'EXPENSE', int sort = 0}) => {
      'id': id,
      'name': name,
      'parentCategoryId': parent,
      'type': type,
      'sortOrder': sort,
    };

Map<String, dynamic> day(String date, int spent) => {'date': date, 'spent': spent};

void main() {
  final categories = [
    cat('food', '식비', sort: 310),
    cat('meal', '식사', parent: 'food'),
    cat('delivery', '배달', parent: 'food'),
    cat('transport', '교통', sort: 320),
    cat('bus', '대중교통', parent: 'transport'),
    cat('saving', '저축', type: 'SAVING', sort: 10),
    cat('deposit', '예금', parent: 'saving', type: 'SAVING'),
  ];

  group('rollUpToMajorCategories', () {
    test('sums leaf categories into their 대분류', () {
      final result = rollUpToMajorCategories([leaf('식사', 8500), leaf('배달', 12000), leaf('대중교통', 3100)], categories);
      expect(result.map((c) => c.name), ['식비', '교통']);
      expect(result.first.amount, 20500);
      expect(result.first.transactionCount, 2);
      expect(result.first.percentage, closeTo(20500 / 23600 * 100, 0.001));
    });

    test('a transaction filed directly on the major counts toward it too', () {
      final result = rollUpToMajorCategories([leaf('식비', 20000), leaf('식사', 8500)], categories);
      expect(result.single.name, '식비');
      expect(result.single.amount, 28500);
    });

    test('a leaf whose name is unknown is kept under its own name', () {
      final result = rollUpToMajorCategories([leaf('처음 보는 카테고리', 5000)], categories);
      expect(result.single.name, '처음 보는 카테고리');
    });

    test('a name that exists under two different majors is not guessed into either', () {
      final ambiguous = [
        ...categories,
        cat('gift-a', '기타', parent: 'food'),
        cat('gift-b', '기타', parent: 'transport'),
      ];
      final result = rollUpToMajorCategories([leaf('기타', 1000)], ambiguous);
      expect(result.single.name, '기타');
    });

    test('non-expense categories never take part', () {
      // "예금" is a SAVING leaf: as far as the expense roll-up knows, it is unknown.
      final result = rollUpToMajorCategories([leaf('예금', 1000)], categories);
      expect(result.single.name, '예금');
    });

    test('equal amounts are ordered by the major\'s sortOrder, not by input order', () {
      final a = rollUpToMajorCategories([leaf('대중교통', 5000), leaf('식사', 5000)], categories);
      final b = rollUpToMajorCategories([leaf('식사', 5000), leaf('대중교통', 5000)], categories);
      expect(a.map((c) => c.name), ['식비', '교통']);
      expect(b.map((c) => c.name), ['식비', '교통']);
    });

    test('the roll-up keeps the leaf total and percentages sum to 100 (chart and legend share one source)', () {
      final leaves = [leaf('식사', 8500), leaf('배달', 12000), leaf('대중교통', 3100), leaf('처음 보는 카테고리', 500)];
      final result = rollUpToMajorCategories(leaves, categories);
      expect(result.fold<int>(0, (sum, c) => sum + c.amount), leaves.fold<int>(0, (sum, c) => sum + c.amount));
      expect(result.fold<double>(0, (sum, c) => sum + c.percentage), closeTo(100, 0.001));
    });

    test('a 대분류 never appears as a leaf name in the roll-up', () {
      final leaves = [leaf('식사', 1), leaf('배달', 2), leaf('대중교통', 3)];
      final names = rollUpToMajorCategories(leaves, categories).map((c) => c.name).toSet();
      expect(names, {'식비', '교통'});
    });
  });

  group('majorNamesByLeaf', () {
    test('maps each leaf to the 대분류 it rolls up under', () {
      final map = majorNamesByLeaf([leaf('식사', 1), leaf('배달', 1), leaf('대중교통', 1), leaf('식비', 1)], categories);
      expect(map, {'식사': '식비', '배달': '식비', '대중교통': '교통', '식비': '식비'});
    });

    test('unknown and ambiguous names map to themselves, matching the roll-up', () {
      final ambiguous = [
        ...categories,
        cat('gift-a', '기타', parent: 'food'),
        cat('gift-b', '기타', parent: 'transport'),
      ];
      final map = majorNamesByLeaf([leaf('기타', 1), leaf('처음 보는 카테고리', 1)], ambiguous);
      expect(map, {'기타': '기타', '처음 보는 카테고리': '처음 보는 카테고리'});
    });
  });

  group('markUnspecifiedSubcategories', () {
    CategoryAmount row(String name, int amount, {String? id, String? parent, int count = 1}) =>
        CategoryAmount(name: name, amount: amount, transactionCount: count, percentage: 0, categoryId: id, parentCategoryId: parent);

    test('flags a row saved directly on a 대분류 that has 소분류, by categoryId', () {
      final marked = markUnspecifiedSubcategories([row('식비', 20000, id: 'food'), row('식사', 64000, id: 'meal', parent: 'food')], categories);
      expect(marked.map((r) => r.isUnspecifiedSubcategory), [true, false]);
    });

    test('falls back to the tree by name when the backend sends no categoryId', () {
      final marked = markUnspecifiedSubcategories([leaf('식비', 20000), leaf('식사', 64000)], categories);
      expect(marked.map((r) => r.isUnspecifiedSubcategory), [true, false]);
    });

    test('does not change amounts, counts, percentages, order or ids', () {
      final rows = [
        CategoryAmount(name: '식사', amount: 64000, transactionCount: 5, percentage: 65, categoryId: 'meal', parentCategoryId: 'food'),
        CategoryAmount(name: '식비', amount: 20000, transactionCount: 1, percentage: 20, categoryId: 'food'),
        CategoryAmount(name: '배달', amount: 14500, transactionCount: 2, percentage: 15, categoryId: 'delivery', parentCategoryId: 'food'),
      ];
      final marked = markUnspecifiedSubcategories(rows, categories);
      expect(marked.map((r) => r.name), ['식사', '식비', '배달']);
      expect(marked.map((r) => r.amount), [64000, 20000, 14500]);
      expect(marked.map((r) => r.transactionCount), [5, 1, 2]);
      expect(marked.map((r) => r.percentage), [65, 20, 15]);
      expect(marked.map((r) => r.categoryId), ['meal', 'food', 'delivery']);
      expect(marked.fold<int>(0, (sum, r) => sum + r.amount), 98500);
    });

    test('a childless root is a leaf, never "소분류 미지정"', () {
      final withCustom = [...categories, cat('custom', '내 카테고리')];
      expect(markUnspecifiedSubcategories([row('내 카테고리', 5000, id: 'custom')], withCustom).single.isUnspecifiedSubcategory, isFalse);
      expect(markUnspecifiedSubcategories([leaf('내 카테고리', 5000)], withCustom).single.isUnspecifiedSubcategory, isFalse);
    });

    test('an unknown row, or a name shared by several categories, is not guessed', () {
      final ambiguous = [...categories, cat('other-food', '식비', parent: 'transport')];
      expect(markUnspecifiedSubcategories([leaf('처음 보는 카테고리', 1)], categories).single.isUnspecifiedSubcategory, isFalse);
      expect(markUnspecifiedSubcategories([leaf('식비', 1)], ambiguous).single.isUnspecifiedSubcategory, isFalse);
      // ...but with an id the shared name is no longer ambiguous.
      expect(markUnspecifiedSubcategories([row('식비', 1, id: 'food')], ambiguous).single.isUnspecifiedSubcategory, isTrue);
    });

    test('non-expense categories are never flagged', () {
      expect(markUnspecifiedSubcategories([row('저축', 1, id: 'saving')], categories).single.isUnspecifiedSubcategory, isFalse);
    });

    test('the roll-up still counts the flagged row toward its 대분류', () {
      final marked = markUnspecifiedSubcategories([leaf('식비', 20000, count: 1), leaf('식사', 64000, count: 5)], categories);
      final majors = rollUpToMajorCategories(marked, categories);
      expect(majors.single.name, '식비');
      expect(majors.single.amount, 84000);
      expect(majors.single.transactionCount, 6);
    });
  });

  group('report helpers', () {
    test('topCategory ignores 0원 rows and empty input', () {
      expect(topCategory(const []), isNull);
      expect(topCategory([leaf('식비', 0)]), isNull);
      expect(topCategory([leaf('식비', 10), leaf('교통', 5)])?.name, '식비');
    });
  });

  group('peakSpendingDay', () {
    test('picks the day with the highest total', () {
      final peak = peakSpendingDay([day('2026-09-13', 3100), day('2026-09-14', 32300), day('2026-09-15', 20000)]);
      expect(peak?.date, DateTime(2026, 9, 14));
      expect(peak?.amount, 32300);
    });

    test('on a tie the later date wins, whatever the row order', () {
      final rows = [day('2026-09-10', 5000), day('2026-09-12', 5000), day('2026-09-11', 1000)];
      expect(peakSpendingDay(rows)?.date, DateTime(2026, 9, 12));
      expect(peakSpendingDay(rows.reversed.toList())?.date, DateTime(2026, 9, 12));
    });

    test('a month with no spending has no peak day', () {
      expect(peakSpendingDay([day('2026-09-01', 0), day('2026-09-02', 0)]), isNull);
      expect(peakSpendingDay(const []), isNull);
    });
  });

  group('주차 (weeks)', () {
    test('boundaries: 1-7, 8-14, 15-21, 22-end (29-31 fold into week 4)', () {
      expect([1, 7, 8, 14, 15, 21, 22, 28, 29, 31].map(weekIndexForDay), [0, 0, 1, 1, 2, 2, 3, 3, 3, 3]);
    });

    test('weekDayRange ends on the month\'s real last day', () {
      expect(weekDayRange(0, DateTime(2026, 9, 1)), (1, 7));
      expect(weekDayRange(3, DateTime(2026, 9, 1)), (22, 30));
      expect(weekDayRange(3, DateTime(2026, 2, 1)), (22, 28));
      expect(weekDayRange(3, DateTime(2026, 10, 1)), (22, 31));
    });

    test('weeklyTotalsFromDaily uses the same boundaries', () {
      final totals = weeklyTotalsFromDaily([day('2026-09-07', 100), day('2026-09-08', 200), day('2026-09-30', 400)]);
      expect(totals, [100, 200, 0, 400]);
    });

    test('topWeekIndexOf: highest wins, later week wins ties, all-zero is null', () {
      expect(topWeekIndexOf([100, 300, 200, 50]), 1);
      expect(topWeekIndexOf([300, 100, 300, 0]), 2);
      expect(topWeekIndexOf([0, 0, 0, 0]), isNull);
    });
  });

  group('buildMainHighlights', () {
    test('no spending -> no rows (no fake 0원 top items)', () {
      expect(buildMainHighlights(month: DateTime(2026, 9, 1), topMajorCategory: null, peakDay: null, weeklyTotals: [0, 0, 0, 0]), isEmpty);
    });

    test('builds the three rows from one month of data', () {
      final rows = buildMainHighlights(
        month: DateTime(2026, 9, 1),
        topMajorCategory: leaf('식비', 68300),
        peakDay: DailyPeak(date: DateTime(2026, 9, 14), amount: 32300),
        weeklyTotals: [42300, 84500, 63200, 51000],
      );
      expect(rows.map((r) => r.kind), [ReportHighlightKind.topCategory, ReportHighlightKind.topDay, ReportHighlightKind.topWeek]);
      expect(rows[0].value, '식비 · 68,300원');
      expect(rows[1].value, '9월 14일 · 32,300원');
      expect(rows[1].date, DateTime(2026, 9, 14));
      expect(rows[2].value, '2주차 · 84,500원');
    });
  });
}
