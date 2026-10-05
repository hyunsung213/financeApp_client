import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_palette.dart';
import 'app_lock.dart';

/// Covers the app with a lock screen while [appLockedProvider] is set, and
/// asks the OS to authenticate. Wraps the router output in
/// `FinanceApp`'s `MaterialApp.builder`, so the app underneath keeps its
/// state while locked.
///
/// The lock comes back when the app returns after being in the background
/// for at least [relockAfter]; shorter trips (e.g. opening the notification
/// access settings) don't ask again.
class AppLockGate extends ConsumerStatefulWidget {
  final Widget child;

  const AppLockGate({super.key, required this.child});

  static const Duration relockAfter = Duration(seconds: 30);

  static const unlockReason = '월릿을 사용하려면 본인 인증이 필요해요.';

  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  DateTime? _backgroundedAt;
  bool _authenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (ref.read(appLockedProvider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The OS prompt itself can move the app out of the foreground; that
    // must not count as leaving the app.
    if (_authenticating) return;
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _backgroundedAt ??= AppLockGate.clock();
      case AppLifecycleState.resumed:
        final since = _backgroundedAt;
        _backgroundedAt = null;
        // Prompt only after a real trip away. Closing the OS prompt also
        // resumes the app; prompting on that resume would reopen the prompt
        // forever, so a cancelled prompt leaves the lock screen and its
        // 잠금 해제 button instead.
        if (since != null &&
            ref.read(appLockEnabledProvider) &&
            AppLockGate.clock().difference(since) >= AppLockGate.relockAfter) {
          ref.read(appLockedProvider.notifier).lock();
          _unlock();
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _unlock() async {
    if (_authenticating || !mounted) return;
    _authenticating = true;
    final result = await ref
        .read(appLockAuthenticatorProvider)
        .authenticate(AppLockGate.unlockReason);
    _authenticating = false;
    if (!mounted) return;
    switch (result) {
      case AppLockAuthResult.success:
        ref.read(appLockedProvider.notifier).unlock();
      case AppLockAuthResult.unavailable:
        // The device lost every way to authenticate (screen lock removed),
        // so the lock could never open again: turn it off instead of
        // trapping the user.
        ref.read(appLockEnabledProvider.notifier).disable();
        ref.read(appLockedProvider.notifier).unlock();
      case AppLockAuthResult.failed:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = ref.watch(appLockedProvider);
    return Stack(
      children: [
        // Hidden from accessibility and input while the lock covers it.
        ExcludeSemantics(
          excluding: locked,
          child: IgnorePointer(ignoring: locked, child: widget.child),
        ),
        if (locked) Positioned.fill(child: AppLockScreen(onUnlock: _unlock)),
      ],
    );
  }
}

class AppLockScreen extends StatelessWidget {
  final VoidCallback onUnlock;

  const AppLockScreen({super.key, required this.onUnlock});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.pageBackground,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: palette.accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_outline,
                  size: 34,
                  color: palette.accent,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '월릿이 잠겨 있어요',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                  letterSpacing: -0.45,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '본인 인증 후 사용할 수 있어요.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.3,
                  letterSpacing: -0.45,
                  color: palette.textMuted,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onUnlock,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    '잠금 해제',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
