import 'package:finance_client/core/theme/wallet_glass.dart';
import 'package:finance_client/features/mypage/screens/data_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester, {DateTime? lastBackupAt}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [lastBackupAtProvider.overrideWithValue(lastBackupAt)],
        child: const MaterialApp(home: DataManagementScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the Frame 105 layout instead of the placeholder', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('백업 및 데이터 관리'), findsOneWidget);
    expect(find.text('데이터 백업'), findsOneWidget);
    expect(find.text('현재 데이터를 안전하게 백업합니다.'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '백업하기'), findsOneWidget);
    expect(find.text('데이터 복원'), findsOneWidget);
    expect(find.text('데이터 내보내기'), findsOneWidget);
    expect(find.text('데이터 초기화'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNWidgets(3));
    expect(find.text('아직 준비중이에요'), findsNothing);
    expect(find.text('홈으로 이동'), findsNothing);
  });

  testWidgets('shows no fake timestamp when there is no backup', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('최근 백업 기록이 없어요'), findsOneWidget);
    expect(find.textContaining('2026.8.25'), findsNothing);
  });

  testWidgets('shows a stored backup timestamp in the Figma format', (
    tester,
  ) async {
    await pumpScreen(tester, lastBackupAt: DateTime(2026, 8, 25, 21, 30));

    expect(find.text('최근 백업: 2026.8.25 21:30'), findsOneWidget);
  });

  testWidgets('reset row uses the warning color', (tester) async {
    await pumpScreen(tester);

    final title = tester.widget<Text>(find.text('데이터 초기화'));
    final subtitle = tester.widget<Text>(find.text('모든 데이터가 삭제됩니다.'));
    expect(title.style?.color, WalletGlass.light.negative);
    expect(subtitle.style?.color, WalletGlass.light.negative);
  });

  testWidgets('backup button shows the backup coming-soon notice', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.text('백업하기'));
    await tester.pump();

    expect(find.text('백업 기능은 준비 중이에요.'), findsOneWidget);
  });

  for (final row in ['데이터 복원', '데이터 내보내기', '데이터 초기화']) {
    testWidgets('$row shows a compact coming-soon notice', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text(row));
      await tester.pump();

      expect(find.text('아직 준비 중이에요.'), findsOneWidget);
      // Still on the same screen: no navigation, no dialog.
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('데이터 백업'), findsOneWidget);
    });
  }
}
