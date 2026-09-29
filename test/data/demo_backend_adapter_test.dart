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
}
