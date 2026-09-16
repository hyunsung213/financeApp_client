import 'package:flutter_test/flutter_test.dart';
import 'package:finance_client/features/calendar/utils/policy_alert_utils.dart';

void main() {
  group('policyAlertTypeForDaysRemaining', () {
    test('exactly 5/3/0 days remaining map to D-5/D-3/D-Day', () {
      expect(policyAlertTypeForDaysRemaining(5), PolicyAlertType.d5);
      expect(policyAlertTypeForDaysRemaining(3), PolicyAlertType.d3);
      expect(policyAlertTypeForDaysRemaining(0), PolicyAlertType.dDay);
    });

    test('D-4/D-2/D-1 and any other day count produce no badge', () {
      for (final days in [4, 2, 1, 6, 10, -1]) {
        expect(
          policyAlertTypeForDaysRemaining(days),
          isNull,
          reason: 'days=$days',
        );
      }
    });
  });

  test('policyAlertUrgency ranks D-Day as most urgent, then D-3, then D-5', () {
    expect(
      policyAlertUrgency(PolicyAlertType.dDay),
      lessThan(policyAlertUrgency(PolicyAlertType.d3)),
    );
    expect(
      policyAlertUrgency(PolicyAlertType.d3),
      lessThan(policyAlertUrgency(PolicyAlertType.d5)),
    );
  });

  test('policyAlertLabel matches the Figma badge text', () {
    expect(policyAlertLabel(PolicyAlertType.d5), '정책 D-5');
    expect(policyAlertLabel(PolicyAlertType.d3), '정책 D-3');
    expect(policyAlertLabel(PolicyAlertType.dDay), '정책 D-Day');
  });
}
