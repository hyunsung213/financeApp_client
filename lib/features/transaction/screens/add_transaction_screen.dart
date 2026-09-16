import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../../data/api/transaction_api.dart';
import '../../../data/api/category_api.dart';
import '../../home/theme/home_tokens.dart';
import '../widgets/category_picker_screen.dart';
import '../providers/transaction_provider.dart';

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final cleanText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanText.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final int value = int.parse(cleanText);
    final formatter = NumberFormat('#,###');
    final String newText = formatter.format(value);

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

/// "수기 거래 입력" (Figma node 362:3036). Presentation is now a full screen
/// (pushed via Navigator) matching Figma, instead of the previous bottom
/// sheet modal - per product direction the create/update/delete API calls,
/// validation, and transaction model below are unchanged; only the outer
/// shell and field styling moved.
class AddTransactionModal extends ConsumerStatefulWidget {
  final DateTime? initialDate;
  final Map<String, dynamic>? existingTransaction;

  const AddTransactionModal({
    super.key,
    this.initialDate,
    this.existingTransaction,
  });

  /// Returns `true` when a create/update/delete actually succeeded (so
  /// callers like Transaction Detail/List can decide whether to refresh),
  /// `null`/`false` when the user just backed out without changing anything.
  static Future<bool?> show(
    BuildContext context, {
    DateTime? initialDate,
    Map<String, dynamic>? existingTransaction,
  }) {
    return Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        builder: (context) => AddTransactionModal(
          initialDate: initialDate,
          existingTransaction: existingTransaction,
        ),
      ),
    );
  }

  @override
  ConsumerState<AddTransactionModal> createState() =>
      _AddTransactionModalState();
}

class _AddTransactionModalState extends ConsumerState<AddTransactionModal> {
  late DateTime _selectedDate;
  String _selectedParentId =
      'core.expense'; // core.expense, core.saving, core.investment, core.income
  String? _selectedCategoryId;
  final _amountController = TextEditingController();
  final _titleController = TextEditingController();
  final _memoController = TextEditingController();
  bool _isSubmitting = false;
  bool _categoryInitialized = false;
  String? _categoryPathLabel;
  // 0:아쉬운 1:평범한 2:만족한 - Figma's 3-state mood picker (icon + label);
  // persisted to the backend via consumptionEvaluation using the subset of
  // the backend's 4-value enum this UI can express (REGRETTABLE/NORMAL/
  // GOOD). There's no 4th slot for "나쁨"/BAD, so that enum value is never
  // sent from this screen - flagged for product/design follow-up.
  int _moodIndex = 1;

  static const _moodIcons = [
    Icons.sentiment_dissatisfied,
    Icons.sentiment_neutral,
    Icons.sentiment_satisfied,
  ];
  static const _moodLabels = ['아쉬운', '평범한', '만족한'];
  static const _moodColors = [
    HomeTokens.negative,
    HomeTokens.textMuted,
    HomeTokens.accent,
  ];
  static const _moodValues = ['REGRETTABLE', 'NORMAL', 'GOOD'];

  bool get _isEditing => widget.existingTransaction != null;

