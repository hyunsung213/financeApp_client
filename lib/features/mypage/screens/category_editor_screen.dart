import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/category/category_appearance.dart';
import '../../../data/api/api_error.dart';
import '../../../data/api/category_api.dart';
import '../providers/category_management_provider.dart';
import '../theme/my_tokens.dart';
import '../widgets/category_row_card.dart';
import '../widgets/settings_form.dart';

const categoryNameMaxLength = 20;

/// 카테고리 추가 / 카테고리 수정 (Figma Frame 109) - one screen, two modes.
///
/// Create ([CategoryEditorScreen.create]) saves through
/// `POST /api/categories`. With `parent` (opened from a 대분류's 소분류 list)
/// the new category goes under it. From the top level, a 지출 category needs a
/// 대분류 picked here (see [requiresParentForNewCategory]) and a 수입 one goes
/// under the `core.income` root.
///
/// Edit ([CategoryEditorScreen.edit]) prefills the category's current name,
/// icon and color and sends only what changed to
/// `PATCH /api/categories/:id`. For a system category that is the user's
/// display override - its id, parent, budget plan and auto-categorisation
/// stay as they are - and "기본값으로 되돌리기" drops the override.
///
/// Quick access has no backend field yet, so its switch is shown disabled.
class CategoryEditorScreen extends ConsumerStatefulWidget {
  const CategoryEditorScreen.create({super.key, required this.tab, this.parent})
    : category = null;

  CategoryEditorScreen.edit({
    super.key,
    required Map<String, dynamic> this.category,
  }) : tab = category['type'] == 'INCOME'
           ? CategoryTab.income
           : CategoryTab.expense,
       parent = null;

  final CategoryTab tab;
  final Map<String, dynamic>? parent;

  /// The `GET /api/categories` row being edited; null when adding.
  final Map<String, dynamic>? category;

  @override
  ConsumerState<CategoryEditorScreen> createState() =>
      _CategoryEditorScreenState();
}

class _CategoryEditorScreenState extends ConsumerState<CategoryEditorScreen> {
  late final CategoryAppearance? _original = widget.category == null
      ? null
      : CategoryAppearance.fromJson(widget.category!);
  late final _nameController = TextEditingController(text: _original?.name);
  late CategoryTab _tab = widget.tab;
  String? _parentId;
  late String _iconKey = _original?.iconKey ?? categoryIconChoiceKeys.first;

  /// null keeps the category's default icon color (edit mode only).
  late Color? _color = _original == null
      ? categoryColorChoices[3]
      : _original.color;
  bool _isSaving = false;

  bool get _isEdit => _original != null;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String get _name => _nameController.text.trim();

  String? get _effectiveParentId {
    if (widget.parent != null) return widget.parent!['id'] as String;
    if (requiresParentForNewCategory(_tab)) return _parentId;
    return _tab.rootId;
  }

  bool get _canSave =>
      _name.isNotEmpty && (_isEdit || _effectiveParentId != null);

  /// The current icon first when it isn't one of the Frame 109 candidates
  /// (e.g. a system category's own icon), so it shows as selected.
  List<String> get _iconKeys => [
    if (_original != null &&
        !categoryIconChoiceKeys.contains(_original.iconKey))
      _original.iconKey,
    ...categoryIconChoiceKeys,
  ];

