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
//
// `bookmarkedPoliciesProvider` already flattens each bookmark row into the
// policy map itself, so the policy id is `row['id']` - the previous lookup of
// `row['policyId']` / `row['policy']['id']` never matched a flattened row and
// left this set permanently empty (no card/detail icon ever showed as
// bookmarked). `.value` (rather than `maybeWhen(data:)`) keeps the previous
// set while the provider reloads after a toggle, so icons don't flicker back
// to "not bookmarked" for a moment on every tap.
final bookmarkedPolicyIdsProvider = Provider.autoDispose<Set<String>>((ref) {
  final rows = ref.watch(bookmarkedPoliciesProvider).value ?? const <Map<String, dynamic>>[];
  final ids = rows.map((row) => (row['id'] ?? '').toString()).where((id) => id.isNotEmpty).toSet();
  // Taps that are still round-tripping to the backend win over the fetched
  // list, so the icon flips immediately instead of after POST + refetch.
  ref.watch(bookmarkOverridesProvider).forEach((id, bookmarked) {
    if (bookmarked) {
      ids.add(id);
    } else {
      ids.remove(id);
    }
  });
  return ids;
});

/// policyId -> the bookmark state the user just asked for, held only while
/// that toggle is in flight (set right before the API call, cleared once the
/// refetched bookmark list - or an error - has settled it).
class BookmarkOverridesNotifier extends Notifier<Map<String, bool>> {
  @override
  Map<String, bool> build() => const {};

  void set(String policyId, bool bookmarked) => state = {...state, policyId: bookmarked};

  void clear(String policyId) {
    final next = {...state}..remove(policyId);
    state = next;
  }
}

final bookmarkOverridesProvider = NotifierProvider<BookmarkOverridesNotifier, Map<String, bool>>(BookmarkOverridesNotifier.new);

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
    final overrides = ref.read(bookmarkOverridesProvider.notifier);
    overrides.set(policyId, !isBookmarked);
    try {
      if (isBookmarked) {
        await api.removeBookmark(policyId);
      } else {
        await api.addBookmark(policyId);
      }
      // Only the bookmark list changes: neither the recommended nor the
      // all-policies response carries a per-user bookmark flag (see
      // bookmarkedPolicyIdsProvider), so invalidating them refetched the
      // whole policy list for nothing - and made PolicyScreen swap its list
      // for a full-screen spinner (resetting scroll) on every bookmark tap.
      ref.invalidate(bookmarkedPoliciesProvider);
      // Hold the override until the refetched list is in, so the icon never
      // briefly reverts to the stale pre-tap state. A refetch error here
      // shouldn't be reported as a failed toggle - the POST/DELETE succeeded.
      try {
        await ref.read(bookmarkedPoliciesProvider.future);
      } catch (_) {}
    } finally {
      overrides.clear(policyId);
    }
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
