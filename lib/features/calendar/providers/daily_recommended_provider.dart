import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/calendar_screen.dart';
import '../utils/salary_cycle_utils.dart';

/// The recommended daily spending amount for [day], or `null` when the
/// backend gave none for it.
///
/// Reads the same `/api/reports/daily` data the Calendar grid already loads
/// (monthlyReportProvider, keyed by the salary cycle that contains [day]), so
/// opening a day's sheet costs no extra request when its cycle is on screen
/// and adds no calculation of its own - the amount is whatever the backend's
/// `recommended` says. That value is currently the cycle-wide even split
/// (planned flexible budget / cycle days), the same for every day of a
/// cycle; once the backend returns the per-date, Home-consistent amount
/// (docs/backend/calendar-daily-spending-ratio-requirements.md) this
/// provider picks it up unchanged.
final dailyRecommendedAmountProvider = FutureProvider.autoDispose
    .family<int?, DateTime>((ref, day) async {
      final salaryDay = await ref.watch(salaryDayProvider.future);
      final cycle = salaryCycleContaining(day, salaryDay);
      final report = await ref.watch(
        monthlyReportProvider((start: cycle.start, end: cycle.end)).future,
      );
      return report[DateTime(day.year, day.month, day.day)]?.recommendedAmount;
    });
