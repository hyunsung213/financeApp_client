import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/format/money_format.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/surface_style.dart';
import '../../../core/theme/wallet_glass.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/manual_input_fab.dart';
import '../../../core/widgets/tab_header.dart';
import '../../../data/api/finance_api.dart';
import '../../../data/api/report_api.dart';
import '../../../data/api/transaction_api.dart';
import '../../policy/providers/policy_provider.dart';
import '../../transaction/screens/add_transaction_screen.dart';
import '../providers/calendar_focus_provider.dart';
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

// One day of `/api/reports/daily`. The backend returns `recommended`/
// `difference` per day (see API_SPEC.md), but per
// docs/backend/calendar-daily-spending-ratio-requirements.md section H, the
// current calculation applies one flat `dailyRecommended` (planned flexible
// budget / cycle days) to every date in the requested range instead of
// resolving each date's own BudgetCycle. That is only right when the range
// sits inside one cycle - which is how the Calendar queries it (one salary
// cycle at a time, see monthlyReportProvider) - so `recommendedAmount` now
// reads `recommended` for the day-detail sheet's usage line
// (dailyRecommendedAmountProvider). `spendingRatio` has no backend source
// yet and stays null, so the Calendar cell still omits its percentage until
// the per-date fix ships. income/expense parsing is unaffected.
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
    final recommended = json['recommendedAmount'] ?? json['recommended'];
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

  bool _applyingFocus = false;

  // A date another screen asked the Calendar to open on (see
  // calendarFocusProvider): jump to the salary cycle containing it, select
  // it, and open the same day sheet a cell tap opens - so the user lands on
  // that day's transactions without hunting for the cell. Only run once this
  // tab is actually the visible one (go_router keeps inactive shell branches
  // built but Offstage/ticker-disabled): this screen may already be built
  // when the request arrives, and the sheet must not pop up over the tab the
  // user is still leaving.
  void _maybeApplyFocus(DateTime? focus) {
    if (focus == null || _applyingFocus) return;
    _applyingFocus = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        // Not the default 25: the offset depends on the user's real salary day.
        final salaryDay = await ref.read(salaryDayProvider.future);
        if (!mounted) return;
        final offset = salaryCycleOffsetBetween(
          DateTime.now(),
          focus,
          salaryDay,
        );
        setState(() {
          _lastCycleShiftDirection = offset.compareTo(_cycleOffset).toDouble();
          _cycleOffset = offset;
          _selectedDay = focus;
        });
        ref.read(calendarFocusProvider.notifier).consume();
        DayDetailSheet.show(context, focus);
      } finally {
        _applyingFocus = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final focusRequest = ref.watch(calendarFocusProvider);
    if (focusRequest != null && TickerMode.valuesOf(context).enabled) {
      _maybeApplyFocus(focusRequest);
    }

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
    // The cheapest and priciest spending days currently on screen, used to
    // normalize every ring's color as a relative "how big is this day next
    // to this cycle's other spending days" heat value instead of an
    // absolute won threshold - see spendIntensityColor's call site in
    // _buildCalendarCell.
    final expenseRange = _expenseRangeInCycle(
      gridDays,
      cycle,
      monthlyReportAsync,
    );

    return Scaffold(
      // The tab shell paints the ambient background behind every tab.
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 100),
                  child: Column(
                    children: [
                      // Header - shared tab header band (same green, title
                      // row and on-header pill style as Home/Report).
                      TabHeaderBand(
                        child: Column(
                          children: [
                            TabHeaderTitleRow(
                              title: '캘린더',
                              actions: [
                                TabHeaderIconButton(
                                  icon: Icons.search,
                                  onPressed: () {},
                                ),
                                TabHeaderIconButton(
                                  icon: Icons.notifications_none,
                                  onPressed: () {},
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: AppSurfaces.onHeroPill
                                  .toBoxDecoration(),
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
                                    // One line even on narrow screens or
                                    // with a large system font.
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        '${DateFormat('yyyy. M. d.').format(cycle.start)} ~ ${DateFormat('yyyy. M. d.').format(cycle.end)}',
                                        maxLines: 1,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
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

                      // Deliberately NOT overlapping the header: the period
                      // selector and the calendar card must read as two
                      // physically separate blocks, with a real gap of visible
                      // page background between them - no negative offset, no
                      // translateY, no absolute positioning pulling this card up
                      // under the green header.
                      const SizedBox(height: AppSpacing.sectionGap),

                      // One unified glass card (Figma `calendar-reference`):
                      // summary box + weekday header + day grid, all on the
                      // same panel - not split into separately-shadowed
                      // cards. The day cells themselves stay plain so dates
                      // read clearly and taps land accurately.
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: GlassSurface(
                          radius: AppRadii.lg,
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  8,
                                ),
                                // Nested inside the calendar card, so it's a
                                // tinted inset tile rather than a second
                                // bordered/shadowed card.
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(
                                    AppSpacing.itemPadding,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.glass.insetFill,
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.md,
                                    ),
                                  ),
                                  child: _buildSummaryRow(monthlyReportAsync),
                                ),
                              ),
                              _buildCalendarGrid(
                                gridDays,
                                cycle,
                                monthlyReportAsync,
                                policyAlerts,
                                expenseRange,
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
    final glass = context.glass;
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
                        ? glass.negative
                        : (weekday == 6 ? glass.info : glass.textSecondary),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
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
    ({int min, int max}) expenseRange,
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
            // The grid moves the same way the finger does: going to the next
            // cycle (left-to-right drag / ">") slides everything rightward -
            // the new cycle enters from the left while the old one exits to
            // the right - and the previous cycle mirrors that. The outgoing
            // child runs this same tween in reverse, so it gets the opposite
            // start offset to exit in the same direction.
            transitionBuilder: (child, animation) {
              final shift = _lastCycleShiftDirection * 0.15;
              final isIncoming = child.key == ValueKey(_cycleOffset);
              return ClipRect(
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: Offset(isIncoming ? -shift : shift, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                ),
              );
            },
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
                            expenseRange,
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
    // The finger's net travel decides the direction whenever it is long
    // enough; release velocity only decides short flicks. Checking
    // "distance OR velocity" per side (left first) turned a left-to-right
    // drag that paused and drifted back on lift - positive distance but
    // negative release velocity - into a "previous cycle" swipe.
    final int direction;
    if (_horizontalDragDistance.abs() >= _swipeDistanceThreshold) {
      direction = _horizontalDragDistance.sign.toInt();
    } else if (velocity.abs() >= _swipeVelocityThreshold) {
      direction = velocity.sign.toInt();
    } else {
      direction = 0;
    }
    if (direction < 0) {
      _goToPreviousCycle();
    } else if (direction > 0) {
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
        ? '${context.formatWon(income!, withUnit: false)} 원'
        : '-';
    final expenseLabel = expense != null
        ? '${context.formatWon(expense!, withUnit: false)} 원'
        : '-';

    final glass = context.glass;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 18, color: glass.textPrimary),
                children: [
                  const TextSpan(text: '이번 달 '),
                  const TextSpan(
                    text: '무지출',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const TextSpan(text: ' '),
                  TextSpan(
                    text: '$noSpendLabel일',
                    style: TextStyle(
                      color: glass.accentText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Both sides shrink rather than overflow on narrow screens / large
        // system fonts.
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Text(
                      '+ 수입 ',
                      style: TextStyle(
                        color: glass.positive,
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
                          color: glass.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '- 지출 ',
                      style: TextStyle(
                        color: glass.negative,
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
                          color: glass.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryPlaceholderBar() {
    return Container(
      width: 64,
      height: 12,
      decoration: BoxDecoration(
        color: context.glass.track,
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

  // The cheapest and priciest spending days (expense > 0 only) within the
  // cycle currently on screen - the reference points every ring's color is
  // normalized against (see spendIntensityColor). Anchoring the low end to
  // the cycle's actual cheapest spend, not 0, is what keeps an ordinary day
  // from reading as almost-as-warm as a real outlier: without it, every
  // day's ratio gets compressed into a narrow band near the low end
  // whenever one day vastly outspends the rest. Deliberately relative to
  // what's visible rather than fixed won thresholds, since "a big spending
  // day" means something different cycle to cycle.
  ({int min, int max}) _expenseRangeInCycle(
    List<DateTime> gridDays,
    SalaryCycle cycle,
    AsyncValue<Map<DateTime, DailyReportEntry>> monthlyReportAsync,
  ) {
    final reportMap = monthlyReportAsync.asData?.value;
    if (reportMap == null) return (min: 0, max: 0);
    var maxExpense = 0;
    int? minExpense;
    for (final day in gridDays) {
      if (!cycle.contains(day)) continue;
      final expense =
          reportMap[DateTime(day.year, day.month, day.day)]?.expense ?? 0;
      if (expense <= 0) continue;
      if (expense > maxExpense) maxExpense = expense;
      if (minExpense == null || expense < minExpense) minExpense = expense;
    }
    return (min: minExpense ?? 0, max: maxExpense);
  }

  Widget _buildCalendarCell(
    DateTime day,
    SalaryCycle cycle,
    AsyncValue<Map<DateTime, DailyReportEntry>> monthlyReportAsync,
    Map<DateTime, List<PolicyAlert>> policyAlerts,
    ({int min, int max}) expenseRange,
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
    final glass = context.glass;

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
                  // shows a full ring. Its fill length still tracks
                  // spendingRatio (vs. the recommended daily amount), but its
                  // color is a separate signal - a continuous green->orange->
                  // red heat scale of this day's expense relative to the
                  // cycle's cheapest/priciest spending days (see
                  // spendIntensityColor).
                  if (ringRatio != null)
                    SpendingProgressRing(
                      ratio: ringRatio,
                      color: spendIntensityColor(
                        expense.toDouble(),
                        expenseRange.min.toDouble(),
                        expenseRange.max.toDouble(),
                      ),
                      size: 34,
                      strokeWidth: 2.5,
                    ),
                  // Inner: today's/selected date circle.
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? glass.accent : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${day.day}',
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : (isOutside
                                  ? glass.textTertiary.withValues(alpha: 0.6)
                                  : isToday
                                  // Today is findable by weight + brand
                                  // color, not a second ring that would
                                  // clash with the spending ring.
                                  ? glass.accentText
                                  : (day.weekday == 7
                                        ? glass.negative
                                        : glass.textPrimary)),
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
                  '+${context.formatWon(income, withUnit: false)}',
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: glass.positive,
                    fontSize: 8,
                    height: 1,
                  ),
                ),
              if (expense > 0)
                Text(
                  '-${context.formatWon(expense, withUnit: false)}',
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: glass.negative,
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
                    color: glass.accentSoft,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: glass.accent, width: 0.5),
                  ),
                  child: Text(
                    extraAlertCount > 0
                        ? '${policyAlertLabel(primaryAlert.type)} +$extraAlertCount'
                        : policyAlertLabel(primaryAlert.type),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: glass.accentText,
                      fontSize: 7,
                      fontWeight: FontWeight.w600,
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
