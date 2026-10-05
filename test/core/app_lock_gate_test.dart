import 'package:finance_client/core/app_lock/app_lock.dart';
import 'package:finance_client/core/app_lock/app_lock_gate.dart';
import 'package:finance_client/features/auth/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthenticator extends AppLockAuthenticator {
  AppLockAuthResult result;
  int prompts = 0;

  _FakeAuthenticator(this.result);

  @override
  bool get isPlatformSupported => true;

  @override
  Future<bool> canUseBiometrics() async => true;

  @override
  Future<AppLockAuthResult> authenticate(String reason) async {
    prompts++;
    return result;
  }
}

void main() {
  late SharedPreferences prefs;

  Future<void> pumpGate(
    WidgetTester tester,
    _FakeAuthenticator auth, {
    required bool enabled,
  }) async {
    SharedPreferences.setMockInitialValues({
      AppLockEnabledNotifier.storageKey: enabled,
    });
    prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appLockAuthenticatorProvider.overrideWithValue(auth),
        ],
        child: MaterialApp(
          builder: (context, child) => AppLockGate(child: child!),
          home: const Scaffold(body: Text('월릿 홈')),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('no lock screen when the lock is off', (tester) async {
    final auth = _FakeAuthenticator(AppLockAuthResult.success);
    await pumpGate(tester, auth, enabled: false);

    expect(find.byType(AppLockScreen), findsNothing);
    expect(auth.prompts, 0);
  });

  testWidgets('asks on launch and opens after success', (tester) async {
    final auth = _FakeAuthenticator(AppLockAuthResult.success);
    await pumpGate(tester, auth, enabled: true);

    expect(auth.prompts, 1);
    expect(find.byType(AppLockScreen), findsNothing);
    expect(find.text('월릿 홈'), findsOneWidget);
  });

  testWidgets('stays locked after a failed prompt until it passes', (
    tester,
  ) async {
    final auth = _FakeAuthenticator(AppLockAuthResult.failed);
    await pumpGate(tester, auth, enabled: true);

    expect(find.byType(AppLockScreen), findsOneWidget);
    expect(find.text('월릿이 잠겨 있어요'), findsOneWidget);

    auth.result = AppLockAuthResult.success;
    await tester.tap(find.text('잠금 해제'));
    await tester.pumpAndSettle();

    expect(auth.prompts, 2);
    expect(find.byType(AppLockScreen), findsNothing);
  });

  testWidgets('turns the lock off if the device can no longer authenticate', (
    tester,
  ) async {
    final auth = _FakeAuthenticator(AppLockAuthResult.unavailable);
    await pumpGate(tester, auth, enabled: true);

    expect(find.byType(AppLockScreen), findsNothing);
    expect(prefs.getBool(AppLockEnabledNotifier.storageKey), isFalse);
  });

  testWidgets('locks again only after a long enough background trip', (
    tester,
  ) async {
    final auth = _FakeAuthenticator(AppLockAuthResult.success);
    await pumpGate(tester, auth, enabled: false);
    final container = ProviderScope.containerOf(
      tester.element(find.text('월릿 홈')),
    );
    // Turned on in-app, so the app is already open.
    await container.read(appLockEnabledProvider.notifier).enable();
    auth.prompts = 0;

    // A short trip (well under AppLockGate.relockAfter) doesn't lock.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byType(AppLockScreen), findsNothing);
    expect(auth.prompts, 0);
  });

  testWidgets('locks and asks again after 30s or more in the background', (
    tester,
  ) async {
    var now = DateTime(2026, 10, 5, 9);
    AppLockGate.clock = () => now;
    addTearDown(() => AppLockGate.clock = DateTime.now);

    final auth = _FakeAuthenticator(AppLockAuthResult.success);
    await pumpGate(tester, auth, enabled: false);
    final container = ProviderScope.containerOf(
      tester.element(find.text('월릿 홈')),
    );
    await container.read(appLockEnabledProvider.notifier).enable();
    auth.prompts = 0;
    auth.result = AppLockAuthResult.failed;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = now.add(AppLockGate.relockAfter);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(auth.prompts, 1);
    expect(find.byType(AppLockScreen), findsOneWidget);

    // Closing the cancelled OS prompt resumes the app; that must not
    // reopen the prompt (it would loop), only leave the lock screen.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(auth.prompts, 1);
    expect(find.byType(AppLockScreen), findsOneWidget);
  });
}
