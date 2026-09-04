import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../../data/api/report_api.dart';
import '../../../data/api/transaction_api.dart';
import '../../home/providers/home_provider.dart';
import '../../transaction/screens/add_transaction_screen.dart';
import '../widgets/day_detail_sheet.dart';

int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}

final monthlyReportProvider = FutureProvider.family<Map<DateTime, dynamic>, DateTime>((ref, month) async {
  final reportApi = ref.watch(reportApiProvider);
  final startDate = DateTime(month.year, month.month, 1);
  final endDate = DateTime(month.year, month.month + 1, 0); // Last day of month

  final data = await reportApi.getDaily(
    startDate: DateFormat('yyyy-MM-dd').format(startDate),
    endDate: DateFormat('yyyy-MM-dd').format(endDate),
  );
  
  final Map<DateTime, dynamic> reportMap = {};
  for (var item in data) {
    final date = DateTime.parse(item['date']);
    reportMap[DateTime(date.year, date.month, date.day)] = item;
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          RichText(
                            text: TextSpan(
                              style: Theme.of(context).textTheme.bodyLarge,
                              children: const [
                                TextSpan(text: '이번 달 무지출 '),
                                TextSpan(text: '3일', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                children: [
                                  const Text('+ 수입 ', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text('1,000,000 원', style: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.8), fontSize: 13)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Text('- 지출 ', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text('500,000 원', style: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.8), fontSize: 13)),
                                ],
                              ),
                            ],
                          )
                        ],
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
                          rowHeight: 70, // Increased for sub-text
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
                            defaultBuilder: (context, day, focusedDay) => _buildCalendarCell(day, monthlyReportAsync, dailyBudget),
                            todayBuilder: (context, day, focusedDay) => _buildCalendarCell(day, monthlyReportAsync, dailyBudget, isToday: true),
                            selectedBuilder: (context, day, focusedDay) => _buildCalendarCell(day, monthlyReportAsync, dailyBudget, isSelected: true),
                            outsideBuilder: (context, day, focusedDay) => _buildCalendarCell(day, monthlyReportAsync, dailyBudget, isOutside: true),
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
    AsyncValue<Map<DateTime, dynamic>> monthlyReportAsync,
    int dailyBudget, {
    bool isToday = false,
    bool isSelected = false,
    bool isOutside = false,
  }) {
    int income = 0;
    int expense = 0;

    if (!isOutside) {
      final report = monthlyReportAsync.asData?.value[DateTime(day.year, day.month, day.day)];
      if (report is Map) {
        income = _toInt(report['income']);
        expense = _toInt(report['spent'] ?? report['expense']);
      }
    }

    final usageRatio = (!isOutside && dailyBudget > 0) ? (expense / dailyBudget).clamp(0.0, 1.0) : 0.0;
    final overBudget = dailyBudget > 0 && expense > dailyBudget;

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
                if (!isOutside && dailyBudget > 0)
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      value: usageRatio,
                      strokeWidth: 2.5,
                      backgroundColor: const Color(0xFFE5E7EB),
                      valueColor: AlwaysStoppedAnimation<Color>(overBudget ? AppColors.danger : AppColors.primary),
                    ),
                  ),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    shape: BoxShape.circle,
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
          ]
        ],
      ),
    );
  }
}
