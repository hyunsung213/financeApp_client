import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import 'add_transaction_screen.dart';

int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toInt();
  if (value is String) {
    final clean = value.replaceAll(RegExp(r'[^0-9.-]'), '');
    return double.tryParse(clean)?.toInt() ?? 0;
  }
  return 0;
}

/// Read-only "공통 거래 상세 화면" (Figma node 335:8091 footer note).
///
/// Takes an already-fetched transaction map (e.g. from
/// `homeRecentTransactionsProvider`) and displays it — no new API call is
/// made. Editing/deleting reuses the existing `AddTransactionModal`, so
/// that logic is untouched.
class TransactionDetailScreen extends StatelessWidget {
  final Map<String, dynamic> transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  String _formatCurrency(int amount) => '${NumberFormat('#,###').format(amount)}원';

  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    final amount = _toInt(tx['amount']);
    final isIncome = tx['type'] == 'INCOME';
    final title = (tx['merchantOrTitle'] ?? (tx['category'] is Map ? tx['category']['name'] : null) ?? '내역').toString();
    final categoryName = ((tx['category'] is Map ? tx['category']['name'] : null) ?? '').toString();
    final memo = (tx['memo'] ?? '').toString();
    final occurredAt = (tx['occurredAt'] ?? '').toString();
    final date = DateTime.tryParse(occurredAt);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('거래 상세', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: '수정',
            onPressed: () => AddTransactionModal.show(context, existingTransaction: tx),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text(
            '${isIncome ? '+' : '-'}${_formatCurrency(amount)}',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: isIncome ? AppColors.primary : AppColors.danger),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                if (categoryName.isNotEmpty) _detailRow('카테고리', categoryName),
                if (date != null) _detailRow('일시', DateFormat('yyyy. M. d (E) HH:mm', 'ko_KR').format(date)),
                if (memo.isNotEmpty) _detailRow('메모', memo),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 72, child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
        ],
      ),
    );
  }
}
