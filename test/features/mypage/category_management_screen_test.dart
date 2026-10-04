import 'package:dio/dio.dart';
import 'package:finance_client/data/api/category_api.dart';
import 'package:finance_client/features/mypage/screens/category_management_screen.dart';
import 'package:finance_client/features/mypage/theme/my_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _category(
  String id,
  String name,
  String type, {
  String? parent,
  bool custom = false,
  int sortOrder = 0,
}) => {
  'id': id,
  'name': name,
  'type': type,
  'parentCategoryId': parent,
  'sortOrder': sortOrder,
  'isActive': true,
  'isSystem': !custom,
  'isCustom': custom,
};

/// In-memory `/api/categories`, shaped like the backend's list response: a
/// system category's rename/icon/color is kept apart from its canonical row
/// (as UserCategoryPreference is) and merged into `name`/`icon`/`color`.
class _FakeCategoryApi extends CategoryApi {
  _FakeCategoryApi() : super(Dio());

  final categories = [
    _category('core.expense.food', '식비', 'EXPENSE', sortOrder: 100),
    _category('core.expense.transport', '교통', 'EXPENSE', sortOrder: 110),
    _category(
      'core.expense.transport.taxi',
      '택시',
      'EXPENSE',
      parent: 'core.expense.transport',
      sortOrder: 112,
    ),
    _category(
      'core.expense.food.meal',
      '식사',
      'EXPENSE',
      parent: 'core.expense.food',
      sortOrder: 101,
    ),
    _category(
      'custom-pet',
      '반려동물',
      'EXPENSE',
      parent: 'core.expense.food',
      custom: true,
      sortOrder: 102,
    ),
    _category('core.income', '수입', 'INCOME', sortOrder: 40),
    _category(
      'core.income.salary',
      '급여',
      'INCOME',
      parent: 'core.income',
      sortOrder: 410,
    ),
  ];
  final created = <Map<String, dynamic>>[];
  final deleted = <String>[];
  final updates = <(String, Map<String, String?>)>[];
  final preferences = <String, Map<String, String?>>{};

  Map<String, dynamic> _serialize(Map<String, dynamic> row) {
    final preference = preferences[row['id']] ?? const {};
    return {
      ...row,
      'name': preference['displayName'] ?? row['name'],
      'canonicalName': row['name'],
      'icon': preference['icon'],
      'color': preference['color'],
      'isCustomized': preference.values.any((v) => v != null),
    };
  }

  Map<String, dynamic> row(String id) =>
      categories.firstWhere((c) => c['id'] == id);

  @override
  Future<List<dynamic>> getCategories() async =>
      categories.where((c) => c['isActive'] == true).map(_serialize).toList();

  @override
  Future<Map<String, dynamic>> updateCategory(
    String id, {
    String? name,
    String? icon,
    String? color,
  }) async {
    updates.add((id, {'name': name, 'icon': icon, 'color': color}));
    final category = row(id);
    final preference = preferences.putIfAbsent(id, () => {});
    if (name != null) {
      if (category['isCustom'] == true) {
        category['name'] = name;
      } else {
        preference['displayName'] = name == category['name'] ? null : name;
      }
    }
    if (icon != null) preference['icon'] = icon;
    if (color != null) preference['color'] = color;
    return _serialize(category);
  }

  @override
  Future<Map<String, dynamic>> resetCategoryAppearance(String id) async {
    preferences.remove(id);
    return _serialize(row(id));
  }

  @override
  Future<Map<String, dynamic>> createCategory({
    required String name,
    required String type,
    required String purposeType,
    required int sortOrder,
    String? parentCategoryId,
    String? icon,
    String? color,
  }) async {
    final category = _category(
      'custom-${created.length}',
      name,
      type,
      parent: parentCategoryId,
      custom: true,
      sortOrder: sortOrder,
    );
    created.add({...category, 'icon': icon, 'color': color});
    categories.add(category);
    preferences[category['id'] as String] = {'icon': icon, 'color': color};
    return _serialize(category);
  }

  @override
  Future<void> deleteCategory(String id) async {
    deleted.add(id);
    categories.firstWhere((c) => c['id'] == id)['isActive'] = false;
  }
}

