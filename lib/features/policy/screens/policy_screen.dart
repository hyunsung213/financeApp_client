import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../home/theme/home_tokens.dart';
import '../providers/policy_provider.dart';
import '../widgets/policy_featured_card.dart';
import '../widgets/policy_filter_chips.dart';
import '../widgets/policy_list_card.dart';

/// Figma node 238:4676 (FINAL_POLICY_SCREENS, "Frame 116"): a single scroll
/// (header -> Featured Card -> filter chips -> list), replacing the old
/// Material AppBar + 3-tab (추천/전체검색/관심) layout. Nothing from the old
/// tabs was deleted - `recommendedPoliciesProvider`, `allPoliciesProvider`,
/// `bookmarkedPoliciesProvider` and `policyActionsProvider` are all reused
/// here, just re-arranged to match Figma's IA. See
/// docs/development-work-policy.md and the Policy backend audit for why the
/// data-source and fallback rules below were chosen.
class PolicyScreen extends ConsumerStatefulWidget {
  const PolicyScreen({super.key});

  @override
  ConsumerState<PolicyScreen> createState() => _PolicyScreenState();
}

class _PolicyScreenState extends ConsumerState<PolicyScreen> {
  String? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final recommendedAsync = ref.watch(recommendedPoliciesProvider);

    return Scaffold(
      backgroundColor: HomeTokens.pageBackground,
      body: SafeArea(
        child: recommendedAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, st) => _buildBody(
            context,
            source: _PolicySource.fallback,
            isProfileRequired: error.toString().contains('PROFILE_REQUIRED'),
          ),
          data: (data) {
            final policies = (data['policies'] as List<dynamic>? ?? []);
            if (policies.isEmpty) {
              return _buildBody(context, source: _PolicySource.fallback, isProfileRequired: false);
            }
            return _buildBody(context, source: _PolicySource.recommended, recommended: policies);
          },
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required _PolicySource source,
    List<dynamic>? recommended,
    bool isProfileRequired = false,
  }) {
    if (source == _PolicySource.recommended) {
      return _PolicyList(
        policies: recommended!,
        selectedCategory: _selectedCategory,
        onCategorySelected: (c) => setState(() => _selectedCategory = c),
        profileBanner: null,
      );
    }

    // Recommended is unavailable (no profile, no matches, or the recommended
    // API call failed) - fall back to the public "all policies" list so the
    // Policy Main layout itself never disappears. No fake recommendation
    // data is synthesized here.
    final allAsync = ref.watch(allPoliciesProvider);
    return allAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('정책 정보를 불러오지 못했습니다.', style: const TextStyle(color: HomeTokens.textMuted))),
      data: (policies) => _PolicyList(
        policies: policies,
        selectedCategory: _selectedCategory,
        onCategorySelected: (c) => setState(() => _selectedCategory = c),
        profileBanner: isProfileRequired ? _ProfileBanner(onSetup: () => _showProfileSheet(context)) : null,
      ),
    );
  }

  void _showProfileSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _ProfileQuickSetupSheet(),
    );
  }
}

enum _PolicySource { recommended, fallback }

class _PolicyList extends ConsumerWidget {
  final List<dynamic> policies;
  final String? selectedCategory;
  final ValueChanged<String?> onCategorySelected;
  final Widget? profileBanner;

