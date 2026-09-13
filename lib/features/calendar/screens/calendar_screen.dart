import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../../data/api/report_api.dart';
import '../../../data/api/transaction_api.dart';
import '../../home/theme/home_tokens.dart';
import '../../policy/providers/policy_provider.dart';
import '../../transaction/screens/add_transaction_screen.dart';
import '../widgets/day_detail_sheet.dart';

int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}

// One day of `/api/reports/daily`. The backend now returns `recommended`/
// `difference` per day (see API_SPEC.md), but per
// docs/backend/calendar-daily-spending-ratio-requirements.md section H, the
// current calculation applies one flat `dailyRecommended` to every date in
// the requested range instead of resolving each date's own BudgetCycle -
// wrong across a cycle boundary, which most calendar months cross. So
// `recommendedAmount`/`spendingRatio` stay nullable and unpopulated here
// until that per-date fix ships; the Calendar cell simply omits the
// percentage until then. income/expense parsing is unaffected either way.
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

final monthlyReportProvider = FutureProvider.family<Map<DateTime, DailyReportEntry>, DateTime>((ref, month) async {
  final reportApi = ref.watch(reportApiProvider);
  final startDate = DateTime(month.year, month.month, 1);
  final endDate = DateTime(month.year, month.month + 1, 0); // Last day of month

  // getDaily() now returns the full `{period, summary, daily}` envelope
  // (API_SPEC.md's `GET /api/reports/daily`), not a bare list - unwrap
  // `daily` here. `summary` isn't used: _buildSummaryRow recomputes
  // income/expense/no-spend-days itself from `daily` (see below), since the
  // backend's `summary` covers the whole requested range rather than "up to
  // today" like the Figma card wants.
  final data = await reportApi.getDaily(
    startDate: DateFormat('yyyy-MM-dd').format(startDate),
    endDate: DateFormat('yyyy-MM-dd').format(endDate),
  );
  final daily = data['daily'] as List<dynamic>? ?? const [];

  final Map<DateTime, DailyReportEntry> reportMap = {};
  for (var item in daily) {
    final date = DateTime.parse(item['date']);
    reportMap[DateTime(date.year, date.month, date.day)] = DailyReportEntry.fromJson(item as Map<String, dynamic>);
  }
  return reportMap;
});

