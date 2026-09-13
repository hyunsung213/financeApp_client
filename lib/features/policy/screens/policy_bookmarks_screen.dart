import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../home/theme/home_tokens.dart';
import '../providers/policy_provider.dart';
import '../widgets/policy_list_card.dart';

/// Bookmark entry point kept after removing the old "관심 정책" tab (see
/// docs/development-work-policy.md - Figma's FINAL_POLICY_SCREENS export has
/// no dedicated bookmark-list frame, but the feature/API already existed and
/// must stay reachable). Reached from a bookmark icon in PolicyScreen's
/// header rather than a tab, so it doesn't compete with Figma's single-list
/// Main layout.
///
/// `bookmarkedPoliciesProvider` returns `PolicyBookmark` rows (id/userId/
/// policyId/createdAt/policy), not flat Policy objects - each row's actual
/// policy fields live under `row['policy']`.
class PolicyBookmarksScreen extends ConsumerWidget {
  const PolicyBookmarksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarksAsync = ref.watch(bookmarkedPoliciesProvider);

    return Scaffold(
      backgroundColor: HomeTokens.pageBackground,
      appBar: AppBar(
        title: const Text('관심 정책', style: TextStyle(color: HomeTokens.textDark, fontWeight: FontWeight.bold)),
        backgroundColor: HomeTokens.pageBackground,
        foregroundColor: HomeTokens.textDark,
        elevation: 0,
      ),
      body: bookmarksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('불러오지 못했습니다: $e', style: const TextStyle(color: HomeTokens.textMuted))),
        data: (rows) {
          final policies = rows
              .whereType<Map>()
              .map((row) => row['policy'])
              .whereType<Map>()
              .map((policy) => Map<String, dynamic>.from(policy))
              .toList();

          if (policies.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bookmark_border_rounded, size: 56, color: HomeTokens.textMuted.withValues(alpha: 0.6)),
                  const SizedBox(height: 12),
                  const Text('관심 등록한 정책이 없습니다.', style: TextStyle(color: HomeTokens.textMuted)),
                ],
              ),
            );
          }

          final bookmarkedIds = policies.map((p) => (p['id'] ?? '').toString()).toSet();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: policies.length,
            itemBuilder: (context, index) {
              final policy = policies[index];
              return PolicyListCard(
                policy: policy,
                isBookmarked: bookmarkedIds.contains((policy['id'] ?? '').toString()),
                onTap: () => context.push('/policy/${policy['id']}'),
              );
            },
          );
        },
      ),
    );
  }
}
