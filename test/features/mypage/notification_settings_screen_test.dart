import 'package:finance_client/core/services/notification_service.dart';
import 'package:finance_client/features/mypage/screens/notification_settings_screen.dart';
import 'package:finance_client/features/notification/providers/notification_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The permission check failing inside the platform plugin.
class _FailingAccessCheck extends NotificationAccessNotifier {
  @override
  Future<NotificationAccessStatus> build() async => throw PlatformException(
    code: 'channel-error',
    message: 'Unable to establish connection on channel: '
        'finance_client/notification_listener',
    details: 'java.lang.SecurityException at NotificationListenerPlugin',
  );
}

void main() {
  testWidgets('a failed permission check shows plain words, not the platform error', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [notificationAccessProvider.overrideWith(_FailingAccessCheck.new)],
        child: const MaterialApp(home: NotificationSettingsScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('알림 권한을 확인할 수 없습니다. 잠시 후 다시 시도해주세요.'), findsOneWidget);
    for (final fragment in [
      '권한 확인 오류',
      'PlatformException',
      'channel-error',
      'finance_client/notification_listener',
      'SecurityException',
      'java.lang',
    ]) {
      expect(find.textContaining(fragment), findsNothing, reason: fragment);
    }
  });
}
