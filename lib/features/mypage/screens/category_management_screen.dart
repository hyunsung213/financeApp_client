import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/category/category_appearance.dart';
import '../../../data/api/api_error.dart';
import '../../../data/api/category_api.dart';
import '../providers/category_management_provider.dart';
import '../../../core/theme/app_radii.dart';
import '../widgets/category_row_card.dart';
import '../widgets/settings_form.dart';
import 'category_editor_screen.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/theme/wallet_glass.dart';

/// 카테고리 관리 (Figma Frame 108). Without [parent] it shows the 지출/수입
/// tabs; tapping a 지출 대분류 opens this same screen for its 소분류.
///
/// Categories come from `GET /api/categories`, already carrying the user's
/// own name/icon/color. Every row opens [CategoryEditorScreen.edit] (a 지출
/// 대분류 opens its 소분류 instead, and is edited from 수정 mode). Only the
/// user's own categories can be deleted, and reordering isn't offered: system
/// categories keep their order and ids for the budget plan and reports.
class CategoryManagementScreen extends ConsumerStatefulWidget {
  const CategoryManagementScreen({super.key})
    : parent = null,
      tab = CategoryTab.expense;

  const CategoryManagementScreen.children({
    super.key,
    required Map<String, dynamic> this.parent,
    required this.tab,
  });

  final Map<String, dynamic>? parent;
  final CategoryTab tab;

