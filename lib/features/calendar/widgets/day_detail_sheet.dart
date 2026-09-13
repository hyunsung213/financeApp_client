import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../home/theme/home_tokens.dart';
import '../../home/utils/category_icons.dart';
import '../../policy/providers/policy_provider.dart';
import '../../transaction/screens/add_transaction_screen.dart';
import '../screens/calendar_screen.dart';
import '../screens/day_transactions_screen.dart';

int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}

/// Figma nodes 362:2359 ("거래 내역"+"관심 정책") and 362:2573 ("관심 정책"
/// expanded) are two states of the same day-detail sheet: tapping an
/// interested-policy row expands it inline instead of navigating away. Data
/// (dailyTransactionsProvider, recommendedPoliciesProvider) and navigation
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

  String _formatCurrency(int amount) => '${NumberFormat('#,###').format(amount)}원';

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
        return Container(
          decoration: const BoxDecoration(
            color: HomeTokens.pageBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
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
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: HomeTokens.textDark),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('거래 내역', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: HomeTokens.textDark)),
                    const SizedBox(height: 10),
                    transactionsAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, st) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text('불러오지 못했습니다: $e', style: const TextStyle(color: HomeTokens.textMuted)),
                      ),
                      data: (transactions) => _buildTransactionCard(context, transactions),
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

  Widget _buildTransactionCard(BuildContext context, List<dynamic> transactions) {
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
      decoration: BoxDecoration(
        color: HomeTokens.cardSurface,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2, offset: const Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _summaryItem('총 수입', income, HomeTokens.accent)),
              Expanded(child: _summaryItem('총 지출', -expense, HomeTokens.negative)),
              Expanded(child: _summaryItem('순변동', net, net >= 0 ? HomeTokens.accent : HomeTokens.negative)),
            ],
          ),
          const SizedBox(height: 12),
          if (transactions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('이 날은 등록된 거래가 없어요.', style: TextStyle(color: HomeTokens.textMuted))),
            )
          else ...[
            ...transactions.take(4).map((tx) => _transactionRow(context, tx)),
            if (transactions.length > 4)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text('… 외 ${transactions.length - 4}건', style: const TextStyle(color: HomeTokens.textMuted, fontSize: 13)),
              ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: HomeTokens.accent,
                    side: const BorderSide(color: HomeTokens.accent),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    AddTransactionModal.show(context, initialDate: widget.day);
                  },
                  child: const Text('거래 추가', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HomeTokens.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => DayTransactionsScreen(day: widget.day)),
                    );
                  },
                  child: const Text('전체보기', style: TextStyle(fontWeight: FontWeight.bold)),
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
        Text(label, style: const TextStyle(fontSize: 12, color: HomeTokens.textMuted)),
        const SizedBox(height: 4),
        Text('$sign${_formatCurrency(amount)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _transactionRow(BuildContext context, dynamic tx) {
    if (tx is! Map) return const SizedBox.shrink();
    final amount = _toInt(tx['amount']);
    final name = (tx['merchantOrTitle'] ?? (tx['category'] is Map ? tx['category']['name'] : null) ?? '내역').toString();
    final categoryName = (tx['category'] is Map ? tx['category']['name'] : null)?.toString();
    final occurredAt = (tx['occurredAt'] ?? '').toString();
    final time = occurredAt.length >= 16 ? occurredAt.substring(11, 16) : '';
    final isIncome = tx['type'] == 'INCOME';

    return InkWell(
      onTap: () {
        Navigator.pop(context);
        AddTransactionModal.show(context, initialDate: widget.day, existingTransaction: Map<String, dynamic>.from(tx));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(categoryIconFor(tx['categoryId']?.toString(), categoryName), size: 20, color: HomeTokens.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: HomeTokens.textDark), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            if (time.isNotEmpty) Text(time, style: const TextStyle(fontSize: 12, color: HomeTokens.textMuted)),
            const SizedBox(width: 10),
            Text(
              '${isIncome ? '+' : '-'}${_formatCurrency(amount)}',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isIncome ? HomeTokens.accent : HomeTokens.negative),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInterestedPolicyCard(BuildContext context, WidgetRef ref) {
    final recommendedAsync = ref.watch(recommendedPoliciesProvider);

    return recommendedAsync.maybeWhen(
      data: (data) {
        final policies = (data['policies'] as List<dynamic>? ?? []).whereType<Map>().take(3).toList();
        if (policies.isEmpty) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          decoration: BoxDecoration(
            color: HomeTokens.cardSurface,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2, offset: const Offset(0, 1))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('관심 정책', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: HomeTokens.textDark)),
              const SizedBox(height: 10),
              ...policies.map((policy) => _policyRow(context, Map<String, dynamic>.from(policy))),
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
        final days = end.difference(DateTime(widget.day.year, widget.day.month, widget.day.day)).inDays;
        dDayLabel = days >= 0 ? 'D-$days' : '마감';
      }
    }
    final isExpanded = _expandedPolicyId == id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expandedPolicyId = isExpanded ? null : id),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: HomeTokens.textDark), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                if (dDayLabel != null) ...[
                  const SizedBox(width: 8),
                  Text(dDayLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: HomeTokens.accent)),
                ],
                const SizedBox(width: 4),
                Icon(isExpanded ? Icons.expand_less : Icons.expand_more, size: 20, color: HomeTokens.textFaint),
              ],
            ),
          ),
        ),
        if (isExpanded) _policyExpandedDetail(context, policy),
      ],
    );
  }

  Widget _policyExpandedDetail(BuildContext context, Map<String, dynamic> policy) {
    final rows = <Widget>[];
    void addRow(String label, dynamic value) {
      final text = value?.toString();
      if (text == null || text.isEmpty) return;
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: HomeTokens.textMuted)),
            const SizedBox(height: 2),
            Text(text, style: const TextStyle(fontSize: 13, color: HomeTokens.textDark)),
          ],
        ),
      ));
    }

    addRow('지원 대상', policy['eligibility']);
    addRow('주요 내용', policy['summary']);
    addRow('신청 방법', policy['applicationMethod']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: HomeTokens.pageBackground, borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (rows.isEmpty)
              const Text('상세 정보가 아직 없어요.', style: TextStyle(fontSize: 13, color: HomeTokens.textMuted))
            else
              ...rows,
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/policy/${policy['id']}');
                },
                child: const Text('정책 상세보기 >', style: TextStyle(color: HomeTokens.accent, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