  @override
  void initState() {
    super.initState();
    final tx = widget.existingTransaction;
    if (tx != null) {
      _selectedDate =
          DateTime.tryParse(tx['occurredAt']?.toString() ?? '') ??
          DateTime.now();
      _amountController.text = tx['amount']?.toString() ?? '';
      _titleController.text = (tx['merchantOrTitle'] ?? '').toString();
      _memoController.text = (tx['memo'] ?? '').toString();
      _selectedCategoryId = tx['categoryId']?.toString();
      // 'BAD' is a valid backend enum value (API_SPEC.md) but this 3-state
      // UI has no slot for it (product decision: no 4th "나쁨" option).
      // Treat it as a legacy/compatibility alias of 'REGRETTABLE' so an
      // existing BAD-tagged transaction still opens on the "아쉬운 소비"
      // bucket instead of silently falling back to the NORMAL default.
      var existingEvaluation = (tx['consumptionEvaluation'] ?? '').toString();
      if (existingEvaluation == 'BAD') existingEvaluation = 'REGRETTABLE';
      final existingMoodIndex = _moodValues.indexOf(existingEvaluation);
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

    return Scaffold(
      backgroundColor: HomeTokens.pageBackground,
      appBar: AppBar(
        backgroundColor: HomeTokens.pageBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: HomeTokens.textDark,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? '내역 수정하기' : '수기 거래 입력',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: HomeTokens.textDark,
          ),
        ),
        centerTitle: false,
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              onPressed: _isSubmitting ? null : _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_isEditing) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: HomeTokens.chipActiveBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          '거래명은 그대로 유지돼요. 나머지 항목은 눌러서 수정할 수 있어요.',
                          style: TextStyle(
                            fontSize: 12,
                            color: HomeTokens.textFaint,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    const Padding(
                      padding: EdgeInsets.only(left: 6, bottom: 10),
                      child: Text(
                        '거래 유형',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: HomeTokens.textDark,
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildTypePill(
                          '지출',
                          'core.expense',
                          Icons.remove_circle_outline,
                          HomeTokens.negative,
                        ),
                        _buildTypePill(
                          '저축',
                          'core.saving',
                          Icons.add_circle_outline,
                          HomeTokens.accent,
                        ),
                        _buildTypePill(
                          '투자',
                          'core.investment',
                          Icons.trending_up,
                          const Color(0xFF26A69A),
                        ),
                        _buildTypePill(
                          '수입',
                          'core.income',
                          Icons.attach_money,
                          Colors.blue,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 거래명 card
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 17,
                        vertical: 15,
                      ),
                      decoration: _cardDecoration(),
                      child: Row(
                        children: [
                          const Text(
                            '거래명',
                            style: TextStyle(
                              fontSize: 16,
                              color: HomeTokens.textDark,
                            ),
                          ),
                          const Spacer(),
                          Flexible(
                            child: TextField(
                              controller: _titleController,
                              readOnly: _isEditing,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: HomeTokens.textDark,
                              ),
                              decoration: const InputDecoration(
                                isDense: true,
                                isCollapsed: true,
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                hintText: '내용을 입력하세요',
                                hintStyle: TextStyle(
                                  color: HomeTokens.textMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: HomeTokens.textFaint,
                          ),
                        ],
                      ),
                    ),

                    // 금액
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 15,
                      ),
                      decoration: _cardDecoration(),
                      child: Row(
                        children: [
                          const Text(
                            '금액',
                            style: TextStyle(
                              fontSize: 16,
                              color: HomeTokens.textDark,
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _amountController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [CurrencyInputFormatter()],
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: HomeTokens.textDark,
                              ),
                              decoration: const InputDecoration(
                                isDense: true,
                                isCollapsed: true,
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                hintText: '0',
                                suffixText: '원',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 날짜 (edit 모드에서도 탭하여 변경 가능 - date picker 자체는 항상
                    // readOnly 텍스트 표시이므로 GestureDetector로 감싸 탭만으로 연다).
                    GestureDetector(
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
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 15,
                        ),
                        decoration: _cardDecoration(
                          border: HomeTokens.chipInactiveBorder,
                        ),
                        child: Row(
                          children: [
                            const Text(
                              '날짜',
                              style: TextStyle(
                                fontSize: 16,
                                color: HomeTokens.textDark,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                DateFormat(
                                  'yyyy년 M월 d일 (E)',
                                  'ko_KR',
                                ).format(_selectedDate),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: HomeTokens.textMuted,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 20,
                              color: HomeTokens.accent,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 카테고리
                    categoriesAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      error: (e, st) {
                        debugPrint('카테고리 로딩 실패: $e');
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Text(
                            '카테고리 정보를 불러오지 못했어요. 잠시 후 다시 시도해주세요.',
                            style: TextStyle(
                              fontSize: 14,
                              color: HomeTokens.textMuted,
                            ),
                          ),
                        );
                      },
                      data: (categories) {
                        if (_isEditing &&
                            !_categoryInitialized &&
                            _selectedCategoryId != null) {
                          _initCategoryPathFromExisting(categories);
                          _categoryInitialized = true;
                        }
                        if (!_isEditing && _selectedCategoryId == null) {
                          _pickDefaultCategory(categories);
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: GestureDetector(
                            onTap: () => _openCategoryPicker(categories),
                            child: Row(
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(left: 6),
                                  child: Text(
                                    '카테고리',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: HomeTokens.textDark,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: HomeTokens.chipInactiveBg,
                                      borderRadius: BorderRadius.circular(30),
                                      border: Border.all(
                                        color: HomeTokens.chipInactiveBorder,
                                      ),
                                    ),
                                    child: Text(
                                      _categoryPathLabel ?? '카테고리를 선택하세요',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: HomeTokens.textDark,
                                      ),
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  size: 22,
                                  color: HomeTokens.textFaint,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 12),
                    const Padding(
                      padding: EdgeInsets.only(left: 6, bottom: 10),
                      child: Text(
                        '소비 평가',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: HomeTokens.textDark,
                        ),
                      ),
                    ),
                    Row(
                      children: List.generate(_moodLabels.length, (i) {
                        final isSelected = _moodIndex == i;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: i == _moodLabels.length - 1 ? 0 : 8,
                            ),
                            child: GestureDetector(
                              onTap: () => setState(() => _moodIndex = i),
                              child: Container(
                                height: 66,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isSelected
                                        ? _moodColors[i]
                                        : HomeTokens.chipInactiveBorder,
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _moodIcons[i],
                                      size: 24,
                                      color: isSelected
                                          ? _moodColors[i]
                                          : HomeTokens.textMuted,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      _moodLabels[i],
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? _moodColors[i]
                                            : HomeTokens.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),

                    // 메모
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 15,
                      ),
                      decoration: _cardDecoration(
                        border: HomeTokens.chipInactiveBorder,
                      ),
                      child: Row(
                        children: [
                          const Text(
                            '메모',
                            style: TextStyle(
                              fontSize: 16,
                              color: HomeTokens.textDark,
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _memoController,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 14,
                                color: HomeTokens.textDark,
                              ),
                              decoration: const InputDecoration(
                                isDense: true,
                                isCollapsed: true,
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                hintText: '메모를 입력하세요 (선택)',
                                hintStyle: TextStyle(
                                  color: HomeTokens.textMuted,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: HomeTokens.textFaint,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // Pinned Bottom Submit Button
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
              decoration: BoxDecoration(
                color: HomeTokens.pageBackground,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HomeTokens.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isEditing ? '저장' : '저장',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
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

  BoxDecoration _cardDecoration({Color border = Colors.transparent}) {
    return BoxDecoration(
      color: HomeTokens.cardSurface,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(
        color: border == Colors.transparent
            ? HomeTokens.chipInactiveBorder
            : border,
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D000000),
          blurRadius: 2,
          offset: Offset(0, 1),
        ),
      ],
    );
  }

  // Walks a category id up to its parent to build the "대분류 > 소분류"
  // label and pick the right "거래 유형" tab. The tab is read straight off
  // the leaf category's own type/purposeType (via [parentTypeIdFor]) rather
  // than the parent chain, since EXPENSE 대분류(식비/교통/...) are now
  // independent root categories - there's no single 'core.expense' parent
  // left to walk up to (see majorCategoriesFor in category_picker_screen.dart).
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

    _selectedParentId = parentTypeIdFor(leaf);
    if (parent != null && !typeRootIds.contains(parent['id'])) {
      // leaf is a 소분류 under a named 대분류 (식비/교통/... or a legacy
      // nested category)
      _categoryPathLabel = '${parent['name']} > ${leaf['name']}';
    } else {
      // leaf is itself a 대분류, or sits directly under a 거래 유형 root
      // (저축/투자/수입의 기존 flat 구조)
      _categoryPathLabel = leaf['name']?.toString();
    }
  }

  void _pickDefaultCategory(List<dynamic> categories) {
    final majors = majorCategoriesFor(categories, _selectedParentId);
    if (majors.isEmpty) return;
    // 지출의 기본 대분류는 정렬 순서(sortOrder)와 무관하게 항상 식비여야
    // 한다 - 사용자 지정 카테고리(예: 커스텀 "AI" 카테고리)가 낮은
    // sortOrder로 끼어들어도 밀려나지 않게 명시적으로 우선한다.
    final major = majors.firstWhere(
      (m) => m['name'] == '식비',
      orElse: () => majors.first,
    );
    final subs = categories
        .whereType<Map>()
        .where((c) => c['parentCategoryId'] == major['id'])
        .toList();
    if (subs.isNotEmpty) {
      _selectedCategoryId = subs.first['id']?.toString();
      _categoryPathLabel = '${major['name']} > ${subs.first['name']}';
    } else {
      _selectedCategoryId = major['id']?.toString();
      _categoryPathLabel = major['name']?.toString();
    }
  }

  Future<void> _openCategoryPicker(List<dynamic> categories) async {
    final result = await showModalBottomSheet<CategoryPickerResult>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => CategoryPickerScreen(
        categories: categories,
        parentTypeId: _selectedParentId,
      ),
    );
    if (result != null) {
      setState(() {
        _selectedCategoryId = result.categoryId;
        _categoryPathLabel =
            result.majorName != null && result.majorName!.isNotEmpty
            ? '${result.majorName} > ${result.categoryName}'
            : result.categoryName;
      });
    }
  }

  Widget _buildTypePill(
    String label,
    String parentId,
    IconData icon,
    Color color,
  ) {
    final isSelected = _selectedParentId == parentId;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedParentId = parentId;
          _selectedCategoryId = null;
          _categoryPathLabel = null;
        });
      },
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? color : HomeTokens.chipInactiveBorder,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 1,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? color : HomeTokens.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : HomeTokens.textMuted,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _refreshAfterChange() {
    // Also covers Home's "recent regrettable spend" list
    // (recentRegrettableTransactionsProvider) via the shared helper below.
    invalidateTransactionDependents(ref);
  }

  Future<void> _submit() async {
    final cleanAmount = _amountController.text.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    final amount = int.tryParse(cleanAmount);
    if (amount == null || amount <= 0 || _selectedCategoryId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('올바른 금액과 카테고리를 선택해주세요.')));
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
        await transactionApi.updateTransaction(
          id,
          amount: amount,
          memo: memo,
          type: _getTransactionType(_selectedParentId),
          occurredAt: DateFormat('yyyy-MM-dd').format(_selectedDate),
          categoryId: _selectedCategoryId,
          consumptionEvaluation: _moodValues[_moodIndex],
        );

        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('내역이 수정되었습니다.'),
              backgroundColor: AppColors.primary,
            ),
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
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '[$categoryName] ${NumberFormat('#,###').format(amount)}원이 등록되었습니다! ✨',
            ),
            backgroundColor: AppColors.primary,
          ),
        );
        _refreshAfterChange();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('저장 중 오류 발생: $e')));
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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
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
        Navigator.pop(context, true);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('내역이 삭제되었습니다.')));
        _refreshAfterChange();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('삭제 중 오류 발생: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
