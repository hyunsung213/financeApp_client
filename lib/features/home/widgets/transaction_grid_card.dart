import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/home_tokens.dart';
import '../utils/category_icons.dart';

int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toInt();
  if (value is String) {
    final clean = value.replaceAll(RegExp(r'[^0-9.-]'), '');
    return double.tryParse(clean)?.toInt() ?? 0;
  }
  return 0;
}

/// One card in Home's "실시간 거래 내역" 2-column grid (Figma Rectangle
/// 29/34/36/38/89/90). Presentation only — the transaction map comes from
/// the existing `homeRecentTransactionsProvider` data untouched.
class TransactionGridCard extends StatelessWidget {
  final Map<dynamic, dynamic> transaction;
  final VoidCallback? onTap;

  const TransactionGridCard({super.key, required this.transaction, this.onTap});

  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    final amount = _toInt(tx['amount']);
    final title = (tx['merchantOrTitle'] ?? (tx['category'] is Map ? tx['category']['name'] : null) ?? '내역').toString();
    final categoryName = ((tx['category'] is Map ? tx['category']['name'] : null) ?? '지출').toString();
    final categoryId = (tx['categoryId'] ?? '').toString();
    final dateStr = (tx['occurredAt'] ?? '').toString();
    final timeOrDate = dateStr.length >= 10 ? dateStr.substring(5) : dateStr;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: HomeTokens.textDark), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: HomeTokens.chipInactiveBg,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: HomeTokens.chipInactiveBorder),
                  ),
                  child: Text(categoryName, style: const TextStyle(fontSize: 10, color: HomeTokens.textDark, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('${NumberFormat('#,###').format(amount)}원', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(timeOrDate, style: const TextStyle(fontSize: 12, color: HomeTokens.textMuted)),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: const Color(0xFFE8FAF0), borderRadius: BorderRadius.circular(8)),
                  child: Icon(categoryIconFor(categoryId, categoryName), size: 17, color: HomeTokens.accent),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
