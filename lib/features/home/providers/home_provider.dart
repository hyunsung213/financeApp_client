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
    required this.potentialExtraSaving,
    required this.paceStatus,
    required this.paceDifference,
    required this.flexibleUsageRatio,
  });

  // Total flexible budget for this salary cycle, derived from the usage ratio
  // since the backend only exposes the remaining amount today.
  int get totalFlexibleAmount => flexibleUsageRatio >= 1
      ? remainingFlexibleAmount
      : (remainingFlexibleAmount / (1 - flexibleUsageRatio)).round();

  int get usedFlexibleAmount => totalFlexibleAmount - remainingFlexibleAmount;

  factory HomeData.fromJson(Map<String, dynamic> json) {
    final rawRatio = json['budget']?['usagePercentage'] ?? json['budget']?['usedPercentage'];
    // ponytail: placeholder 0.75 ratio until backend exposes real usage %, upgrade when that field lands.
    final ratio = rawRatio is num ? (rawRatio / 100).clamp(0.0, 1.0).toDouble() : 0.75;

    return HomeData(
      recommendedAmount: _toInt(json['today']?['recommendedAmount']),
      spentAmount: _toInt(json['today']?['spentAmount']),
      remainingToday: _toInt(json['today']?['remainingToday']),
      daysUntilSalary: _toInt(json['daysUntilSalary']),
      remainingFlexibleAmount: _toInt(json['budget']?['remainingFlexibleAmount']),
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
