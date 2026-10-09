import 'package:dio/dio.dart';
import 'package:finance_client/data/api/api_client.dart';
import 'package:finance_client/data/api/api_error.dart';
import 'package:finance_client/data/api/category_api.dart';
import 'package:finance_client/features/auth/providers/auth_provider.dart';
import 'package:finance_client/features/report/screens/report_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../support/fake_backend.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ko_KR', null));

  late FakeBackend backend;
  late Never Function(RequestOptions)? outage;

  Future<ResponseBody> respond(RequestOptions r) async {
    final failure = outage;
    if (failure != null) failure(r);
    switch (r.path) {
      case '/api/reports/summary':
        return ok({'expense': 12000, 'income': 0});
      case '/api/reports/daily':
        return ok({'daily': <Object>[]});
      default:
        return ok(<Object>[]);
    }
  }

  Future<void> pumpReport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    backend = FakeBackend(respond);

    await tester.pumpWidget(
      ProviderScope(
        retry: apiRetry,
        overrides: [
          authProvider.overrideWith(SignedInAuth.new),
          categoriesProvider.overrideWith((ref) => const <Object>[]),
          apiClientProvider.overrideWith((ref) => ApiClient.create(adapter: backend)),
        ],
        child: const MaterialApp(home: ReportScreen()),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  testWidgets('an outage shows a readable error with 다시 시도, never the raw exception', (tester) async {
    outage = connectionRefused;
    await pumpReport(tester);

    expect(find.text('리포트를 불러오지 못했어요'), findsOneWidget);
    expect(find.text('서버에 연결할 수 없습니다. 잠시 후 다시 시도해주세요.'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
    for (final fragment in rawErrorFragments) {
      expect(find.textContaining(fragment), findsNothing, reason: fragment);
    }
  });

  testWidgets('다시 시도 re-requests the report and shows it once the backend is back', (tester) async {
    outage = connectionRefused;
    await pumpReport(tester);
    final before = backend.count('/api/reports/summary');

    outage = null;
    await tester.tap(find.text('다시 시도'));
    await settle(tester);

    expect(backend.count('/api/reports/summary'), greaterThan(before));
    expect(find.text('리포트를 불러오지 못했어요'), findsNothing);
    expect(find.text('이번 달 지출'), findsOneWidget);
  });

  testWidgets('pull-to-refresh on the error re-requests the report too', (tester) async {
    outage = connectionRefused;
    await pumpReport(tester);
    final before = backend.count('/api/reports/summary');

    outage = null;
    await tester.fling(find.text('리포트를 불러오지 못했어요'), const Offset(0, 400), 1000);
    await settle(tester);

    expect(backend.count('/api/reports/summary'), greaterThan(before));
    expect(find.text('이번 달 지출'), findsOneWidget);
  });

  testWidgets('a timeout says so in plain words', (tester) async {
    outage = receiveTimeout;
    await pumpReport(tester);

    expect(find.text('요청 시간이 초과되었습니다. 다시 시도해주세요.'), findsOneWidget);
    expect(find.textContaining('DioException'), findsNothing);
  });
}
