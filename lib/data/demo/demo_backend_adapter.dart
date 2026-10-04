import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'demo_catalog.dart';
import 'demo_store.dart';

/// Answers the app's API calls in the browser for the web demo
/// (`DEMO_MODE=true`), so no request ever leaves the device.
///
/// It is plugged in as Dio's [HttpClientAdapter], below every `*Api` class,
/// providers and screen, which therefore run unchanged against it. Response
/// shapes follow the backend (`financeApp_backend/src/controllers`), and the
/// budget numbers follow its `dailyBudgetService` / `reportService` rules, so
/// the demo behaves like the app on sample data from [DemoStore].
class DemoBackendAdapter implements HttpClientAdapter {
  DemoBackendAdapter([DemoStore? store]) : _store = store ?? DemoStore.instance;

  final DemoStore _store;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    await _store.ensureLoaded();
    // A short pause keeps the app's loading states from flashing.
    await Future<void>.delayed(const Duration(milliseconds: 120));

    _DemoResponse result;
    try {
      result = _route(
        options.method.toUpperCase(),
        options.uri.path,
        options.uri.queryParameters,
        options.data is Map
            ? Map<String, dynamic>.from(options.data as Map)
            : const <String, dynamic>{},
      );
    } on _DemoError catch (e) {
      result = _DemoResponse(e.status, {
        'success': false,
        'error': {'code': e.code, 'message': e.message},
      });
    }
    if (result.mutated) await _store.save();

    return ResponseBody.fromString(
      jsonEncode(result.body),
      result.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}

  // ---------------------------------------------------------------------------
  // Routing

  _DemoResponse _route(
    String method,
    String path,
    Map<String, String> q,
    Map<String, dynamic> body,
  ) {
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.length < 2 || segments[0] != 'api') {
      throw _DemoError.notFound();
    }
    final rest = segments.sublist(1);
    final route = '$method /${rest.join('/')}';

    switch (route) {
      case 'GET /home':
        return _ok(_home());
      case 'GET /categories':
        return _ok([
          for (final c in _categories())
            if (c['isActive'] == true) _serializeCategory(c),
        ]);
      case 'POST /categories':
        return _created(_createCategory(body));
      case 'GET /finance/setting':
        return _ok(_serializeSetting());
      case 'PUT /finance/setting':
        return _ok(_updateSetting(body), mutated: true);
      case 'GET /finance/budget-plan':
        return _ok(_budgetPlan());
      case 'PUT /finance/budget-plan':
        return _ok(_updateBudgetPlan(body), mutated: true);
      case 'GET /profile':
        return _ok(_serializeProfile());
      case 'PUT /profile':
        return _ok(_updateProfile(body), mutated: true);
      case 'GET /transactions':
        return _ok(_listTransactions(q));
      case 'POST /transactions':
        return _created(_createTransaction(body));
      case 'GET /reports/summary':
        return _ok(_summary(q['startDate'], q['endDate']));
      case 'GET /reports/daily':
        return _ok(_daily(q['startDate'], q['endDate']));
      case 'GET /reports/monthly':
        return _ok(_monthly());
      case 'GET /reports/categories':
        return _ok(_categoryReport(q['startDate'], q['endDate']));
      case 'GET /reports/budget':
        return _ok(_budgetReport());
      case 'GET /reports/pace':
        final c = _context(DateTime.now());
        return _ok({
          'current': {
            'cycleStart': DemoStore.dateKey(c.start),
            'cycleEnd': DemoStore.dateKey(c.end),
            ...c.result,
          },
          'previous': null,
        });
      case 'GET /fixed-expenses':
        return _ok(_store.fixedExpenses);
      case 'POST /fixed-expenses':
        return _created(_createFixedExpense(body));
      case 'GET /policies':
        return _ok(_policies(q));
      case 'GET /policies/recommended':
        return _ok(_recommendedPolicies());
      case 'GET /policies/bookmarks':
        return _ok(_bookmarks());
      case 'GET /policies/calendar':
        return _ok(_calendarEvents());
    }

