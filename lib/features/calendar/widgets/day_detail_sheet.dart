import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/format/money_format.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/category/category_appearance.dart';
import '../../policy/providers/policy_provider.dart';
import '../../transaction/screens/add_transaction_screen.dart';
import '../providers/daily_recommended_provider.dart';
import '../screens/calendar_screen.dart';
import '../screens/day_transactions_screen.dart';
import '../utils/daily_budget_usage.dart';
import '../../../core/theme/wallet_glass.dart';

int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}

/// Figma nodes 362:2359 ("거래 내역"+"관심 정책") and 362:2573 ("관심 정책"
/// expanded) are two states of the same day-detail sheet: tapping an
/// interested-policy row expands it inline instead of navigating away. Data
/// (dailyTransactionsProvider, bookmarkedPoliciesProvider) and navigation
/// targets (AddTransactionModal, DayTransactionsScreen, /policy/:id) are
/// unchanged from before - presentation only.
class DayDetailSheet extends ConsumerStatefulWidget {
  final DateTime day;

  const DayDetailSheet({super.key, required this.day});

  static Future<void> show(BuildContext context, DateTime day) {
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DayDetailSheet(day: day),
    );
  }

  @override
  ConsumerState<DayDetailSheet> createState() => _DayDetailSheetState();
}

class _DayDetailSheetState extends ConsumerState<DayDetailSheet> {
  String? _expandedPolicyId;

  String _formatCurrency(int amount) => context.formatWon(amount);