  Future<void> _run(Future<void> Function() action, String failure) async {
    setState(() => _isSaving = true);
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(apiErrorMessage(e) ?? failure)));
    }
  }

  Future<void> _save(List<dynamic> categories) async {
    final actions = ref.read(categoryActionsProvider.notifier);
    final original = _original;
    if (original == null) {
      final parentId = _effectiveParentId!;
      return _run(() async {
        await actions.create(
          name: _name,
          tab: _tab,
          parentCategoryId: parentId,
          siblings: childCategoriesOf(categories, parentId),
          icon: _iconKey,
          color: _color == null ? null : categoryColorHex(_color!),
        );
        if (mounted) Navigator.of(context).pop('카테고리를 추가했어요.');
      }, '카테고리를 추가하지 못했어요.');
    }

    final name = _name == original.name ? null : _name;
    final icon = _iconKey == original.iconKey ? null : _iconKey;
    final color = _color == null || _color == original.color
        ? null
        : categoryColorHex(_color!);
    if (name == null && icon == null && color == null) {
      Navigator.of(context).pop();
      return;
    }
    return _run(() async {
      await actions.update(original.id, name: name, icon: icon, color: color);
      if (mounted) Navigator.of(context).pop('카테고리를 수정했어요.');
    }, '카테고리를 수정하지 못했어요.');
  }

  Future<void> _resetToDefault() => _run(() async {
    await ref
        .read(categoryActionsProvider.notifier)
        .resetAppearance(_original!.id);
    if (mounted) Navigator.of(context).pop('기본값으로 되돌렸어요.');
  }, '기본값으로 되돌리지 못했어요.');

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).asData?.value ?? const [];
    final original = _original;
    final showParentPicker =
        !_isEdit && widget.parent == null && requiresParentForNewCategory(_tab);

    return Scaffold(
      backgroundColor: MyTokens.pageBackground,
      appBar: settingsAppBar(_isEdit ? '카테고리 수정' : '카테고리 추가'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(15, 12, 15, 16),
        children: [
          if (original != null && original.isSystem) ...[
            const _SystemCategoryNotice(),
            const SizedBox(height: 16),
          ],
          const _Label('카테고리 명'),
          const SizedBox(height: 8),
          _NameField(controller: _nameController),
          const SizedBox(height: 24),
          Row(
            children: [
              const _Label('카테고리 유형'),
              const SizedBox(width: 16),
              for (final tab in CategoryTab.values) ...[
                Expanded(
                  child: _ChoiceButton(
                    label: tab.label,
                    selected: _tab == tab,
                    // Under a fixed 대분류, or once it exists, the type is set.
                    onTap: !_isEdit && widget.parent == null
                        ? () => setState(() {
                            _tab = tab;
                            _parentId = null;
                          })
                        : null,
                  ),
                ),
                if (tab != CategoryTab.values.last) const SizedBox(width: 6),
              ],
            ],
          ),
          if (widget.parent != null) ...[
            const SizedBox(height: 10),
            Text(
              "'${widget.parent!['name']}'의 하위 카테고리로 추가돼요.",
              style: const TextStyle(fontSize: 13, color: MyTokens.accentDark),
            ),
          ],
          if (showParentPicker) ...[
            const SizedBox(height: 24),
            const _Label('상위 카테고리'),
            const SizedBox(height: 4),
            const _Caption('지출 카테고리는 대분류 아래에 추가돼 예산에 함께 반영돼요.'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final major in categoriesForTab(categories, _tab))
                  _ChoiceButton(
                    label: '${major['name']}',
                    selected: _parentId == major['id'],
                    compact: true,
                    onTap: () =>
                        setState(() => _parentId = major['id'] as String),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          const _Label('아이콘 선택'),
          const SizedBox(height: 10),
          _IconGrid(
            keys: _iconKeys,
            selected: _iconKey,
            onSelected: (key) => setState(() => _iconKey = key),
          ),
          const SizedBox(height: 24),
          const _Label('색상 선택'),
          const SizedBox(height: 10),
          _ColorRow(
            selected: _color,
            // Editing a category that still has its default color offers
            // that default first, selected.
            showDefault: original != null && original.color == null,
            onSelected: (color) => setState(() => _color = color),
          ),
          const SizedBox(height: 24),
          const _QuickAccessRow(),
          const SizedBox(height: 20),
          _Preview(
            name: _name,
            icon: categoryIconForKey(_iconKey),
            color: _color ?? MyTokens.accentDark,
          ),
          if (original != null &&
              original.isSystem &&
              original.isCustomized) ...[
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                key: const ValueKey('category-reset'),
                onPressed: _isSaving ? null : _resetToDefault,
                style: TextButton.styleFrom(
                  foregroundColor: MyTokens.placeholder,
                ),
                child: Text(
                  "기본값으로 되돌리기 ('${original.canonicalName}')",
                  style: const TextStyle(
                    fontSize: 14,
                    decoration: TextDecoration.underline,
                    decorationColor: MyTokens.placeholder,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(14, 8, 14, 16),
        child: SizedBox(
          height: 55,
          child: FilledButton(
            key: const ValueKey('category-save'),
            onPressed: _canSave && !_isSaving ? () => _save(categories) : null,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF00AF76),
              disabledBackgroundColor: MyTokens.placeholder,
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isSaving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    '저장',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.45,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Small note shown only when editing a 기본 카테고리.
class _SystemCategoryNotice extends StatelessWidget {
  const _SystemCategoryNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: MyTokens.accentSoftBg,
        borderRadius: BorderRadius.circular(MyTokens.cardRadius),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: MyTokens.accentDark),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '기본 카테고리예요. 이름·아이콘·색상은 내 화면에만 바뀌고, '
              '예산·리포트·자동 분류는 그대로 유지돼요.',
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                letterSpacing: -0.3,
                color: MyTokens.accentDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.45,
      color: MyTokens.textPrimary,
    ),
  );
}

class _Caption extends StatelessWidget {
  const _Caption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 13,
      letterSpacing: -0.3,
      color: MyTokens.placeholder,
    ),
  );
}

class _NameField extends StatelessWidget {
  const _NameField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const ValueKey('category-name'),
      controller: controller,
      maxLength: categoryNameMaxLength,
      style: const TextStyle(fontSize: 16, color: MyTokens.textPrimary),
      decoration:
          settingsInputDecoration(
            contentPadding: const EdgeInsets.fromLTRB(17, 10, 9, 10),
            isDense: true,
          ).copyWith(
            hintText: '카테고리에 들어갈 이름을 설정하세요',
            // The Figma counter sits inside the field, on the right.
            counterText: '',
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                '${controller.text.characters.length}/$categoryNameMaxLength',
                style: const TextStyle(
                  fontSize: 16,
                  color: MyTokens.placeholder,
                ),
              ),
            ),
            suffixIconConstraints: const BoxConstraints(minHeight: 0),
          ),
    );
  }
}