  const _PolicyList({
    required this.policies,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.profileBanner,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = policies.whereType<Map>().map((p) => Map<String, dynamic>.from(p)).toList();
    final bookmarkedIds = ref.watch(bookmarkedPolicyIdsProvider);

    if (items.isEmpty) {
      return CustomScrollView(
        slivers: [
          _sliverHeader(context),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off_rounded, size: 56, color: HomeTokens.textMuted.withValues(alpha: 0.6)),
                  const SizedBox(height: 12),
                  const Text('표시할 정책이 없습니다.', style: TextStyle(color: HomeTokens.textMuted)),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final featured = items.first;
    final rest = items.skip(1).toList();
    final categories = rest
        .map((p) => (p['category'] ?? '').toString())
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    final filtered = selectedCategory == null ? rest : rest.where((p) => p['category'] == selectedCategory).toList();

    return CustomScrollView(
      slivers: [
        _sliverHeader(context),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          sliver: SliverToBoxAdapter(child: PolicyFeaturedCard(policy: featured, onTap: () => context.push('/policy/${featured['id']}'))),
        ),
        if (profileBanner != null)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            sliver: SliverToBoxAdapter(child: profileBanner!),
          ),
        SliverPadding(
          padding: const EdgeInsets.only(top: 16),
          sliver: SliverToBoxAdapter(
            child: PolicyFilterChips(categories: categories, selected: selectedCategory, onSelected: onCategorySelected),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
          sliver: filtered.isEmpty
              ? const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('선택한 카테고리의 정책이 없습니다.', style: TextStyle(color: HomeTokens.textMuted))),
                  ),
                )
              : SliverList.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final policy = filtered[index];
                    final id = (policy['id'] ?? '').toString();
                    return PolicyListCard(
                      policy: policy,
                      isBookmarked: bookmarkedIds.contains(id),
                      onTap: () => context.push('/policy/$id'),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _sliverHeader(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Row(
          children: [
            const Text('청년정책', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: HomeTokens.textDark)),
            const Spacer(),
            // Figma's header only has a bell icon; the bookmark entry point
            // is an intentional addition since the old "관심" tab was
            // removed and Figma's exported frames have no dedicated
            // bookmark-list screen to point to instead (see
            // docs/development-work-policy.md scope notes for Policy).
            IconButton(
              icon: const Icon(Icons.bookmark_border_rounded, color: HomeTokens.textDark),
              onPressed: () => context.push('/policy/bookmarks'),
            ),
            IconButton(
              icon: const Icon(Icons.notifications_none_rounded, color: HomeTokens.textDark),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileBanner extends StatelessWidget {
  final VoidCallback onSetup;

  const _ProfileBanner({required this.onSetup});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HomeTokens.chipActiveBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: HomeTokens.chipActiveBorder),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              '나이·지역을 입력하면 나에게 맞는 정책을 추천해 드려요.',
              style: TextStyle(fontSize: 13, color: HomeTokens.accentDark, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: onSetup,
            child: const Text('설정하기', style: TextStyle(color: HomeTokens.accentDark, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

/// Same fields/action the old full-page `_ProfileForm` gate had
/// (`policyActionsProvider.updateProfile`), just presented as a dismissible
/// bottom sheet instead of blocking the entire Policy Main screen - Figma's
/// Main layout has no such gate, and the approved scope says PROFILE_REQUIRED
/// must not hide it.
class _ProfileQuickSetupSheet extends ConsumerStatefulWidget {
  const _ProfileQuickSetupSheet();

  @override
  ConsumerState<_ProfileQuickSetupSheet> createState() => _ProfileQuickSetupSheetState();
}

class _ProfileQuickSetupSheetState extends ConsumerState<_ProfileQuickSetupSheet> {
  final _ageController = TextEditingController();
  String? _selectedRegion;
  bool _saving = false;

  static const _regions = [
    '서울', '부산', '대구', '인천', '광주', '대전', '울산',
    '세종', '경기', '강원', '충북', '충남', '전북', '전남', '경북', '경남', '제주',
  ];

  @override
  void dispose() {
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final age = int.tryParse(_ageController.text);
    if (age == null && _selectedRegion == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('나이 또는 지역을 입력해주세요.')));
      return;
    }
    setState(() => _saving = true);
    await ref.read(policyActionsProvider.notifier).updateProfile(age: age, region: _selectedRegion);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('맞춤형 정책을 추천해 드릴게요', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: HomeTokens.textDark)),
            const SizedBox(height: 16),
            TextField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '만 나이', hintText: '예: 25', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedRegion,
              decoration: const InputDecoration(labelText: '거주 지역', border: OutlineInputBorder()),
              items: _regions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (val) => setState(() => _selectedRegion = val),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: HomeTokens.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('저장하고 추천받기', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}