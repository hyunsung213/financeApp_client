import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/skeleton.dart';
import '../providers/policy_provider.dart';

class _SelectedPolicyCategoryNotifier extends Notifier<String> {
  @override
  String build() => 'ALL';

  void select(String category) => state = category;
}

final _selectedPolicyCategoryProvider = NotifierProvider<_SelectedPolicyCategoryNotifier, String>(() {
  return _SelectedPolicyCategoryNotifier();
});

Map<String, dynamic> _presentationOf(Map<String, dynamic> policy) {
  final presentation = policy['presentation'];
  return presentation is Map ? Map<String, dynamic>.from(presentation) : const {};
}

class PolicyScreen extends ConsumerWidget {
  const PolicyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policiesAsync = ref.watch(allPoliciesProvider);
    final categoriesAsync = ref.watch(allPolicyCategoriesProvider);
    final selectedCategory = ref.watch(_selectedPolicyCategoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('청년정책', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.notifications_none), onPressed: () {}),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 0, 0),
              child: SizedBox(
                height: 38,
                child: categoriesAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (e, st) => const SizedBox.shrink(),
                  data: (categories) => ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length + 1,
                    itemBuilder: (context, i) {
                      final value = i == 0 ? 'ALL' : categories[i - 1];
                      final label = i == 0 ? '전체' : categories[i - 1];
                      final isSelected = selectedCategory == value;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => ref.read(_selectedPolicyCategoryProvider.notifier).select(value),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primaryLight : Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: isSelected ? AppColors.primary : const Color(0xFFE5E7EB)),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: policiesAsync.when(
                loading: () => const PolicyListSkeleton(),
                error: (e, st) => Center(child: Text('정책을 불러오지 못했어요: $e', style: const TextStyle(color: AppColors.textSecondary))),
                data: (raw) {
                  final policies = raw
                      .whereType<Map>()
                      .map((p) => Map<String, dynamic>.from(p))
                      .where((p) => selectedCategory == 'ALL' || p['category'] == selectedCategory)
                      .toList();

                  if (policies.isEmpty) {
                    return const Center(child: Text('조건에 맞는 정책이 없어요.', style: TextStyle(color: AppColors.textSecondary)));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    itemCount: policies.length,
                    itemBuilder: (context, i) {
                      final policy = policies[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: i == 0 ? _HeroPolicyCard(policy: policy) : _PolicyRow(policy: policy),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Decorative stand-in for a policy photo — the backend has no image field
/// for policies, so a real thumbnail isn't available; this is chrome, not data.
class _PolicyImagePlaceholder extends StatelessWidget {
  final double size;
  final BorderRadius borderRadius;

  const _PolicyImagePlaceholder({required this.size, required this.borderRadius});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF00C875), Color(0xFF64B5F6)],
        ),
      ),
      child: Icon(Icons.description_outlined, color: Colors.white.withValues(alpha: 0.85), size: size * 0.4),
    );
  }
}

class _HeroPolicyCard extends StatelessWidget {
  final Map<String, dynamic> policy;
  const _HeroPolicyCard({required this.policy});

  @override
  Widget build(BuildContext context) {
    final presentation = _presentationOf(policy);
    final category = (presentation['categoryText'] ?? policy['category'] ?? '카테고리').toString();
    final headline = (presentation['headline'] ?? policy['title'] ?? '').toString();
    final summary = (presentation['summary'] ?? policy['summary'] ?? '').toString();
    final deadline = presentation['deadlineLabel']?.toString();

    return GestureDetector(
      onTap: () => context.push('/policy/${policy['id']}'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: _PolicyImagePlaceholder(size: 140, borderRadius: BorderRadius.zero),
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: _badge(category, Colors.black.withValues(alpha: 0.6)),
                ),
                if (deadline != null)
                  Positioned(
                    right: 12,
                    top: 12,
                    child: _badge(deadline, AppColors.danger),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(headline, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Text(summary, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

class _PolicyRow extends StatelessWidget {
  final Map<String, dynamic> policy;
  const _PolicyRow({required this.policy});

  @override
  Widget build(BuildContext context) {
    final presentation = _presentationOf(policy);
    final category = (presentation['categoryText'] ?? policy['category'] ?? '카테고리').toString();
    final headline = (presentation['headline'] ?? policy['title'] ?? '').toString();
    final summary = (presentation['summary'] ?? policy['summary'] ?? '').toString();

    return GestureDetector(
      onTap: () => context.push('/policy/${policy['id']}'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text(category, style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8),
                  Text(headline, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(summary, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _PolicyImagePlaceholder(size: 64, borderRadius: BorderRadius.circular(10)),
          ],
        ),
      ),
    );
  }
}
