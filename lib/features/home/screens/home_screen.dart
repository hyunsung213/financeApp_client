import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/home_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../data/api/category_api.dart';
import '../../transaction/screens/add_transaction_screen.dart';
import '../../transaction/screens/transaction_detail_screen.dart';
import '../../transaction/screens/transaction_list_screen.dart';
import '../theme/home_tokens.dart';
import '../utils/category_icons.dart';
import '../widgets/category_filter_chip.dart';
import '../widgets/home_section_header.dart';
import '../widgets/gauge_progress_bar.dart';
import '../widgets/transaction_grid_card.dart';
import '../widgets/regret_spending_section.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _formatCurrency(int amount) {
    return '${NumberFormat('#,###').format(amount)}원';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeDataAsync = ref.watch(homeDataProvider);
    final user = ref.watch(authProvider).user;
    final selectedFilter = ref.watch(homeCategoryFilterProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final recentTxAsync = ref.watch(homeRecentTransactionsProvider);

    return Scaffold(
      backgroundColor: HomeTokens.pageBackground,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: HomeTokens.heroGradient,
            stops: HomeTokens.heroGradientStops,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              // Top Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${user?.name ?? '사용자'}님, 안녕하세요',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'How are you feeling today?',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // NOTE: The Figma header (335:8091) only shows the bell
                      // icon; the profile avatar was removed because MyPage
                      // is now reached via the 5th bottom-nav tab.
                      IconButton(
                        icon: const Icon(Icons.notifications_none, color: Colors.white, size: 26),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
              ),

              // Date Pill
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        DateFormat('M. d. E', 'ko_KR').format(DateTime.now()),
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ),

              // Hero Section (homeData dependent)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: homeDataAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)),
                    ),
                    error: (err, st) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.redAccent, size: 36),
                            const SizedBox(height: 8),
                            Text('홈 데이터 로딩 실패\n$err', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: HomeTokens.accent, foregroundColor: Colors.white),
                              onPressed: () => ref.invalidate(homeDataProvider),
                              child: const Text('다시 시도'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    data: (data) => Column(
                      children: [
                        const SizedBox(height: 16),
                        // Big remaining amount + recommended amount label
                        GestureDetector(
                          onTap: () => _showTodayDetailSheet(context, data),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.bottomLeft,
                                  child: Text(
                                    NumberFormat('#,###').format(data.remainingToday),
                                    style: const TextStyle(
                                      color: Colors.white, fontSize: 48, fontWeight: FontWeight.w800, letterSpacing: -1,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('권장 소비액', style: TextStyle(color: HomeTokens.textOnHero, fontSize: 13)),
                                    Text(
                                      '/ ${_formatCurrency(data.recommendedAmount)}',
                                      style: const TextStyle(color: HomeTokens.textOnHero, fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),

                        // D-Day & Budget Card (frosted glass over the gradient)
                        GestureDetector(
                          onTap: () => _showSalaryCycleDetailSheet(context, data),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text('다음 월급일까지 앞으로 ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
                                        Text('D-${data.daysUntilSalary}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: HomeTokens.accent)),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${_formatCurrency(data.remainingFlexibleAmount)} 남았어요',
                                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1F2937)),
                                        ),
                                        Text(
                                          '${(data.flexibleUsageRatio * 100).round()}% 사용',
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF374151)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    // Single continuous gauge with 25/50/75% ticks
                                    // (replaces the previous 4-segment row) -
                                    // ratio calculation itself is unchanged.
                                    GaugeProgressBar(
                                      ratio: data.flexibleUsageRatio,
                                      backgroundColor: Colors.white.withValues(alpha: 0.5),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),


              // Transactions Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                  child: HomeSectionHeader(
                    title: '실시간 거래 내역',
                    actionLabel: '더보기',
                    onActionTap: () => Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(builder: (_) => const TransactionListScreen()),
                    ),
                  ),
                ),
              ),

              // Filter Chips
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 0, 0),
                  child: SizedBox(
                    height: 38,
                    child: categoriesAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (e, st) => const SizedBox.shrink(),
                      data: (categories) {
                        final expenseCategories = categories
                            .where((c) => c is Map && c['parentCategoryId'] == 'core.expense')
                            .toList();
                        return ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: expenseCategories.length + 1,
                          itemBuilder: (ctx, i) {
                            if (i == 0) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: CategoryFilterChip(
                                  label: '전체',
                                  selected: selectedFilter == 'ALL',
                                  onTap: () => ref.read(homeCategoryFilterProvider.notifier).setFilter('ALL'),
                                ),
                              );
                            }
                            final c = expenseCategories[i - 1];
                            if (c is! Map) return const SizedBox.shrink();
                            final id = (c['id'] ?? '').toString();
                            final name = (c['name'] ?? '').toString();
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: CategoryFilterChip(
                                label: name,
                                icon: categoryIconFor(id, name),
                                selected: selectedFilter == id,
                                onTap: () => ref.read(homeCategoryFilterProvider.notifier).setFilter(id),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),

              // Transaction Cards
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: recentTxAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator(color: HomeTokens.accent)),
                    ),
                    error: (e, st) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('거래 내역 로딩 오류: $e', style: const TextStyle(color: Colors.grey)),
                    ),
                    data: (transactions) {
                      if (transactions.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                          child: const Center(child: Text('오늘 등록된 거래 내역이 없습니다.', style: TextStyle(color: Color(0xFF9CA3AF)))),
                        );
                      }
                      return _buildTransactionGrid(context, transactions);
                    },
                  ),
                ),
              ),

              // "어제 소비 돌아보기" - presentation-only shell. There is no
              // backend endpoint today that classifies regret spending, so
              // `items` stays null and this renders nothing. Wire it to a
              // real provider once that contract exists.
              const SliverToBoxAdapter(
                child: RegretSpendingSection(items: null),
              ),

              // Bottom spacer
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 72),
        child: FloatingActionButton(
          backgroundColor: HomeTokens.accent,
          foregroundColor: Colors.white,
          elevation: 4,
          onPressed: () => AddTransactionModal.show(context),
          child: const Icon(Icons.add, size: 28),
        ),
      ),
    );
  }

  void _showTodayDetailSheet(BuildContext context, HomeData data) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => _DetailSheet(
        title: '오늘 쓸 수 있는 돈',
        headline: _formatCurrency(data.remainingToday),
        rows: [
          _DetailRow(Icons.stars_outlined, '오늘 권장 소비액', _formatCurrency(data.recommendedAmount)),
          _DetailRow(Icons.access_time, '오늘 사용한 금액', _formatCurrency(data.spentAmount)),
          _DetailRow(Icons.check_circle_outline, '오늘 남은 금액', _formatCurrency(data.remainingToday)),
          _DetailRow(Icons.event_outlined, '다음 월급일까지', 'D-${data.daysUntilSalary}'),
          _DetailRow(Icons.account_balance_wallet_outlined, '남은 가용금액', _formatCurrency(data.remainingFlexibleAmount)),
        ],
        footer: '현재 월급 주기와 남은 금액을 기준으로 계산되었어요.',
      ),
    );
  }

  void _showSalaryCycleDetailSheet(BuildContext context, HomeData data) {
    final cycleEnd = DateTime.now().add(Duration(days: data.daysUntilSalary));
    final cycleStart = DateTime(cycleEnd.year, cycleEnd.month - 1, cycleEnd.day);
    final dateFormat = DateFormat('M월 d일', 'ko_KR');

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => _DetailSheet(
        title: '이번 월급 주기',
        subtitle: '${dateFormat.format(cycleStart)} ~ ${dateFormat.format(cycleEnd)}',
        headline: 'D-${data.daysUntilSalary}',
        headlineColor: HomeTokens.accent,
        rows: [
          _DetailRow(Icons.check_circle_outline, '현재 남은 금액', _formatCurrency(data.remainingFlexibleAmount)),
          _DetailRow(Icons.payments_outlined, '사용한 금액', _formatCurrency(data.usedFlexibleAmount)),
          _DetailRow(Icons.pie_chart_outline, '사용률', '${(data.flexibleUsageRatio * 100).round()}%'),
          _DetailRow(Icons.hourglass_bottom, '남은 기간', '${data.daysUntilSalary}일'),
          _DetailRow(Icons.stars_outlined, '오늘 권장 소비액', _formatCurrency(data.recommendedAmount)),
        ],
      ),
    );
  }

  Widget _buildTransactionGrid(BuildContext context, List<dynamic> transactions) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: transactions.map((tx) {
            if (tx is! Map) return const SizedBox.shrink();
            return SizedBox(
              width: cardWidth,
              child: TransactionGridCard(
                transaction: tx,
                onTap: () => Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(builder: (_) => TransactionDetailScreen(transactionId: tx['id'].toString())),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _DetailRow {
  final IconData icon;
  final String label;
  final String value;

  _DetailRow(this.icon, this.label, this.value);
}

class _DetailSheet extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String headline;
  final Color headlineColor;
  final List<_DetailRow> rows;
  final String? footer;

  const _DetailSheet({
    required this.title,
    this.subtitle,
    required this.headline,
    this.headlineColor = const Color(0xFF1F2937),
    required this.rows,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!, style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
            ],
            const SizedBox(height: 8),
            Text(headline, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: headlineColor)),
            const SizedBox(height: 20),
            ...rows.map((row) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(row.icon, size: 18, color: HomeTokens.accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(row.label, style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563))),
                      ),
                      Text(row.value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
                    ],
                  ),
                )),
            if (footer != null) ...[
              const SizedBox(height: 12),
              Text(footer!, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: HomeTokens.accent, foregroundColor: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('확인'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}