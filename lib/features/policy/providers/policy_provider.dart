import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/api/policy_api.dart';

// --- Profile Provider ---
final profileProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(policyApiProvider);
  return await api.getProfile();
});

// --- Recommended Policies Provider ---
final recommendedPoliciesProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(policyApiProvider);
  return await api.getRecommendedPolicies();
});

// --- Search Filter State ---
class PolicyFilter {
  final String? category;
  final String? region;
  final int? age;
  final String? keyword;

  PolicyFilter({this.category, this.region, this.age, this.keyword});

  PolicyFilter copyWith({String? category, String? region, int? age, String? keyword}) {
    return PolicyFilter(
      category: category ?? this.category,
      region: region ?? this.region,
      age: age ?? this.age,
      keyword: keyword ?? this.keyword,
    );
  }
}

class PolicyFilterNotifier extends Notifier<PolicyFilter> {
  @override
  PolicyFilter build() => PolicyFilter();

  void updateFilter(PolicyFilter newFilter) {
    state = newFilter;
  }
}

final policyFilterProvider = NotifierProvider<PolicyFilterNotifier, PolicyFilter>(() {
  return PolicyFilterNotifier();
});

// --- All Policies Provider ---
final allPoliciesProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final api = ref.watch(policyApiProvider);
  final filter = ref.watch(policyFilterProvider);
  
  final data = await api.getPolicies(
    category: filter.category,
    region: filter.region,
    age: filter.age,
    keyword: filter.keyword,
  );
  return data['items'] as List<dynamic>? ?? [];
});

// --- Bookmarked Policies Provider ---
final bookmarkedPoliciesProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final api = ref.watch(policyApiProvider);
  return await api.getBookmarks();
});

// --- Policy Actions Notifier ---
class PolicyActionsNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<void> updateProfile({int? age, String? region}) async {
    final api = ref.read(policyApiProvider);
    await api.updateProfile(age: age, region: region);
    ref.invalidate(profileProvider);
    ref.invalidate(recommendedPoliciesProvider);
  }

  Future<void> toggleBookmark(String policyId, bool isBookmarked) async {
    final api = ref.read(policyApiProvider);
    if (isBookmarked) {
      await api.removeBookmark(policyId);
    } else {
      await api.addBookmark(policyId);
    }
    ref.invalidate(bookmarkedPoliciesProvider);
    ref.invalidate(recommendedPoliciesProvider);
    ref.invalidate(allPoliciesProvider);
  }
}

final policyActionsProvider = NotifierProvider<PolicyActionsNotifier, void>(() {
  return PolicyActionsNotifier();
});
