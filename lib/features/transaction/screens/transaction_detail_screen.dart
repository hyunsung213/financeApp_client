import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/format/money_format.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/category/category_appearance.dart';
import '../providers/transaction_provider.dart';
import 'add_transaction_screen.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/theme/wallet_glass.dart';
import '../../../data/api/api_error.dart';

int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toInt();
  if (value is String) {
    final clean = value.replaceAll(RegExp(r'[^0-9.-]'), '');
    return double.tryParse(clean)?.toInt() ?? 0;
  }
  return 0;
}

/// Common "거래 상세" screen (Figma node 470:9711), reused from Home,
/// Report, and Calendar alike. Always fetches by id via
/// `GET /api/transactions/:id` (`transactionByIdProvider`) instead of only
/// rendering whatever partial object the caller already had, so it works
/// the same way no matter where it was opened from.
class TransactionDetailScreen extends ConsumerWidget {
  final String transactionId;

  const TransactionDetailScreen({super.key, required this.transactionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(transactionByIdProvider(transactionId));

    return WalletBackground(child: Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Same rounded-bottom hero gradient as Report Main (Figma keeps
          // this header style consistent across screens).
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 140,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [context.glass.heroGradient[2], context.glass.heroGradient[2].withValues(alpha: 0)],
                ),
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(AppRadii.button), bottomRight: Radius.circular(AppRadii.button)),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios_new, size: 20, color: context.glass.textPrimary),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Text('거래 상세', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: context.glass.textPrimary)),
                    ],
                  ),
                ),
                Expanded(
                  child: txAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, st) => Center(child: Text('거래 내역을 불러오지 못했어요\n${userErrorMessage(e)}', textAlign: TextAlign.center)),
                    data: (tx) => _DetailBody(tx: tx),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ));
  }
}

class _DetailBody extends ConsumerWidget {
  final Map<String, dynamic> tx;
  const _DetailBody({required this.tx});


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final amount = _toInt(tx['amount']);
    final type = (tx['type'] ?? 'EXPENSE').toString();
    final isIncome = type == 'INCOME';
    final categories = ref.watch(categoryDirectoryProvider);
    final categoryName = categories.nameForTransaction(tx);
    final title = (tx['merchantOrTitle'] ?? categoryName ?? '내역').toString();
    final memo = (tx['memo'] ?? '').toString();
    final occurredAt = (tx['occurredAt'] ?? '').toString();
    final date = DateTime.tryParse(occurredAt);
    final typeLabel = switch (type) { 'INCOME' => '수입', 'SAVING' => '저축', _ => '지출' };

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(color: context.glass.accentSoft, shape: BoxShape.circle),
                child: Icon(categories.iconForTransaction(tx), size: 32, color: context.glass.chipSelectedText),
              ),
              const SizedBox(height: 12),
              Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: context.glass.textPrimary)),
              const SizedBox(height: 6),
              Text(
                '${isIncome ? '+' : '-'}${context.formatWon(amount)}',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w600, color: isIncome ? context.glass.chipSelectedText : context.glass.negative),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Figma renders each field as its own separate rounded card with a
        // gap between them, not one card with internal dividers.
        _DetailCard(
          child: _EditableRow(
            label: '거래 유형',
            value: typeLabel,
            valueColor: isIncome ? context.glass.chipSelectedText : context.glass.negative,
            onTap: () => AddTransactionModal.show(context, existingTransaction: tx),
          ),
        ),
        const SizedBox(height: 8),
        _DetailCard(
          child: _EditableRow(
            label: '날짜',
            value: date == null ? '-' : DateFormat('M월 d일 HH:mm', 'ko_KR').format(date),
            onTap: () => AddTransactionModal.show(context, existingTransaction: tx),
          ),
        ),
        const SizedBox(height: 8),
        _DetailCard(
          child: _EditableRow(
            label: '카테고리',
            value: categoryName ?? '미분류',
            onTap: () => AddTransactionModal.show(context, existingTransaction: tx),
          ),
        ),
        const SizedBox(height: 8),
        const _DetailCard(child: _MoodRow()),
        const SizedBox(height: 8),
        _DetailCard(
          child: _EditableRow(
            label: '메모',
            value: memo.isEmpty ? '메모 추가' : memo,
            valueColor: context.glass.textTertiary,
            trailingIcon: Icons.edit_outlined,
            onTap: () => AddTransactionModal.show(context, existingTransaction: tx),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 55,
          child: OutlinedButton(
            onPressed: () => _confirmDelete(context, ref),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.glass.negative,
              side: BorderSide(color: context.glass.negative.withValues(alpha: 0.35)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.button)),
            ),
            child: const Text('거래 삭제', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20)),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('내역 삭제'),
        content: const Text('이 내역을 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('삭제', style: TextStyle(color: context.glass.negative))),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final id = tx['id'].toString();
      await deleteTransactionAndRefresh(ref, id);
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('내역이 삭제되었습니다.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userErrorMessage(e))));
      }
    }
  }
}

class _DetailCard extends StatelessWidget {
  final Widget child;
  const _DetailCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: glassDecoration(context, radius: AppRadii.md),
      child: child,
    );
  }
}

class _EditableRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final IconData trailingIcon;
  final VoidCallback onTap;

  const _EditableRow({
    required this.label,
    required this.value,
    required this.onTap,
    this.valueColor,
    this.trailingIcon = Icons.chevron_right,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            SizedBox(width: 80, child: Text(label, style: TextStyle(fontSize: 16, color: context.glass.textPrimary))),
            Expanded(
              child: Text(value, textAlign: TextAlign.right, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: valueColor ?? context.glass.textPrimary)),
            ),
            const SizedBox(width: 6),
            Icon(trailingIcon, size: 20, color: context.glass.textTertiary),
          ],
        ),
      ),
    );
  }
}

/// "소비 평가" row (Figma "아쉬운 소비 🙁"). The backend `Transaction` model
/// has no field for this yet (see docs/backend/report-backend-requirements.md
/// item 2 — and `AddTransactionModal`'s own `_moodIndex`, which already
/// picks the same 아쉬운/평범한/만족한 states but never persists them). So
/// this row always reads as "기록 없음" in production and tapping it
/// explains that editing isn't available yet, instead of writing a value
/// nothing on the backend will ever read back.
///
/// kDebugMode shows one sample "아쉬운 소비" state (matching Figma exactly,
/// including the emoji icon) purely so this row's *filled* layout can be
/// visually QA'd before the backend field exists — never shown in a
/// release/profile build, never a real value.
class _MoodRow extends StatelessWidget {
  const _MoodRow();

  @override
  Widget build(BuildContext context) {
    final showDebugSample = kDebugMode;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.md),
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('소비 평가 기록 기능은 준비 중이에요.')),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            SizedBox(width: 80, child: Text('소비 평가', style: TextStyle(fontSize: 16, color: context.glass.textPrimary))),
            Expanded(
              child: Text(
                showDebugSample ? '아쉬운 소비' : '기록 없음',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: showDebugSample ? context.glass.negative : context.glass.textTertiary),
              ),
            ),
            if (showDebugSample) ...[
              const SizedBox(width: 6),
              Icon(Icons.sentiment_dissatisfied, size: 20, color: context.glass.negative),
            ],
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, size: 20, color: context.glass.textTertiary),
          ],
        ),
      ),
    );
  }
}
