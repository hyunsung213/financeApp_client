import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Single shared "today" for the whole app. Screens that show today's date,
/// compute D-Day/budget-cycle ranges, or filter "today's" data should watch
/// this instead of calling `DateTime.now()` directly, so they can never
/// disagree with each other about what day it is.
///
/// Without this, a widget that only rebuilds when its own providers change
/// (e.g. Home, which is kept alive by the bottom-nav `IndexedStack` and has
/// no other reason to rebuild once its data has loaded) can keep showing a
/// `DateTime.now()` value captured at its last build, long after the device
/// date has moved on. This notifier re-reads the clock at the next local
/// midnight and whenever [refresh] is called (wired to app-resume in
/// `main.dart`), and anything watching it rebuilds/refetches accordingly.
class CurrentDateNotifier extends Notifier<DateTime> {
  Timer? _midnightTimer;

  @override
  DateTime build() {
    _scheduleMidnightRefresh();
    ref.onDispose(() => _midnightTimer?.cancel());
    return DateTime.now();
  }

  /// Re-reads the device clock. Call this when the app comes back to the
  /// foreground so a date shown before backgrounding doesn't stay stale.
  void refresh() {
    state = DateTime.now();
    _scheduleMidnightRefresh();
  }

  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(nextMidnight.difference(now), refresh);
  }
}

final currentDateProvider = NotifierProvider<CurrentDateNotifier, DateTime>(
  CurrentDateNotifier.new,
);
