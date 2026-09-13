import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../data/api/policy_api.dart';
import '../providers/policy_provider.dart';

final policyDetailProvider = FutureProvider.family.autoDispose<Map<String, dynamic>, String>((ref, id) async {
  final api = ref.watch(policyApiProvider);
  return await api.getPolicy(id);
});

Map<String, dynamic> _presentationOf(Map<String, dynamic> policy) {
  final presentation = policy['presentation'];
  return presentation is Map ? Map<String, dynamic>.from(presentation) : const {};
}

class PolicyDetailScreen extends ConsumerWidget {
  final String policyId;

  const PolicyDetailScreen({super.key, required this.policyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(policyDetailProvider(policyId));
    final bookmarkedAsync = ref.watch(bookmarkedPoliciesProvider);
    final calendarEventsAsync = ref.watch(policyCalendarEventsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF00C875),
      body: detailAsync.when(
        loading: () => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),
              _whiteSkeleton(height: 160, radius: 20),
              const SizedBox(height: 24),
              _whiteSkeleton(width: 220, height: 24),
              const SizedBox(height: 12),
              _whiteSkeleton(height: 16),
              const SizedBox(height: 24),
              _whiteSkeleton(height: 200, radius: 16),
            ],
          ),
        ),
        error: (e, st) => Center(child: Text('불러오지 못했어요: $e', style: const TextStyle(color: Colors.white))),
        data: (policy) {
          final presentation = _presentationOf(policy);
          final isBookmarked = (bookmarkedAsync.asData?.value ?? const []).any((p) => p['id'] == policyId);
          final calendarEvent = (calendarEventsAsync.asData?.value ?? const []).cast<Map<String, dynamic>?>().firstWhere(
                (p) => p?['id'] == policyId,
                orElse: () => null,
              );
          final isAddedToCalendar = calendarEvent != null;

          final category = (presentation['categoryText'] ?? policy['category'] ?? '카테고리').toString();
          final deadline = presentation['deadlineLabel']?.toString();
          final headline = (presentation['headline'] ?? policy['title'] ?? '').toString();
          final applicationText = (presentation['applicationText'] ?? '').toString();
          final targetText = (presentation['targetText'] ?? '').toString();
          final benefitText = (presentation['benefitText'] ?? policy['summary'] ?? '').toString();
          final applicationUrl = policy['applicationUrl']?.toString();

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hero image placeholder + badges + action icons
                      Stack(
                        children: [
                          Container(
                            width: double.infinity,
                            height: 220,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF00C875), Color(0xFF64B5F6)],
                              ),
                            ),
                            child: Icon(Icons.description_outlined, color: Colors.white.withValues(alpha: 0.85), size: 72),
                          ),
                          Positioned(
                            left: 12,
                            top: 12,
                            child: SafeArea(
                              bottom: false,
                              child: _circleIconButton(
                                icon: Icons.arrow_back_ios_new,
                                onTap: () => Navigator.of(context).pop(),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 12,
                            right: 12,
                            bottom: 12,
                            child: Row(
                              children: [
                                _badge(category, Colors.black.withValues(alpha: 0.6)),
                                if (deadline != null) ...[
                                  const SizedBox(width: 8),
                                  _badge(deadline, AppColors.danger),
                                ],
                                const Spacer(),
                                _circleIconButton(
                                  icon: isAddedToCalendar ? Icons.event_available : Icons.calendar_month_outlined,
                                  iconColor: isAddedToCalendar ? AppColors.primary : AppColors.textPrimary,
                                  onTap: () => _onCalendarTap(context, ref, policy, presentation, isAddedToCalendar),
                                ),
                                const SizedBox(width: 8),
                                _circleIconButton(
                                  icon: isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                                  iconColor: isBookmarked ? AppColors.primary : AppColors.textPrimary,
                                  onTap: () async {
                                    await ref.read(policyActionsProvider.notifier).toggleBookmark(policyId, isBookmarked);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Title + application period, on the green background
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(headline, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, height: 1.3)),
                            if (applicationText.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(applicationText, style: const TextStyle(color: Colors.white, fontSize: 13)),
                            ],
                          ],
                        ),
                      ),

                      // Content card
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle('지원 대상'),
                            _sectionText(targetText.isNotEmpty ? targetText : '대상 정보가 없어요'),
                            const SizedBox(height: 20),
                            _sectionTitle('주요 내용'),
                            _sectionText(benefitText.isNotEmpty ? benefitText : '상세 내용이 없어요'),
                            const SizedBox(height: 20),
                            _sectionTitle('신청 방법'),
                            _sectionText(applicationText.isNotEmpty ? applicationText : '신청 방법 정보가 없어요'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // Pinned CTA on the green background.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: applicationUrl == null || applicationUrl.isEmpty
                          ? null
                          : () async {
                              final uri = Uri.tryParse(applicationUrl);
                              if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
                            },
                      child: const Text('공식 홈페이지 보러가기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _onCalendarTap(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> policy,
    Map<String, dynamic> presentation,
    bool isAddedToCalendar,
  ) async {
    if (isAddedToCalendar) {
      await ref.read(policyActionsProvider.notifier).removeFromCalendar(policyId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('캘린더에서 제거했어요.')));
      }
      return;
    }

    final endDate = policy['applicationEndDate']?.toString();
    final startDate = policy['applicationStartDate']?.toString();
    final eventDateStr = (endDate != null && endDate.isNotEmpty)
        ? endDate
        : (startDate != null && startDate.isNotEmpty)
            ? startDate
            : DateFormat('yyyy-MM-dd').format(DateTime.now());

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => _AddToCalendarSheet(
        categoryText: (presentation['categoryText'] ?? policy['category'] ?? '정책').toString(),
        startDate: startDate,
        endDate: endDate,
      ),
    );

    if (confirmed == true) {
      await ref.read(policyActionsProvider.notifier).addToCalendar(policyId, eventDateStr);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('내 캘린더에 추가했어요.'), backgroundColor: AppColors.primary));
      }
    }
  }

  Widget _circleIconButton({required IconData icon, required VoidCallback onTap, Color iconColor = AppColors.textPrimary}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: Icon(icon, size: 18, color: iconColor),
      ),
    );
  }

  Widget _whiteSkeleton({double width = double.infinity, required double height, double radius = 8}) {
    return SkeletonBox(
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(radius),
      baseColor: Colors.white.withValues(alpha: 0.25),
      highlightColor: Colors.white.withValues(alpha: 0.45),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
    );
  }

  Widget _sectionText(String content) {
    return Text(content, style: const TextStyle(height: 1.6, fontSize: 14, color: AppColors.textSecondary));
  }
}

class _AddToCalendarSheet extends StatelessWidget {
  final String categoryText;
  final String? startDate;
  final String? endDate;

  const _AddToCalendarSheet({required this.categoryText, this.startDate, this.endDate});

  String _formatShort(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '';
    final date = DateTime.tryParse(isoDate);
    if (date == null) return '';
    return DateFormat('M월 d일', 'ko_KR').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final startLabel = _formatShort(startDate);
    final endLabel = _formatShort(endDate);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          const Text('내 캘린더에 추가하시겠습니까?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          if (startLabel.isNotEmpty || endLabel.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _dateDot(startLabel.isNotEmpty ? startLabel : '시작'),
                Expanded(child: Container(height: 2, margin: const EdgeInsets.symmetric(horizontal: 4), color: AppColors.primaryLight)),
                _dateDot(endLabel.isNotEmpty ? endLabel : '마감'),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              [if (startLabel.isNotEmpty) startLabel, if (endLabel.isNotEmpty) endLabel].join(' - '),
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
          ],
          Text('$categoryText 정책을 내 캘린더에 추가하기', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('취소', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('추가', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateDot(String label) {
    return Container(
      width: 52,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(16)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
