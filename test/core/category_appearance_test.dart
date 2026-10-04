import 'package:finance_client/core/category/category_appearance.dart';
import 'package:finance_client/data/api/category_api.dart';
import 'package:finance_client/features/home/widgets/transaction_grid_card.dart';
import 'package:finance_client/features/report/utils/report_insight_utils.dart';
import 'package:finance_client/features/transaction/widgets/category_picker_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// `GET /api/categories` rows after the user renamed 택시 to 카카오택시 and
/// 식비 to 먹는 돈 (ids, parents and canonical names unchanged).
final _categories = [
  {
    'id': 'core.expense.food',
    'name': '먹는 돈',
    'canonicalName': '식비',
    'type': 'EXPENSE',
    'parentCategoryId': null,
    'sortOrder': 310,
    'isSystem': true,
    'isCustomized': true,
  },
  {
    'id': 'core.expense.transport',
    'name': '교통',
    'canonicalName': '교통',
    'type': 'EXPENSE',
    'parentCategoryId': null,
    'sortOrder': 320,
    'isSystem': true,
  },
  {
    'id': 'core.expense.transport.taxi',
    'name': '카카오택시',
    'canonicalName': '택시',
    'type': 'EXPENSE',
    'parentCategoryId': 'core.expense.transport',
    'sortOrder': 322,
    'icon': null,
    'color': '#5D9CEC',
    'isSystem': true,
    'isCustomized': true,
  },
  {
    'id': 'core.expense.transport.public',
    'name': '이동',
    'canonicalName': '대중교통',
    'type': 'EXPENSE',
    'parentCategoryId': 'core.expense.transport',
    'sortOrder': 321,
    'icon': 'pets_outlined',
    'isSystem': true,
    'isCustomized': true,
  },
];

/// A transaction as `/api/transactions` returns it: the embedded category is
/// the canonical row.
final _taxiRide = {
  'id': 'tx-1',
  'categoryId': 'core.expense.transport.taxi',
  'category': {'id': 'core.expense.transport.taxi', 'name': '택시'},
  'merchantOrTitle': '카카오T',
  'amount': 12000,
  'type': 'EXPENSE',
  'occurredAt': '2026-10-04',
};

void main() {
  group('default icon', () {
    test('comes from the canonical name, not the display name', () {
      final taxi = CategoryAppearance.fromJson(_categories[2]);
      expect(taxi.name, '카카오택시');
      expect(taxi.iconKey, 'local_taxi_outlined');
      expect(taxi.icon, Icons.local_taxi_outlined);
      expect(taxi.color, const Color(0xFF5D9CEC));
    });

    test('a picked icon wins over the default', () {
      final renamed = CategoryAppearance.fromJson(_categories[3]);
      expect(renamed.icon, Icons.pets_outlined);
      expect(renamed.hasCustomIcon, isTrue);
    });

    test('an unknown stored icon key falls back to the default', () {
      final row = {..._categories[2], 'icon': 'not_an_icon'};
      expect(CategoryAppearance.fromJson(row).icon, Icons.local_taxi_outlined);
    });

    test('rows without canonicalName (older backend) use their name', () {
      final row = {'id': 'core.expense.transport.taxi', 'name': '택시'};
      expect(CategoryAppearance.fromJson(row).icon, Icons.local_taxi_outlined);
    });
  });

  group('CategoryDirectory', () {
    final directory = CategoryDirectory(_categories);

    test('names a transaction by its categoryId', () {
      expect(directory.nameForTransaction(_taxiRide), '카카오택시');
      expect(
        directory.iconForTransaction(_taxiRide),
        Icons.local_taxi_outlined,
      );
    });

    test('falls back to the embedded name for an unknown category', () {
      final tx = {
        'categoryId': 'deleted-custom',
        'category': {'name': '야식'},
      };
      expect(directory.nameForTransaction(tx), '야식');
      expect(CategoryDirectory.empty.nameForTransaction(_taxiRide), '택시');
    });

    test('a 대분류 rename keeps the budget plan id', () {
      expect(directory.nameOf('core.expense.food', '식비'), '먹는 돈');
      expect(directory['core.expense.food']!.id, 'core.expense.food');
    });
  });

  test('color hex round-trips', () {
    expect(categoryColorHex(const Color(0xFF5D9CEC)), '#5D9CEC');
    expect(parseCategoryColor('#5d9cec'), const Color(0xFF5D9CEC));
    expect(parseCategoryColor('blue'), isNull);
  });

  test('report rows roll up by categoryId even after a rename', () {
    // The report's row name is canonical; the provider renames it by id.
    final directory = CategoryDirectory(_categories);
    final rows = [
      CategoryAmount(
        name: directory.nameOf('core.expense.transport.taxi', '택시')!,
        amount: 12000,
        transactionCount: 1,
        percentage: 0,
        categoryId: 'core.expense.transport.taxi',
      ),
      CategoryAmount(
        name: directory.nameOf('core.expense.transport.public', '대중교통')!,
        amount: 3000,
        transactionCount: 2,
        percentage: 0,
        categoryId: 'core.expense.transport.public',
      ),
    ];
    expect(rows.map((r) => r.name), ['카카오택시', '이동']);
    final majors = rollUpToMajorCategories(rows, _categories);
    expect(majors.single.name, '교통');
    expect(majors.single.amount, 15000);
  });

  testWidgets('Home transaction card shows the user’s category name', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith((ref) async => _categories),
        ],
        child: MaterialApp(
          home: Scaffold(body: TransactionGridCard(transaction: _taxiRide)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('카카오택시'), findsOneWidget);
    expect(find.text('택시'), findsNothing);
    expect(find.byIcon(Icons.local_taxi_outlined), findsOneWidget);
  });

  testWidgets('the transaction category picker shows display names', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CategoryPickerScreen(
          categories: _categories,
          parentTypeId: 'core.expense',
          initialCategoryId: 'core.expense.transport.taxi',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('카카오택시'), findsOneWidget);
    expect(find.text('이동'), findsOneWidget);
    expect(find.byIcon(Icons.local_taxi_outlined), findsOneWidget);
  });
}
