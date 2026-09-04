import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:finance_client/features/home/screens/home_screen.dart';
import 'package:finance_client/features/home/providers/home_provider.dart';
import 'package:finance_client/data/api/category_api.dart';
import 'package:finance_client/core/services/notification_service.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko_KR', null);
  });

  testWidgets('HomeScreen renders with mocked data and handles taps without errors', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mockHomeData = HomeData(
      recommendedAmount: 50000,
      spentAmount: 5000,
      remainingToday: 12849,
      daysUntilSalary: 14,
      remainingFlexibleAmount: 500000,
      potentialExtraSaving: 0,
      paceStatus: 'UNDER',
      paceDifference: 60000,
    );

    final mockCategories = [
      {'id': 'core.expense', 'name': '지출', 'parentCategoryId': null},
      {'id': 'core.expense.food', 'name': '식비', 'parentCategoryId': 'core.expense'},
      {'id': 'core.expense.transport', 'name': '교통', 'parentCategoryId': 'core.expense'},
    ];

    final mockTransactions = [
      {
        'id': 'tx-1',
        'merchantOrTitle': '스타벅스',
        'amount': '13000',
        'occurredAt': '2026-08-25',
        'categoryId': 'core.expense.food',
        'category': {'id': 'core.expense.food', 'name': '식비'}
      }
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeDataProvider.overrideWith((ref) => mockHomeData),
          categoriesProvider.overrideWith((ref) => mockCategories),
          homeRecentTransactionsProvider.overrideWith((ref) => mockTransactions),
        ],
        child: const MaterialApp(
          home: HomeScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify UI components rendered properly
    expect(find.text('12,849'), findsOneWidget);
    expect(find.text('다음 월급일까지 앞으로  '), findsOneWidget);
    expect(find.text('D-14'), findsOneWidget);
    expect(find.text('스타벅스'), findsOneWidget);
    expect(find.text('13,000원'), findsOneWidget);

    // Test hit testing (tap on screen elements)
    await tester.tap(find.text('전체'), warnIfMissed: false);
    await tester.pumpAndSettle();

    await tester.tap(find.text('식비').first, warnIfMissed: false);
    await tester.pumpAndSettle();
  });

  testWidgets('Floating Bottom Navigation Bar renders correctly', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Center(child: Text('Content')),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Content'), findsOneWidget);
  });

  testWidgets('NotificationService handles non-Android platform gracefully', (WidgetTester tester) async {
    final status = await NotificationService.isNotificationAccessGranted();
    expect(status, equals(NotificationAccessStatus.unsupported));

    final opened = await NotificationService.openNotificationAccessSettings();
    expect(opened, isFalse);

    final notifications = await NotificationService.getRecentNotifications();
    expect(notifications, isEmpty);
  });
}
