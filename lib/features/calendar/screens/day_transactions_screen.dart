import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../transaction/screens/add_transaction_screen.dart';
import 'calendar_screen.dart';

int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}

class DayTransactionsScreen extends ConsumerWidget {
  final DateTime day;

  const DayTransactionsScreen({super.key, required this.day});

  String _formatCurrency(int amount) => '${NumberFormat('#,###').format(amount)}원';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(dailyTransactionsProvider(day));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(DateFormat('M월 d일 (E)', 'ko_KR').format(day)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('불러오지 못했습니다: $e')),
        data: (transactions) {
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
            children: [
              Container(
                width: double.infinity,
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('전체 거래 내역', style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _summaryItem('총 수입', income, AppColors.primary)),
                        Expanded(child: _summaryItem('총 지출', -expense, AppColors.danger)),
                        Expanded(child: _summaryItem('순변동', net, net >= 0 ? AppColors.primary : AppColors.danger)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: transactions.isEmpty
                    ? const Center(child: Text('이 날은 등록된 거래가 없어요.', style: TextStyle(color: AppColors.textSecondary)))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        itemCount: transactions.length,
                        separatorBuilder: (context, i) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        itemBuilder: (context, i) => _transactionTile(context, transactions[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _summaryItem(String label, int amount, Color color) {
    final sign = amount > 0 ? '+' : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text('$sign${_formatCurrency(amount)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _transactionTile(BuildContext context, dynamic tx) {
    if (tx is! Map) return const SizedBox.shrink();
    final amount = _toInt(tx['amount']);
    final name = (tx['merchantOrTitle'] ?? (tx['category'] is Map ? tx['category']['name'] : null) ?? '내역').toString();
    final categoryName = ((tx['category'] is Map ? tx['category']['name'] : null) ?? '').toString();
    final occurredAt = (tx['occurredAt'] ?? '').toString();
    final time = occurredAt.length >= 16 ? occurredAt.substring(11, 16) : '';
    final isIncome = tx['type'] == 'INCOME';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: AppColors.background,
        child: const Icon(Icons.receipt_long_outlined, color: AppColors.textSecondary),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text([categoryName, time].where((s) => s.isNotEmpty).join(' · ')),
      trailing: Text(
        '${isIncome ? '+' : '-'}${_formatCurrency(amount)}',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isIncome ? AppColors.primary : AppColors.danger),
      ),
      onTap: () => AddTransactionModal.show(context, initialDate: day, existingTransaction: Map<String, dynamic>.from(tx)),
    );
  }
}
