import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/api/category_api.dart';
import '../../transaction/widgets/category_picker_screen.dart'
    show majorCategoriesFor;

/// 카테고리 관리 tabs. 지출 lists the 지출 대분류 (each opens its 소분류);
/// 수입 lists the categories under the `core.income` root, which the
/// transaction picker also treats as 수입's 대분류.
enum CategoryTab { expense, income }

extension CategoryTabX on CategoryTab {
  String get label => this == CategoryTab.expense ? '지출' : '수입';
  String get type => this == CategoryTab.expense ? 'EXPENSE' : 'INCOME';
  String get rootId =>
      this == CategoryTab.expense ? 'core.expense' : 'core.income';
}

/// Top-level rows of a tab, in the API's sortOrder.
List<Map<String, dynamic>> categoriesForTab(
  List<dynamic> categories,
  CategoryTab tab,
) => majorCategoriesFor(categories, tab.rootId);

List<Map<String, dynamic>> childCategoriesOf(
  List<dynamic> categories,
  String parentId,
) => categories
    .whereType<Map>()
    .where((c) => c['parentCategoryId'] == parentId)
    .map((c) => Map<String, dynamic>.from(c))
    .toList();

/// Every category's name, icon and color can be changed. Only categories the
/// user added can be deleted: system categories are tied to the budget plan,
/// reports and the notification parser by id, so the backend keeps them (and
/// stores a rename as the user's display override, never a new id).
bool isDeletableCategory(Map<String, dynamic> category) =>
    category['isCustom'] == true;

/// A new 지출 category is always a 소분류: budget amounts and the daily
/// allowance only count spending under the 10 fixed 지출 대분류, so a custom
/// 지출 대분류 would let its spending bypass the budget.
bool requiresParentForNewCategory(CategoryTab tab) =>
    tab == CategoryTab.expense;

class CategoryActionsNotifier extends Notifier<void> {
  @override
  void build() {}

  /// Appends after its siblings ([siblings] are the rows it will sit with).
  Future<void> create({
    required String name,
    required CategoryTab tab,
    required String parentCategoryId,
    required List<Map<String, dynamic>> siblings,
    String? icon,
    String? color,
  }) async {
    final lastOrder = siblings.fold<int>(
      0,
      (max, c) => (c['sortOrder'] as num? ?? 0) > max
          ? (c['sortOrder'] as num).toInt()
          : max,
    );
    await ref
        .read(categoryApiProvider)
        .createCategory(
          name: name,
          type: tab.type,
          purposeType: 'GENERAL',
          sortOrder: lastOrder + 1,
          parentCategoryId: parentCategoryId,
          icon: icon,
          color: color,
        );
    ref.invalidate(categoriesProvider);
  }

  /// Sends only the fields given (null = unchanged).
  Future<void> update(
    String id, {
    String? name,
    String? icon,
    String? color,
  }) async {
    await ref
        .read(categoryApiProvider)
        .updateCategory(id, name: name, icon: icon, color: color);
    ref.invalidate(categoriesProvider);
  }

  Future<void> resetAppearance(String id) async {
    await ref.read(categoryApiProvider).resetCategoryAppearance(id);
    ref.invalidate(categoriesProvider);
  }

  Future<void> delete(String id) async {
    await ref.read(categoryApiProvider).deleteCategory(id);
    ref.invalidate(categoriesProvider);
  }
}

final categoryActionsProvider = NotifierProvider<CategoryActionsNotifier, void>(
  CategoryActionsNotifier.new,
);
