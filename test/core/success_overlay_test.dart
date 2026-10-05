import 'package:finance_client/core/widgets/success_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<BuildContext> pump(WidgetTester tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            context = c;
            return const Scaffold();
          },
        ),
      ),
    );
    return context;
  }

  /// Advances [ms] in 50ms frames, the way the animation actually runs.
  Future<void> advance(WidgetTester tester, int ms) async {
    for (var t = 0; t < ms; t += 50) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('shows the message and dismisses itself', (tester) async {
    final context = await pump(tester);
    showSuccessOverlay(context, '저장했어요!');
    await advance(tester, 200);
    expect(find.text('저장했어요!'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

    // Still up while held, gone within 1.5s once the fade-out finishes.
    await advance(tester, 800);
    expect(find.text('저장했어요!'), findsOneWidget);
    await advance(tester, 450);
    expect(find.text('저장했어요!'), findsNothing);
  });

  testWidgets('replaces the one on screen instead of stacking', (
    tester,
  ) async {
    final context = await pump(tester);
    for (var i = 0; i < 3; i++) {
      showSuccessOverlay(context, '저장했어요!');
      await advance(tester, 100);
    }
    expect(find.text('저장했어요!'), findsOneWidget);

    await advance(tester, 1500);
    expect(find.text('저장했어요!'), findsNothing);
  });
}
