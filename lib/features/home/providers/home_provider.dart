import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/api/home_api.dart';
import '../../../data/api/transaction_api.dart';
import '../../auth/providers/auth_provider.dart';

int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toInt();
  if (value is String) {
    final clean = value.replaceAll(RegExp(r'[^0-9.-]'), '');
    return double.tryParse(clean)?.toInt() ?? 0;
  }
  return 0;
}

class HomeData {
  final int recommendedAmount;
  final int spentAmount;
  final int remainingToday;
  final int daysUntilSalary;
  final int remainingFlexibleAmount;
  final int totalFlexibleAmount;
  final int usedFlexibleAmount;
  final int potentialExtraSaving;
  final String paceStatus;
  final int paceDifference;
  final double flexibleUsageRatio;

  HomeData({
    required this.recommendedAmount,
    required this.spentAmount,
    required this.remainingToday,
    required this.daysUntilSalary,
    required this.remainingFlexibleAmount,
    required this.totalFlexibleAmount,
    required this.usedFlexibleAmount,
    required this.potentialExtraSaving,
    required this.paceStatus,
    required this.paceDifference,
    required this.flexibleUsageRatio,
  });

  factory HomeData.fromJson(Map<String, dynamic> json) {
    final flexibleBudget = _toInt(json['budget']?['flexibleBudget']);
    final flexibleSpent = _toInt(json['budget']?['flexibleSpent']);
    final ratio = flexibleBudget > 0 ? (flexibleSpent / flexibleBudget).clamp(0.0, 1.0) : 0.0;

    return HomeData(
      recommendedAmount: _toInt(json['today']?['recommendedAmount']),
      spentAmount: _toInt(json['today']?['spentAmount']),
      remainingToday: _toInt(json['today']?['remainingToday']),
      daysUntilSalary: _toInt(json['daysUntilSalary']),
      remainingFlexibleAmount: _toInt(json['budget']?['remainingFlexibleAmount']),
      totalFlexibleAmount: flexibleBudget,
      usedFlexibleAmount: flexibleSpent,
      potentialExtraSaving: _toInt(json['savingProjection']?['potentialExtraSaving']),
      paceStatus: json['pace']?['status']?.toString() ?? 'UNKNOWN',
      paceDifference: _toInt(json['pace']?['difference']),
      flexibleUsageRatio: ratio,
    );
  }
}

final homeDataProvider = FutureProvider<HomeData>((ref) async {
  final user = ref.watch(authProvider).user;
  if (user == null) throw Exception("User not found");

  final homeApi = ref.watch(homeApiProvider);
  final data = await homeApi.getHomeDashboard();
  
  return HomeData.fromJson(data);
});

class HomeCategoryFilterNotifier extends Notifier<String> {
  @override
  String build() => 'ALL';

  void setFilter(String categoryId) {
    state = categoryId;
  }
}

final homeCategoryFilterProvider = NotifierProvider<HomeCategoryFilterNotifier, String>(() {
  return HomeCategoryFilterNotifier();
});

final homeRecentTransactionsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final txApi = ref.watch(transactionApiProvider);
  final filter = ref.watch(homeCategoryFilterProvider);
  final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

  try {
    final res = await txApi.getTransactions(
      startDate: todayStr,
      endDate: todayStr,
      categoryId: filter == 'ALL' ? null : filter,
      limit: 50,
    );
    List<dynamic> list = [];
    if (res['items'] is List) {
      list = res['items'] as List<dynamic>;
    } else if (res['transactions'] is List) {
      list = res['transactions'] as List<dynamic>;
    }

    // Filter to ensure only today's transactions are returned
    return list.where((tx) {
      if (tx is! Map) return false;
      final occurredAt = (tx['occurredAt'] ?? '').toString();
      return occurredAt.startsWith(todayStr);
    }).toList();
  } catch (e) {
    return [];
  }
});

/// Yesterday's expenses the user rated as "아쉬운 소비" (REGRETTABLE), for the
/// home screen's "어제 소비 돌아보기" section. This filtering happens entirely
/// client-side (the API call below has no consumptionEvaluation filter), so
/// legacy 'BAD' rows - a valid backend enum value (API_SPEC.md) with no slot
/// in the current 3-state mood picker - are included here too, bucketed
/// with REGRETTABLE rather than silently dropped.
final yesterdayRegrettableTransactionsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final txApi = ref.watch(transactionApiProvider);
  final yesterdayStr = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 1)));

  try {
    final res = await txApi.getTransactions(
      startDate: yesterdayStr,
      endDate: yesterdayStr,
      type: 'EXPENSE',
      limit: 100,
    );
    List<dynamic> list = [];
    if (res['items'] is List) {
      list = res['items'] as List<dynamic>;
    } else if (res['transactions'] is List) {
      list = res['transactions'] as List<dynamic>;
    }

    return list.where((tx) => tx is Map && (tx['consumptionEvaluation'] == 'REGRETTABLE' || tx['consumptionEvaluation'] == 'BAD')).toList();
  } catch (e) {
    return [];
  }
});
