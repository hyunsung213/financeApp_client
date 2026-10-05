import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/category/category_appearance.dart';
import '../../../core/format/money_format.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/wallet_glass.dart';
import '../../../core/widgets/glass.dart';

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

    final glass = context.glass;

    return GlassCard(
      onTap: onTap,
      radius: AppRadii.md,
      padding: const EdgeInsets.all(AppSpacing.itemPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: glass.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: glass.insetFill,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(categoryName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: glass.textSecondary, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            context.formatWon(amount),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.amountMedium.copyWith(fontSize: 17, fontWeight: FontWeight.w800, color: glass.textPrimary),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(timeOrDate, style: TextStyle(fontSize: 12, color: glass.textTertiary)),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: glass.accentSoft, borderRadius: BorderRadius.circular(10)),
                child: Icon(categories.iconForTransaction(tx), size: 17, color: glass.accent),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
