import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../policy/providers/policy_provider.dart';
import '../../transaction/screens/add_transaction_screen.dart';
import '../screens/calendar_screen.dart';
import '../screens/day_transactions_screen.dart';

int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}

class DayDetailSheet extends ConsumerWidget {
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

  String _formatCurrency(int amount) => '${NumberFormat('#,###').format(amount)}원';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(dailyTransactionsProvider(day));

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
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
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    transactionsAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, st) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text('불러오지 못했습니다: $e', style: const TextStyle(color: AppColors.textSecondary)),
                      ),
                      data: (transactions) => _buildContent(context, transactions),
                    ),
                    const SizedBox(height: 24),
                    _buildInterestedPolicy(context, ref),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, List<dynamic> transactions) {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary row: 총수입 / 총지출 / 순변동
        Row(
          children: [
            Expanded(child: _summaryItem('총 수입', income, AppColors.primary)),
            Expanded(child: _summaryItem('총 지출', -expense, AppColors.danger)),
            Expanded(child: _summaryItem('순변동', net, net >= 0 ? AppColors.primary : AppColors.danger)),
          ],
        ),
        const SizedBox(height: 20),
        const Text('거래 내역 미리보기', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (transactions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: Text('이 날은 등록된 거래가 없어요.', style: TextStyle(color: AppColors.textSecondary))),
          )
        else ...[
          ...transactions.take(4).map((tx) => _transactionRow(context, tx)),
          if (transactions.length > 4)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text('… 외 ${transactions.length - 4}건', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  AddTransactionModal.show(context, initialDate: day);
                },
                child: const Text('거래 추가', style: TextStyle(fontWeight: FontWeight.bold)),
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
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => DayTransactionsScreen(day: day)),
                  );
                },
                child: const Text('전체보기', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _summaryItem(String label, int amount, Color color) {
    final sign = amount > 0 ? '+' : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text('$sign${_formatCurrency(amount)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _transactionRow(BuildContext context, dynamic tx) {
    if (tx is! Map) return const SizedBox.shrink();
    final amount = _toInt(tx['amount']);
    final name = (tx['merchantOrTitle'] ?? (tx['category'] is Map ? tx['category']['name'] : null) ?? '내역').toString();
    final occurredAt = (tx['occurredAt'] ?? '').toString();
    final time = occurredAt.length >= 16 ? occurredAt.substring(11, 16) : '';
    final isIncome = tx['type'] == 'INCOME';

    return InkWell(
      onTap: () {
        Navigator.pop(context);
        AddTransactionModal.show(context, initialDate: day, existingTransaction: Map<String, dynamic>.from(tx));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.receipt_long_outlined, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            if (time.isNotEmpty) Text(time, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(width: 10),
            Text(
              '${isIncome ? '+' : '-'}${_formatCurrency(amount)}',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isIncome ? AppColors.primary : AppColors.danger),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInterestedPolicy(BuildContext context, WidgetRef ref) {
    final recommendedAsync = ref.watch(recommendedPoliciesProvider);

    return recommendedAsync.maybeWhen(
      data: (data) {
        final policies = data['policies'] as List<dynamic>? ?? [];
        if (policies.isEmpty) return const SizedBox.shrink();
        final policy = policies.first as Map<String, dynamic>;
        final deadline = policy['applicationEndDate'] ?? policy['deadline'];
        String? dDayLabel;
        if (deadline is String && deadline.isNotEmpty) {
          final end = DateTime.tryParse(deadline);
          if (end != null) {
            final days = end.difference(DateTime(day.year, day.month, day.day)).inDays;
            dDayLabel = days >= 0 ? 'D-$days' : '마감';
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('관심 정책', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            InkWell(
              onTap: () {
                Navigator.pop(context);
                context.push('/policy/${policy['id']}');
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        (policy['category'] ?? '정책').toString(),
                        style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        (policy['title'] ?? '').toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (dDayLabel != null) ...[
                      const SizedBox(width: 8),
                      Text(dDayLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
