import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/app_config.dart';
import '../../../data/demo/demo_store.dart';
import '../../../data/mocks/db.dart'; // Keeping for User model

/// App-wide [SharedPreferences], overridden in `main()` once loaded. Null in
/// tests and anywhere it isn't provided, which simply disables persistence.
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null);

class AuthState {
  final bool isAuthenticated;
  final MockUser? user;

  AuthState({this.isAuthenticated = false, this.user});
}

/// DEV-ONLY stand-in for the Supabase session: remembers which email was
/// used to "sign in" so 자동 로그인 survives a relaunch.
///
/// This is not authentication and must not grow into it. It stores the email
/// only - never a password, and no token is created (the backend runs with
/// `DEV_AUTH_BYPASS` and ignores credentials). When Supabase Auth is wired
/// up, delete this class and restore the session from Supabase instead.
class _MockSessionStore {
  const _MockSessionStore(this._prefs);

  static const _emailKey = 'auth.mockSessionEmail';

  final SharedPreferences? _prefs;

  String? read() => _prefs?.getString(_emailKey);

  void save(String email) => _prefs?.setString(_emailKey, email);

  void clear() => _prefs?.remove(_emailKey);
}

/// Pre-Supabase sign-in state.
///
/// There is no real auth yet: "signing in" only records the entered email
/// (see [MockAuthActions.signIn]). Screens and the router depend only on
/// [AuthState], so replacing this notifier's internals with a Supabase
/// session doesn't touch them.
class AuthNotifier extends Notifier<AuthState> {
  _MockSessionStore get _mockSession =>
      _MockSessionStore(ref.read(sharedPreferencesProvider));

  static const _demoSessionKey = 'demo.session';

  @override
  AuthState build() {
    if (AppConfig.demoMode) {
      final inDemo =
          ref.read(sharedPreferencesProvider)?.getBool(_demoSessionKey) ==
          true;
      return inDemo ? _demoSignedIn() : AuthState();
    }
    final email = _mockSession.read();
    return email == null ? AuthState() : _signedIn(email);
  }

  AuthState _signedIn(String email) => AuthState(
    isAuthenticated: true,
    user: MockUser(
      id: 'auth-user-uuid',
      email: email,
      name: email.split('@')[0],
    ),
  );

  void login(String email, {bool keepSignedIn = false}) {
    if (keepSignedIn) {
      _mockSession.save(email);
    } else {
      _mockSession.clear();
    }
    state = _signedIn(email);
  }

  void logout() {
    if (AppConfig.demoMode) {
      // Leaving the demo discards the visitor's sample edits as well.
      ref.read(sharedPreferencesProvider)?.remove(_demoSessionKey);
      DemoStore.instance.reset();
      state = AuthState();
      return;
    }
    _mockSession.clear();
    state = AuthState();
  }

  /// Web demo entry (`DEMO_MODE=true` only): a signed-in state backed by the
  /// in-browser sample account, with no credentials involved. Kept apart from
  /// the email mock above, which the Android dev build keeps using.
  void startDemoSession() {
    assert(AppConfig.demoMode, 'Demo session outside DEMO_MODE');
    ref.read(sharedPreferencesProvider)?.setBool(_demoSessionKey, true);
    state = _demoSignedIn();
  }

  AuthState _demoSignedIn() => AuthState(
    isAuthenticated: true,
    user: MockUser(
      id: DemoStore.userId,
      email: 'demo@wallet.example',
      name: '월릿 데모 사용자',
    ),
  );
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});
