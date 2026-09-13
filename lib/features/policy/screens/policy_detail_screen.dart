import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/api/policy_api.dart';
import '../../home/theme/home_tokens.dart';
import '../providers/policy_provider.dart';
import '../utils/policy_category_visual.dart';
import '../utils/policy_dday.dart';
import '../widgets/policy_calendar_add_sheet.dart';

final policyDetailProvider = FutureProvider.family.autoDispose<Map<String, dynamic>, String>((ref, id) async {
  final api = ref.watch(policyApiProvider);
  return await api.getPolicy(id);
});

/// Figma nodes 244:5144 (bookmark outline) / 246:5631 (bookmark solid) -
/// two states of the same Detail screen, not two different screens.
class PolicyDetailScreen extends ConsumerWidget {
  final String policyId;

  const PolicyDetailScreen({super.key, required this.policyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(policyDetailProvider(policyId));

    return Scaffold(
      backgroundColor: HomeTokens.pageBackground,
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('불러오지 못했습니다: $e', style: const TextStyle(color: HomeTokens.textMuted))),
        data: (policy) => _DetailBody(policy: policy, policyId: policyId),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  final Map<String, dynamic> policy;
  final String policyId;

  const _DetailBody({required this.policy, required this.policyId});

  String? _eligibilityText() {
    final ageMin = policy['ageMin'];
    final ageMax = policy['ageMax'];
    final region = (policy['region'] ?? '').toString();

    String? agePart;
    if (ageMin != null && ageMax != null) {
      agePart = '만 $ageMin~$ageMax세';
    } else if (ageMin != null) {
      agePart = '만 $ageMin세 이상';
    } else if (ageMax != null) {
      agePart = '만 $ageMax세 이하';
    }

    final parts = [agePart, region.isNotEmpty ? region : null].whereType<String>().toList();
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  String? _applicationPeriodText() {
    final start = policy['applicationStartDate']?.toString();
    final end = policy['applicationEndDate']?.toString();
    String? format(String? iso) {
      if (iso == null || iso.isEmpty) return null;
      final date = DateTime.tryParse(iso);
      if (date == null) return null;
      return DateFormat('yyyy년 M월 d일', 'ko_KR').format(date);
    }

    final startLabel = format(start);
    final endLabel = format(end);
    if (startLabel == null && endLabel == null) return null;
    if (startLabel != null && endLabel != null) return '신청기간 $startLabel - $endLabel';
    return '신청기간 ${startLabel ?? endLabel}';
  }

  Future<void> _launchOfficialSite(BuildContext context) async {
    final url = (policy['applicationUrl'] ?? policy['sourceUrl'])?.toString();
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('유효한 링크가 아니에요.')));
      return;
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('링크를 열 수 없어요.')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = (policy['category'] ?? '기타').toString();
    final title = (policy['title'] ?? '제목 없음').toString();
    final dDay = policyDDayLabel(policy['applicationEndDate']?.toString());
    final visual = PolicyCategoryVisual.forCategory(category);
    final isBookmarked = ref.watch(bookmarkedPolicyIdsProvider).contains(policyId);
    final applicationPeriod = _applicationPeriodText();
    final eligibility = _eligibilityText();
    final officialUrl = (policy['applicationUrl'] ?? policy['sourceUrl'])?.toString();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: visual.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            child: SafeArea(
              bottom: false,
              child: Stack(
                children: [
                  Positioned(
                    right: -20,
                    top: 20,
                    child: Icon(visual.icon, size: 140, color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                            onPressed: () => Navigator.of(context).maybePop(),
                          ),
                          const Spacer(),
                          IconButton(
                            // Always outline: there is no real "already added to my calendar"
                            // state to reflect yet (PolicyCalendarEvent has no API - see
                            // docs/backend/policy-backend-requirements.md item 1), so this
                            // must not borrow `isBookmarked` or otherwise imply a saved state
                            // that does not exist.
                            icon: const Icon(Icons.calendar_month_outlined, color: Colors.white),
                            tooltip: '캘린더에 추가',
                            onPressed: () => PolicyCalendarAddSheet.show(
                              context,
                              title: title,
                              applicationStartDate: policy['applicationStartDate']?.toString(),
                              applicationEndDate: policy['applicationEndDate']?.toString(),
                            ),
                          ),
                          IconButton(
                            icon: Icon(isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: Colors.white),
                            onPressed: () => ref.read(policyActionsProvider.notifier).toggleBookmark(policyId, isBookmarked),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
                            child: Text(category, style: const TextStyle(fontSize: 13, color: HomeTokens.textDark, fontWeight: FontWeight.w600)),
                          ),
                          if (dDay != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(color: HomeTokens.negative, borderRadius: BorderRadius.circular(6)),
                              child: Text(dDay, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white)),
                      if (applicationPeriod != null) ...[
                        const SizedBox(height: 12),
                        Text(applicationPeriod, style: const TextStyle(fontSize: 15, color: Colors.white)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
          sliver: SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionBlock('지원 대상', eligibility ?? '-'),
                  const SizedBox(height: 24),
                  _sectionBlock('주요 내용', (policy['description'] ?? policy['summary'] ?? '내용 없음').toString()),
                  const SizedBox(height: 24),
                  _sectionBlock('신청 방법', '자세한 신청 방법은 공식 홈페이지에서 확인할 수 있어요.'),
                ],
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(15, 0, 15, 24),
          sliver: SliverToBoxAdapter(
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: HomeTokens.accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: HomeTokens.accent.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: officialUrl == null || officialUrl.isEmpty ? null : () => _launchOfficialSite(context),
                child: const Text('공식 홈페이지 보러가기', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionBlock(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: HomeTokens.textDark)),
        const SizedBox(height: 8),
        Text(content, style: const TextStyle(fontSize: 14, color: Color(0xFF8F8E8E), height: 1.4)),
      ],
    );
  }
}