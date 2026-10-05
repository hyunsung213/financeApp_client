import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

import '../../features/auth/providers/auth_provider.dart';

enum AppLockAuthResult {
  success,

  /// The user cancelled or failed the prompt.
  failed,

  /// The device can no longer authenticate at all (no biometrics and no
  /// screen lock), so a lock could never be opened again.
  unavailable,
}

/// Thin wrapper over the OS authentication API (`local_auth`). The app never
/// sees or stores biometric data; it only gets a yes/no from the OS.
class AppLockAuthenticator {
  const AppLockAuthenticator();

  /// Android/iOS app only; the web build has no biometric API.
  bool get isPlatformSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Whether at least one biometric (fingerprint, face) is enrolled and
  /// usable by the app.
  Future<bool> canUseBiometrics() async {
    if (!isPlatformSupported) return false;
    try {
      final auth = LocalAuthentication();
      if (!await auth.isDeviceSupported()) return false;
      if (!await auth.canCheckBiometrics) return false;
      return (await auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Biometrics first, with the device PIN/pattern as the OS fallback so a
  /// user whose fingerprint stops matching is never locked out.
  Future<AppLockAuthResult> authenticate(String reason) async {
    if (!isPlatformSupported) return AppLockAuthResult.unavailable;
    try {
      final auth = LocalAuthentication();
      if (!await auth.isDeviceSupported()) return AppLockAuthResult.unavailable;
      final ok = await auth.authenticate(
        localizedReason: reason,
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: '본인 인증',
            signInHint: '지문 센서를 터치해 주세요',
            cancelButton: '취소',
          ),
          IOSAuthMessages(cancelButton: '취소'),
        ],
        persistAcrossBackgrounding: true,
      );
      return ok ? AppLockAuthResult.success : AppLockAuthResult.failed;
    } on LocalAuthException catch (e) {
      return switch (e.code) {
        LocalAuthExceptionCode.noBiometricHardware ||
        LocalAuthExceptionCode.noCredentialsSet =>
          AppLockAuthResult.unavailable,
        _ => AppLockAuthResult.failed,
      };
    } catch (_) {
      return AppLockAuthResult.failed;
    }
  }
}

final appLockAuthenticatorProvider = Provider<AppLockAuthenticator>(
  (ref) => const AppLockAuthenticator(),
);

enum AppLockEnableResult { enabled, unsupportedPlatform, noBiometrics, failed }

/// 앱 잠금 on/off. Only this flag is stored on the device.
class AppLockEnabledNotifier extends Notifier<bool> {
  static const storageKey = 'settings.appLockEnabled';

  static const enableReason = '월릿 잠금을 설정하려면 본인 인증이 필요해요.';

  @override
  bool build() {
    if (!ref.read(appLockAuthenticatorProvider).isPlatformSupported) {
      return false;
    }
    return ref.read(sharedPreferencesProvider)?.getBool(storageKey) ?? false;
  }

  /// Turns the lock on only after the user passes an OS prompt.
  Future<AppLockEnableResult> enable() async {
    final authenticator = ref.read(appLockAuthenticatorProvider);
    if (!authenticator.isPlatformSupported) {
      return AppLockEnableResult.unsupportedPlatform;
    }
    if (!await authenticator.canUseBiometrics()) {
      return AppLockEnableResult.noBiometrics;
    }
    final result = await authenticator.authenticate(enableReason);
    if (result != AppLockAuthResult.success) return AppLockEnableResult.failed;
    _save(true);
    return AppLockEnableResult.enabled;
  }

  void disable() => _save(false);

  void _save(bool enabled) {
    state = enabled;
    ref.read(sharedPreferencesProvider)?.setBool(storageKey, enabled);
  }
}

final appLockEnabledProvider = NotifierProvider<AppLockEnabledNotifier, bool>(
  AppLockEnabledNotifier.new,
);

/// Whether the lock screen is currently covering the app. Starts locked on
/// launch when the lock is on.
class AppLockedNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(appLockEnabledProvider);

  void lock() => state = true;

  void unlock() => state = false;
}

final appLockedProvider = NotifierProvider<AppLockedNotifier, bool>(
  AppLockedNotifier.new,
);