  @override
  ConsumerState<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState
    extends ConsumerState<CategoryManagementScreen> {
  late CategoryTab _tab = widget.tab;
  bool _editing = false;
  bool _showGuide = true;

  bool get _isTopLevel => widget.parent == null;

  List<Map<String, dynamic>> _rows(List<dynamic> categories) => _isTopLevel
      ? categoriesForTab(categories, _tab)
      : childCategoriesOf(categories, widget.parent!['id'] as String);

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openEditor(Widget editor) async {
    final message = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => editor));
    if (message != null && mounted) _showMessage(message);
  }

  void _openAdd() => _openEditor(
    CategoryEditorScreen.create(tab: _tab, parent: widget.parent),
  );

  void _openEdit(Map<String, dynamic> category) =>
      _openEditor(CategoryEditorScreen.edit(category: category));

  Future<void> _delete(Map<String, dynamic> category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.glass.surfaceFill,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
        ),
        title: Text("'${category['name']}' 삭제"),
        content: const Text('카테고리 목록과 입력 화면에서 사라져요.\n이미 기록된 거래는 그대로 남아요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: context.glass.negative,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(categoryActionsProvider.notifier)
          .delete(category['id'] as String);
      if (mounted) _showMessage('카테고리를 삭제했어요.');
    } catch (e) {
      if (mounted) _showMessage(apiErrorMessage(e) ?? '삭제하지 못했어요.');
    }
  }

  void _openChildren(Map<String, dynamic> category) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            CategoryManagementScreen.children(parent: category, tab: _tab),
      ),
    );
  }

  List<Widget> _trailingFor(Map<String, dynamic> category) {
    if (_editing) {
      return [
        _RowIconButton(
          icon: Icons.edit_outlined,
          tooltip: '수정',
          onTap: () => _openEdit(category),
        ),
        if (isDeletableCategory(category))
          _RowIconButton(
            icon: Icons.delete_outline,
            tooltip: '삭제',
            color: context.glass.negative,
            onTap: () => _delete(category),
          ),
      ];
    }
    return [
      Icon(Icons.chevron_right, size: 24, color: context.glass.textPrimary),
    ];
  }

  void _onRowTap(Map<String, dynamic> category) {
    if (!_editing && _isDrillable) {
      _openChildren(category);
    } else {
      _openEdit(category);
    }
  }

  // Only 지출 대분류 have 소분류; 수입 categories are a single level.
  bool get _isDrillable => _isTopLevel && _tab == CategoryTab.expense;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final categories = categoriesAsync.asData?.value ?? const [];
    final rows = _rows(categories);
    // Looked up again so a rename of this 대분류 shows in the title.
    final parentName = _isTopLevel
        ? null
        : CategoryDirectory(
            categories,
          ).nameOf(widget.parent!['id'] as String, '${widget.parent!['name']}');

    return WalletBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: settingsAppBar(_isTopLevel ? '카테고리 관리' : parentName!),
        body: Column(
          children: [
            if (_isTopLevel)
              _CategoryTabs(
                selected: _tab,
                onSelected: (tab) => setState(() => _tab = tab),
              ),
            Expanded(
              child: categoriesAsync.when(
                loading: () => Center(
                  child: CircularProgressIndicator(
                    color: context.glass.accentText,
                  ),
                ),
                error: (e, _) => _LoadError(
                  onRetry: () => ref.invalidate(categoriesProvider),
                ),
                data: (_) => ListView(
                  padding: const EdgeInsets.fromLTRB(15, 12, 15, 16),
                  children: [
                    if (_isTopLevel && _showGuide) ...[
                      _GuideBanner(
                        onClose: () => setState(() => _showGuide = false),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (rows.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text(
                            '아직 카테고리가 없어요.',
                            style: TextStyle(color: context.glass.textTertiary),
                          ),
                        ),
                      ),
                    for (final category in rows) ...[
                      Builder(
                        builder: (context) {
                          final look = CategoryAppearance.fromJson(category);
                          return CategoryRowCard(
                            key: ValueKey('category-row-${category['id']}'),
                            icon: look.icon,
                            iconColor: look.color,
                            name: look.name,
                            trailing: _trailingFor(category),
                            onTap: () => _onRowTap(category),
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(15, 8, 15, 16),
          child: Row(
            children: [
              _EditButton(
                editing: _editing,
                onTap: () => setState(() => _editing = !_editing),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: _AddButton(
                  onTap: categoriesAsync.hasValue ? _openAdd : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Figma tab bar: selected tab green with a green underline, the other grey.
class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({required this.selected, required this.onSelected});

  final CategoryTab selected;
  final ValueChanged<CategoryTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Row(
        children: [
          for (final tab in CategoryTab.values)
            Expanded(
              child: InkWell(
                onTap: () => onSelected(tab),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        width: 2,
                        color: tab == selected
                            ? context.glass.accentText
                            : context.glass.textTertiary,
                      ),
                    ),
                  ),
                  child: Text(
                    tab.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.45,
                      color: tab == selected
                          ? context.glass.accentText
                          : context.glass.textTertiary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GuideBanner extends StatelessWidget {
  const _GuideBanner({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 8, 14),
      decoration: glassDecoration(
        context,
        radius: AppRadii.md,
      ).copyWith(border: Border.all(color: context.glass.accent)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '카테고리 추가 • 수정 • 삭제',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.45,
                    color: context.glass.chipSelectedText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '카테고리를 누르면 이름·아이콘·색상을 바꿀 수 있어요.\n'
                  '직접 추가한 카테고리만 삭제할 수 있어요.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.3,
                    letterSpacing: -0.45,
                    color: context.glass.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            tooltip: '닫기',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close, size: 24, color: context.glass.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _RowIconButton extends StatelessWidget {
  const _RowIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  /// Defaults to the theme's primary text color.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      padding: EdgeInsets.zero,
      icon: Icon(icon, size: 24, color: color ?? context.glass.textPrimary),
    );
  }
}

// Figma bottom buttons: rounded 16, 55 tall. The green 추가 button keeps
// its soft drop shadow; 수정 is a glass card.
const _bottomButtonShadow = [
  BoxShadow(color: Color(0x30606960), offset: Offset(0, 5.4), blurRadius: 5),
  BoxShadow(color: Color(0x1F606960), offset: Offset(0, 1.2), blurRadius: 1.2),
];

class _EditButton extends StatelessWidget {
  const _EditButton({required this.editing, required this.onTap});

  final bool editing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 55,
      decoration: glassDecoration(
        context,
        radius: AppRadii.md,
      ).copyWith(border: Border.all(color: context.glass.chipSelectedText)),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  editing ? Icons.check : Icons.edit_outlined,
                  size: 24,
                  color: context.glass.chipSelectedText,
                ),
                const SizedBox(width: 6),
                Text(
                  editing ? '완료' : '수정',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.45,
                    color: context.glass.chipSelectedText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    // White on brand green; while disabled a muted track fill with muted
    // content so it stays legible in both light and dark mode.
    final content = enabled ? Colors.white : context.glass.textTertiary;
    return Container(
      height: 55,
      decoration: BoxDecoration(
        color: enabled ? const Color(0xFF00AF76) : context.glass.track,
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: enabled ? _bottomButtonShadow : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.md),
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline, size: 24, color: content),
              const SizedBox(width: 10),
              Text(
                '추가',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.45,
                  color: content,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '카테고리를 불러오지 못했어요.',
            style: TextStyle(color: context.glass.textPrimary),
          ),
          TextButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}
