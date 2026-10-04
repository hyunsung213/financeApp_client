import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'demo_catalog.dart';

/// The sample account behind the web demo (`DEMO_MODE=true`).
///
/// Everything lives in this browser only: the state is kept in memory and
/// mirrored to `SharedPreferences` (localStorage on the web) so a reload keeps
/// the visitor's edits. Nothing here is copied from a real account - the
/// transactions are generated from fixed templates relative to today.
class DemoStore {
  DemoStore._();

  static final DemoStore instance = DemoStore._();

  static const _storageKey = 'demo.state.v1';
  static const userId = 'demo-user';
  static const salaryAmount = 2500000;
  static const salaryDay = 25;

  Map<String, dynamic> setting = {};
  List<Map<String, dynamic>> plan = [];
  bool planConfigured = true;
  Map<String, dynamic> profile = {};
  List<Map<String, dynamic>> transactions = [];
  List<Map<String, dynamic>> customCategories = [];

  /// Per-category display overrides (displayName/icon/color) by category id,
  /// like the backend's UserCategoryPreference: system categories keep their
  /// canonical rows in demo_catalog.dart.
  Map<String, Map<String, dynamic>> categoryPreferences = {};
  List<Map<String, dynamic>> fixedExpenses = [];
  Map<String, String> bookmarks = {};
  Map<String, String> calendarEvents = {};
  int _nextId = 1;