void main() {
  Future<_FakeCategoryApi> pump(
    WidgetTester tester, {
    void Function(_FakeCategoryApi api)? setUp,
  }) async {
    final api = _FakeCategoryApi();
    setUp?.call(api);
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [categoryApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: CategoryManagementScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return api;
  }

  testWidgets('지출/수입 tabs list the real categories', (tester) async {
    await pump(tester);
    expect(find.text('카테고리 관리'), findsOneWidget);
    expect(find.text('식비'), findsOneWidget);
    expect(find.text('교통'), findsOneWidget);
    expect(find.text('급여'), findsNothing);

    await tester.tap(find.text('수입'));
    await tester.pumpAndSettle();
    expect(find.text('급여'), findsOneWidget);
    expect(find.text('식비'), findsNothing);
  });

  testWidgets('a 대분류 opens its 소분류 list', (tester) async {
    await pump(tester);
    await tester.tap(find.text('식비'));
    await tester.pumpAndSettle();
    expect(find.text('식사'), findsOneWidget);
    expect(find.text('반려동물'), findsOneWidget);
    expect(find.text('교통'), findsNothing);
  });

  testWidgets('수정 mode can delete custom categories but not system ones', (
    tester,
  ) async {
    final api = await pump(tester);
    await tester.tap(find.text('식비'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('수정'));
    await tester.pumpAndSettle();

    final systemRow = find.byKey(
      const ValueKey('category-row-core.expense.food.meal'),
    );
    expect(
      find.descendant(of: systemRow, matching: find.text('기본')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: systemRow,
        matching: find.byIcon(Icons.edit_outlined),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: systemRow,
        matching: find.byIcon(Icons.delete_outline),
      ),
      findsNothing,
    );

    final customRow = find.byKey(const ValueKey('category-row-custom-pet'));
    await tester.tap(
      find.descendant(
        of: customRow,
        matching: find.byIcon(Icons.delete_outline),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '삭제'));
    await tester.pumpAndSettle();

    expect(api.deleted, ['custom-pet']);
    expect(find.text('반려동물'), findsNothing);
  });

  Future<void> openTaxi(WidgetTester tester) async {
    await tester.tap(find.text('교통'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('category-row-core.expense.transport.taxi')),
    );
    await tester.pumpAndSettle();
  }

  Color? tileColor(WidgetTester tester, String iconKey) => tester
      .widget<Material>(
        find
            .descendant(
              of: find.byKey(ValueKey('category-icon-$iconKey')),
              matching: find.byType(Material),
            )
            .first,
      )
      .color;

  testWidgets('a system row opens 카테고리 수정 prefilled with its values', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('교통'));
    await tester.pumpAndSettle();
    final taxiRow = find.byKey(
      const ValueKey('category-row-core.expense.transport.taxi'),
    );
    expect(
      find.descendant(of: taxiRow, matching: find.byIcon(Icons.chevron_right)),
      findsOneWidget,
    );

    await tester.tap(taxiRow);
    await tester.pumpAndSettle();

    expect(find.text('카테고리 수정'), findsOneWidget);
    expect(find.textContaining('기본 카테고리예요'), findsOneWidget);
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('category-name')),
    );
    expect(field.controller!.text, '택시');
    expect(find.text('2/20'), findsOneWidget);
    // Its own (taxi) icon leads the grid, selected; the default color too.
    expect(tileColor(tester, 'local_taxi_outlined'), MyTokens.accentSoftBg);
    expect(tileColor(tester, 'pets_outlined'), Colors.white);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('category-color-default')),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('category-preview')),
        matching: find.byIcon(Icons.local_taxi_outlined),
      ),
      findsOneWidget,
    );
    // Nothing to reset yet.
    expect(find.byKey(const ValueKey('category-reset')), findsNothing);
  });

  testWidgets(
    'renaming a system category keeps its id and shows the new name',
    (tester) async {
      final api = await pump(tester);
      await openTaxi(tester);

      await tester.enterText(
        find.byKey(const ValueKey('category-name')),
        '  카카오택시 ',
      );
      await tester.tap(
        find.byKey(const ValueKey('category-icon-pets_outlined')),
      );
      await tester.tap(find.byKey(const ValueKey('category-color-#5D9CEC')));
      await tester.pump();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('category-preview')),
          matching: find.byIcon(Icons.pets_outlined),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('category-save')));
      await tester.pumpAndSettle();

      expect(api.updates.single.$1, 'core.expense.transport.taxi');
      expect(api.updates.single.$2, {
        'name': '카카오택시',
        'icon': 'pets_outlined',
        'color': '#5D9CEC',
      });
      // Canonical row untouched: same id, same name, same parent.
      expect(
        api.row('core.expense.transport.taxi'),
        containsPair('name', '택시'),
      );
      expect(
        api.row('core.expense.transport.taxi'),
        containsPair('parentCategoryId', 'core.expense.transport'),
      );
      expect(find.text('카테고리를 수정했어요.'), findsOneWidget);

      final taxiRow = find.byKey(
        const ValueKey('category-row-core.expense.transport.taxi'),
      );
      expect(
        find.descendant(of: taxiRow, matching: find.text('카카오택시')),
        findsOneWidget,
      );
      final icon = tester.widget<Icon>(
        find.descendant(
          of: taxiRow,
          matching: find.byIcon(Icons.pets_outlined),
        ),
      );
      expect(icon.color, const Color(0xFF5D9CEC));

      // Reopening prefills what was saved.
      await tester.tap(taxiRow);
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('category-name')),
      );
      expect(field.controller!.text, '카카오택시');
      expect(tileColor(tester, 'pets_outlined'), MyTokens.accentSoftBg);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('category-color-#5D9CEC')),
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('category-color-default')),
        findsNothing,
      );
    },
  );

  testWidgets('기본값으로 되돌리기 restores the canonical name and icon', (
    tester,
  ) async {
    final api = await pump(
      tester,
      setUp: (api) => api.preferences['core.expense.transport.taxi'] = {
        'displayName': '이동',
        'icon': 'pets_outlined',
        'color': '#ED5564',
      },
    );
    await tester.tap(find.text('교통'));
    await tester.pumpAndSettle();
    expect(find.text('이동'), findsOneWidget);
    await tester.tap(find.text('이동'));
    await tester.pumpAndSettle();

    // The reset link sits at the very end of the form.
    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(find.text("기본값으로 되돌리기 ('택시')"), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('category-reset')));
    await tester.pumpAndSettle();

    expect(api.preferences, isEmpty);
    final taxiRow = find.byKey(
      const ValueKey('category-row-core.expense.transport.taxi'),
    );
    expect(
      find.descendant(of: taxiRow, matching: find.text('택시')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: taxiRow,
        matching: find.byIcon(Icons.local_taxi_outlined),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a 대분류 is edited from 수정 mode and keeps its id', (tester) async {
    final api = await pump(tester);
    await tester.tap(find.text('수정'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('식비'));
    await tester.pumpAndSettle();
    expect(find.text('카테고리 수정'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('category-name')), '먹는 돈');
    await tester.tap(find.byKey(const ValueKey('category-save')));
    await tester.pumpAndSettle();

    expect(api.updates.single.$1, 'core.expense.food');
    expect(api.updates.single.$2, {
      'name': '먹는 돈',
      'icon': null,
      'color': null,
    });
    expect(find.text('먹는 돈'), findsOneWidget);
  });

  testWidgets('a custom category is renamed on its own row', (tester) async {
    final api = await pump(tester);
    await tester.tap(find.text('식비'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('반려동물'));
    await tester.pumpAndSettle();
    expect(find.text('카테고리 수정'), findsOneWidget);
    expect(find.textContaining('기본 카테고리예요'), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('category-name')), '반려견');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('category-save')));
    await tester.pumpAndSettle();

    expect(api.updates.single.$1, 'custom-pet');
    expect(api.row('custom-pet')['name'], '반려견');
    expect(find.text('반려견'), findsOneWidget);
  });

  testWidgets('an empty name cannot be saved', (tester) async {
    await pump(tester);
    await openTaxi(tester);
    await tester.enterText(find.byKey(const ValueKey('category-name')), '   ');
    await tester.pump();
    final save = tester.widget<FilledButton>(
      find.byKey(const ValueKey('category-save')),
    );
    expect(save.onPressed, isNull);
  });

  testWidgets('adding inside a 대분류 creates its 소분류 and refreshes the list', (
    tester,
  ) async {
    final api = await pump(tester);
    await tester.tap(find.text('식비'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();
    expect(find.text('카테고리 추가'), findsOneWidget);
    expect(find.text('0/20'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('category-name')), '야식');
    await tester.pump();
    expect(find.text('2/20'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('category-preview')),
        matching: find.text('야식'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.pets_outlined).first);
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('category-preview')));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('category-preview')),
        matching: find.byIcon(Icons.pets_outlined),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('category-save')));
    await tester.pumpAndSettle();

    expect(api.created.single['parentCategoryId'], 'core.expense.food');
    expect(api.created.single['type'], 'EXPENSE');
    expect(api.created.single['sortOrder'], 103);
    expect(api.created.single['icon'], 'pets_outlined');
    expect(api.created.single['color'], '#00AE76');
    expect(find.text('카테고리 관리'), findsNothing);
    expect(find.text('야식'), findsOneWidget);
  });

  testWidgets('a top-level 지출 category needs a 대분류 before it can be saved', (
    tester,
  ) async {
    final api = await pump(tester);
    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('category-name')),
      '반려동물 용품',
    );
    await tester.pump();

    FilledButton save() =>
        tester.widget(find.byKey(const ValueKey('category-save')));
    expect(save().onPressed, isNull);

    await tester.tap(find.widgetWithText(InkWell, '교통'));
    await tester.pump();
    expect(save().onPressed, isNotNull);

    await tester.tap(find.byKey(const ValueKey('category-save')));
    await tester.pumpAndSettle();
    expect(api.created.single['parentCategoryId'], 'core.expense.transport');
  });

  testWidgets('a 수입 category goes under the 수입 root', (tester) async {
    final api = await pump(tester);
    await tester.tap(find.text('수입'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();
    expect(find.text('상위 카테고리'), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('category-name')), '용돈');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('category-save')));
    await tester.pumpAndSettle();

    expect(api.created.single['parentCategoryId'], 'core.income');
    expect(api.created.single['type'], 'INCOME');
    expect(find.text('용돈'), findsOneWidget);
  });
}
