import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/api/finance_api.dart';
import '../../../data/api/policy_api.dart';
import '../../home/providers/home_provider.dart';
import '../../policy/providers/policy_provider.dart';

/// Maps a budget allocation's display name to the backend enums it needs.
/// Matches the color/name convention already used across the mypage UI.
(String, String) _allocationTypeFor(String name) {
  switch (name) {
    case '저축':
      return ('SAVING', 'LOCKED');
    case '투자':
      return ('INVESTMENT', 'LOCKED');
    case '고정생활':
      return ('FIXED_LIVING', 'RESERVED');
    case '소비':
      return ('FLEXIBLE', 'FLEXIBLE');
    default:
      return ('OTHER', 'FLEXIBLE');
  }
}

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

    // 2. Update existing allocations by id, or create ones that don't exist on
    // the backend yet (e.g. the default 저축/투자/고정생활/소비 split shown to a
    // brand-new user has no real id — PATCHing a made-up id would 404 silently).
    for (final alloc in allocations) {
      final id = alloc['id']?.toString();
      final name = alloc['name'] as String? ?? '항목';
      final rawPercentage = alloc['percentage'];
      double percentage = 0.0;
      if (rawPercentage is num) {
        percentage = rawPercentage.toDouble();
      } else if (rawPercentage is String) {
        percentage = double.tryParse(rawPercentage) ?? 0.0;
      }
      final active = alloc['active'] as bool? ?? true;

      if (id != null && id.isNotEmpty) {
        await financeApi.updateAllocation(id, percentage: percentage, active: active);
      } else {
        final (allocationType, spendability) = _allocationTypeFor(name);
        await financeApi.createAllocation(
          name: name,
          allocationType: allocationType,
          percentage: percentage,
          spendability: spendability,
          active: active,
        );
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
