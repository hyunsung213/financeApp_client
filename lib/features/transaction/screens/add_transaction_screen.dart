import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../../data/api/transaction_api.dart';
import '../../../data/api/category_api.dart';
import '../../home/providers/home_provider.dart';
import '../../calendar/screens/calendar_screen.dart';
import '../widgets/category_picker_screen.dart';

class AddTransactionModal extends ConsumerStatefulWidget {
  final DateTime? initialDate;
  final Map<String, dynamic>? existingTransaction;

  const AddTransactionModal({super.key, this.initialDate, this.existingTransaction});

  static Future<void> show(BuildContext context, {DateTime? initialDate, Map<String, dynamic>? existingTransaction}) {
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTransactionModal(initialDate: initialDate, existingTransaction: existingTransaction),
    );
  }

  @override
  ConsumerState<AddTransactionModal> createState() => _AddTransactionModalState();
}

class _AddTransactionModalState extends ConsumerState<AddTransactionModal> {
  late DateTime _selectedDate;
  String _selectedParentId = 'core.expense'; // core.expense, core.saving, core.investment, core.income
  String? _selectedCategoryId;
  final _amountController = TextEditingController();
  final _titleController = TextEditingController();
  final _memoController = TextEditingController();
  bool _isSubmitting = false;
  bool _categoryInitialized = false;
  String? _categoryPathLabel;
  int _moodIndex = 1; // 0:좋음 1:보통 2:아쉬움 3:나쁨

  static const _moodEmojis = ['😊', '🙂', '😐', '☹️'];
  static const _moodLabels = ['좋음', '보통', '아쉬움', '나쁨'];
  static const _moodValues = ['GOOD', 'NORMAL', 'REGRETTABLE', 'BAD'];

  bool get _isEditing => widget.existingTransaction != null;

