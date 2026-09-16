import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/manual_input_fab.dart';
import '../../../data/api/finance_api.dart';
import '../../../data/api/report_api.dart';
import '../../../data/api/transaction_api.dart';
import '../../home/theme/home_tokens.dart';
import '../../policy/providers/policy_provider.dart';
import '../../transaction/screens/add_transaction_screen.dart';
import '../utils/policy_alert_utils.dart';
import '../utils/salary_cycle_utils.dart';
import '../widgets/day_detail_sheet.dart';
import '../widgets/spending_progress_ring.dart';

int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}

bool _isSameDay(DateTime? a, DateTime b) {
  if (a == null) return false;
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

// One day of `/api/reports/daily`. The backend now returns `recommended`/
// `difference` per day (see API_SPEC.md), but per
// docs/backend/calendar-daily-spending-ratio-requirements.md section H, the
// current calculation applies one flat `dailyRecommended` to every date in
// the requested range instead of resolving each date's own BudgetCycle -
// wrong across a cycle boundary, which most calendar months (and salary
// cycles) cross. So `recommendedAmount`/`spendingRatio` stay nullable and
// unpopulated here until that per-date fix ships; the Calendar cell simply
// omits the ring/percentage until then. income/expense parsing is
// unaffected either way.
class DailyReportEntry {
  final int income;
  final int expense;
  final int? recommendedAmount;
  final double? spendingRatio;

  const DailyReportEntry({
    required this.income,
    required this.expense,
    this.recommendedAmount,
    this.spendingRatio,
  });

  factory DailyReportEntry.fromJson(Map<String, dynamic> json) {
    final recommended = json['recommendedAmount'];
    final ratio = json['spendingRatio'];
    return DailyReportEntry(
      income: _toInt(json['income']),
      expense: _toInt(json['spent'] ?? json['expense']),
      recommendedAmount: recommended is num ? recommended.toInt() : null,
      spendingRatio: ratio is num ? ratio.toDouble() : null,
    );
  }
}

/// Queried by the visible salary-cycle window (start/end, both inclusive)
/// rather than a calendar month, so the fetched range always matches what
/// the grid actually renders (see [salaryCycleGridDays]). Records have
/// built-in value equality, so this is a safe/stable family key.
final monthlyReportProvider =
    FutureProvider.family<
      Map<DateTime, DailyReportEntry>,
      ({DateTime start, DateTime end})
    >((ref, range) async {
      final reportApi = ref.watch(reportApiProvider);

      // getDaily() now returns the full `{period, summary, daily}` envelope
      // (API_SPEC.md's `GET /api/reports/daily`), not a bare list - unwrap
      // `daily` here. `summary` isn't used: _buildSummaryRow recomputes
      // income/expense/no-spend-days itself from `daily` (see below), since the
      // backend's `summary` covers the whole requested range rather than "up to
      // today" like the Figma card wants.
      final data = await reportApi.getDaily(
        startDate: DateFormat('yyyy-MM-dd').format(range.start),
        endDate: DateFormat('yyyy-MM-dd').format(range.end),
      );
      final daily = data['daily'] as List<dynamic>? ?? const [];

      final Map<DateTime, DailyReportEntry> reportMap = {};
      for (var item in daily) {
        final date = DateTime.parse(item['date']);
        reportMap[DateTime(date.year, date.month, date.day)] =
            DailyReportEntry.fromJson(item as Map<String, dynamic>);
      }
      return reportMap;
    });

final dailyTransactionsProvider =
    FutureProvider.family<List<dynamic>, DateTime>((ref, day) async {
      final txApi = ref.watch(transactionApiProvider);
      final dateStr = DateFormat('yyyy-MM-dd').format(day);
      try {
        final data = await txApi.getTransactions(
          startDate: dateStr,
          endDate: dateStr,
        );
        if (data['items'] is List) return data['items'] as List<dynamic>;
        if (data['transactions'] is List)
          return data['transactions'] as List<dynamic>;
        return [];
      } catch (e) {
        return [];
      }
    });

/// The user's configured payday (재사용: same `FinanceApi.getSetting()` call
/// Home/MyPage already make - see `salary_cycle_settings_screen.dart`). 25
/// is the same fallback used there and at onboarding when nothing is set
/// yet, so the Calendar and Settings screens never disagree while loading.
const int _defaultSalaryDay = 25;

final salaryDayProvider = FutureProvider.autoDispose<int>((ref) async {
  final financeApi = ref.watch(financeApiProvider);
  try {
    final setting = await financeApi.getSetting();
    final raw = setting['salaryDay'];
    final parsed = raw is num
        ? raw.toInt()
        : int.tryParse(raw?.toString() ?? '');
    return (parsed ?? _defaultSalaryDay).clamp(1, 31);
  } catch (_) {
    return _defaultSalaryDay;
  }
});

// Figma node 114:5459 (FINAL_CALENDAR_SCREENS Frame 25) header gradient, a
// shorter 2-stop variant of the Home hero gradient sized for the calendar
// top panel.
const _headerGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFF6DD9AB), Color(0xFF00AF76)],
);

