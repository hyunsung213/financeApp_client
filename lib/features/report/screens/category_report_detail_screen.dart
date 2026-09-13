import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';

num _toNum(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value;
  return num.tryParse(value.toString()) ?? 0;
}

int _toInt(dynamic value) => _toNum(value).toInt();

/// Full category breakdown for a month. Shows each category's share of total
/// spend as a progress bar. There's no per-category budget in the backend
/// data model (BudgetCycleAllocation is keyed by spendability, not by
/// category), so this shows share-of-total-spend, not budget-vs-actual.
class CategoryReportDetailScreen extends StatelessWidget {
  final DateTime month;
  final int totalExpense;
  final List<Map<String, dynamic>> categories;

  const CategoryReportDetailScreen({
    super.key,
    required this.month,
    required this.totalExpense,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text('${month.month}월 카테고리 별 지출'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (context, i) {
          final c = categories[i];
          final name = (c['category'] ?? '기타').toString();
          final amount = _toInt(c['amount']);
          final percent = _toNum(c['percentage']).toDouble();
          final count = _toInt(c['transactionCount']);

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    Text('${NumberFormat('#,###').format(amount)}원', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (percent / 100).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: const Color(0xFFF3F4F6),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
                const SizedBox(height: 8),
                Text('전체의 ${percent.round()}% · 거래 $count건', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          );
        },
      ),
    );
  }
}
