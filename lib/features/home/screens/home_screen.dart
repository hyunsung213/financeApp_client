import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/home_provider.dart';
import '../providers/home_section_visibility_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/category/category_appearance.dart';
import '../../../core/format/money_format.dart';
import '../../../core/providers/current_date_provider.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/surface_style.dart';
import '../../../core/theme/wallet_glass.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/manual_input_fab.dart';
import '../../../core/widgets/tab_header.dart';
import '../../../data/api/category_api.dart';
import '../../transaction/screens/add_transaction_screen.dart';
import '../../transaction/screens/transaction_detail_screen.dart';
import '../../transaction/screens/transaction_list_screen.dart';
import '../../transaction/widgets/category_picker_screen.dart'
    show majorCategoriesFor;
import '../widgets/category_filter_chip.dart';
import '../widgets/home_section_header.dart';
import '../widgets/gauge_progress_bar.dart';
import '../widgets/transaction_grid_card.dart';
import '../widgets/regret_spending_section.dart';

int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toInt();
  if (value is String) {
    final clean = value.replaceAll(RegExp(r'[^0-9.-]'), '');
    return double.tryParse(clean)?.toInt() ?? 0;
  }
  return 0;
}

/// "최근 소비 돌아보기" rows can span several different days (it's no longer
/// scoped to a single "yesterday"), so each row needs its own date label.
/// `occurredAt` is date-only (`YYYY-MM-DD`, API_SPEC.md), so this formats
/// just the date - there is no time-of-day to show.
String _formatOccurredAt(dynamic occurredAt) {
  final raw = occurredAt?.toString();
  if (raw == null || raw.isEmpty) return '';
  final date = DateTime.tryParse(raw);
  if (date == null) return '';
  return DateFormat('M.d').format(date);
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeDataAsync = ref.watch(homeDataProvider);
    final user = ref.watch(authProvider).user;
    final selectedFilter = ref.watch(homeCategoryFilterProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final categoryDirectory = ref.watch(categoryDirectoryProvider);
    final recentTxAsync = ref.watch(homeRecentTransactionsProvider);
    final recentRegretAsync = ref.watch(recentRegrettableTransactionsProvider);
    // Single "today" for this whole build - the date pill, D-Day and
    // budget-cycle range must never disagree about what day it is.
    final now = ref.watch(currentDateProvider);
    final sections = ref.watch(homeSectionVisibilityProvider);

    final glass = context.glass;

    return Scaffold(
      // The tab shell paints the ambient background behind every tab.
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: glass.accent,
              onRefresh: () => _onRefresh(ref),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Header + Date Pill + the main card share one hero panel
                  // that dissolves into the ambient page background right
                  // where "실시간 거래 내역" begins.
                  SliverToBoxAdapter(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            ...glass.heroGradient,
                            glass.heroGradient.last.withValues(alpha: 0),
                          ],
                          stops: const [0.0, 0.14, 0.45, 0.72, 1.0],
                        ),
                      ),
                      child: Column(
                        children: [
                          // Top Header
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.gutter,
                              12,
                              AppSpacing.gutter,
                              0,
                            ),
                            // NOTE: The Figma header (335:8091) only shows the bell
                            // icon; the profile avatar was removed because MyPage
                            // is now reached via the 5th bottom-nav tab.
                            child: TabHeaderTitleRow(
                              title: '${user?.name ?? '사용자'}님, 안녕하세요',
                              subtitle: 'How are you feeling today?',
                              actions: [
                                TabHeaderIconButton(
                                  icon: Icons.notifications_none,
                                  onPressed: () {},
                                ),
                              ],
                            ),
                          ),

                          // Date Pill
                          Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                decoration: AppSurfaces.onHeroPill
                                    .toBoxDecoration(),
                                child: Text(
                                  DateFormat('M. d. E', 'ko_KR').format(now),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Hero card (homeData dependent)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.gutter,
                              20,
                              AppSpacing.gutter,
                              0,
                            ),
                            child: homeDataAsync.when(
                              loading: () => const Padding(
                                padding: EdgeInsets.symmetric(vertical: 60),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  ),
                                ),
                              ),
                              error: (err, st) {
                                // Full exception stays in the debug console only - the
                                // card must never surface DioException/SocketException
                                // internals (host, port, etc.) to end users.
                                debugPrint('홈 데이터 로딩 실패: $err');
                                return GlassSurface(
                                  radius: AppRadii.xl,
                                  fill: glass.heroCardFill,
                                  border: glass.heroCardBorder,
                                  blurSigma: GlassBlur.card,
                                  padding: const EdgeInsets.all(20),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.error_outline,
                                          color: glass.negative,
                                          size: 36,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '홈 정보를 불러오지 못했어요',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: glass.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '잠시 후 다시 시도해주세요.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: glass.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        ElevatedButton(
                                          onPressed: () =>
                                              ref.invalidate(homeDataProvider),
                                          child: const Text('다시 시도'),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              data: (data) => _HomeHeroCard(
                                data: data,
                                onTodayTap: () =>
                                    _showTodayDetailSheet(context, data),
                                onCycleTap: () => _showSalaryCycleDetailSheet(
                                  context,
                                  data,
                                  now,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 실시간 거래 내역 (header, chips, cards) - can be hidden in
                  // 앱 설정 > 홈 화면 설정.
                  if (sections.showRecentTransactions) ...[
                    // Transactions Header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                        child: HomeSectionHeader(
                          title: '실시간 거래 내역',
                          actionLabel: '더보기',
                          // Branch-local push (not rootNavigator) so the shared
                          // Bottom Navigation shell stays visible here
                          // (docs/figma/report-spec.md C.8.1). Category Report's
                          // "거래 내역 보기" also opens this screen, but on top of
                          // that nav-less detail page, so it has no nav there.
                          onActionTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const TransactionListScreen(),
                            ),
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
                              final expenseCategories = majorCategoriesFor(
                                categories,
                                'core.expense',
                              );
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
                                        onTap: () => ref
                                            .read(
                                              homeCategoryFilterProvider
                                                  .notifier,
                                            )
                                            .setFilter('ALL'),
                                      ),
                                    );
                                  }
                                  final c = expenseCategories[i - 1];
                                  final id = (c['id'] ?? '').toString();
                                  final name = (c['name'] ?? '').toString();
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: CategoryFilterChip(
                                      label: name,
                                      icon: CategoryAppearance.fromJson(c).icon,
                                      selected: selectedFilter == id,
                                      onTap: () => ref
                                          .read(
                                            homeCategoryFilterProvider.notifier,
                                          )
                                          .setFilter(id),
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
                          loading: () => Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: glass.accent,
                              ),
                            ),
                          ),
                          error: (e, st) => Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              '거래 내역 로딩 오류: $e',
                              style: TextStyle(color: glass.textTertiary),
                            ),
                          ),
                          data: (transactions) {
                            if (transactions.isEmpty) {
                              return GlassCard(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 28,
                                  horizontal: 20,
                                ),
                                radius: AppRadii.md,
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.receipt_long_outlined,
                                      size: 28,
                                      color: glass.textTertiary,
                                    ),
                                    const SizedBox(height: 8),
                                    Center(
                                      child: Text(
                                        '오늘 등록된 거래 내역이 없습니다.',
                                        style: AppTextStyles.caption.copyWith(
                                          color: glass.textSecondary,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return _buildTransactionGrid(context, transactions);
                          },
                        ),
                      ),
                    ),
                  ],

                  // "최근 소비 돌아보기" - wired to recentRegrettableTransactionsProvider,
                  // the most recently *evaluated* REGRETTABLE/BAD expenses from
                  // `/api/transactions?evaluation=REGRETTABLE,BAD&sort=consumptionEvaluationUpdatedAt`
                  // (see home_provider.dart and API_SPEC.md). This used to be
                  // scoped to literally "yesterday", which went empty on any day
                  // yesterday had no evaluated transaction even if older ones
                  // existed. Rows can now span several different days, so `time`
                  // shows each transaction's occurredAt date instead of being left
                  // blank.
                  if (sections.showRegretReview)
                    SliverToBoxAdapter(
                      child: recentRegretAsync.maybeWhen(
                        data: (transactions) => RegretSpendingSection(
                          items: transactions
                              .whereType<Map>()
                              .map(
                                (tx) => {
                                  'merchantOrTitle':
                                      (tx['merchantOrTitle'] ??
                                              categoryDirectory
                                                  .nameForTransaction(tx) ??
                                              '내역')
                                          .toString(),
                                  'time': _formatOccurredAt(tx['occurredAt']),
                                  'amountLabel':
                                      '-${context.formatWon(_toInt(tx['amount']))}',
                                  'categoryPath':
                                      categoryDirectory.nameForTransaction(
                                        tx,
                                      ) ??
                                      '기타',
                                  'id': tx['id'],
                                },
                              )
                              .toList(),
                          // Branch-local push (not rootNavigator) so the shared
                          // Bottom Navigation shell stays visible here, matching
                          // every other entry point into Transaction Detail
                          // (docs/figma/report-spec.md C.8).
                          onItemTap: (item) => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TransactionDetailScreen(
                                transactionId: item['id'].toString(),
                              ),
                            ),
                          ),
                        ),
                        orElse: () => const RegretSpendingSection(items: null),
                      ),
                    ),

                  // Bottom spacer
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
          ),
          ManualInputFabOverlay(
            onPressed: () => AddTransactionModal.show(context),
          ),
        ],
      ),
    );
  }

  Future<void> _onRefresh(WidgetRef ref) async {
    ref.invalidate(homeDataProvider);
    ref.invalidate(homeRecentTransactionsProvider);
    ref.invalidate(recentRegrettableTransactionsProvider);
    await Future.wait([
      ref.read(homeDataProvider.future),
      ref.read(homeRecentTransactionsProvider.future),
      ref.read(recentRegrettableTransactionsProvider.future),
    ]);
  }

  void _showTodayDetailSheet(BuildContext context, HomeData data) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DetailSheet(
        title: '오늘 쓸 수 있는 돈',
        headline: context.formatWon(data.remainingToday),
        isNegative: data.remainingToday < 0,
        rows: [
          _DetailRow(
            Icons.stars_outlined,
            '오늘 권장 소비액',
            context.formatWon(data.recommendedAmount),
          ),
          _DetailRow(
            Icons.access_time,
            '오늘 사용한 금액',
            context.formatWon(data.spentAmount),
          ),
          _DetailRow(
            Icons.check_circle_outline,
            '오늘 남은 금액',
            context.formatWon(data.remainingToday),
          ),
          _DetailRow(
            Icons.event_outlined,
            '다음 수입까지',
            data.salaryCountdownLabel,
          ),
          _DetailRow(
            Icons.account_balance_wallet_outlined,
            '남은 가용금액',
            context.formatWon(data.remainingFlexibleAmount),
          ),
        ],
        footer: '현재 수입 주기와 남은 금액을 기준으로 계산되었어요.',
      ),
    );
  }

  void _showSalaryCycleDetailSheet(
    BuildContext context,
    HomeData data,
    DateTime now,
  ) {
    final cycleEnd = now.add(Duration(days: data.daysUntilSalary));
    final cycleStart = DateTime(
      cycleEnd.year,
      cycleEnd.month - 1,
      cycleEnd.day,
    );
    final dateFormat = DateFormat('M월 d일', 'ko_KR');

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DetailSheet(
        title: '이번 수입 주기',
        subtitle: data.awaitingSalary
            ? '예정 수입일이 지났어요'
            : '${dateFormat.format(cycleStart)} ~ ${dateFormat.format(cycleEnd)}',
        headline: data.salaryCountdownLabel,
        isAccent: true,
        rows: [
          _DetailRow(
            Icons.check_circle_outline,
            '현재 남은 금액',
            context.formatWon(data.remainingFlexibleAmount),
          ),
          _DetailRow(
            Icons.payments_outlined,
            '사용한 금액',
            context.formatWon(data.usedFlexibleAmount),
          ),
          _DetailRow(
            Icons.pie_chart_outline,
            '사용률',
            '${(data.flexibleUsageRatio * 100).round()}%',
          ),
          _DetailRow(
            Icons.hourglass_bottom,
            '남은 기간',
            data.awaitingSalary ? '수입 입력 전' : '${data.daysUntilSalary}일',
          ),
          _DetailRow(
            Icons.stars_outlined,
            '오늘 권장 소비액',
            context.formatWon(data.recommendedAmount),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionGrid(
    BuildContext context,
    List<dynamic> transactions,
  ) {
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
                // Branch-local push (not rootNavigator) so the shared
                // Bottom Navigation shell stays visible here, matching
                // every other entry point into Transaction Detail
                // (docs/figma/report-spec.md C.8).
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TransactionDetailScreen(
                      transactionId: tx['id'].toString(),
                    ),
                  ),
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
  final bool isNegative;
  final bool isAccent;
  final List<_DetailRow> rows;
  final String? footer;

  const _DetailSheet({
    required this.title,
    this.subtitle,
    required this.headline,
    this.isNegative = false,
    this.isAccent = false,
    required this.rows,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final headlineColor = isNegative
        ? glass.negative
        : (isAccent ? glass.accentText : glass.textPrimary);
    return GlassSheet(
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: glass.textSecondary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: TextStyle(fontSize: 13, color: glass.textTertiary),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                headline,
                style: AppTextStyles.amountHero.copyWith(
                  fontSize: 32,
                  color: headlineColor,
                ),
              ),
              const SizedBox(height: 16),
              // One inset group instead of loose rows, so label/value pairs
              // scan as a table.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: glass.insetFill,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Column(
                  children: [
                    for (final row in rows)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        child: Row(
                          children: [
                            Icon(row.icon, size: 18, color: glass.accent),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                row.label,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: glass.textSecondary,
                                ),
                              ),
                            ),
                            Text(
                              row.value,
                              style: AppTextStyles.amountMedium.copyWith(
                                fontSize: 14,
                                color: glass.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (footer != null) ...[
                const SizedBox(height: 12),
                Text(
                  footer!,
                  style: TextStyle(fontSize: 12, color: glass.textTertiary),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('확인'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The main Home card: "오늘 쓸 수 있는 돈" first and largest, then the
/// income cycle and how much of its flexible budget is used. Two tap areas
/// open the same two detail sheets as before (today / income cycle).
class _HomeHeroCard extends StatelessWidget {
  final HomeData data;
  final VoidCallback onTodayTap;
  final VoidCallback onCycleTap;

  const _HomeHeroCard({
    required this.data,
    required this.onTodayTap,
    required this.onCycleTap,
  });

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final isOver = data.remainingToday < 0;
    final usedPct = (data.flexibleUsageRatio * 100).round();
    final amountColor = isOver ? glass.negative : glass.textPrimary;

    return GlassSurface(
      radius: AppRadii.xl,
      fill: glass.heroCardFill,
      border: glass.heroCardBorder,
      blurSigma: GlassBlur.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Today's spendable amount.
          InkWell(
            onTap: onTodayTap,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadii.xl),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '오늘 쓸 수 있는 돈',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: glass.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: glass.textTertiary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          context.formatWon(
                            data.remainingToday,
                            withUnit: false,
                          ),
                          style: AppTextStyles.amountHero.copyWith(
                            color: amountColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '원',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: amountColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: '권장 소비액 '),
                        TextSpan(
                          text: '/ ${context.formatWon(data.recommendedAmount)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: glass.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    style: TextStyle(fontSize: 13, color: glass.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Divider(height: 1, thickness: 1, color: glass.divider),
          ),
          // 2. Income cycle + flexible budget progress.
          InkWell(
            onTap: onCycleTap,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(AppRadii.xl),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          data.awaitingSalary
                              ? '예정 수입일이 지났어요 · '
                              : '다음 수입까지 앞으로 ',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: glass.textSecondary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: glass.accentSoft,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                        child: Text(
                          data.salaryCountdownLabel,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: glass.accentText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          '${context.formatWon(data.remainingFlexibleAmount)} 남았어요',
                          style: AppTextStyles.amountLarge.copyWith(
                            fontSize: 20,
                            color: glass.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$usedPct% 사용',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: usedPct > 100
                              ? glass.negative
                              : glass.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Single continuous gauge with 25/50/75% ticks - ratio
                  // calculation itself is unchanged.
                  GaugeProgressBar(
                    ratio: data.flexibleUsageRatio,
                    backgroundColor: glass.track,
                    tickColor: glass.heroCardFill.withValues(alpha: 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
