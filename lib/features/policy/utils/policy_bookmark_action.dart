import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/policy_provider.dart';

/// Toggles a policy's bookmark through the real `/api/policies/:id/bookmark`
/// endpoint (via [PolicyActionsNotifier.toggleBookmark]) and tells the user
/// if it failed, instead of letting the exception escape a tap handler.
Future<void> toggleBookmarkWithFeedback(
  BuildContext context,
  WidgetRef ref, {
  required String policyId,
  required bool isBookmarked,
}) async {
  try {
    await ref.read(policyActionsProvider.notifier).toggleBookmark(policyId, isBookmarked);
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(isBookmarked ? '북마크를 해제하지 못했어요.' : '북마크에 추가하지 못했어요.')),
    );
  }
}
