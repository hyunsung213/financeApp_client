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
// `getPolicies` already returns the raw list (see policy_api.dart for why
// the old `data['items']` unwrap was wrong against the real backend shape).
final allPoliciesProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final api = ref.watch(policyApiProvider);
  final filter = ref.watch(policyFilterProvider);

  return await api.getPolicies(
    category: filter.category,
    region: filter.region,
    age: filter.age,
    keyword: filter.keyword,
  );
});

/// Full unfiltered policy list — used to derive the category filter chips
/// (filtering by the already-selected category would shrink the chip set).
final allPolicyCategoriesProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final api = ref.watch(policyApiProvider);
  final policies = await api.getPolicies();
  final categories = policies
      .whereType<Map>()
      .map((p) => (p['category'] ?? '').toString())
      .where((c) => c.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
  return categories;
});

/// Flattens `{bookmarkId, bookmarkedAt, policy: {...}}` into a plain policy
/// map (with `bookmarkId`/`bookmarkedAt` merged in) so callers can treat it
/// like any other policy object.
final bookmarkedPoliciesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(policyApiProvider);
  final raw = await api.getBookmarks();
  return raw
      .whereType<Map>()
      .where((b) => b['policy'] is Map)
      .map((b) => {
            ...Map<String, dynamic>.from(b['policy'] as Map),
            'bookmarkId': b['bookmarkId'],
            'bookmarkedAt': b['bookmarkedAt'],
          })
      .toList();
});

/// Flattens `{id, eventDate, note, policy: {...}}` into a plain policy map
/// (with `calendarEventId`/`calendarEventDate` merged in).
final policyCalendarEventsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(policyApiProvider);
  final raw = await api.getCalendarEvents();
  return raw
      .whereType<Map>()
      .where((e) => e['policy'] is Map)
      .map((e) => {
            ...Map<String, dynamic>.from(e['policy'] as Map),
            'calendarEventId': e['id'],
            'calendarEventDate': e['eventDate'],
          })
      .toList();
});

// --- Bookmarked Policy Id Set ---
// Neither `/api/policies`, `/api/policies/recommended`, nor
// `/api/policies/:id` return an `isBookmarked` flag on a policy (see
// docs/backend/policy-backend-requirements.md item 5). This derives the
// same information from the existing `/api/policies/bookmarks` endpoint so
// every card/detail screen computes bookmark state the same way, from one
// place, instead of each one calling a bookmark-status API individually.
final bookmarkedPolicyIdsProvider = Provider.autoDispose<Set<String>>((ref) {
  final bookmarksAsync = ref.watch(bookmarkedPoliciesProvider);
  return bookmarksAsync.maybeWhen(
    data: (rows) => rows
        .whereType<Map>()
        .map((row) => (row['policyId'] ?? (row['policy'] is Map ? row['policy']['id'] : null) ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet(),
    orElse: () => <String>{},
  );
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

  Future<void> addToCalendar(String policyId, String eventDate) async {
    final api = ref.read(policyApiProvider);
    await api.addCalendarEvent(policyId, eventDate: eventDate);
    ref.invalidate(policyCalendarEventsProvider);
  }

  Future<void> removeFromCalendar(String policyId) async {
    final api = ref.read(policyApiProvider);
    await api.removeCalendarEvent(policyId);
    ref.invalidate(policyCalendarEventsProvider);
  }
}

final policyActionsProvider = NotifierProvider<PolicyActionsNotifier, void>(() {
  return PolicyActionsNotifier();
});
