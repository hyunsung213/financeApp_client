import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/category/category_appearance.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/surface_style.dart';
import '../theme/home_tokens.dart';

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
class TransactionGridCard extends ConsumerWidget {
  final Map<dynamic, dynamic> transaction;
  final VoidCallback? onTap;

  const TransactionGridCard({super.key, required this.transaction, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tx = transaction;
    final categories = ref.watch(categoryDirectoryProvider);
    final amount = _toInt(tx['amount']);
    final title = (tx['merchantOrTitle'] ?? categories.nameForTransaction(tx) ?? '내역').toString();
    final categoryName = categories.nameForTransaction(tx) ?? '지출';
    final dateStr = (tx['occurredAt'] ?? '').toString();
    final timeOrDate = dateStr.length >= 10 ? dateStr.substring(5) : dateStr;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.itemPadding),
        decoration: AppSurfaces.contentCard.toBoxDecoration(),
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
                    borderRadius: BorderRadius.circular(AppRadii.pill),
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
                  decoration: BoxDecoration(color: HomeTokens.chipActiveBg, borderRadius: BorderRadius.circular(8)),
                  child: Icon(categories.iconForTransaction(tx), size: 17, color: HomeTokens.accent),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