  @override
  Widget build(BuildContext context) {
    final day = widget.day;
    final transactionsAsync = ref.watch(dailyTransactionsProvider(day));

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return GlassSheet(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('M월 d일 (E)', 'ko_KR').format(day),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: context.glass.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: context.glass.textSecondary),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '거래 내역',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: context.glass.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    transactionsAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, st) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          '불러오지 못했습니다: $e',
                          style: TextStyle(color: context.glass.textTertiary),
                        ),
                      ),
                      data: (transactions) =>
                          _buildTransactionCard(context, transactions),
                    ),
                    const SizedBox(height: 24),
                    _buildInterestedPolicyCard(context, ref),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTransactionCard(
    BuildContext context,
    List<dynamic> transactions,
  ) {
    int income = 0;
    int expense = 0;
    for (final tx in transactions) {
      if (tx is! Map) continue;
      final amount = _toInt(tx['amount']);
      if (tx['type'] == 'INCOME') {
        income += amount;
      } else {
        expense += amount;
      }
    }
    final net = income - expense;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: glassDecoration(context, radius: AppRadii.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _summaryItem('총 수입', income, context.glass.accentText)),
              Expanded(
                child: _summaryItem('총 지출', -expense, context.glass.negative),
              ),
              Expanded(
                child: _summaryItem(
                  '순변동',
                  net,
                  net >= 0 ? context.glass.accentText : context.glass.negative,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: context.glass.divider),
          const SizedBox(height: 12),
          _BudgetUsageRow(day: widget.day, spent: expense),
          const SizedBox(height: 12),
          if (transactions.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  '이 날은 등록된 거래가 없어요.',
                  style: TextStyle(color: context.glass.textTertiary),
                ),
              ),
            )
          else ...[
            ...transactions.take(4).map((tx) => _transactionRow(context, tx)),
            if (transactions.length > 4)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  '… 외 ${transactions.length - 4}건',
                  style: TextStyle(
                    color: context.glass.textTertiary,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.glass.accentText,
                    backgroundColor: context.glass.chipFill,
                    side: BorderSide(color: context.glass.chipSelectedBorder),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    AddTransactionModal.show(context, initialDate: widget.day);
                  },
                  child: const Text(
                    '거래 추가',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            DayTransactionsScreen(day: widget.day),
                      ),
                    );
                  },
                  child: const Text(
                    '전체보기',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, int amount, Color color) {
    final sign = amount > 0 ? '+' : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: context.glass.textTertiary),
        ),
        const SizedBox(height: 4),
        Text(
          '$sign${_formatCurrency(amount)}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _transactionRow(BuildContext context, dynamic tx) {
    if (tx is! Map) return const SizedBox.shrink();
    final amount = _toInt(tx['amount']);
    final categories = ref.watch(categoryDirectoryProvider);
    final categoryName = categories.nameForTransaction(tx);
    final name = (tx['merchantOrTitle'] ?? categoryName ?? '내역').toString();
    final occurredAt = (tx['occurredAt'] ?? '').toString();
    final time = occurredAt.length >= 16 ? occurredAt.substring(11, 16) : '';
    final isIncome = tx['type'] == 'INCOME';

    return InkWell(
      onTap: () {
        Navigator.pop(context);
        AddTransactionModal.show(
          context,
          initialDate: widget.day,
          existingTransaction: Map<String, dynamic>.from(tx),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              categories.iconForTransaction(tx),
              size: 20,
              color: context.glass.accentText,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.glass.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (time.isNotEmpty)
              Text(
                time,
                style: TextStyle(
                  fontSize: 12,
                  color: context.glass.textTertiary,
                ),
              ),
            const SizedBox(width: 10),
            Text(
              '${isIncome ? '+' : '-'}${_formatCurrency(amount)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isIncome ? context.glass.accentText : context.glass.negative,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInterestedPolicyCard(BuildContext context, WidgetRef ref) {
    // 관심(bookmarked) policies only - this used to read recommendedPoliciesProvider,
    // which is every recommended policy regardless of whether the user
    // bookmarked it, so the calendar's D-5/D-3/D-Day badges and this "관심
    // 정책" sheet card would show policies the user never marked as
    // interesting. bookmarkedPoliciesProvider (already used by
    // PolicyBookmarksScreen) is the actual "관심" source.
    final bookmarkedAsync = ref.watch(bookmarkedPoliciesProvider);

    return bookmarkedAsync.maybeWhen(
      data: (rows) {
        final policies = rows.take(3).toList();
        if (policies.isEmpty) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          decoration: glassDecoration(context, radius: AppRadii.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '관심 정책',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.glass.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              ...policies.map(
                (policy) =>
                    _policyRow(context, Map<String, dynamic>.from(policy)),
              ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _policyRow(BuildContext context, Map<String, dynamic> policy) {
    final id = (policy['id'] ?? '').toString();
    final title = (policy['title'] ?? '').toString();
    final deadline = policy['applicationEndDate'] ?? policy['deadline'];
    String? dDayLabel;
    if (deadline is String && deadline.isNotEmpty) {
      final end = DateTime.tryParse(deadline);
      if (end != null) {
        final days = end
            .difference(
              DateTime(widget.day.year, widget.day.month, widget.day.day),
            )
            .inDays;
        dDayLabel = days >= 0 ? 'D-$days' : '마감';
      }
    }
    final isExpanded = _expandedPolicyId == id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () =>
              setState(() => _expandedPolicyId = isExpanded ? null : id),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: context.glass.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (dDayLabel != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    dDayLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: context.glass.accentText,
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: context.glass.textSecondary,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) _policyExpandedDetail(context, policy),
      ],
    );
  }

  Widget _policyExpandedDetail(
    BuildContext context,
    Map<String, dynamic> policy,
  ) {
    final rows = <Widget>[];
    void addRow(String label, dynamic value) {
      final text = value?.toString();
      if (text == null || text.isEmpty) return;
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.glass.textTertiary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  color: context.glass.textPrimary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    addRow('지원 대상', policy['eligibility']);
    addRow('주요 내용', policy['summary']);
    addRow('신청 방법', policy['applicationMethod']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.glass.insetFill,
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (rows.isEmpty)
              Text(
                '상세 정보가 아직 없어요.',
                style: TextStyle(fontSize: 13, color: context.glass.textTertiary),
              )
            else
              ...rows,
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/policy/${policy['id']}');
                },
                child: Text(
                  '정책 상세보기 >',
                  style: TextStyle(
                    color: context.glass.accentText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "하루 권장 소비액 대비 사용 현황" line of the day sheet's summary card:
/// that day's recommended amount, what was actually spent, and the usage
/// percentage. The recommended amount comes from
/// [dailyRecommendedAmountProvider] and the percentage from
/// [dailyBudgetUsagePercent] - this widget only lays them out.
class _BudgetUsageRow extends ConsumerWidget {
  final DateTime day;
  final int spent;

  const _BudgetUsageRow({required this.day, required this.spent});


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommendedAsync = ref.watch(
      dailyRecommendedAmountProvider(DateTime(day.year, day.month, day.day)),
    );

    return recommendedAsync.when(
      loading: () => _message(context, '권장 소비액을 불러오는 중이에요'),
      error: (_, _) => _message(context, '권장 소비액 정보를 불러올 수 없어요'),
      data: (recommended) {
        if (recommended == null) {
          return _message(context, '권장 소비액 정보를 불러올 수 없어요');
        }
        final percent = dailyBudgetUsagePercent(
          spent: spent,
          recommended: recommended,
        );
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '하루 권장 소비액',
                    style: TextStyle(fontSize: 12, color: context.glass.textTertiary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${context.formatWon(recommended)} 중 ${context.formatWon(spent)} 사용',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: context.glass.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _percentPill(context, percent),
          ],
        );
      },
    );
  }

  // A recommended amount of 0 leaves nothing to divide by, so the pill says so
  // instead of showing 0% or infinity. Up to 100% reads in the app's green;
  // past it, in the same soft orange the report's over-budget badge uses -
  // informative, not alarming.
  Widget _percentPill(BuildContext context, double? percent) {
    final over = percent != null && percent > 100;
    final fg = percent == null
        ? context.glass.textSecondary
        : (over ? context.glass.negative : context.glass.chipSelectedText);
    final bg = percent == null
        ? context.glass.insetFill
        : (over ? context.glass.negativeSoft : context.glass.accentSoft);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        percent == null ? '계산 불가' : '${percent.round()}%',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }

  Widget _message(BuildContext context, String text) => Text(
    text,
    style: TextStyle(fontSize: 12, color: context.glass.textTertiary),
  );
}
