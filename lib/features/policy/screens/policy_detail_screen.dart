import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../data/api/policy_api.dart';
import '../providers/policy_provider.dart';

final policyDetailProvider = FutureProvider.family.autoDispose<Map<String, dynamic>, String>((ref, id) async {
  final api = ref.watch(policyApiProvider);
  return await api.getPolicy(id);
});

class PolicyDetailScreen extends ConsumerWidget {
  final String policyId;

  const PolicyDetailScreen({super.key, required this.policyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(policyDetailProvider(policyId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('정책 상세'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          detailAsync.maybeWhen(
            data: (policy) {
              final isBookmarked = policy['isBookmarked'] == true;
              return IconButton(
                icon: Icon(
                  isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  color: isBookmarked ? AppColors.primary : AppColors.textSecondary,
                ),
                onPressed: () async {
                  await ref.read(policyActionsProvider.notifier).toggleBookmark(policyId, isBookmarked);
                  ref.invalidate(policyDetailProvider(policyId));
                },
              );
            },
            orElse: () => const SizedBox(),
          ),
        ],
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('에러 발생: $e')),
        data: (policy) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        policy['category'] ?? '분류없음',
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        policy['region'] ?? '전국',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  policy['title'] ?? '제목 없음',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('정책 요약'),
                _buildSectionContent(policy['summary'] ?? '내용 없음'),
                
                const SizedBox(height: 24),
                _buildSectionTitle('지원 대상'),
                _buildSectionContent(policy['eligibility'] ?? '조건 정보 없음'),
                
                const SizedBox(height: 24),
                _buildSectionTitle('신청 방법'),
                _buildSectionContent(policy['applicationMethod'] ?? '신청 방법 정보 없음'),
                
                if (policy['applicationUrl'] != null) ...[
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () {
                        // TODO: Launch URL
                      },
                      child: const Text('신청 사이트로 이동', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
      ),
    );
  }

  Widget _buildSectionContent(String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Text(
        content,
        style: const TextStyle(height: 1.6, fontSize: 15, color: AppColors.textPrimary),
      ),
    );
  }
}