    // Parameterised routes.
    if (rest.length == 2 && rest[0] == 'transactions') {
      final id = rest[1];
      switch (method) {
        case 'GET':
          return _ok(_serializeTransaction(_findTransaction(id)));
        case 'PATCH':
          return _ok(_updateTransaction(id, body), mutated: true);
        case 'DELETE':
          _findTransaction(id);
          _store.transactions.removeWhere((t) => t['id'] == id);
          return _ok({'deleted': true}, mutated: true);
      }
    }
    if (rest.length == 2 && rest[0] == 'categories') {
      switch (method) {
        case 'PATCH':
          return _ok(_updateCategory(rest[1], body), mutated: true);
        case 'DELETE':
          return _ok(
            _updateCategory(rest[1], {'isActive': false}),
            mutated: true,
          );
      }
    }
    if (rest.length == 3 &&
        rest[0] == 'categories' &&
        rest[2] == 'preference' &&
        method == 'DELETE') {
      final category = _findCategory(rest[1]);
      _store.categoryPreferences.remove(rest[1]);
      return _ok(_serializeCategory(category), mutated: true);
    }
    if (rest.length >= 2 && rest[0] == 'policies') {
      final id = rest[1];
      final policy = _policyById(id);
      if (rest.length == 2 && method == 'GET') return _ok(policy);
      if (rest.length == 3 && rest[2] == 'bookmark') {
        if (method == 'POST') {
          _store.bookmarks[id] = DateTime.now().toUtc().toIso8601String();
          return _ok({'bookmarked': true}, mutated: true);
        }
        if (method == 'DELETE') {
          _store.bookmarks.remove(id);
          return _ok({'bookmarked': false}, mutated: true);
        }
      }
      if (rest.length == 3 && rest[2] == 'calendar') {
        if (method == 'POST') {
          final date = _requireDate(body['eventDate'], 'eventDate');
          _store.calendarEvents[id] = date;
          return _ok({'eventDate': date}, mutated: true);
        }
        if (method == 'DELETE') {
          _store.calendarEvents.remove(id);
          return _ok({'deleted': true}, mutated: true);
        }
      }
    }
    if (rest.length == 4 &&
        rest[0] == 'fixed-expenses' &&
        rest[1] == 'occurrences' &&
        rest[3] == 'match' &&
        method == 'POST') {
      return _ok(_matchOccurrence(rest[2], body), mutated: true);
    }
    throw _DemoError.notFound();
  }

  _DemoResponse _ok(Object? data, {bool mutated = false}) =>
      _DemoResponse(200, {'success': true, 'data': data}, mutated: mutated);

  _DemoResponse _created(Object? data) =>
      _DemoResponse(201, {'success': true, 'data': data}, mutated: true);

  // ---------------------------------------------------------------------------
  // Categories

  late final List<Map<String, dynamic>> _systemCategories = [
    for (final (id, name, type, purposeType, parent, sortOrder)
        in demoCategoryCatalog)
      {
        'id': id,
        'ownerUserId': null,
        'sourceCategoryId': null,
        'parentCategoryId': parent,
        'name': name,
        'type': type,
        'purposeType': purposeType,
        'isActive': true,
        'sortOrder': sortOrder,
        'isSystem': true,
        'isCustom': false,
        'systemCategoryId': null,
      },
  ];

  List<Map<String, dynamic>> _categories() {
    final all = [..._systemCategories, ..._store.customCategories];
    all.sort((a, b) {
      final bySort = (a['sortOrder'] as num).compareTo(b['sortOrder'] as num);
      return bySort != 0
          ? bySort
          : (a['name'] as String).compareTo(b['name'] as String);
    });
    return all;
  }

  Map<String, Map<String, dynamic>> get _categoryById => {
    for (final c in _categories()) c['id'] as String: c,
  };

  /// The 대분류 a category rolls up to (itself when it has no parent).
  String? _rootCategoryId(String? categoryId) {
    final byId = _categoryById;
    var current = byId[categoryId];
    final seen = <String>{};
    while (current?['parentCategoryId'] != null &&
        seen.add(current!['id'] as String)) {
      current = byId[current['parentCategoryId']];
    }
    return current?['id'] as String?;
  }

  Map<String, dynamic> _createCategory(Map<String, dynamic> body) {
    final name = (body['name'] ?? '').toString().trim();
    final type = (body['type'] ?? '').toString();
    if (name.isEmpty || !{'EXPENSE', 'INCOME', 'SAVING'}.contains(type)) {
      throw _DemoError.validation('카테고리 이름과 종류를 확인해주세요.');
    }
    final parentId = body['parentCategoryId'] as String?;
    if (parentId != null) {
      final parent = _categoryById[parentId];
      if (parent == null || parent['parentCategoryId'] != null) {
        throw _DemoError(400, 'INVALID_CATEGORY_PARENT', '상위 카테고리를 확인해주세요.');
      }
    }
    final category = {
      'id': _store.nextId('category'),
      'ownerUserId': DemoStore.userId,
      'sourceCategoryId': null,
      'parentCategoryId': parentId,
      'name': name,
      'type': type,
      'purposeType': body['purposeType'] ?? 'GENERAL',
      'isActive': true,
      'sortOrder': (body['sortOrder'] as num?)?.toInt() ?? 1000,
      'isSystem': false,
      'isCustom': true,
      'systemCategoryId': null,
    };
    _store.customCategories.add(category);
    _savePreference(category['id'] as String, {
      'icon': body['icon'],
      'color': body['color'],
    });
    return _serializeCategory(category);
  }

  Map<String, dynamic> _findCategory(String id) =>
      _categoryById[id] ??
      (throw _DemoError(404, 'CATEGORY_NOT_FOUND', '카테고리를 찾을 수 없어요.'));

  /// A category as `GET /api/categories` returns it: `name` is the user's
  /// display name, `canonicalName` the row's own (see the backend's
  /// CategoryService.serialize).
  Map<String, dynamic> _serializeCategory(Map<String, dynamic> category) {
    final preference =
        _store.categoryPreferences[category['id']] ?? const <String, dynamic>{};
    return {
      ...category,
      'name': preference['displayName'] ?? category['name'],
      'canonicalName': category['name'],
      'icon': preference['icon'],
      'color': preference['color'],
      'isCustomized': preference.values.any((v) => v != null),
    };
  }

  /// Merges [changes] (keys present = set, null = clear) into the category's
  /// override and drops it once nothing is overridden.
  void _savePreference(String id, Map<String, dynamic> changes) {
    final next = {...?_store.categoryPreferences[id], ...changes};
    if (next.values.every((v) => v == null)) {
      _store.categoryPreferences.remove(id);
    } else {
      _store.categoryPreferences[id] = next;
    }
  }

  static final _iconKey = RegExp(r'^[a-z0-9_]{1,40}$');
  static final _colorHex = RegExp(r'^#[0-9A-Fa-f]{6}$');

  /// Mirrors `PATCH /api/categories/:id`: a system category only takes a
  /// display name, icon and color, kept as the user's override (its row, id,
  /// parent and order never change, and it can't be deleted). The demo user's
  /// own categories rename in place; deleting deactivates, so transactions on
  /// the category keep resolving it.
  Map<String, dynamic> _updateCategory(String id, Map<String, dynamic> body) {
    final category = _findCategory(id);
    final isSystem = category['isSystem'] == true;
    if (isSystem &&
        (body.containsKey('parentCategoryId') ||
            body.containsKey('sortOrder') ||
            body.containsKey('isActive'))) {
      throw _DemoError(
        403,
        'SYSTEM_CATEGORY_IMMUTABLE',
        '기본 카테고리는 이름·아이콘·색상만 바꿀 수 있고 삭제할 수 없습니다.',
      );
    }
    final name = body['name']?.toString().trim();
    if (name != null && (name.isEmpty || name.length > 50)) {
      throw _DemoError.validation('카테고리 이름을 확인해주세요.');
    }
    final icon = body['icon'];
    if (icon != null && !_iconKey.hasMatch('$icon')) {
      throw _DemoError.validation('아이콘을 확인해주세요.');
    }
    final color = body['color'];
    if (color != null && !_colorHex.hasMatch('$color')) {
      throw _DemoError.validation('색상을 확인해주세요.');
    }

    final changes = <String, dynamic>{
      if (body.containsKey('icon')) 'icon': icon,
      if (body.containsKey('color')) 'color': color?.toString().toUpperCase(),
    };
    if (isSystem) {
      if (name != null) {
        changes['displayName'] = name == category['name'] ? null : name;
      }
    } else {
      if (name != null) category['name'] = name;
      if (body['isActive'] is bool) category['isActive'] = body['isActive'];
    }
    _savePreference(id, changes);
    return _serializeCategory(category);
  }

  // ---------------------------------------------------------------------------
  // Finance setting / budget plan / profile

  Map<String, dynamic> _serializeSetting() => {
    'userId': DemoStore.userId,
    ..._store.setting,
    'salaryAmount': '${_store.setting['salaryAmount']}',
  };

  Map<String, dynamic> _updateSetting(Map<String, dynamic> body) {
    final amount = (body['salaryAmount'] as num?)?.toInt();
    final day = (body['salaryDay'] as num?)?.toInt();
    final reportingDay = (body['reportingStartDay'] as num?)?.toInt();
    if (amount == null || amount < 0 || day == null || day < 1 || day > 31) {
      throw _DemoError.validation('월급 금액과 월급일을 확인해주세요.');
    }
    _store.setting = {
      ..._store.setting,
      'salaryAmount': amount,
      'salaryDay': day,
      'reportingStartDay': reportingDay ?? _store.setting['reportingStartDay'],
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };
    return _serializeSetting();
  }

  String _categoryName(String id) =>
      _categoryById[id]?['name'] as String? ?? id;

  List<Map<String, dynamic>> _serializePlan() => [
    for (final item in _store.plan)
      {...item, 'name': _categoryName(item['categoryId'] as String)},
  ];

  Map<String, dynamic> _budgetPlan() => {
    'isConfigured': _store.planConfigured,
    'salaryAmount': _salaryAmount,
    'allocations': _serializePlan(),
  };

  Map<String, dynamic> _updateBudgetPlan(Map<String, dynamic> body) {
    final items = (body['allocations'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (a) => {
            'categoryId': a['categoryId']?.toString(),
            'percentage': (a['percentage'] as num?) ?? -1,
          },
        )
        .toList();
    final planIds = [for (final (id, _) in demoDefaultBudgetPlan) id];
    final ids = items.map((i) => i['categoryId']).toSet();
    final total = items.fold<num>(0, (s, i) => s + (i['percentage'] as num));
    final valid =
        items.length == planIds.length &&
        ids.length == planIds.length &&
        planIds.every(ids.contains) &&
        items.every((i) => (i['percentage'] as num) >= 0) &&
        (total * 100).round() == 10000;
    if (!valid) {
      throw _DemoError.validation('예산 배분은 12개 항목의 합계가 100%여야 해요.');
    }
    items.sort(
      (a, b) => planIds
          .indexOf(a['categoryId'] as String)
          .compareTo(planIds.indexOf(b['categoryId'] as String)),
    );
    _store.plan = items;
    _store.planConfigured = true;
    return {
      'salaryAmount': _salaryAmount,
      'allocations': _serializePlan(),
      'effectiveFrom': 'CURRENT_CYCLE',
    };
  }

  Map<String, dynamic> _serializeProfile() => {
    'id': DemoStore.userId,
    'timezone': 'Asia/Seoul',
    ..._store.profile,
  };

  Map<String, dynamic> _updateProfile(Map<String, dynamic> body) {
    for (final key in const ['nickname', 'age', 'region']) {
      if (body.containsKey(key)) _store.profile[key] = body[key];
    }
    return _serializeProfile();
  }

  // ---------------------------------------------------------------------------
  // Transactions

  static const _evaluations = {'GOOD', 'NORMAL', 'REGRETTABLE', 'BAD'};
  static const _statuses = {'CONFIRMED', 'PENDING', 'EXCLUDED'};

  Map<String, dynamic> _findTransaction(String id) =>
      _store.transactions.firstWhere(
        (t) => t['id'] == id,
        orElse: () =>
            throw _DemoError(404, 'NOT_FOUND', 'Transaction not found'),
      );

  int _amountOf(Map<String, dynamic> t) => (t['amount'] as num).toInt();

  int _effectiveAmount(Map<String, dynamic> t) =>
      math.max(0, _amountOf(t) - ((t['refundedAmount'] as num?)?.toInt() ?? 0));

  Map<String, dynamic> _serializeTransaction(Map<String, dynamic> t) {
    final category = _categoryById[t['categoryId']];
    return {
      ...t,
      'amount': '${t['amount']}',
      'refundedAmount': '${t['refundedAmount'] ?? 0}',
      'category': category == null
          ? null
          : {
              for (final e in category.entries)
                if (!{
                  'isSystem',
                  'isCustom',
                  'systemCategoryId',
                }.contains(e.key))
                  e.key: e.value,
            },
      'effectiveAmount': _effectiveAmount(t),
    };
  }

  Map<String, dynamic> _listTransactions(Map<String, String> q) {
    final page = math.max(1, int.tryParse(q['page'] ?? '') ?? 1);
    final limit = (int.tryParse(q['limit'] ?? '') ?? 50).clamp(1, 100);
    final evaluations = q['evaluation']
        ?.split(',')
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toSet();
    final start = q['startDate'];
    final end = q['endDate'];

    final rows = _store.transactions.where((t) {
      final date = t['occurredAt'] as String;
      return (q['categoryId'] == null || t['categoryId'] == q['categoryId']) &&
          (q['type'] == null || t['type'] == q['type']) &&
          (q['status'] == null || t['status'] == q['status']) &&
          (evaluations == null ||
              evaluations.isEmpty ||
              evaluations.contains(t['consumptionEvaluation'])) &&
          (start == null || date.compareTo(start) >= 0) &&
          (end == null || date.compareTo(end) <= 0);
    }).toList();

    const sortable = {
      'occurredAt',
      'consumptionEvaluationUpdatedAt',
      'createdAt',
    };
    final sortKey = sortable.contains(q['sort']) ? q['sort']! : 'occurredAt';
    final ascending = q['order']?.toUpperCase() == 'ASC';
    rows.sort((a, b) {
      final av = a[sortKey] as String?;
      final bv = b[sortKey] as String?;
      var cmp = av == null
          ? (bv == null ? 0 : -1)
          : bv == null
          ? 1
          : av.compareTo(bv);
      if (cmp == 0) {
        cmp = (a['createdAt'] as String).compareTo(b['createdAt'] as String);
      }
      return ascending ? cmp : -cmp;
    });

    final from = (page - 1) * limit;
    return {
      'items': rows.skip(from).take(limit).map(_serializeTransaction).toList(),
      'page': page,
      'limit': limit,
      'total': rows.length,
    };
  }

  Map<String, dynamic> _requireCategoryFor(String? categoryId, String type) {
    final category = _categoryById[categoryId];
    if (category == null) {
      throw _DemoError(400, 'INVALID_CATEGORY', 'Category not found');
    }
    if (category['type'] != type) {
      throw _DemoError(
        400,
        'INVALID_CATEGORY',
        'Transaction type must match the category type',
      );
    }
    return category;
  }

  String _requireDate(Object? value, String field) {
    final text = value?.toString() ?? '';
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) {
      throw _DemoError.validation('$field must use YYYY-MM-DD format');
    }
    return text;
  }

  Map<String, dynamic> _createTransaction(Map<String, dynamic> body) {
    final type = (body['type'] ?? '').toString();
    final category = _requireCategoryFor(body['categoryId'] as String?, type);
    // Same rule as the backend: new transactions land on a 소분류.
    if (category['parentCategoryId'] == null && category['isCustom'] != true) {
      throw _DemoError(400, 'INVALID_CATEGORY', '세부 카테고리를 선택해주세요.');
    }
    final amount = (body['amount'] as num?)?.toInt() ?? 0;
    if (amount <= 0) throw _DemoError.validation('금액을 확인해주세요.');
    final status = (body['status'] ?? 'CONFIRMED').toString();
    final evaluation = body['consumptionEvaluation'] as String?;
    if (!_statuses.contains(status) ||
        (evaluation != null && !_evaluations.contains(evaluation))) {
      throw _DemoError.validation('입력값을 확인해주세요.');
    }
    final row = _store.newTransaction(
      categoryId: category['id'] as String,
      type: type,
      amount: amount,
      occurredAt: _requireDate(body['occurredAt'], 'occurredAt'),
      merchantOrTitle: (body['merchantOrTitle'] ?? category['name']).toString(),
      memo: body['memo'] as String?,
      consumptionEvaluation: evaluation,
      source: (body['source'] ?? 'MANUAL').toString(),
      status: status,
    )..['userEdited'] = true;
    _store.transactions.add(row);
    return _serializeTransaction(row);
  }

  Map<String, dynamic> _updateTransaction(
    String id,
    Map<String, dynamic> body,
  ) {
    final row = _findTransaction(id);
    final type = (body['type'] ?? row['type']).toString();
    final categoryId = (body['categoryId'] ?? row['categoryId']) as String;
    _requireCategoryFor(categoryId, type);
    final now = DateTime.now().toUtc().toIso8601String();
    final evaluation = body.containsKey('consumptionEvaluation')
        ? body['consumptionEvaluation'] as String?
        : row['consumptionEvaluation'] as String?;
    if (evaluation != null && !_evaluations.contains(evaluation)) {
      throw _DemoError.validation('입력값을 확인해주세요.');
    }
    if (evaluation != row['consumptionEvaluation']) {
      row['consumptionEvaluationUpdatedAt'] = evaluation == null ? null : now;
    }
    if (body['amount'] != null) {
      final amount = (body['amount'] as num).toInt();
      if (amount <= 0) throw _DemoError.validation('금액을 확인해주세요.');
      row['amount'] = amount;
    }
    if (body['occurredAt'] != null) {
      row['occurredAt'] = _requireDate(body['occurredAt'], 'occurredAt');
    }
    for (final key in const ['memo', 'status', 'merchantOrTitle']) {
      if (body[key] != null) row[key] = body[key];
    }
    row
      ..['type'] = type
      ..['categoryId'] = categoryId
      ..['consumptionEvaluation'] = evaluation
      ..['userEdited'] = true
      ..['updatedAt'] = now;
    return _serializeTransaction(row);
  }

  // ---------------------------------------------------------------------------
  // Budget (ports of the backend's DailyBudgetService / ReportService.context)

  static const _savingId = 'core.saving';
  static const _investmentId = 'core.investment';
  static const _fixedId = 'core.expense.fixed';

  bool _isExpenseBudget(String id) => id.startsWith('core.expense.');
  bool _isDailySpendable(String id) => _isExpenseBudget(id) && id != _fixedId;

  int get _salaryAmount =>
      (_store.setting['salaryAmount'] as num?)?.toInt() ?? 0;

  bool _isSalary(Map<String, dynamic> t) =>
      t['categoryId'] == 'core.income.salary';

  /// Plan amounts for [total], rounding remainder added to 기타 (as the
  /// backend's `amountsFor`).
  Map<String, int> _allocationAmounts(int total) {
    final amounts = <String, int>{
      for (final item in _store.plan)
        item['categoryId'] as String:
            (total * (item['percentage'] as num) / 100).floor(),
    };
    final target = amounts.containsKey('core.expense.other')
        ? 'core.expense.other'
        : amounts.keys.last;
    amounts[target] =
        amounts[target]! + total - amounts.values.fold(0, (s, v) => s + v);
    return amounts;
  }

  List<Map<String, dynamic>> _between(String start, String end) =>
      _store.transactions.where((t) {
        final date = t['occurredAt'] as String;
        return date.compareTo(start) >= 0 && date.compareTo(end) <= 0;
      }).toList();

  /// Budget state of the current pay cycle as seen on [asOf].
  ({DateTime start, DateTime end, Map<String, dynamic> result}) _context(
    DateTime asOf,
  ) {
    final now = DateTime.now();
    final cycle = _store.cycleRange(now);
    final startKey = DemoStore.dateKey(cycle.start);
    final endKey = DemoStore.dateKey(cycle.end);
    final inCycle = _between(startKey, endKey);

    // Additional (non-salary) income raises the distributable total.
    final additional = inCycle
        .where(
          (t) =>
              t['type'] == 'INCOME' &&
              t['status'] == 'CONFIRMED' &&
              !_isSalary(t),
        )
        .fold<int>(0, (s, t) => s + _amountOf(t));
    final salary = _salaryAmount + additional;
    final allocations = _allocationAmounts(salary);

    var today = DateTime(asOf.year, asOf.month, asOf.day);
    if (today.isBefore(cycle.start)) today = cycle.start;
    if (today.isAfter(cycle.end)) today = cycle.end;
    final todayKey = DemoStore.dateKey(today);
    final cycleDays = DemoStore.daysBetween(cycle.start, cycle.end) + 1;
    final elapsedDays = DemoStore.daysBetween(cycle.start, today) + 1;
    final remainingDays = math.max(
      1,
      DemoStore.daysBetween(today, cycle.end) + 1,
    );

    final expenses = inCycle.where(
      (t) =>
          t['status'] == 'CONFIRMED' &&
          t['type'] == 'EXPENSE' &&
          (t['occurredAt'] as String).compareTo(todayKey) <= 0,
    );
    final spentByCategory = <String, int>{};
    var todayVariable = 0;
    for (final t in expenses) {
      final root = _rootCategoryId(t['categoryId'] as String?);
      if (root == null || !_isExpenseBudget(root)) continue;
      spentByCategory[root] =
          (spentByCategory[root] ?? 0) + _effectiveAmount(t);
      if (_isDailySpendable(root) && t['occurredAt'] == todayKey) {
        todayVariable += _effectiveAmount(t);
      }
    }

    final categoryProgress = [
      for (final item in _store.plan)
        if (_isExpenseBudget(item['categoryId'] as String))
          () {
            final id = item['categoryId'] as String;
            final planned = allocations[id] ?? 0;
            final spent = spentByCategory[id] ?? 0;
            return {
              'categoryId': id,
              'plannedAmount': planned,
              'spentAmount': spent,
              'remainingAmount': planned - spent,
              'usageRate': planned == 0 ? 0 : spent / planned * 100,
            };
          }(),
    ];
    final usable = categoryProgress.where(
      (c) => _isDailySpendable(c['categoryId'] as String),
    );
    final usableBudget = usable.fold<int>(
      0,
      (s, c) => s + (c['plannedAmount'] as int),
    );
    final variableExpense = usable.fold<int>(
      0,
      (s, c) => s + (c['spentAmount'] as int),
    );
    final remainingUsable = usableBudget - variableExpense;
    final todayRecommended = math.max(0, remainingUsable ~/ remainingDays);
    final plannedToDate = usableBudget * elapsedDays ~/ cycleDays;
    final difference = plannedToDate - variableExpense;
    final tolerance = math.max(1, (usableBudget * 0.02).floor());
    final dailyAverage = variableExpense ~/ elapsedDays;
    final projected =
        variableExpense + dailyAverage * math.max(0, cycleDays - elapsedDays);
    final expectedRemaining = usableBudget - projected;

    return (
      start: cycle.start,
      end: cycle.end,
      result: {
        'cycleDays': cycleDays,
        'elapsedDays': elapsedDays,
        'remainingDays': remainingDays,
        'salaryAmount': salary,
        'savingBudgetAmount': allocations[_savingId] ?? 0,
        'investmentBudgetAmount': allocations[_investmentId] ?? 0,
        'fixedExpenseBudgetAmount': allocations[_fixedId] ?? 0,
        'usableBudgetAmount': usableBudget,
        'variableExpenseAmount': variableExpense,
        'fixedExpenseAmount': spentByCategory[_fixedId] ?? 0,
        'remainingUsableAmount': remainingUsable,
        'todayVariableExpenseAmount': todayVariable,
        'todayRecommendedAmount': todayRecommended,
        'remainingTodayAmount': todayRecommended - todayVariable,
        'categoryProgress': categoryProgress,
        'budgetStatus': remainingUsable < 0 ? 'OVER_BUDGET' : 'ON_TRACK',
        'plannedSpendToDate': plannedToDate,
        'actualSpendToDate': variableExpense,
        'difference': difference,
        'paceStatus': difference > tolerance
            ? 'UNDER'
            : difference < -tolerance
            ? 'OVER'
            : 'ON_TRACK',
        'currentDailyAverage': dailyAverage,
        'projectedTotalSpend': projected,
        'expectedRemainingAmount': expectedRemaining,
        'potentialExtraSaving': math.max(0, expectedRemaining),
        'confidence': elapsedDays <= 2
            ? 'LOW'
            : elapsedDays <= 7
            ? 'MEDIUM'
            : 'HIGH',
        'sampleDays': elapsedDays,
      },
    );
  }

  Map<String, dynamic> _home() {
    final c = _context(DateTime.now());
    final r = c.result;
    return {
      'salaryDay': _store.currentSalaryDay,
      'nextSalaryDate': DemoStore.dateKey(DemoStore.addDays(c.end, 1)),
      'daysUntilSalary': r['remainingDays'],
      'cycle': {
        'startDate': DemoStore.dateKey(c.start),
        'projectedEndDate': DemoStore.dateKey(c.end),
        'status': 'ACTIVE',
      },
      'today': {
        'recommendedAmount': r['todayRecommendedAmount'],
        'spentAmount': r['todayVariableExpenseAmount'],
        'remainingToday': r['remainingTodayAmount'],
      },
      'budget': {
        'calculationMode': 'CATEGORY_PERCENTAGE_ALLOCATION',
        for (final key in const [
          'salaryAmount',
          'savingBudgetAmount',
          'investmentBudgetAmount',
          'fixedExpenseBudgetAmount',
          'usableBudgetAmount',
          'variableExpenseAmount',
          'fixedExpenseAmount',
          'remainingUsableAmount',
        ])
          key: r[key],
        'categories': r['categoryProgress'],
      },
      'pace': {'status': r['paceStatus'], 'difference': r['difference']},
      'savingProjection': {
        'potentialExtraSaving': r['potentialExtraSaving'],
        'confidence': r['confidence'],
        'sampleDays': r['sampleDays'],
      },
    };
  }

  // ---------------------------------------------------------------------------
  // Reports

  DateTime _asOf(String? end) =>
      end == null ? DateTime.now() : DemoStore.parseDate(end);

  List<Map<String, dynamic>> _confirmedIn(String? start, String? end) =>
      _store.transactions.where((t) {
        final date = t['occurredAt'] as String;
        return t['status'] == 'CONFIRMED' &&
            (start == null || date.compareTo(start) >= 0) &&
            (end == null || date.compareTo(end) <= 0);
      }).toList();

  String? _purposeOf(Map<String, dynamic> t) =>
      _categoryById[t['categoryId']]?['purposeType'] as String?;

  Map<String, dynamic> _summary(String? start, String? end) {
    final c = _context(_asOf(end));
    final rows = start == null && end == null
        ? _confirmedIn(DemoStore.dateKey(c.start), DemoStore.dateKey(c.end))
        : _confirmedIn(start, end);
    int total(bool Function(Map<String, dynamic>) test) =>
        rows.where(test).fold(0, (s, t) => s + _effectiveAmount(t));
    return {
      'income': total((t) => t['type'] == 'INCOME'),
      'expense': total((t) => t['type'] == 'EXPENSE'),
      'saving': total(
        (t) => t['type'] == 'SAVING' && _purposeOf(t) == 'SAVING',
      ),
      'investment': total(
        (t) => t['type'] == 'SAVING' && _purposeOf(t) == 'INVESTMENT',
      ),
      'remainingAvailableAmount': c.result['remainingUsableAmount'],
    };
  }

  Map<String, dynamic> _daily(String? start, String? end) {
    final c = _context(_asOf(end));
    final from = start == null ? c.start : DemoStore.parseDate(start);
    final to = end == null ? c.end : DemoStore.parseDate(end);
    final income = <String, int>{};
    final expense = <String, int>{};
    for (final t in _confirmedIn(
      DemoStore.dateKey(from),
      DemoStore.dateKey(to),
    )) {
      final target = switch (t['type']) {
        'INCOME' => income,
        'EXPENSE' => expense,
        _ => null,
      };
      if (target == null) continue;
      final key = t['occurredAt'] as String;
      target[key] = (target[key] ?? 0) + _effectiveAmount(t);
    }
    final usable = c.result['usableBudgetAmount'] as int;
    final recommended = usable == 0
        ? 0
        : usable ~/ (c.result['cycleDays'] as int);
    var noSpendDays = 0, noActivityDays = 0, totalIncome = 0, totalExpense = 0;
    final rows = <Map<String, dynamic>>[];
    for (var d = from; !d.isAfter(to); d = DemoStore.addDays(d, 1)) {
      final key = DemoStore.dateKey(d);
      final inc = income[key] ?? 0;
      final exp = expense[key] ?? 0;
      if (exp == 0) noSpendDays++;
      if (inc == 0 && exp == 0) noActivityDays++;
      totalIncome += inc;
      totalExpense += exp;
      rows.add({
        'date': key,
        'income': inc,
        'expense': exp,
        'spent': exp,
        'recommended': recommended,
        'difference': exp - recommended,
      });
    }
    return {
      'period': {
        'startDate': DemoStore.dateKey(from),
        'endDate': DemoStore.dateKey(to),
      },
      'summary': {
        'totalIncome': totalIncome,
        'totalExpense': totalExpense,
        'noSpendDays': noSpendDays,
        'noActivityDays': noActivityDays,
      },
      'daily': rows,
    };
  }

  List<Map<String, dynamic>> _monthly() {
    final byMonth = <String, Map<String, int>>{};
    for (final t in _confirmedIn(null, null)) {
      final month = (t['occurredAt'] as String).substring(0, 7);
      final row = byMonth.putIfAbsent(
        month,
        () => {'income': 0, 'expense': 0, 'saving': 0, 'investment': 0},
      );
      final key = switch (t['type']) {
        'INCOME' => 'income',
        'EXPENSE' => 'expense',
        _ => _purposeOf(t) == 'INVESTMENT' ? 'investment' : 'saving',
      };
      row[key] = row[key]! + _effectiveAmount(t);
    }
    final months = byMonth.keys.toList()..sort();
    return [
      for (final m in months) {'month': m, ...byMonth[m]!},
    ];
  }

  List<Map<String, dynamic>> _categoryReport(String? start, String? end) {
    final rows = <String, Map<String, dynamic>>{};
    var total = 0;
    for (final t in _confirmedIn(start, end)) {
      if (t['type'] != 'EXPENSE') continue;
      final amount = _effectiveAmount(t);
      total += amount;
      final id = t['categoryId'] as String;
      final category = _categoryById[id];
      final row = rows.putIfAbsent(
        id,
        () => {
          'categoryId': id,
          'category': category?['name'] ?? '기타',
          'parentCategoryId': category?['parentCategoryId'],
          'amount': 0,
          'transactionCount': 0,
        },
      );
      row['amount'] = (row['amount'] as int) + amount;
      row['transactionCount'] = (row['transactionCount'] as int) + 1;
    }
    return [
      for (final row in rows.values)
        {
          ...row,
          'percentage': total == 0 ? 0 : (row['amount'] as int) / total * 100,
        },
    ];
  }

  Map<String, dynamic> _budgetReport() {
    final c = _context(DateTime.now());
    final percentages = {
      for (final item in _store.plan)
        item['categoryId'] as String: item['percentage'],
    };
    return {
      'cycle': {
        'startDate': DemoStore.dateKey(c.start),
        'endDate': DemoStore.dateKey(c.end),
        'salaryAmount': c.result['salaryAmount'],
      },
      'categories': [
        for (final p in c.result['categoryProgress'] as List)
          {
            ...p as Map<String, dynamic>,
            'name': _categoryName(p['categoryId'] as String),
            'percentage': percentages[p['categoryId']] ?? 0,
          },
      ],
      'saving': {
        'plannedAmount': c.result['savingBudgetAmount'],
        'percentage': percentages[_savingId] ?? 0,
      },
      'investment': {
        'plannedAmount': c.result['investmentBudgetAmount'],
        'percentage': percentages[_investmentId] ?? 0,
      },
    };
  }

  // ---------------------------------------------------------------------------
  // Fixed expenses

  Map<String, dynamic> _createFixedExpense(Map<String, dynamic> body) {
    final amount = (body['expectedAmount'] as num?)?.toInt() ?? 0;
    final day = (body['billingDay'] as num?)?.toInt() ?? 0;
    if (amount <= 0 || day < 1 || day > 31) {
      throw _DemoError.validation('금액과 결제일을 확인해주세요.');
    }
    final row = {
      'id': _store.nextId('fixed'),
      'userId': DemoStore.userId,
      ...body,
      'expectedAmount': '$amount',
      'active': true,
      'occurrences': <Map<String, dynamic>>[],
    };
    _store.fixedExpenses.add(row);
    return row;
  }

  Map<String, dynamic> _matchOccurrence(
    String occurrenceId,
    Map<String, dynamic> body,
  ) {
    for (final expense in _store.fixedExpenses) {
      for (final o in (expense['occurrences'] as List).cast<Map>()) {
        if (o['id'] == occurrenceId) {
          o['status'] = 'MATCHED';
          o['matchedTransactionId'] = body['transactionId'];
          return Map<String, dynamic>.from(o);
        }
      }
    }
    throw _DemoError(404, 'NOT_FOUND', 'Occurrence not found');
  }

  // ---------------------------------------------------------------------------
  // Policies (a few illustrative sample entries, labelled as 예시)

  late final List<Map<String, dynamic>> _samplePolicies = _buildPolicies();

  List<Map<String, dynamic>> _buildPolicies() {
    final today = DateTime.now();
    String offset(int days) =>
        DemoStore.dateKey(DemoStore.addDays(today, days));
    String dotted(String key) => key.replaceAll('-', '.');
    Map<String, dynamic> policy({
      required String id,
      required String title,
      required String category,
      required String summary,
      required String benefit,
      required int ageMin,
      required int ageMax,
      required String region,
      required int startOffset,
      required int endOffset,
    }) {
      final start = offset(startOffset);
      final end = offset(endOffset);
      final daysLeft = endOffset;
      return {
        'id': id,
        'title': title,
        'provider': '월릿 데모',
        'providerType': 'PUBLIC',
        'category': category,
        'summary': summary,
        'description': '$summary\n\n월릿 데모에서 보여주는 예시 정책이에요.',
        'ageMin': ageMin,
        'ageMax': ageMax,
        'region': region,
        'applicationStartDate': start,
        'applicationEndDate': end,
        'applicationUrl': null,
        'sourceUrl': null,
        'presentation': {
          'badgeText': '예시 정책',
          'headline': title,
          'summary': summary,
          'targetText': '만 $ageMin~$ageMax세 · $region',
          'benefitText': benefit,
          'applicationText': '신청기간 ${dotted(start)} ~ ${dotted(end)}',
          'categoryText': category,
          'deadlineLabel': daysLeft <= 0 ? '마감' : 'D-$daysLeft',
        },
      };
    }

    return [
      policy(
        id: 'demo-policy-rent',
        title: '청년 월세 지원 (예시)',
        category: '주거',
        summary: '무주택 청년의 월세 부담을 덜어주는 지원 예시예요.',
        benefit: '월 최대 20만 원, 최대 12개월',
        ageMin: 19,
        ageMax: 34,
        region: '전국',
        startOffset: -10,
        endOffset: 20,
      ),
      policy(
        id: 'demo-policy-saving',
        title: '청년 자산형성 적금 (예시)',
        category: '금융',
        summary: '매달 저축하면 기여금을 더해주는 적금 예시예요.',
        benefit: '납입액의 일정 비율 매칭 적립',
        ageMin: 19,
        ageMax: 34,
        region: '전국',
        startOffset: -3,
        endOffset: 6,
      ),
      policy(
        id: 'demo-policy-job',
        title: '청년 구직활동 지원금 (예시)',
        category: '일자리',
        summary: '구직 중인 청년의 활동비를 지원하는 예시예요.',
        benefit: '월 50만 원, 최대 6개월',
        ageMin: 18,
        ageMax: 34,
        region: '서울',
        startOffset: -20,
        endOffset: 35,
      ),
      policy(
        id: 'demo-policy-culture',
        title: '청년 문화패스 (예시)',
        category: '문화',
        summary: '공연·전시 관람비를 지원하는 예시예요.',
        benefit: '연 최대 15만 원 문화비',
        ageMin: 19,
        ageMax: 20,
        region: '전국',
        startOffset: 5,
        endOffset: 60,
      ),
    ];
  }

  Map<String, dynamic> _policyById(String id) => _samplePolicies.firstWhere(
    (p) => p['id'] == id,
    orElse: () => throw _DemoError(404, 'NOT_FOUND', 'Policy not found'),
  );

  List<Map<String, dynamic>> _policies(Map<String, String> q) {
    final age = int.tryParse(q['age'] ?? '');
    final keyword = q['keyword']?.trim();
    return _samplePolicies.where((p) {
      return (q['category'] == null || p['category'] == q['category']) &&
          (q['region'] == null ||
              p['region'] == q['region'] ||
              p['region'] == '전국') &&
          (age == null ||
              (age >= (p['ageMin'] as int) && age <= (p['ageMax'] as int))) &&
          (keyword == null ||
              keyword.isEmpty ||
              '${p['title']} ${p['summary']}'.contains(keyword));
    }).toList();
  }

  Map<String, dynamic> _recommendedPolicies() {
    final age = _store.profile['age'];
    final region = _store.profile['region'];
    if (age == null || region == null) {
      throw _DemoError(409, 'PROFILE_REQUIRED', '나이와 지역을 먼저 입력해주세요.');
    }
    return {
      'profile': {'age': age, 'region': region},
      'policies': _policies({'age': '$age', 'region': '$region'}),
    };
  }

  List<Map<String, dynamic>> _bookmarks() => [
    for (final e in _store.bookmarks.entries)
      if (_samplePolicies.any((p) => p['id'] == e.key))
        {
          'bookmarkId': 'demo-bookmark-${e.key}',
          'bookmarkedAt': e.value,
          'policy': _policyById(e.key),
        },
  ];

  List<Map<String, dynamic>> _calendarEvents() => [
    for (final e in _store.calendarEvents.entries)
      if (_samplePolicies.any((p) => p['id'] == e.key))
        {
          'id': 'demo-event-${e.key}',
          'eventDate': e.value,
          'note': null,
          'createdAt': e.value,
          'policy': _policyById(e.key),
        },
  ];
}

class _DemoResponse {
  _DemoResponse(this.status, this.body, {this.mutated = false});

  final int status;
  final Map<String, dynamic> body;
  final bool mutated;
}

class _DemoError implements Exception {
  _DemoError(this.status, this.code, this.message);

  _DemoError.notFound() : this(404, 'NOT_FOUND', '데모에서는 지원하지 않는 기능이에요.');

  _DemoError.validation(String message)
    : this(400, 'VALIDATION_ERROR', message);

  final int status;
  final String code;
  final String message;
}
