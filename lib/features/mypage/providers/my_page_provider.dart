import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/api/finance_api.dart';
import '../../../data/api/policy_api.dart';
import '../../home/providers/home_provider.dart';
import '../../policy/providers/policy_provider.dart';

class MyPageData {
  final Map<String, dynamic> setting;
  final List<dynamic> allocations;
  final Map<String, dynamic> profile;

  MyPageData({
    required this.setting,
    required this.allocations,
    required this.profile,
  });
}

final myPageDataProvider = FutureProvider.autoDispose<MyPageData>((ref) async {
  final financeApi = ref.watch(financeApiProvider);
  final policyApi = ref.watch(policyApiProvider);

  Map<String, dynamic> setting = {};
  try {
    setting = await financeApi.getSetting();
  } catch (e) {
    setting = {
      'salaryAmount': 2500000,
      'salaryDay': 10,
      'reportingStartDay': 1,
    };
  }

  List<dynamic> allocations = [];
  try {
    allocations = await financeApi.getAllocations();
  } catch (e) {
    allocations = [];
  }

  Map<String, dynamic> profile = {};
  try {
    profile = await policyApi.getProfile();
  } catch (e) {
    profile = {};
  }

  return MyPageData(
    setting: setting,
    allocations: allocations,
    profile: profile,
  );
});

class MyPageActionsNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<void> saveMyPageSettings({
    required int salaryAmount,
    required int salaryDay,
    required int reportingStartDay,
    required List<Map<String, dynamic>> allocations,
    int? age,
    String? region,
  }) async {
    final financeApi = ref.read(financeApiProvider);
    final policyApi = ref.read(policyApiProvider);

    // 1. Update Finance Setting
    await financeApi.updateSetting(
      salaryAmount: salaryAmount,
      salaryDay: salaryDay,
      reportingStartDay: reportingStartDay,
    );

    // 2. Update Allocations if IDs exist, or create if needed
    for (final alloc in allocations) {
      final id = alloc['id']?.toString();
      final rawPercentage = alloc['percentage'];
      double percentage = 0.0;
      if (rawPercentage is num) {
        percentage = rawPercentage.toDouble();
      } else if (rawPercentage is String) {
        percentage = double.tryParse(rawPercentage) ?? 0.0;
      }
      final active = alloc['active'] as bool? ?? true;

      if (id != null && id.isNotEmpty) {
        try {
          await financeApi.updateAllocation(id, percentage: percentage, active: active);
        } catch (_) {
          // ignore or handle
        }
      }
    }

    // 3. Update Policy Profile
    if (age != null || region != null) {
      try {
        await policyApi.updateProfile(age: age, region: region);
      } catch (_) {}
    }

    // Invalidate caches
    ref.invalidate(myPageDataProvider);
    ref.invalidate(homeDataProvider);
    ref.invalidate(profileProvider);
    ref.invalidate(recommendedPoliciesProvider);
  }
}

final myPageActionsProvider = NotifierProvider<MyPageActionsNotifier, void>(() {
  return MyPageActionsNotifier();
});
