import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A one-shot "open the Calendar on this date" request.
///
/// Other screens (e.g. Report's "가장 많이 쓴 날") call [request] and then
/// switch to the Calendar tab; CalendarScreen consumes it - moving to the
/// salary cycle that contains the date, selecting the day and opening its
/// day sheet - and clears it, so a later visit to the tab doesn't replay it.
/// It's a provider rather than a route parameter because the Calendar tab
/// keeps its state alive (StatefulShellRoute) and so isn't rebuilt from a
/// URL each time it's shown.
class CalendarFocusNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void request(DateTime day) => state = DateTime(day.year, day.month, day.day);

  void consume() => state = null;
}

final calendarFocusProvider = NotifierProvider<CalendarFocusNotifier, DateTime?>(CalendarFocusNotifier.new);
