import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../../data/api/transaction_api.dart';
import '../../../data/api/category_api.dart';
import '../../home/providers/home_provider.dart';
import '../../calendar/screens/calendar_screen.dart';



class QuickAddForm extends ConsumerStatefulWidget {
  const QuickAddForm({super.key});

  @override
  ConsumerState<QuickAddForm> createState() => _QuickAddFormState();
}

class _QuickAddFormState extends ConsumerState<QuickAddForm> {
  final _amountController = TextEditingController();
  final _titleController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String? _selectedCategoryId;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  String _getCategoryDisplayName(dynamic category, List<dynamic> allCategories) {
    if (category is! Map) return '';
    final parentId = category['parentCategoryId'];
    if (parentId != null) {
      for (final c in allCategories) {
        if (c is Map && c['id'] == parentId) {
          return '[${c['name'] ?? ''}] ${category['name'] ?? ''}';
        }
      }
    }
    return (category['name'] ?? '').toString();
  }

  String _getTransactionType(dynamic category) {
    if (category is! Map) return 'EXPENSE';
    final parentId = (category['parentCategoryId'] ?? category['id'] ?? '').toString();
    if (parentId.startsWith('core.saving') || parentId.startsWith('core.investment')) {
      return 'SAVING';
    } else if (parentId.startsWith('core.income')) {
      return 'INCOME';
    }
    return 'EXPENSE';
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '빠른 내역 입력',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  DateFormat('yyyy.MM.dd').format(_selectedDate),
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Date & Category Selector
            Row(
              children: [
                // Date Picker Button
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => _selectedDate = date);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          DateFormat('MM/dd').format(_selectedDate),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Category Dropdown
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: categoriesAsync.when(
                      loading: () => const SizedBox(
                        height: 44,
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                      error: (e, st) => SizedBox(
                        height: 44,
                        child: Center(
                          child: Text('에러: $e', style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                      data: (categories) {
                        final validSubCategories = categories
                            .where((c) => c is Map && c['parentCategoryId'] != null)
                            .map((c) => Map<String, dynamic>.from(c as Map))
                            .toList();

                        if (validSubCategories.isEmpty) {
                          return const SizedBox(
                            height: 44,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text('카테고리 없음', style: TextStyle(fontSize: 13, color: Colors.grey)),
                            ),
                          );
                        }

                        final currentSelectedId = validSubCategories.any((c) => c['id'] == _selectedCategoryId)
                            ? _selectedCategoryId
                            : validSubCategories.first['id'] as String;

                        return DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: currentSelectedId,
                            isExpanded: true,
                            items: validSubCategories.map((c) {
                              final id = c['id'] as String;
                              return DropdownMenuItem<String>(
                                value: id,
                                child: Text(
                                  _getCategoryDisplayName(c, categories),
                                  style: const TextStyle(fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedCategoryId = val);
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Amount & Title Inputs
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '금액 (원)',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      hintText: '내용 (선택)',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  elevation: 0,
                ),
                onPressed: _isSubmitting ? null : _submitTransaction,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('등록', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitTransaction() async {
    final cleanAmount = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final amount = int.tryParse(cleanAmount);

    final categoriesList = ref.read(categoriesProvider).asData?.value ?? [];
    final validSubCategories = categoriesList
        .where((c) => c is Map && c['parentCategoryId'] != null)
        .map((c) => Map<String, dynamic>.from(c as Map))
        .toList();

    final targetCategoryId = (_selectedCategoryId != null && validSubCategories.any((c) => c['id'] == _selectedCategoryId))
        ? _selectedCategoryId
        : (validSubCategories.isNotEmpty ? validSubCategories.first['id'] as String : null);

    if (amount == null || amount <= 0 || targetCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('올바른 금액과 카테고리를 선택해주세요.')),
      );
      return;
    }

    String categoryName = '기타';
    String txType = 'EXPENSE';

    for (final c in categoriesList) {
      if (c is Map && c['id'] == targetCategoryId) {
        categoryName = c['name']?.toString() ?? '기타';
        txType = _getTransactionType(c);
        break;
      }
    }

    final merchantOrTitle = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : categoryName;

    setState(() => _isSubmitting = true);

    try {
      final transactionApi = ref.read(transactionApiProvider);
      await transactionApi.createTransaction(
        categoryId: targetCategoryId,
        type: txType,
        amount: amount,
        occurredAt: DateFormat('yyyy-MM-dd').format(_selectedDate),
        merchantOrTitle: merchantOrTitle,
        source: 'MANUAL',
        status: 'CONFIRMED',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('[$categoryName] ${NumberFormat('#,###').format(amount)}원이 등록되었습니다! ✨'),
            backgroundColor: AppColors.primary,
          ),
        );
        _amountController.clear();
        _titleController.clear();

        // Invalidate and refresh all relevant dashboard/calendar data
        ref.invalidate(homeDataProvider);
        ref.invalidate(monthlyReportProvider);
        ref.invalidate(dailyTransactionsProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('등록 중 오류 발생: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
