import 'package:finance_client/core/services/notification_service.dart';
import 'package:finance_client/data/api/api_error.dart';
import 'package:finance_client/features/mypage/screens/notification_settings_screen.dart';
import 'package:finance_client/features/notification/providers/notification_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('finance_app/notification_access');

const _checkFailed = '알림 권한을 확인할 수 없습니다. 잠시 후 다시 시도해주세요.';

/// What the Android plugin answers to `isNotificationAccessGranted`.
late Future<Object?> Function() _pluginAnswer;

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

PlatformException _pluginFailure() => PlatformException(
  code: 'channel-error',
  message: 'Unable to establish connection on channel: '
      'finance_app/notification_access',
  details: 'java.lang.SecurityException at NotificationChannelHandler',
);

void _expectNoPlatformDetails() {
  for (final fragment in [
    '권한 확인 오류',
    'PlatformException',
    'channel-error',
    'finance_client/notification_listener',
    'finance_app/notification_access',
    'SecurityException',
    'java.lang',
  ]) {
    expect(find.textContaining(fragment), findsNothing, reason: fragment);
  }
}

/// The settings screen wired to the real provider and service, with the
/// Android plugin replaced by [_pluginAnswer] and the app's retry policy.
Future<void> _pumpScreen(WidgetTester tester) async {
  await tester.pumpWidget(
    const ProviderScope(
      retry: apiRetry,
      child: MaterialApp(home: NotificationSettingsScreen()),
    ),
  );
  await tester.pump();
}

void main() {
  final realIsAndroid = NotificationService.isAndroid;

  setUp(() {
    NotificationService.isAndroid = () => true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          if (call.method == 'isNotificationAccessGranted') {
            return _pluginAnswer();
          }
          return null;
        });
  });

  tearDown(() {
    NotificationService.isAndroid = realIsAndroid;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  testWidgets('a failed permission check shows plain words, not the platform error', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [notificationAccessProvider.overrideWith(_FailingAccessCheck.new)],
        child: const MaterialApp(home: NotificationSettingsScreen()),
      ),
    );
    await tester.pump();

    expect(find.text(_checkFailed), findsOneWidget);
    _expectNoPlatformDetails();
  });

  testWidgets('plugin says granted: 허용됨', (tester) async {
    _pluginAnswer = () async => true;
    await _pumpScreen(tester);

    expect(find.text('허용됨'), findsOneWidget);
    expect(find.text('허용되지 않음'), findsNothing);
    expect(find.text(_checkFailed), findsNothing);
  });

  testWidgets('plugin says not granted: 허용되지 않음', (tester) async {
    _pluginAnswer = () async => false;
    await _pumpScreen(tester);

    expect(find.text('허용되지 않음'), findsOneWidget);
    expect(find.text('허용됨'), findsNothing);
    expect(find.text(_checkFailed), findsNothing);
  });

  testWidgets('plugin throws: the failure is not passed off as 허용되지 않음', (tester) async {
    _pluginAnswer = () async => throw _pluginFailure();
    await _pumpScreen(tester);

    expect(find.text(_checkFailed), findsOneWidget);
    expect(find.text('허용되지 않음'), findsNothing);
    expect(find.text('허용됨'), findsNothing);
    _expectNoPlatformDetails();
  });

  testWidgets('checking again after a failure shows the real answer', (tester) async {
    _pluginAnswer = () async => throw _pluginFailure();
    await _pumpScreen(tester);
    expect(find.text(_checkFailed), findsOneWidget);

    _pluginAnswer = () async => true;
    final container = ProviderScope.containerOf(
      tester.element(find.byType(NotificationSettingsScreen)),
    );
    await container.read(notificationAccessProvider.notifier).checkStatus();
    await tester.pump();

    expect(find.text('허용됨'), findsOneWidget);
    expect(find.text(_checkFailed), findsNothing);
  });
}