final dailyTransactionsProvider = FutureProvider.family<List<dynamic>, DateTime>((ref, day) async {
  final txApi = ref.watch(transactionApiProvider);
  final dateStr = DateFormat('yyyy-MM-dd').format(day);
  try {
    final data = await txApi.getTransactions(startDate: dateStr, endDate: dateStr);
    if (data['items'] is List) return data['items'] as List<dynamic>;
    if (data['transactions'] is List) return data['transactions'] as List<dynamic>;
    return [];
  } catch (e) {
    return [];
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
// provider - it is a local, purely presentational fallback so the badge
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
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final monthStart = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final monthlyReportAsync = ref.watch(monthlyReportProvider(monthStart));
    // Policy application deadlines, reused from the existing recommended-policies
    // provider (already used by DayDetailSheet) so calendar D-N badges need
    // no new backend endpoint. Maps each day to the smallest remaining D-N
    // (0 = deadline day) for any policy whose deadline falls within the next
    // 5 days of that cell, matching Frame 25 policy D-5 / policy D-Day chips.
    final policyDday = _policyDdayByDay(ref);

    return Scaffold(
      backgroundColor: HomeTokens.pageBackground,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                children: [
                  // Header
                  Container(
                    decoration: const BoxDecoration(gradient: _headerGradient),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 22),
                                const SizedBox(width: 8),
                                const Text('캘린더', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.search, color: Colors.white),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                  onPressed: () {},
                                ),
                                const SizedBox(width: 20),
                                IconButton(
                                  icon: const Icon(Icons.notifications_none, color: Colors.white),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                  onPressed: () {},
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6DD9AB).withValues(alpha: 0.56),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.white),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2, offset: const Offset(0, 1))],
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.chevron_left, color: Colors.white),
                                    onPressed: () => setState(() => _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1)),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '${_focusedDay.year}. ${_focusedDay.month}. 25 ~ ${_focusedDay.year}. ${_focusedDay.month + 1}. 24.',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.chevron_right, color: Colors.white),
                                    onPressed: () => setState(() => _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Unified white card: summary row + calendar grid
                  Transform.translate(
                    offset: const Offset(0, -36),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                              child: _buildSummaryRow(monthlyReportAsync),
                            ),
                            TableCalendar(
                              firstDay: DateTime.utc(2020, 1, 1),
                              lastDay: DateTime.utc(2030, 12, 31),
                              focusedDay: _focusedDay,
                              availableGestures: AvailableGestures.horizontalSwipe,
                              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                              onDaySelected: (selectedDay, focusedDay) {
                                setState(() {
                                  _selectedDay = selectedDay;
                                  _focusedDay = focusedDay;
                                });
                                DayDetailSheet.show(context, selectedDay);
                              },
                              onPageChanged: (focusedDay) {
                                setState(() => _focusedDay = focusedDay);
                              },
                              headerVisible: false,
                              rowHeight: 70,
                              daysOfWeekHeight: 36,
                              daysOfWeekStyle: DaysOfWeekStyle(
                                weekendStyle: const TextStyle(color: HomeTokens.textFaint, fontWeight: FontWeight.bold),
                                weekdayStyle: TextStyle(color: HomeTokens.textDark.withValues(alpha: 0.8), fontWeight: FontWeight.bold),
                              ),
                              calendarBuilders: CalendarBuilders(
                                dowBuilder: (context, day) {
                                  final text = DateFormat.E('ko_KR').format(day);
                                  return Center(
                                    child: Text(text, style: TextStyle(
                                      color: day.weekday == 7 ? HomeTokens.negative : (day.weekday == 6 ? Colors.blue : HomeTokens.textDark),
                                      fontWeight: FontWeight.bold,
                                    )),
                                  );
                                },
                                defaultBuilder: (context, day, focusedDay) => _buildCalendarCell(day, monthlyReportAsync, policyDday),
                                todayBuilder: (context, day, focusedDay) => _buildCalendarCell(day, monthlyReportAsync, policyDday, isToday: true),
                                selectedBuilder: (context, day, focusedDay) => _buildCalendarCell(day, monthlyReportAsync, policyDday, isSelected: true),
                                outsideBuilder: (context, day, focusedDay) => _buildCalendarCell(day, monthlyReportAsync, policyDday, isOutside: true),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 72),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(colors: [Color(0xFF00AF76), Color(0xFFBFEBDD)]),
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: const [BoxShadow(color: Color(0x33606960), blurRadius: 5, offset: Offset(0, 5))],
          ),
          child: IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 22),
            onPressed: () => AddTransactionModal.show(context, initialDate: _selectedDay ?? _focusedDay),
          ),
        ),
      ),
    );
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
  Widget _buildSummaryRow(AsyncValue<Map<DateTime, DailyReportEntry>> monthlyReportAsync) {
    final isInitialLoad = monthlyReportAsync.isLoading && !monthlyReportAsync.hasValue;

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
    final incomeLabel = income != null ? '${NumberFormat('#,###').format(income)} 원' : '-';
    final expenseLabel = expense != null ? '${NumberFormat('#,###').format(expense)} 원' : '-';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 20, color: HomeTokens.textDark),
            children: [
              const TextSpan(text: '이번 달 '),
              const TextSpan(text: '무지출', style: TextStyle(fontWeight: FontWeight.w600)),
              const TextSpan(text: ' '),
              TextSpan(text: '$noSpendLabel일', style: const TextStyle(color: HomeTokens.accent, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              children: [
                const Text('+ 수입 ', style: TextStyle(color: HomeTokens.accent, fontWeight: FontWeight.bold, fontSize: 13)),
                if (isInitialLoad)
                  _summaryPlaceholderBar()
                else
                  Text(incomeLabel, style: TextStyle(color: HomeTokens.textDark.withValues(alpha: 0.8), fontSize: 13)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Text('- 지출 ', style: TextStyle(color: HomeTokens.negative, fontWeight: FontWeight.bold, fontSize: 13)),
                if (isInitialLoad)
                  _summaryPlaceholderBar()
                else
                  Text(expenseLabel, style: TextStyle(color: HomeTokens.textDark.withValues(alpha: 0.8), fontSize: 13)),
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

  // Maps each day to the smallest remaining D-N (0 = deadline day) for any
  // policy whose deadline falls within the next 5 days of that cell, using
  // the existing recommendedPoliciesProvider data (same source DayDetailSheet
  // already uses) for the Figma policy D-5 / policy D-Day badges. No new
  // backend call; the 5-day lookback keeps the badge range consistent with
  // Frame 25 D-5..D-Day examples instead of counting down from an
  // arbitrarily distant deadline.
  Map<DateTime, int> _policyDdayByDay(WidgetRef ref) {
    final recommendedAsync = ref.watch(recommendedPoliciesProvider);
    final map = <DateTime, int>{};
    recommendedAsync.whenData((data) {
      final policies = data['policies'] as List<dynamic>? ?? [];
      for (final p in policies) {
        if (p is! Map) continue;
        final deadline = p['applicationEndDate'] ?? p['deadline'];
        if (deadline is! String || deadline.isEmpty) continue;
        final end = DateTime.tryParse(deadline);
        if (end == null) continue;
        final endDay = DateTime(end.year, end.month, end.day);
        for (int n = 0; n <= 5; n++) {
          final day = endDay.subtract(Duration(days: n));
          final existing = map[day];
          if (existing == null || n < existing) map[day] = n;
        }
      }
    });
    return map;
  }

  Widget _buildCalendarCell(
    DateTime day,
    AsyncValue<Map<DateTime, DailyReportEntry>> monthlyReportAsync,
    Map<DateTime, int> policyDday, {
    bool isToday = false,
    bool isSelected = false,
    bool isOutside = false,
  }) {
    final entry = isOutside ? null : monthlyReportAsync.asData?.value[DateTime(day.year, day.month, day.day)];
    final income = entry?.income ?? 0;
    final expense = entry?.expense ?? 0;

    // spendingRatio only comes from the backend (DailyReportEntry.spendingRatio).
    // There is intentionally no frontend fallback formula here - see
    // docs/backend/calendar-daily-spending-ratio-requirements.md for why
    // today's recommendedAmount cannot be reused for past dates. The only
    // exception is the kDebugMode sample below, purely for Figma visual QA.
    double? spendingRatio = entry?.spendingRatio;
    if (spendingRatio == null && kDebugMode && !isOutside && expense > 0) {
      spendingRatio = _debugSampleSpendingRatios[day.day % _debugSampleSpendingRatios.length];
    }

    final dday = isOutside ? null : policyDday[DateTime(day.year, day.month, day.day)];
    final policyBadge = dday == null ? null : (dday == 0 ? '정책 D-Day' : '정책 D-$dday');

    return Container(
      margin: const EdgeInsets.all(2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? HomeTokens.accent : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${day.day}',
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : (isOutside ? HomeTokens.textMuted : (day.weekday == 7 ? HomeTokens.negative : HomeTokens.textDark)),
                fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ),
          if (!isOutside && (income > 0 || expense > 0)) ...[
            const SizedBox(height: 2),
            if (income > 0)
              Text('+${NumberFormat.compact().format(income)}',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: HomeTokens.accent, fontSize: 8, height: 1)),
            if (expense > 0)
              Text('-${NumberFormat.compact().format(expense)}',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: HomeTokens.negative, fontSize: 8, height: 1)),
          ],
          if (spendingRatio != null) ...[
            Text('${spendingRatio.round()}%',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: spendingRatio > 100 ? HomeTokens.negative : HomeTokens.textFaint,
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  height: 1,
                )),
          ],
          if (policyBadge != null) ...[
            const SizedBox(height: 1),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(
                color: HomeTokens.chipActiveBg,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: HomeTokens.accent, width: 0.5),
              ),
              child: Text(policyBadge, style: const TextStyle(color: HomeTokens.accent, fontSize: 7)),
            ),
          ],
        ],
      ),
    );
  }
}