// Design-QA-only sample spending ratios (Frame 25 shows 60% / 85% / 125%
// examples). This never touches the DailyReportEntry model or the report
// provider - it is a local, purely presentational fallback so the ring/badge
// layout can be reviewed before the backend computes a real spendingRatio
// (see docs/backend/calendar-daily-spending-ratio-requirements.md). Gated on
// kDebugMode so the tree-shaker drops it entirely from release builds; it
// must never be mistaken for backend data.
const List<double> _debugSampleSpendingRatios = [60, 85, 125];

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  // Cycles away from "today's" cycle, not a calendar month - see
  // docs/development-work-policy.md / this screen's spec: navigation must
  // move by salary cycle, not Gregorian month.
  int _cycleOffset = 0;
  DateTime? _selectedDay;

  // Tracks which way the grid should slide in from, for both the header
  // chevrons and the grid swipe - see _buildCalendarGrid's AnimatedSwitcher.
  double _lastCycleShiftDirection = 0;
  // Accumulates horizontal drag distance for the duration of one gesture
  // (reset in onHorizontalDragStart) so a slow-but-long swipe is recognized
  // even when its release velocity is low - see _handleGridSwipeEnd.
  double _horizontalDragDistance = 0;

  // Shared by the header chevrons and the grid swipe gesture so both move
  // the exact same state the exact same way (see docs/development-work-policy.md
  // - the salary-cycle-based grid must never show two different periods).
  void _goToPreviousCycle() {
    setState(() {
      _cycleOffset -= 1;
      _lastCycleShiftDirection = -1;
    });
  }

  void _goToNextCycle() {
    setState(() {
      _cycleOffset += 1;
      _lastCycleShiftDirection = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final salaryDayAsync = ref.watch(salaryDayProvider);
    final salaryDay = salaryDayAsync.asData?.value ?? _defaultSalaryDay;
    final baseCycle = salaryCycleContaining(DateTime.now(), salaryDay);
    final cycle = shiftSalaryCycle(baseCycle, _cycleOffset, salaryDay);
    final gridDays = salaryCycleGridDays(cycle);

    final monthlyReportAsync = ref.watch(
      monthlyReportProvider((start: cycle.start, end: cycle.end)),
    );
    // Policy application deadlines for bookmarked ("관심") policies only,
    // reused from the existing bookmarks provider (already used by
    // PolicyBookmarksScreen) so calendar D-5/D-3/D-Day badges need no new
    // backend endpoint.
    final policyAlerts = _policyAlertsByDay(ref);

    return Scaffold(
      backgroundColor: HomeTokens.pageBackground,
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 100),
                  child: Column(
                    children: [
                      // Header
                      Container(
                        decoration: const BoxDecoration(
                          gradient: _headerGradient,
                        ),
                        child: SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.account_balance_wallet_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      '캘린더',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.search,
                                        color: Colors.white,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 24,
                                        minHeight: 24,
                                      ),
                                      onPressed: () {},
                                    ),
                                    const SizedBox(width: 20),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.notifications_none,
                                        color: Colors.white,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 24,
                                        minHeight: 24,
                                      ),
                                      onPressed: () {},
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF6DD9AB,
                                    ).withValues(alpha: 0.56),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.85,
                                      ),
                                      width: 1.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.12,
                                        ),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.chevron_left,
                                          color: Colors.white,
                                        ),
                                        onPressed: _goToPreviousCycle,
                                      ),
                                      Expanded(
                                        child: Text(
                                          '${DateFormat('yyyy. M. d.').format(cycle.start)} ~ ${DateFormat('yyyy. M. d.').format(cycle.end)}',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.chevron_right,
                                          color: Colors.white,
                                        ),
                                        onPressed: _goToNextCycle,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Deliberately NOT overlapping the header: the period
                      // selector and the calendar card must read as two
                      // physically separate blocks, with a real gap of visible
                      // page background between them - no negative offset, no
                      // translateY, no absolute positioning pulling this card up
                      // under the green header.
                      const SizedBox(height: 20),

                      // One unified white card (Figma `calendar-reference`):
                      // summary box (its own blue-bordered sub-card) + weekday
                      // header + day grid, all on the same panel - not split
                      // into separately-shadowed cards.
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  8,
                                ),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    // Quiet neutral-gray hairline + a soft shadow
                                    // instead of a colored border - this card has
                                    // enough visual accents already (header
                                    // green, ring colors, income/expense text),
                                    // so its own boundary should recede rather
                                    // than compete for attention.
                                    border: Border.all(
                                      color: const Color(0xFFDADDE1),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.05,
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: _buildSummaryRow(monthlyReportAsync),
                                ),
                              ),
                              _buildCalendarGrid(
                                gridDays,
                                cycle,
                                monthlyReportAsync,
                                policyAlerts,
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          ManualInputFabOverlay(
            onPressed: () => AddTransactionModal.show(
              context,
              initialDate: _selectedDay ?? DateTime.now(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayHeader() {
    const labels = ['일', '월', '화', '수', '목', '금', '토'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          for (int weekday = 0; weekday < 7; weekday++)
            Expanded(
              child: Center(
                child: Text(
                  labels[weekday],
                  style: TextStyle(
                    color: weekday == 0
                        ? HomeTokens.negative
                        : (weekday == 6
                              ? Colors.blue
                              : HomeTokens.textDark.withValues(alpha: 0.8)),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Minimum horizontal travel/speed (logical px / px-per-second) before a
  // drag counts as an intentional "change month" swipe rather than a
  // slightly-diagonal tap or an incidental wobble while scrolling.
  static const double _swipeDistanceThreshold = 60;
  static const double _swipeVelocityThreshold = 300;

  // Only the weekday header + day grid get the horizontal gesture (not the
  // summary card above them or the FAB overlaid on top), so swipe-to-change-
  // month can't fight with those other interactions. Wrapping just this
  // sub-area, rather than GestureDetector(onHorizontalDragEnd: ...) plus
  // manual axis checks, is enough: HorizontalDragGestureRecognizer already
  // only claims the gesture arena over the parent SingleChildScrollView's
  // vertical scroll when the drag is predominantly horizontal, the same way
  // a horizontal PageView nested in a vertical list already works today.
  Widget _buildCalendarGrid(
    List<DateTime> gridDays,
    SalaryCycle cycle,
    AsyncValue<Map<DateTime, DailyReportEntry>> monthlyReportAsync,
    Map<DateTime, List<PolicyAlert>> policyAlerts,
  ) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => _horizontalDragDistance = 0,
      onHorizontalDragUpdate: (details) =>
          _horizontalDragDistance += details.delta.dx,
      onHorizontalDragEnd: _handleGridSwipeEnd,
      child: Column(
        children: [
          _buildWeekdayHeader(),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => ClipRect(
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: Offset(_lastCycleShiftDirection * 0.15, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              ),
            ),
            child: Column(
              key: ValueKey(_cycleOffset),
              children: [
                for (int i = 0; i < gridDays.length; i += 7)
                  Row(
                    children: [
                      for (final day in gridDays.skip(i).take(7))
                        Expanded(
                          child: _buildCalendarCell(
                            day,
                            cycle,
                            monthlyReportAsync,
                            policyAlerts,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // "왼쪽으로 swipe -> 이전 달", "오른쪽으로 swipe -> 다음 달" (spec's direction, opposite
  // of a typical page-forward gesture): dragging a finger leftward produces a
  // negative dx, which reuses the exact same _goToPreviousCycle the left
  // chevron calls, so both stay perfectly in sync (see _goToPreviousCycle /
  // _goToNextCycle docs above).
  void _handleGridSwipeEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final swipedLeft =
        _horizontalDragDistance < -_swipeDistanceThreshold ||
        velocity < -_swipeVelocityThreshold;
    final swipedRight =
        _horizontalDragDistance > _swipeDistanceThreshold ||
        velocity > _swipeVelocityThreshold;
    if (swipedLeft) {
      _goToPreviousCycle();
    } else if (swipedRight) {
      _goToNextCycle();
    }
  }

  // Frame 25's monthly summary card is a permanent part of the Calendar
  // Main layout, not something that should disappear whenever the report
  // API has not returned data yet. Previously this whole area collapsed to
  // an empty SizedBox on both the loading and error branches of
  // monthlyReportAsync.when(...), which is exactly what made it vanish in a
  // preview with no reachable backend (the request errors out, so the old
  // `error: (e, st) => const SizedBox(height: 21)` branch fired and rendered
  // nothing). The card structure below is now always built; only the value
  // area changes per state.
  Widget _buildSummaryRow(
    AsyncValue<Map<DateTime, DailyReportEntry>> monthlyReportAsync,
  ) {
    final isInitialLoad =
        monthlyReportAsync.isLoading && !monthlyReportAsync.hasValue;

    int? income;
    int? expense;
    int? noSpendDays;
    monthlyReportAsync.whenData((reportMap) {
      int inc = 0;
      int exp = 0;
      int noSpend = 0;
      reportMap.forEach((day, entry) {
        inc += entry.income;
        exp += entry.expense;
        if (entry.expense == 0 && !day.isAfter(DateTime.now())) noSpend++;
      });
      income = inc;
      expense = exp;
      noSpendDays = noSpend;
    });

    // Figma visual QA only: this app currently has no reachable backend in
    // preview, so monthlyReportAsync settles into an error state with no
    // data. Rather than leave the card empty, kDebugMode builds fall back to
    // Frame 25's own sample numbers so the layout can be reviewed. This is a
    // local presentation fallback only - it never touches DailyReportEntry,
    // the provider, or production data, and the tree-shaker drops this
    // whole branch from release builds.
    if (income == null && !isInitialLoad && kDebugMode) {
      income = 1000000;
      expense = 500000;
      noSpendDays = 3;
    }

    final noSpendLabel = isInitialLoad ? '-' : (noSpendDays?.toString() ?? '-');
    final incomeLabel = income != null
        ? '${NumberFormat('#,###').format(income)} 원'
        : '-';
    final expenseLabel = expense != null
        ? '${NumberFormat('#,###').format(expense)} 원'
        : '-';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 20, color: HomeTokens.textDark),
            children: [
              const TextSpan(text: '이번 달 '),
              const TextSpan(
                text: '무지출',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const TextSpan(text: ' '),
              TextSpan(
                text: '$noSpendLabel일',
                style: const TextStyle(
                  color: HomeTokens.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              children: [
                const Text(
                  '+ 수입 ',
                  style: TextStyle(
                    color: HomeTokens.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                if (isInitialLoad)
                  _summaryPlaceholderBar()
                else
                  Text(
                    incomeLabel,
                    style: TextStyle(
                      color: HomeTokens.textDark.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Text(
                  '- 지출 ',
                  style: TextStyle(
                    color: HomeTokens.negative,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                if (isInitialLoad)
                  _summaryPlaceholderBar()
                else
                  Text(
                    expenseLabel,
                    style: TextStyle(
                      color: HomeTokens.textDark.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _summaryPlaceholderBar() {
    return Container(
      width: 64,
      height: 12,
      decoration: BoxDecoration(
        color: HomeTokens.chipInactiveBorder,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  // Precomputes every bookmarked ("관심") policy's D-5/D-3/D-Day alerts by
  // calendar day, once per build - so each cell does a plain map lookup
  // instead of re-filtering the whole bookmark list per cell (section 22/23
  // aggregation). All alerts for a day are kept (not just the most urgent
  // one), so a day with multiple deadlines never silently drops one.
  Map<DateTime, List<PolicyAlert>> _policyAlertsByDay(WidgetRef ref) {
    final bookmarkedAsync = ref.watch(bookmarkedPoliciesProvider);
    final map = <DateTime, List<PolicyAlert>>{};
    bookmarkedAsync.whenData((policies) {
      for (final p in policies) {
        final deadline = p['applicationEndDate'] ?? p['deadline'];
        if (deadline is! String || deadline.isEmpty) continue;
        final end = DateTime.tryParse(deadline);
        if (end == null) continue;
        final endDay = DateTime(end.year, end.month, end.day);
        final id = (p['id'] ?? '').toString();
        final title = (p['title'] ?? '정책').toString();
        for (final n in const [5, 3, 0]) {
          final type = policyAlertTypeForDaysRemaining(n);
          if (type == null) continue;
          final day = endDay.subtract(Duration(days: n));
          map
              .putIfAbsent(DateTime(day.year, day.month, day.day), () => [])
              .add(PolicyAlert(policyId: id, policyTitle: title, type: type));
        }
      }
    });
    return map;
  }

  Widget _buildCalendarCell(
    DateTime day,
    SalaryCycle cycle,
    AsyncValue<Map<DateTime, DailyReportEntry>> monthlyReportAsync,
    Map<DateTime, List<PolicyAlert>> policyAlerts,
  ) {
    final isOutside = !cycle.contains(day);
    final isToday = _isSameDay(DateTime.now(), day);
    final isSelected = _isSameDay(_selectedDay, day);

    final entry = isOutside
        ? null
        : monthlyReportAsync.asData?.value[DateTime(
            day.year,
            day.month,
            day.day,
          )];
    final income = entry?.income ?? 0;
    final expense = entry?.expense ?? 0;

    // spendingRatio only comes from the backend (DailyReportEntry.spendingRatio)
    // - see docs/backend/calendar-daily-spending-ratio-requirements.md for why
    // today's recommendedAmount cannot be reused for past dates. The only
    // exception is the kDebugMode sample below, purely for Figma visual QA.
    double? spendingRatio = entry?.spendingRatio;
    if (spendingRatio == null && kDebugMode && !isOutside && expense > 0) {
      spendingRatio =
          _debugSampleSpendingRatios[day.day %
              _debugSampleSpendingRatios.length];
    }
    final ringRatio = isOutside
        ? null
        : spendingRingRatio(
            expense: expense,
            spendingRatioPercent: spendingRatio,
          );

    final alerts = isOutside
        ? null
        : policyAlerts[DateTime(day.year, day.month, day.day)];
    PolicyAlert? primaryAlert;
    if (alerts != null && alerts.isNotEmpty) {
      final sorted = [...alerts]
        ..sort(
          (a, b) =>
              policyAlertUrgency(a.type).compareTo(policyAlertUrgency(b.type)),
        );
      primaryAlert = sorted.first;
    }
    final extraAlertCount = (alerts?.length ?? 0) - 1;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedDay = day);
        DayDetailSheet.show(context, day);
      },
      child: Container(
        height: 76,
        margin: const EdgeInsets.all(2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 34,
              height: 34,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer: spending-vs-recommended ring. Independent of
                  // selection state - a selected day with no spending shows
                  // no ring, and an unselected day with heavy spending still
                  // shows a full ring.
                  if (ringRatio != null)
                    SpendingProgressRing(
                      ratio: ringRatio,
                      color: spendingRingColor(spendingRatio!),
                      size: 34,
                      strokeWidth: 2.5,
                    ),
                  // Inner: today's/selected date circle.
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? HomeTokens.accent
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${day.day}',
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : (isOutside
                                  ? HomeTokens.textMuted
                                  : (day.weekday == 7
                                        ? HomeTokens.negative
                                        : HomeTokens.textDark)),
                        fontWeight: isSelected || isToday
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!isOutside && (income > 0 || expense > 0)) ...[
              const SizedBox(height: 2),
              if (income > 0)
                Text(
                  '+${NumberFormat('#,###').format(income)}',
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: HomeTokens.accent,
                    fontSize: 8,
                    height: 1,
                  ),
                ),
              if (expense > 0)
                Text(
                  '-${NumberFormat('#,###').format(expense)}',
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: HomeTokens.negative,
                    fontSize: 8,
                    height: 1,
                  ),
                ),
            ],
            if (primaryAlert != null) ...[
              const SizedBox(height: 1),
              GestureDetector(
                onTap: () {
                  if (extraAlertCount <= 0) {
                    context.push('/policy/${primaryAlert!.policyId}');
                  } else {
                    DayDetailSheet.show(context, day);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 3,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: HomeTokens.chipActiveBg,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: HomeTokens.accent, width: 0.5),
                  ),
                  child: Text(
                    extraAlertCount > 0
                        ? '${policyAlertLabel(primaryAlert.type)} +$extraAlertCount'
                        : policyAlertLabel(primaryAlert.type),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: HomeTokens.accent,
                      fontSize: 7,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