/// Figma 지출/수입 selector: mint fill + green border when selected.
class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null && !selected;
    return Material(
      color: selected ? MyTokens.accentSoftBg : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MyTokens.cardRadius),
        side: BorderSide(
          color: selected ? MyTokens.accent : Colors.transparent,
          width: 1.5,
        ),
      ),
      elevation: selected ? 0 : 1,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      child: InkWell(
        borderRadius: BorderRadius.circular(MyTokens.cardRadius),
        onTap: onTap,
        child: Container(
          height: 35,
          padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 16),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: compact ? 15 : 16,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.45,
              color: selected
                  ? MyTokens.accent
                  : disabled
                  ? MyTokens.borderNeutral
                  : MyTokens.placeholder,
            ),
          ),
        ),
      ),
    );
  }
}

class _IconGrid extends StatelessWidget {
  const _IconGrid({
    required this.keys,
    required this.selected,
    required this.onSelected,
  });

  final List<String> keys;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 45 / 44,
      children: [
        for (final key in keys)
          _IconTile(
            key: ValueKey('category-icon-$key'),
            icon: categoryIconForKey(key),
            selected: key == selected,
            onTap: () => onSelected(key),
          ),
      ],
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({
    super.key,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? MyTokens.accentSoftBg : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MyTokens.cardRadius),
        side: selected
            ? const BorderSide(color: MyTokens.accent, width: 2)
            : BorderSide.none,
      ),
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      child: InkWell(
        borderRadius: BorderRadius.circular(MyTokens.cardRadius),
        onTap: onTap,
        child: Icon(icon, size: 24, color: MyTokens.accentDark),
      ),
    );
  }
}

class _ColorRow extends StatelessWidget {
  const _ColorRow({
    required this.selected,
    required this.onSelected,
    this.showDefault = false,
  });

  /// null is the category's default color (see [showDefault]).
  final Color? selected;
  final ValueChanged<Color?> onSelected;
  final bool showDefault;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        if (showDefault)
          _swatch(const ValueKey('category-color-default'), null),
        for (final color in categoryColorChoices)
          _swatch(ValueKey('category-color-${categoryColorHex(color)}'), color),
      ],
    );
  }

  Widget _swatch(Key key, Color? color) => GestureDetector(
    key: key,
    onTap: () => onSelected(color),
    child: Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color ?? MyTokens.accentDark,
        borderRadius: BorderRadius.circular(MyTokens.cardRadius),
        boxShadow: MyTokens.cardShadow,
      ),
      child: color == selected
          ? const Icon(Icons.check, size: 24, color: Colors.white)
          : null,
    ),
  );
}

/// No quick-access field exists on categories yet, so the switch is shown
/// off and disabled instead of pretending to save.
class _QuickAccessRow extends StatelessWidget {
  const _QuickAccessRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Label('입력화면에 바로 표시 (선택)'),
              SizedBox(height: 2),
              Text(
                '카테고리가 입력 화면의 빠른 선택 목록에 표시됩니다.',
                style: TextStyle(
                  fontSize: 14,
                  letterSpacing: -0.45,
                  color: MyTokens.textPrimary,
                ),
              ),
              SizedBox(height: 2),
              _Caption('준비 중인 기능이에요.'),
            ],
          ),
        ),
        Switch(value: false, onChanged: null),
      ],
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.name, required this.icon, required this.color});

  final String name;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 12, 15, 16),
      decoration: BoxDecoration(
        color: MyTokens.cardSurface,
        borderRadius: BorderRadius.circular(MyTokens.cardRadius),
        boxShadow: MyTokens.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Label('미리보기'),
          const SizedBox(height: 10),
          CategoryRowCard(
            key: const ValueKey('category-preview'),
            icon: icon,
            iconColor: color,
            name: name.isEmpty ? '카테고리 이름' : name,
            highlighted: true,
          ),
        ],
      ),
    );
  }
}
