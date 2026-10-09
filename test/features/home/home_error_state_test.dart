import 'package:dio/dio.dart';
import 'package:finance_client/data/api/api_client.dart';
import 'package:finance_client/data/api/api_error.dart';
import 'package:finance_client/data/api/category_api.dart';
import 'package:finance_client/features/auth/providers/auth_provider.dart';
import 'package:finance_client/features/home/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../support/fake_backend.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ko_KR', null));

  late FakeBackend backend;
  var backendUp = false;

  Future<ResponseBody> respond(RequestOptions r) async {
    if (!backendUp) connectionRefused(r);
    if (r.path == '/api/home') return ok({'today': {'remainingToday': 12849}, 'daysUntilSalary': 14});
    return ok({'items': <Object>[]});
  }

  Future<void> pumpHome(WidgetTester tester) async {
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
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    // Through the two automatic retries of a connection failure.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
  }

  testWidgets('a failed load is an error with a retry, not the "no transactions today" empty state', (tester) async {
    backendUp = false;
    await pumpHome(tester);

    expect(find.text('오늘 등록된 거래 내역이 없습니다.'), findsNothing);
    expect(find.text('거래 내역을 불러오지 못했어요'), findsOneWidget);
    expect(find.text('홈 정보를 불러오지 못했어요'), findsOneWidget);
    expect(find.text('서버에 연결할 수 없습니다. 잠시 후 다시 시도해주세요.'), findsNWidgets(2));
    for (final fragment in rawErrorFragments) {
      expect(find.textContaining(fragment), findsNothing, reason: fragment);
    }
  });

  testWidgets('다시 시도 after the backend is back shows the real (empty) day', (tester) async {
    backendUp = false;
    await pumpHome(tester);

    backendUp = true;
    await tester.tap(find.text('다시 시도').first);
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }

    expect(find.text('거래 내역을 불러오지 못했어요'), findsNothing);
    expect(find.text('홈 정보를 불러오지 못했어요'), findsNothing);
    expect(find.text('오늘 등록된 거래 내역이 없습니다.'), findsOneWidget);
    expect(find.text('D-14'), findsOneWidget);
  });
}
