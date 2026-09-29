import 'package:finance_client/features/auth/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  /// A fresh container over the same stored prefs, like an app relaunch.
  Future<ProviderContainer> launch() async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('first launch is signed out (no forced dev login)', () async {
    expect((await launch()).read(authProvider).isAuthenticated, isFalse);
  });

  test('자동 로그인 keeps the session across a relaunch', () async {
    (await launch())
        .read(authProvider.notifier)
        .login('seed@example.local', keepSignedIn: true);

    final relaunched = (await launch()).read(authProvider);
    expect(relaunched.isAuthenticated, isTrue);
    expect(relaunched.user?.email, 'seed@example.local');
  });

  test('without 자동 로그인 a relaunch asks to sign in again', () async {
    (await launch())
        .read(authProvider.notifier)
        .login('seed@example.local', keepSignedIn: false);
    expect((await launch()).read(authProvider).isAuthenticated, isFalse);
  });

  test('logout clears the kept session', () async {
    final app = await launch();
    app
        .read(authProvider.notifier)
        .login('seed@example.local', keepSignedIn: true);
    app.read(authProvider.notifier).logout();
    expect((await launch()).read(authProvider).isAuthenticated, isFalse);
  });
}