  @override
  void initState() {
    super.initState();
    final tx = widget.existingTransaction;
    if (tx != null) {
      _selectedDate = DateTime.tryParse(tx['occurredAt']?.toString() ?? '') ?? DateTime.now();
      _amountController.text = tx['amount']?.toString() ?? '';
      _titleController.text = (tx['merchantOrTitle'] ?? '').toString();
      _memoController.text = (tx['memo'] ?? '').toString();
      _selectedCategoryId = tx['categoryId']?.toString();
      final existingMoodIndex = _moodValues.indexOf((tx['consumptionEvaluation'] ?? '').toString());
      if (existingMoodIndex != -1) _moodIndex = existingMoodIndex;
    } else {
      _selectedDate = widget.initialDate ?? DateTime.now();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  String _getTransactionType(String parentId) {
    if (parentId == 'core.saving' || parentId == 'core.investment') {
      return 'SAVING';
    } else if (parentId == 'core.income') {
      return 'INCOME';
    }
    return 'EXPENSE';
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final viewInsets = MediaQuery.of(context).viewInsets;
    final screenHeight = MediaQuery.of(context).size.height;
    final modalHeight = screenHeight * 0.85;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        height: modalHeight,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Pinned Header Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isEditing ? '내역 수정하기' : '내역 추가하기',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                      ),
                      Row(
                        children: [
                          if (_isEditing)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                              onPressed: _isSubmitting ? null : _delete,
                              visualDensity: VisualDensity.compact,
                            ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),

            // Scrollable Form Content
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_isEditing) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          '분류/날짜/내용은 그대로 두고 금액과 메모만 수정할 수 있어요.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Major Type Selector Tabs (지출, 저축, 투자, 수입)
                    IgnorePointer(
                      ignoring: _isEditing,
                      child: Opacity(
                        opacity: _isEditing ? 0.5 : 1,
                        child: Row(
                          children: [
                            _buildTypeTab('지출', 'core.expense', AppColors.danger),
                            const SizedBox(width: 8),
                            _buildTypeTab('저축', 'core.saving', AppColors.primary),
                            const SizedBox(width: 8),
                            _buildTypeTab('투자', 'core.investment', const Color(0xFF26A69A)),
                            const SizedBox(width: 8),
                            _buildTypeTab('수입', 'core.income', Colors.blue),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Amount row
                    _formRow(
                      label: '금액',
                      child: TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: '0',
                          suffixText: '원',
                        ),
                      ),
                    ),

                    // Title / Merchant row
                    _formRow(
                      label: '거래명',
                      child: TextField(
                        controller: _titleController,
                        readOnly: _isEditing,
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: '사용처를 입력하세요',
                        ),
                      ),
                    ),

                    // Category row: tap opens the 대분류 → 소분류 picker screen.
                    categoriesAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      error: (e, st) => Text('카테고리 로딩 에러: $e'),
                      data: (categories) {
                        if (_isEditing && !_categoryInitialized && _selectedCategoryId != null) {
                          _initCategoryPathFromExisting(categories);
                          _categoryInitialized = true;
                        }
                        if (!_isEditing && _selectedCategoryId == null) {
                          _pickDefaultCategory(categories);
                        }

                        return _formRow(
                          label: '카테고리',
                          onTap: _isEditing ? null : () => _openCategoryPicker(categories),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Flexible(
                                child: Text(
                                  _categoryPathLabel ?? '카테고리를 선택하세요',
                                  textAlign: TextAlign.right,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.primary),
                                ),
                              ),
                              if (!_isEditing) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.chevron_right, size: 18, color: AppColors.primary),
                              ],
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 20),
                    const Text('소비 평가', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(_moodEmojis.length, (i) {
                        final isSelected = _moodIndex == i;
                        return InkWell(
                          onTap: () => setState(() => _moodIndex = i),
                          borderRadius: BorderRadius.circular(28),
                          child: Column(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected ? AppColors.primaryLight : Colors.grey.shade100,
                                  border: isSelected ? Border.all(color: AppColors.primary, width: 1.5) : null,
                                ),
                                child: Text(_moodEmojis[i], style: const TextStyle(fontSize: 22)),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _moodLabels[i],
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),

                    // Memo row
                    _formRow(
                      label: '메모',
                      child: TextField(
                        controller: _memoController,
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 14),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: '메모를 입력하세요 (선택)',
                        ),
                      ),
                    ),

                    // Date row
                    IgnorePointer(
                      ignoring: _isEditing,
                      child: Opacity(
                        opacity: _isEditing ? 0.5 : 1,
                        child: _formRow(
                          label: '날짜',
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
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                DateFormat('yyyy. M. d (E)', 'ko_KR').format(_selectedDate),
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.calendar_month, size: 18, color: AppColors.primary),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // Pinned Bottom Submit Button
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            '저장',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Walks a category id up to its parent (and grandparent, if any) to build
  // the "대분류 > 소분류" label and pick the right top-level type tab.
  void _initCategoryPathFromExisting(List<dynamic> categories) {
    Map<String, dynamic>? find(String? id) {
      if (id == null) return null;
      for (final c in categories) {
        if (c is Map && c['id'] == id) return Map<String, dynamic>.from(c);
      }
      return null;
    }

    final leaf = find(_selectedCategoryId);
    if (leaf == null) return;
    final parent = find(leaf['parentCategoryId']?.toString());

    if (parent != null && parent['parentCategoryId'] != null) {
      // leaf is a 소분류 under a 대분류
      _selectedParentId = parent['parentCategoryId'].toString();
      _categoryPathLabel = '${parent['name']} > ${leaf['name']}';
    } else if (parent != null) {
      // leaf is itself a 대분류 (flat type, e.g. 저축/투자/수입)
      _selectedParentId = parent['id'].toString();
      _categoryPathLabel = leaf['name']?.toString();
    }
  }

  void _pickDefaultCategory(List<dynamic> categories) {
    final majors = categories.whereType<Map>().where((c) => c['parentCategoryId'] == _selectedParentId).toList();
    if (majors.isEmpty) return;
    final major = majors.first;
    final subs = categories.whereType<Map>().where((c) => c['parentCategoryId'] == major['id']).toList();
    if (subs.isNotEmpty) {
      _selectedCategoryId = subs.first['id']?.toString();
      _categoryPathLabel = '${major['name']} > ${subs.first['name']}';
    } else {
      _selectedCategoryId = major['id']?.toString();
      _categoryPathLabel = major['name']?.toString();
    }
  }

  Future<void> _openCategoryPicker(List<dynamic> categories) async {
    final result = await Navigator.of(context, rootNavigator: true).push<CategoryPickerResult>(
      MaterialPageRoute(builder: (_) => CategoryPickerScreen(categories: categories, parentTypeId: _selectedParentId)),
    );
    if (result != null) {
      setState(() {
        _selectedCategoryId = result.categoryId;
        _categoryPathLabel = result.majorName != null && result.majorName!.isNotEmpty
            ? '${result.majorName} > ${result.categoryName}'
            : result.categoryName;
      });
    }
  }

  Widget _formRow({required String label, required Widget child, VoidCallback? onTap}) {
    final row = Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          ),
          Expanded(child: child),
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }

  Widget _buildTypeTab(String label, String parentId, Color activeColor) {
    final isSelected = _selectedParentId == parentId;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedParentId = parentId;
            _selectedCategoryId = null;
            _categoryPathLabel = null;
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withValues(alpha: 0.12) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? activeColor : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _refreshAfterChange() {
    ref.invalidate(homeDataProvider);
    ref.invalidate(homeRecentTransactionsProvider);
    ref.invalidate(yesterdayRegrettableTransactionsProvider);
    ref.invalidate(monthlyReportProvider);
    ref.invalidate(dailyTransactionsProvider);
  }

  Future<void> _submit() async {
    final cleanAmount = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final amount = int.tryParse(cleanAmount);
    if (amount == null || amount <= 0 || _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('올바른 금액과 카테고리를 선택해주세요.')),
      );
      return;
    }

    final memo = _memoController.text.trim().isNotEmpty
        ? _memoController.text.trim()
        : null;

    setState(() => _isSubmitting = true);

    try {
      final transactionApi = ref.read(transactionApiProvider);

      if (_isEditing) {
        final id = widget.existingTransaction!['id'].toString();
        await transactionApi.updateTransaction(id, amount: amount, memo: memo, consumptionEvaluation: _moodValues[_moodIndex]);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('내역이 수정되었습니다.'), backgroundColor: AppColors.primary),
          );
          _refreshAfterChange();
        }
        return;
      }

      final categoriesList = ref.read(categoriesProvider).asData?.value ?? [];
      String categoryName = '기타';
      for (final c in categoriesList) {
        if (c is Map && c['id'] == _selectedCategoryId) {
          categoryName = c['name']?.toString() ?? '기타';
          break;
        }
      }

      final title = _titleController.text.trim().isNotEmpty
          ? _titleController.text.trim()
          : categoryName;

      final txType = _getTransactionType(_selectedParentId);

      await transactionApi.createTransaction(
        categoryId: _selectedCategoryId!,
        type: txType,
        amount: amount,
        occurredAt: DateFormat('yyyy-MM-dd').format(_selectedDate),
        merchantOrTitle: title,
        memo: memo,
        consumptionEvaluation: _moodValues[_moodIndex],
        source: 'MANUAL',
        status: 'CONFIRMED',
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('[$categoryName] ${NumberFormat('#,###').format(amount)}원이 등록되었습니다! ✨'),
            backgroundColor: AppColors.primary,
          ),
        );
        _refreshAfterChange();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 중 오류 발생: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('내역 삭제'),
        content: const Text('이 내역을 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isSubmitting = true);
    try {
      final id = widget.existingTransaction!['id'].toString();
      await ref.read(transactionApiProvider).deleteTransaction(id);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('내역이 삭제되었습니다.')),
        );
        _refreshAfterChange();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 중 오류 발생: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
