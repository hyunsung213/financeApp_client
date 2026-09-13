import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../data/api/report_api.dart';
import '../../../data/api/transaction_api.dart';
import '../../home/providers/home_provider.dart';
import '../../policy/providers/policy_provider.dart';
import '../../transaction/screens/add_transaction_screen.dart';
import '../widgets/day_detail_sheet.dart';

int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}

class MonthlyReport {
  final Map<DateTime, dynamic> byDate;
  final int noSpendDays;
  final int totalIncome;
  final int totalExpense;

  MonthlyReport({
    required this.byDate,
    required this.noSpendDays,
    required this.totalIncome,
    required this.totalExpense,
  });
}

final monthlyReportProvider = FutureProvider.family<MonthlyReport, DateTime>((ref, month) async {
  final reportApi = ref.watch(reportApiProvider);
  final startDate = DateTime(month.year, month.month, 1);
  final endDate = DateTime(month.year, month.month + 1, 0); // Last day of month

  final data = await reportApi.getDaily(
    startDate: DateFormat('yyyy-MM-dd').format(startDate),
    endDate: DateFormat('yyyy-MM-dd').format(endDate),
  );

  final daily = data['daily'] as List<dynamic>? ?? const [];
  final summary = data['summary'] as Map<String, dynamic>? ?? const {};

  final Map<DateTime, dynamic> reportMap = {};
  for (var item in daily) {
    final date = DateTime.parse(item['date']);
    reportMap[DateTime(date.year, date.month, date.day)] = item;
  }
  return MonthlyReport(
    byDate: reportMap,
    noSpendDays: _toInt(summary['noSpendDays']),
    totalIncome: _toInt(summary['totalIncome']),
    totalExpense: _toInt(summary['totalExpense']),
  );
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
    // Daily usable budget: reuse the home dashboard's recommended-per-day amount as the gauge's 100%.
    final dailyBudget = ref.watch(homeDataProvider).asData?.value.recommendedAmount ?? 0;
    final policyCalendarEvents = ref.watch(policyCalendarEventsProvider).asData?.value ?? const [];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background Gradient
          Positioned(
            top: 0, left: 0, right: 0, height: 250,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [const Color(0xFFD4F7D4), AppColors.background],
                ),
              ),
            ),
          ),
          
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.account_balance_wallet, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text('캘린더', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(icon: const Icon(Icons.search), onPressed: () {}),
                            IconButton(icon: const Icon(Icons.notifications_none), onPressed: () {}),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Date Range Selector (Mockup format)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: () => setState(() => _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1)),
                          ),
                          Expanded(
                            child: Text(
                              '${_focusedDay.year}. ${_focusedDay.month}. 25 ~ ${_focusedDay.year}. ${_focusedDay.month + 1}. 24.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: () => setState(() => _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Summary Card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: monthlyReportAsync.when(
                        loading: () => const CalendarSummarySkeleton(),
                        error: (e, st) => Text('요약을 불러오지 못했어요', style: TextStyle(color: AppColors.textSecondary)),
                        data: (report) => Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            RichText(
                              text: TextSpan(
                                style: Theme.of(context).textTheme.bodyLarge,
                                children: [
                                  const TextSpan(text: '이번 달 무지출 '),
                                  TextSpan(text: '${report.noSpendDays}일', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  children: [
                                    const Text('+ 수입 ', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                                    Text('${NumberFormat('#,###').format(report.totalIncome)} 원', style: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.8), fontSize: 13)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Text('- 지출 ', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 13)),
                                    Text('${NumberFormat('#,###').format(report.totalExpense)} 원', style: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.8), fontSize: 13)),
                                  ],
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Custom Calendar and Transactions
                  Container(
                    color: Colors.white,
                    child: Column(
                      children: [
                        TableCalendar(
                          firstDay: DateTime.utc(2020, 1, 1),
                          lastDay: DateTime.utc(2030, 12, 31),
                          focusedDay: _focusedDay,
                          availableGestures: AvailableGestures.horizontalSwipe, // Prevent vertical swipe conflict
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
                          rowHeight: 82, // Increased for sub-text + policy deadline badge
                          daysOfWeekHeight: 40,
                          daysOfWeekStyle: DaysOfWeekStyle(
                            weekendStyle: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.6)),
                            weekdayStyle: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.6)),
                          ),
                          calendarBuilders: CalendarBuilders(
                            dowBuilder: (context, day) {
                              final text = DateFormat.E('ko_KR').format(day);
                              return Center(
                                child: Text(text, style: TextStyle(
                                  color: day.weekday == 7 ? AppColors.danger : (day.weekday == 6 ? Colors.blue : AppColors.textPrimary),
                                  fontWeight: FontWeight.bold,
                                )),
                              );
                            },
                            defaultBuilder: (context, day, focusedDay) => _buildCalendarCell(day, monthlyReportAsync, dailyBudget, policyCalendarEvents),
                            todayBuilder: (context, day, focusedDay) => _buildCalendarCell(day, monthlyReportAsync, dailyBudget, policyCalendarEvents, isToday: true),
                            selectedBuilder: (context, day, focusedDay) => _buildCalendarCell(day, monthlyReportAsync, dailyBudget, policyCalendarEvents, isSelected: true),
                            outsideBuilder: (context, day, focusedDay) => _buildCalendarCell(day, monthlyReportAsync, dailyBudget, policyCalendarEvents, isOutside: true),
                          ),
                        ),
                      ],
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
        child: FloatingActionButton(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 4,
          onPressed: () => AddTransactionModal.show(context, initialDate: _selectedDay ?? _focusedDay),
          child: const Icon(Icons.add, size: 28),
        ),
      ),
    );
  }

  Widget _buildCalendarCell(
    DateTime day,
    AsyncValue<MonthlyReport> monthlyReportAsync,
    int dailyBudget,
    List<Map<String, dynamic>> policyCalendarEvents, {
    bool isToday = false,
    bool isSelected = false,
    bool isOutside = false,
  }) {
    int income = 0;
    int expense = 0;
    String? policyBadge;

    if (!isOutside) {
      final report = monthlyReportAsync.asData?.value.byDate[DateTime(day.year, day.month, day.day)];
      if (report is Map) {
        income = _toInt(report['income']);
        expense = _toInt(report['spent'] ?? report['expense']);
      }

      final today = DateTime.now();
      for (final p in policyCalendarEvents) {
        final deadlineStr = (p['applicationEndDate'] ?? p['deadline'])?.toString();
        if (deadlineStr == null || deadlineStr.isEmpty) continue;
        final end = DateTime.tryParse(deadlineStr);
        if (end == null || end.year != day.year || end.month != day.month || end.day != day.day) continue;
        final daysLeft = DateTime(end.year, end.month, end.day)
            .difference(DateTime(today.year, today.month, today.day))
            .inDays;
        policyBadge = daysLeft <= 0 ? '정책 D-Day' : '정책 D-$daysLeft';
        break;
      }
    }

    final hasSpending = !isOutside && dailyBudget > 0 && expense > 0;
    final usageRatio = hasSpending ? (expense / dailyBudget).clamp(0.0, 1.0) : 0.0;
    final overBudget = hasSpending && expense > dailyBudget;

    return Container(
      margin: const EdgeInsets.all(2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (hasSpending)
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: CustomPaint(
                      painter: _GradientRingPainter(
                        progress: usageRatio,
                        gradientColors: overBudget
                            ? const [Color(0xFFFF8A65), AppColors.danger]
                            : const [Color(0xFF6EE7B7), AppColors.primary],
                      ),
                    ),
                  ),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    shape: BoxShape.circle,
                    border: (isToday && !isSelected) ? Border.all(color: AppColors.primary, width: 1.5) : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${day.day}',
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : (isOutside ? Colors.grey.shade400 : (day.weekday == 7 ? AppColors.danger : AppColors.textPrimary)),
                      fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
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
              Text('+${NumberFormat('#,###').format(income)}',
                  style: const TextStyle(color: AppColors.primary, fontSize: 8, height: 1)),
            if (expense > 0)
              Text('-${NumberFormat('#,###').format(expense)}',
                  style: const TextStyle(color: AppColors.danger, fontSize: 8, height: 1)),
          ],
          if (policyBadge != null) ...[
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: policyBadge == '정책 D-Day' ? AppColors.danger : AppColors.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(policyBadge, style: const TextStyle(color: Colors.white, fontSize: 7, height: 1.4, fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Paints the daily-spending gauge ring as a gradient arc instead of a flat
/// color, with no gray track drawn at all when there's nothing to show for
/// (caller only builds this when `hasSpending` is true).
class _GradientRingPainter extends CustomPainter {
  static const _strokeWidth = 2.5;

  final double progress;
  final List<Color> gradientColors;

  _GradientRingPainter({
    required this.progress,
    required this.gradientColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - _strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    if (sweep <= 0) return;

    final gradientPaint = Paint()
      ..shader = SweepGradient(
        colors: gradientColors,
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -math.pi / 2, sweep, false, gradientPaint);
  }

  @override
  bool shouldRepaint(covariant _GradientRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.gradientColors != gradientColors;
}
