import 'package:dio/dio.dart';
import 'package:finance_client/data/demo/demo_backend_adapter.dart';
import 'package:finance_client/data/demo/demo_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Dio dio;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DemoStore.instance.reset();
    dio = Dio(BaseOptions(baseUrl: 'http://unused.invalid'))
      ..httpClientAdapter = DemoBackendAdapter();
  });

  Future<Map<String, dynamic>> home() async =>
      (await dio.get('/api/home')).data['data'] as Map<String, dynamic>;

  test('sample account is fully set up (onboarding is skipped)', () async {
    final setting = (await dio.get('/api/finance/setting')).data['data'];
    expect(setting['salaryAmount'], '2500000');
    final plan = (await dio.get('/api/finance/budget-plan')).data['data'];
    expect(plan['isConfigured'], isTrue);
    final allocations = plan['allocations'] as List;
    expect(allocations, hasLength(12));
    expect(
      allocations.fold<num>(0, (s, a) => s + (a['percentage'] as num)),
      100,
    );
  });

  test('saving a budget plan re-budgets Home', () async {
    final before = await home();
    final plan = (await dio.get('/api/finance/budget-plan')).data['data'];
    final allocations = [
      for (final a in plan['allocations'] as List)
        {
          'categoryId': a['categoryId'],
          'percentage': switch (a['categoryId']) {
            'core.saving' => 10,
            'core.expense.food' => 25,
            _ => a['percentage'],
          },
        },
    ];
    await dio.put(
      '/api/finance/budget-plan',
      data: {'allocations': allocations},
    );

    final after = await home();
    expect(
      after['budget']['usableBudgetAmount'] -
          before['budget']['usableBudgetAmount'],
      250000,
    );
    expect(
      after['budget']['remainingUsableAmount'] -
          before['budget']['remainingUsableAmount'],
      250000,
    );
  });

  test('a plan that does not total 100% is rejected', () async {
    final plan = (await dio.get('/api/finance/budget-plan')).data['data'];
    final allocations = [
      for (final a in plan['allocations'] as List)
        {
          'categoryId': a['categoryId'],
          'percentage': a['categoryId'] == 'core.saving' ? 10 : a['percentage'],
        },
    ];
    expect(
      () => dio.put(
        '/api/finance/budget-plan',
        data: {'allocations': allocations},
      ),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'status',
          400,
        ),
      ),
    );
  });

  test('a manual expense shows up in Home, the list and the report', () async {
    final today = DemoStore.dateKey(DateTime.now());
    final before = await home();
    final beforeSummary = (await dio.get(
      '/api/reports/summary',
      queryParameters: {'startDate': today, 'endDate': today},
    )).data['data'];

    await dio.post(
      '/api/transactions',
      data: {
        'categoryId': 'core.expense.food.meal',
        'type': 'EXPENSE',
        'amount': 12000,
        'occurredAt': today,
        'merchantOrTitle': '식사',
        'source': 'MANUAL',
        'status': 'CONFIRMED',
      },
    );

    final after = await home();
    expect(
      after['today']['spentAmount'] - before['today']['spentAmount'],
      12000,
    );
    expect(
      before['budget']['remainingUsableAmount'] -
          after['budget']['remainingUsableAmount'],
      12000,
    );

    final list = (await dio.get(
      '/api/transactions',
      queryParameters: {'startDate': today, 'endDate': today},
    )).data['data'];
    expect(
      (list['items'] as List).any(
        (t) => t['amount'] == '12000' && t['category']['name'] == '식사',
      ),
      isTrue,
    );

    final summary = (await dio.get(
      '/api/reports/summary',
      queryParameters: {'startDate': today, 'endDate': today},
    )).data['data'];
    expect(summary['expense'] - beforeSummary['expense'], 12000);
  });

  test('a transaction on a 대분류 or with a mismatched type is rejected', () {
    for (final body in [
      {'categoryId': 'core.expense.food', 'type': 'EXPENSE'},
      {'categoryId': 'core.expense.food.meal', 'type': 'INCOME'},
    ]) {
      expect(
        () => dio.post(
          '/api/transactions',
          data: {
            ...body,
            'amount': 1000,
            'occurredAt': DemoStore.dateKey(DateTime.now()),
            'merchantOrTitle': 'x',
            'source': 'MANUAL',
            'status': 'CONFIRMED',
          },
        ),
        throwsA(isA<DioException>()),
      );
    }
  });

  test('edits survive a reload of the stored demo state', () async {
    await dio.put('/api/profile', data: {'nickname': '바뀐 이름'});
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('demo.state.v1'), contains('바뀐 이름'));
  });

  test(
    'custom categories can be added, renamed and deleted in demo state',
    () async {
      final created = (await dio.post(
        '/api/categories',
        data: {
          'name': '야식',
          'type': 'EXPENSE',
          'purposeType': 'GENERAL',
          'sortOrder': 200,
          'parentCategoryId': 'core.expense.food',
        },
      )).data['data'];
      final id = created['id'];

      await dio.patch('/api/categories/$id', data: {'name': '야식·간식'});
      var list = (await dio.get('/api/categories')).data['data'] as List;
      expect(list.firstWhere((c) => c['id'] == id)['name'], '야식·간식');

      await dio.delete('/api/categories/$id');
      list = (await dio.get('/api/categories')).data['data'] as List;
      expect(list.where((c) => c['id'] == id), isEmpty);
    },
  );

  test(
    'a system category rename is a demo-local override that keeps its id',
    () async {
      const taxi = 'core.expense.transport.taxi';
      Future<Map> taxiRow() async =>
          ((await dio.get('/api/categories')).data['data'] as List).firstWhere(
            (c) => c['id'] == taxi,
          );
      final created = (await dio.post(
        '/api/transactions',
        data: {
          'categoryId': taxi,
          'type': 'EXPENSE',
          'amount': 12000,
          'occurredAt': '2026-10-04',
          'merchantOrTitle': '카카오T',
        },
      )).data['data'];

      final updated = (await dio.patch(
        '/api/categories/$taxi',
        data: {'name': '카카오택시', 'icon': 'pets_outlined', 'color': '#5d9cec'},
      )).data['data'];
      expect(updated, containsPair('id', taxi));
      expect(updated, containsPair('name', '카카오택시'));
      expect(updated, containsPair('canonicalName', '택시'));
      expect(
        updated,
        containsPair('parentCategoryId', 'core.expense.transport'),
      );

      expect(await taxiRow(), containsPair('icon', 'pets_outlined'));
      expect(await taxiRow(), containsPair('color', '#5D9CEC'));
      expect(await taxiRow(), containsPair('isCustomized', true));

      // The transaction keeps the same canonical category.
      final tx = (await dio.get(
        '/api/transactions/${created['id']}',
      )).data['data'];
      expect(tx['categoryId'], taxi);
      expect(tx['category']['name'], '택시');

      // Only demo storage holds it.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('demo.state.v1'), contains('카카오택시'));

      await dio.delete('/api/categories/$taxi/preference');
      expect(await taxiRow(), containsPair('name', '택시'));
      expect(await taxiRow(), containsPair('icon', null));
      expect(await taxiRow(), containsPair('isCustomized', false));
    },
  );

  test('a 대분류 rename leaves the budget plan on the same id', () async {
    await dio.patch(
      '/api/categories/core.expense.food',
      data: {'name': '먹는 돈'},
    );
    final plan = (await dio.get('/api/finance/budget-plan')).data['data'];
    final ids = [for (final a in plan['allocations'] as List) a['categoryId']];
    expect(ids, contains('core.expense.food'));
    final list = (await dio.get('/api/categories')).data['data'] as List;
    expect(
      list.firstWhere((c) => c['id'] == 'core.expense.food')['name'],
      '먹는 돈',
    );
  });

  test('a system category cannot be deleted or re-parented', () async {
    for (final request in [
      () => dio.delete('/api/categories/core.expense.transport.taxi'),
      () => dio.patch(
        '/api/categories/core.expense.transport.taxi',
        data: {'parentCategoryId': 'core.expense.food'},
      ),
    ]) {
      await expectLater(
        request(),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            403,
          ),
        ),
      );
    }
    final list = (await dio.get('/api/categories')).data['data'] as List;
    final taxi = list.firstWhere(
      (c) => c['id'] == 'core.expense.transport.taxi',
    );
    expect(taxi['parentCategoryId'], 'core.expense.transport');
  });

  test('a custom category keeps its icon and color', () async {
    final created = (await dio.post(
      '/api/categories',
      data: {
        'name': '반려동물',
        'type': 'EXPENSE',
        'purposeType': 'GENERAL',
        'sortOrder': 200,
        'parentCategoryId': 'core.expense.living',
        'icon': 'pets_outlined',
        'color': '#00AE76',
      },
    )).data['data'];
    expect(created['icon'], 'pets_outlined');
    await dio.patch(
      '/api/categories/${created['id']}',
      data: {'color': '#ED5564'},
    );
    final list = (await dio.get('/api/categories')).data['data'] as List;
    final row = list.firstWhere((c) => c['id'] == created['id']);
    expect(row['icon'], 'pets_outlined');
    expect(row['color'], '#ED5564');
    expect(row['name'], '반려동물');
  });
}