  Future<void>? _loading;

  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    final stored = await _read();
    final storedPayday = ((stored?['setting'] as Map?)?['salaryDay'] as num?)
        ?.toInt();
    if (stored != null &&
        stored['cycleStart'] ==
            dateKey(cycleRange(DateTime.now(), storedPayday).start)) {
      _restore(stored);
    } else {
      // First visit, or the sample month has rolled over to a new pay cycle:
      // start again from fresh sample data around today.
      _seed(DateTime.now());
      await save();
    }
  }

  /// Drops the visitor's changes; the next request starts from fresh data.
  Future<void> reset() async {
    _loading = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (_) {
      // Storage can be unavailable (private mode); memory is reset anyway.
    }
  }

  String nextId(String prefix) => 'demo-$prefix-${_nextId++}';

  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storageKey,
        jsonEncode({
          'cycleStart': dateKey(cycleRange(DateTime.now()).start),
          'setting': setting,
          'plan': plan,
          'planConfigured': planConfigured,
          'profile': profile,
          'transactions': transactions,
          'customCategories': customCategories,
          'categoryPreferences': categoryPreferences,
          'fixedExpenses': fixedExpenses,
          'bookmarks': bookmarks,
          'calendarEvents': calendarEvents,
          'nextId': _nextId,
        }),
      );
    } catch (_) {
      // Without storage the demo still works; it just resets on reload.
    }
  }

  Future<Map<String, dynamic>?> _read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null) return null;
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  void _restore(Map<String, dynamic> s) {
    List<Map<String, dynamic>> rows(Object? v) => (v as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    setting = Map<String, dynamic>.from(s['setting'] as Map);
    plan = rows(s['plan']);
    planConfigured = s['planConfigured'] == true;
    profile = Map<String, dynamic>.from(s['profile'] as Map);
    transactions = rows(s['transactions']);
    customCategories = rows(s['customCategories']);
    categoryPreferences = {
      for (final e in (s['categoryPreferences'] as Map? ?? const {}).entries)
        '${e.key}': Map<String, dynamic>.from(e.value as Map),
    };
    fixedExpenses = rows(s['fixedExpenses']);
    bookmarks = Map<String, String>.from(s['bookmarks'] as Map? ?? const {});
    calendarEvents = Map<String, String>.from(
      s['calendarEvents'] as Map? ?? const {},
    );
    _nextId = (s['nextId'] as num?)?.toInt() ?? 1000;
  }

  // ---------------------------------------------------------------------------
  // Sample data

  void _seed(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final stamp = now.toUtc().toIso8601String();
    _nextId = 1;
    setting = {
      'salaryAmount': salaryAmount,
      'salaryDay': salaryDay,
      'reportingStartDay': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    };
    plan = [
      for (final (categoryId, percentage) in demoDefaultBudgetPlan)
        {'categoryId': categoryId, 'percentage': percentage},
    ];
    planConfigured = true;
    profile = {
      'nickname': '월릿 데모 사용자',
      'email': 'demo@wallet.example',
      'age': 27,
      'region': '서울',
    };
    customCategories = [];
    categoryPreferences = {};
    bookmarks = {};
    calendarEvents = {};
    transactions = [];

    // Two earlier pay cycles as well, so last month's report is complete.
    final current = cycleRange(today);
    final first = cycleRange(
      addDays(cycleRange(addDays(current.start, -1)).start, -1),
    );
    for (var day = first.start; !day.isAfter(today); day = addDays(day, 1)) {
      _seedDay(
        day,
        daysBetween(cycleRange(day).start, day),
        isToday: day == today,
      );
    }

    fixedExpenses = [
      _fixedExpense('core.expense.housing', '월세', 450000, salaryDay, today),
      _fixedExpense('core.expense.communication', '휴대폰 요금', 55000, 27, today),
      _fixedExpense(
        'core.expense.living.subscription',
        '음악 스트리밍',
        13900,
        30,
        today,
      ),
    ];
  }

  static const _lunches = [
    ('김치찌개 정식', 9000),
    ('회사 근처 백반', 8500),
    ('포케 샐러드', 11500),
    ('돈까스', 10500),
    ('비빔밥', 9500),
    ('쌀국수', 12000),
  ];

  void _seedDay(DateTime day, int cycleDay, {required bool isToday}) {
    void add(
      String categoryId,
      String type,
      int amount,
      String title, {
      String? evaluation,
    }) {
      transactions.add(
        newTransaction(
          categoryId: categoryId,
          type: type,
          amount: amount,
          occurredAt: dateKey(day),
          merchantOrTitle: title,
          consumptionEvaluation: evaluation,
          source: 'MANUAL',
          status: 'CONFIRMED',
          createdAt: DateTime(day.year, day.month, day.day, 20),
        ),
      );
    }

    // Today only gets everyday items, leaving most of the day's allowance for
    // the visitor to try adding their own.
    // Once per pay cycle.
    if (!isToday) {
      switch (cycleDay) {
        case 0:
          add('core.income.salary', 'INCOME', salaryAmount, '월급');
          add('core.expense.housing', 'EXPENSE', 450000, '월세');
        case 1:
          add('core.saving.installment', 'SAVING', 500000, '청년 적금 자동이체');
          add('core.investment.etf', 'SAVING', 250000, 'ETF 적립');
        case 2:
          add('core.expense.communication', 'EXPENSE', 55000, '휴대폰 요금');
        case 3:
          add(
            'core.expense.health.exercise',
            'EXPENSE',
            55000,
            '헬스장 월 이용권',
            evaluation: 'GOOD',
          );
        case 5:
          add('core.expense.living.subscription', 'EXPENSE', 13900, '음악 스트리밍');
        case 8:
          add(
            'core.expense.shopping.clothing',
            'EXPENSE',
            59000,
            '가을 니트',
            evaluation: 'REGRETTABLE',
          );
        case 10:
          add('core.expense.insurance-tax', 'EXPENSE', 42000, '실손보험');
        case 12:
          add(
            'core.expense.education.book',
            'EXPENSE',
            16800,
            '재테크 도서',
            evaluation: 'GOOD',
          );
        case 14:
          add('core.expense.living.utilities', 'EXPENSE', 38500, '관리비·공과금');
        case 17:
          add('core.expense.health.pharmacy', 'EXPENSE', 7800, '감기약');
        case 20:
          add(
            'core.expense.transport.taxi',
            'EXPENSE',
            13200,
            '야근 후 택시',
            evaluation: 'REGRETTABLE',
          );
      }
      if (cycleDay % 9 == 4) {
        add('core.expense.living.necessities', 'EXPENSE', 18900, '생필품 구매');
      }
    }

    final weekday = day.weekday;
    if (weekday <= DateTime.friday) {
      final (lunch, price) = _lunches[(day.day + day.month) % _lunches.length];
      add('core.expense.transport.public', 'EXPENSE', 2900, '출퇴근 교통비');
      add('core.expense.food.meal', 'EXPENSE', price, lunch);
      if (day.day.isEven && !isToday) {
        add('core.expense.food.cafe', 'EXPENSE', 4500, '아메리카노');
      }
      if (weekday == DateTime.wednesday && day.day % 3 == 0) {
        add(
          'core.expense.food.convenience',
          'EXPENSE',
          6300,
          '편의점 간식',
          evaluation: 'REGRETTABLE',
        );
      }
    } else if (weekday == DateTime.saturday) {
      add(
        'core.expense.food.delivery',
        'EXPENSE',
        23000,
        '치킨 배달',
        evaluation: day.day.isOdd ? 'REGRETTABLE' : null,
      );
      add('core.expense.relationship.friends', 'EXPENSE', 38000, '친구들과 저녁');
      if (day.day > 14) {
        add(
          'core.expense.leisure-culture.movie-performance',
          'EXPENSE',
          15000,
          '영화 관람',
          evaluation: 'GOOD',
        );
      }
    } else {
      add('core.expense.living.grocery', 'EXPENSE', 42000, '주간 장보기');
    }
  }

  Map<String, dynamic> _fixedExpense(
    String categoryId,
    String name,
    int amount,
    int billingDay,
    DateTime today,
  ) {
    final id = nextId('fixed');
    final lastDay = DateTime(today.year, today.month + 1, 0).day;
    final due = DateTime(
      today.year,
      today.month,
      billingDay > lastDay ? lastDay : billingDay,
    );
    return {
      'id': id,
      'userId': userId,
      'categoryId': categoryId,
      'name': name,
      'expectedAmount': '$amount',
      'billingDay': billingDay,
      'recurrenceType': 'MONTHLY',
      'startDate': dateKey(DateTime(today.year, today.month - 1, 1)),
      'endDate': null,
      'active': true,
      'occurrences': [
        {
          'id': nextId('occurrence'),
          'fixedExpenseId': id,
          'dueDate': dateKey(due),
          'expectedAmount': '$amount',
          'status': 'SCHEDULED',
          'matchedTransactionId': null,
        },
      ],
    };
  }

  /// A transaction row in the stored (not yet serialized) shape.
  Map<String, dynamic> newTransaction({
    required String categoryId,
    required String type,
    required int amount,
    required String occurredAt,
    required String merchantOrTitle,
    String? memo,
    String? consumptionEvaluation,
    required String source,
    required String status,
    DateTime? createdAt,
  }) {
    final created = (createdAt ?? DateTime.now()).toUtc().toIso8601String();
    return {
      'id': nextId('tx'),
      'userId': userId,
      'budgetCycleId': null,
      'categoryId': categoryId,
      'notificationId': null,
      'type': type,
      'amount': amount,
      'refundedAmount': 0,
      'occurredAt': occurredAt,
      'merchantOrTitle': merchantOrTitle,
      'memo': memo,
      'consumptionEvaluation': consumptionEvaluation,
      'consumptionEvaluationUpdatedAt': consumptionEvaluation == null
          ? null
          : created,
      'source': source,
      'status': status,
      'userEdited': false,
      'createdAt': created,
      'updatedAt': created,
    };
  }

  // ---------------------------------------------------------------------------
  // Dates (same rules as the backend's utils/dates.ts, in local time)

  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static DateTime parseDate(String key) {
    final p = key.substring(0, 10).split('-').map(int.parse).toList();
    return DateTime(p[0], p[1], p[2]);
  }

  static DateTime addDays(DateTime d, int days) =>
      DateTime(d.year, d.month, d.day + days);

  /// Whole calendar days from [from] to [to] (DST-safe).
  static int daysBetween(DateTime from, DateTime to) => DateTime.utc(
    to.year,
    to.month,
    to.day,
  ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

  static DateTime salaryDate(int year, int month, int day) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, day > lastDay ? lastDay : day);
  }

  int get currentSalaryDay =>
      (setting['salaryDay'] as num?)?.toInt() ?? salaryDay;

  /// The pay cycle containing [date]: from the latest payday on or before it
  /// to the day before the following payday.
  ({DateTime start, DateTime end}) cycleRange(DateTime date, [int? payday]) {
    final dayOfMonth = payday ?? currentSalaryDay;
    final day = DateTime(date.year, date.month, date.day);
    final thisMonth = salaryDate(day.year, day.month, dayOfMonth);
    final start = !day.isBefore(thisMonth)
        ? thisMonth
        : salaryDate(day.year, day.month - 1, dayOfMonth);
    final next = salaryDate(start.year, start.month + 1, dayOfMonth);
    return (start: start, end: addDays(next, -1));
  }
}
