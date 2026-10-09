import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/format/money_format.dart';
import '../../../core/category/category_appearance.dart';
import '../../transaction/screens/add_transaction_screen.dart';
import 'calendar_screen.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/theme/wallet_glass.dart';
import '../../../data/api/api_error.dart';

int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}

class DayTransactionsScreen extends ConsumerWidget {
  final DateTime day;

  const DayTransactionsScreen({super.key, required this.day});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(dailyTransactionsProvider(day));

    return WalletBackground(child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(DateFormat('M월 d일 (E)', 'ko_KR').format(day)),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        foregroundColor: context.glass.textPrimary,
        elevation: 0,
      ),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('불러오지 못했습니다.\n${userErrorMessage(e)}', textAlign: TextAlign.center)),
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
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                decoration: glassDecoration(context, radius: AppRadii.lg),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '전체 거래 내역',
                      style: TextStyle(
                        fontSize: 15,
                        color: context.glass.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _summaryItem(
                            context,
                            '총 수입',
                            income,
                            context.glass.accentText,
                          ),
                        ),
                        Expanded(
                          child: _summaryItem(
                            context,
                            '총 지출',
                            -expense,
                            context.glass.negative,
                          ),
                        ),
                        Expanded(
                          child: _summaryItem(
                            context,
                            '순변동',
                            net,
                            net >= 0 ? context.glass.accentText : context.glass.negative,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: transactions.isEmpty
                    ? Center(
                        child: Text(
                          '이 날은 등록된 거래가 없어요.',
                          style: TextStyle(color: context.glass.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        itemCount: transactions.length,
                        separatorBuilder: (context, i) =>
                            Divider(height: 1, color: context.glass.divider),
                        itemBuilder: (context, i) => _transactionTile(
                          context,
                          transactions[i],
                          ref.watch(categoryDirectoryProvider),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    ));
  }

  Widget _summaryItem(
    BuildContext context,
    String label,
    int amount,
    Color color,
  ) {
    final sign = amount > 0 ? '+' : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: context.glass.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          '$sign${context.formatWon(amount)}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _transactionTile(
    BuildContext context,
    dynamic tx,
    CategoryDirectory categories,
  ) {
    if (tx is! Map) return const SizedBox.shrink();
    final amount = _toInt(tx['amount']);
    final categoryName = categories.nameForTransaction(tx) ?? '';
    final name =
        (tx['merchantOrTitle'] ??
                (categoryName.isEmpty ? null : categoryName) ??
                '내역')
            .toString();
    final occurredAt = (tx['occurredAt'] ?? '').toString();
    final time = occurredAt.length >= 16 ? occurredAt.substring(11, 16) : '';
    final isIncome = tx['type'] == 'INCOME';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: context.glass.insetFill,
        child: Icon(
          Icons.receipt_long_outlined,
          color: context.glass.textSecondary,
        ),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        [categoryName, time].where((s) => s.isNotEmpty).join(' · '),
      ),
      trailing: Text(
        '${isIncome ? '+' : '-'}${context.formatWon(amount)}',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 15,
          color: isIncome ? context.glass.accentText : context.glass.negative,
        ),
      ),
      onTap: () => AddTransactionModal.show(
        context,
        initialDate: day,
        existingTransaction: Map<String, dynamic>.from(tx),
      ),
    );
  }
}
