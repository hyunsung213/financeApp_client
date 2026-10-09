import 'package:dio/dio.dart';
import 'package:finance_client/data/api/api_client.dart';
import 'package:finance_client/data/api/api_error.dart';
import 'package:finance_client/data/api/category_api.dart';
import 'package:finance_client/features/auth/providers/auth_provider.dart';
import 'package:finance_client/features/calendar/screens/calendar_screen.dart';
import 'package:finance_client/features/calendar/screens/day_transactions_screen.dart';
import 'package:finance_client/features/calendar/widgets/day_detail_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../../support/fake_backend.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ko_KR', null));

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final todayStr = DateFormat('yyyy-MM-dd').format(today);

  late FakeBackend backend;
  var backendUp = false;
  var hasTransactions = true;

  Future<ResponseBody> respond(RequestOptions r) async {
    if (!backendUp) connectionRefused(r);
    switch (r.path) {
      case '/api/transactions':
        return ok({
          'items': [
            if (hasTransactions)
              {
                'id': 'tx-1',
                'type': 'EXPENSE',
                'merchantOrTitle': 'GateLunch',
                'amount': 12000,
                'occurredAt': todayStr,
              },
          ],
        });
      case '/api/reports/daily':
        return ok({
          'daily': [
            {'date': todayStr, 'income': 0, 'expense': 12000, 'spent': 12000},
          ],
        });
      case '/api/finance/setting':
        return ok({'salaryDay': 25, 'salaryAmount': 3000000});
      default:
        return ok(<Object>[]);
    }
  }

  Future<void> pump(WidgetTester tester, Widget child) async {
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
        child: MaterialApp(home: child),
      ),
    );
    // Through the two automatic retries of a connection failure.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  void expectNoRawError() {
    for (final fragment in rawErrorFragments) {
      expect(find.textContaining(fragment), findsNothing, reason: fragment);
    }
  }

  setUp(() {
    backendUp = false;
    hasTransactions = true;
  });

  group('day transactions screen', () {
    testWidgets('an outage is an error with 다시 시도, not "no transactions"', (tester) async {
      await pump(tester, DayTransactionsScreen(day: today));

      expect(find.text('이 날은 등록된 거래가 없어요.'), findsNothing);
      expect(find.text('거래 내역을 불러오지 못했어요'), findsOneWidget);
      expect(find.text('서버에 연결할 수 없습니다. 잠시 후 다시 시도해주세요.'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
      expectNoRawError();
    });

    testWidgets('다시 시도 re-requests the day and shows its transactions', (tester) async {
      await pump(tester, DayTransactionsScreen(day: today));
      final before = backend.count('/api/transactions');

      backendUp = true;
      await tester.tap(find.text('다시 시도'));
      await settle(tester);

      expect(backend.count('/api/transactions'), before + 1);
      expect(find.text('거래 내역을 불러오지 못했어요'), findsNothing);
      expect(find.text('GateLunch'), findsOneWidget);
    });

    testWidgets('a day that really has no transactions keeps the empty state', (tester) async {
      backendUp = true;
      hasTransactions = false;
      await pump(tester, DayTransactionsScreen(day: today));

      expect(find.text('이 날은 등록된 거래가 없어요.'), findsOneWidget);
      expect(find.text('거래 내역을 불러오지 못했어요'), findsNothing);
    });
  });

  group('day detail sheet', () {
    testWidgets('an outage is an error; 다시 시도 recovers the transactions', (tester) async {
      await pump(tester, Scaffold(body: DayDetailSheet(day: today)));

      expect(find.text('이 날은 등록된 거래가 없어요.'), findsNothing);
      expect(find.text('거래 내역을 불러오지 못했어요'), findsOneWidget);
      expectNoRawError();

      backendUp = true;
      await tester.tap(find.text('다시 시도'));
      await settle(tester);

      expect(find.text('거래 내역을 불러오지 못했어요'), findsNothing);
      expect(find.text('GateLunch'), findsOneWidget);
    });

    testWidgets('a day that really has no transactions keeps the empty state', (tester) async {
      backendUp = true;
      hasTransactions = false;
      await pump(tester, Scaffold(body: DayDetailSheet(day: today)));

      expect(find.text('이 날은 등록된 거래가 없어요.'), findsOneWidget);
      expect(find.text('거래 내역을 불러오지 못했어요'), findsNothing);
    });
  });

  group('calendar grid', () {
    testWidgets('an outage shows an error with 다시 시도 instead of an empty month', (tester) async {
      await pump(tester, const CalendarScreen());

      expect(find.text('캘린더 정보를 불러오지 못했어요'), findsOneWidget);
      expect(find.text('서버에 연결할 수 없습니다. 잠시 후 다시 시도해주세요.'), findsOneWidget);
      // No figures (real or sample) are shown for a month that didn't load.
      expect(find.textContaining('무지출'), findsNothing);
      expectNoRawError();
    });

    testWidgets('다시 시도 re-requests the cycle and shows its figures', (tester) async {
      await pump(tester, const CalendarScreen());
      final before = backend.count('/api/reports/daily');

      backendUp = true;
      await tester.tap(find.text('다시 시도'));
      await settle(tester);

      expect(backend.count('/api/reports/daily'), before + 1);
      expect(find.text('캘린더 정보를 불러오지 못했어요'), findsNothing);
      expect(find.text('12,000 원'), findsOneWidget);
    });
  });
}
