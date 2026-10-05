import 'package:finance_client/core/format/money_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatMoney', () {
    test('exact keeps every won', () {
      expect(formatMoney(1234567, MoneyDisplayFormat.exact), '1,234,567원');
      expect(formatMoney(0, MoneyDisplayFormat.exact), '0원');
      expect(formatMoney(-12000, MoneyDisplayFormat.exact), '-12,000원');
      expect(
        formatMoney(12962, MoneyDisplayFormat.exact, withUnit: false),
        '12,962',
      );
    });

    test('compact shows 만 with one decimal', () {
      expect(formatMoney(1234567, MoneyDisplayFormat.compact), '123.5만원');
      expect(formatMoney(1025000, MoneyDisplayFormat.compact), '102.5만원');
      expect(formatMoney(350000, MoneyDisplayFormat.compact), '35만원');
      expect(formatMoney(123456789, MoneyDisplayFormat.compact), '12,345.7만원');
      expect(formatMoney(-1025000, MoneyDisplayFormat.compact), '-102.5만원');
      expect(
        formatMoney(12962, MoneyDisplayFormat.compact, withUnit: false),
        '1.3만',
      );
    });

    test('compact leaves amounts under 10,000 exact', () {
      expect(formatMoney(9999, MoneyDisplayFormat.compact), '9,999원');
      expect(formatMoney(0, MoneyDisplayFormat.compact), '0원');
    });
  });

  testWidgets('context.formatWon follows the nearest MoneyFormatScope', (
    tester,
  ) async {
    final format = ValueNotifier(MoneyDisplayFormat.exact);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ValueListenableBuilder(
          valueListenable: format,
          builder: (context, value, _) => MoneyFormatScope(
            format: value,
            child: Builder(
              builder: (context) => Text(context.formatWon(1025000)),
            ),
          ),
        ),
      ),
    );
    expect(find.text('1,025,000원'), findsOneWidget);

    format.value = MoneyDisplayFormat.compact;
    await tester.pump();
    expect(find.text('102.5만원'), findsOneWidget);
  });

  testWidgets('context.formatWon is exact without a scope', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(builder: (context) => Text(context.formatWon(1025000))),
      ),
    );
    expect(find.text('1,025,000원'), findsOneWidget);
  });
}
