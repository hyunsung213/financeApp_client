import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme.dart';
import '../providers/policy_provider.dart';

class PolicyScreen extends StatelessWidget {
  const PolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('청년 정책', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(text: '추천 정책'),
              Tab(text: '전체 검색'),
              Tab(text: '관심 정책'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _RecommendedTab(),
            _SearchTab(),
            _BookmarkTab(),
          ],
        ),
      ),
    );
  }
}

class _RecommendedTab extends ConsumerWidget {
  const _RecommendedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);

    return profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) {
        if (e.toString().contains('PROFILE_REQUIRED')) {
          return const _ProfileForm();
        }
        return Center(child: Text('에러 발생: $e'));
      },
      data: (profile) {
        final recommendedAsync = ref.watch(recommendedPoliciesProvider);
        return recommendedAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('추천 정책을 불러오지 못했습니다.')),
          data: (data) {
            final policies = data['policies'] as List<dynamic>? ?? [];
            if (policies.isEmpty) {
              return _buildEmptyState('현재 조건에 맞는 추천 정책이 없습니다.');
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: policies.length,
              itemBuilder: (context, index) => _PolicyCard(policy: policies[index]),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm();

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  final _ageController = TextEditingController();
  String? _selectedRegion;

  final List<String> _regions = [
    '서울', '부산', '대구', '인천', '광주', '대전', '울산', 
    '세종', '경기', '강원', '충북', '충남', '전북', '전남', '경북', '경남', '제주'
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.person_pin, size: 64, color: AppColors.primary),
          const SizedBox(height: 24),
          Text(
            '맞춤형 정책을 추천해 드릴게요!',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '나이와 거주 지역을 입력하시면\n조건에 딱 맞는 정책만 모아서 보여드립니다.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _ageController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '만 나이',
              hintText: '예: 25',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedRegion,
            decoration: const InputDecoration(
              labelText: '거주 지역',
              border: OutlineInputBorder(),
            ),
            items: _regions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
            onChanged: (val) => setState(() => _selectedRegion = val),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final age = int.tryParse(_ageController.text);
              if (age == null && _selectedRegion == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('나이 또는 지역을 입력해주세요.')),
                );
                return;
              }
              await ref.read(policyActionsProvider.notifier).updateProfile(
                age: age,
                region: _selectedRegion,
              );
            },
            child: const Text('저장하고 추천받기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _SearchTab extends ConsumerWidget {
  const _SearchTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allAsync = ref.watch(allPoliciesProvider);
    final filter = ref.watch(policyFilterProvider);

    return Column(
      children: [
        // Filter Bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: '정책 이름 또는 키워드 검색',
                    prefixIcon: const Icon(Icons.search),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: AppColors.background,
                  ),
                  onSubmitted: (value) {
                    ref.read(policyFilterProvider.notifier).updateFilter(filter.copyWith(keyword: value));
                  },
                ),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: allAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('에러 발생: $e')),
            data: (policies) {
              if (policies.isEmpty) {
                return const Center(child: Text('조건에 맞는 정책이 없습니다.'));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: policies.length,
                itemBuilder: (context, index) => _PolicyCard(policy: policies[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BookmarkTab extends ConsumerWidget {
  const _BookmarkTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarksAsync = ref.watch(bookmarkedPoliciesProvider);

    return bookmarksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('에러 발생: $e')),
      data: (policies) {
        if (policies.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bookmark_border, size: 64, color: AppColors.textSecondary),
                SizedBox(height: 16),
                Text('관심 등록한 정책이 없습니다.', style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: policies.length,
          itemBuilder: (context, index) => _PolicyCard(policy: policies[index]),
        );
      },
    );
  }
}

class _PolicyCard extends ConsumerWidget {
  final Map<String, dynamic> policy;
  
  const _PolicyCard({required this.policy});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isBookmarked = policy['isBookmarked'] == true;
    final String title = policy['title'] ?? '제목 없음';
    final String summary = policy['summary'] ?? '';
    final String region = policy['region'] ?? '전국';
    final String category = policy['category'] ?? '기타';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: Colors.white,
      child: InkWell(
        onTap: () {
          context.push('/policy/${policy['id']}');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      category,
                      style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      region,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () {
                      ref.read(policyActionsProvider.notifier).toggleBookmark(policy['id'], isBookmarked);
                    },
                    child: Icon(
                      isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                      color: isBookmarked ? AppColors.primary : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (summary.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  summary,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
