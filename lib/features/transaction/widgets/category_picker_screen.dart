import 'package:flutter/material.dart';
import '../../home/theme/home_tokens.dart';

IconData categoryIconFor(String? name) {
  final n = (name ?? '').toLowerCase();
  if (n == '생활') return Icons.home_work_outlined;
  if (n.contains('식비') || n.contains('식사') || n.contains('배달') || n.contains('간식')) return Icons.restaurant;
  if (n.contains('카페') || n.contains('술')) return Icons.local_cafe_outlined;
  if (n.contains('편의점')) return Icons.local_convenience_store_outlined;
  if (n.contains('차량관리')) return Icons.build_outlined;
  if (n.contains('교통') || n.contains('대중교통') || n.contains('기차') || n.contains('버스')) return Icons.directions_bus_outlined;
  if (n.contains('택시')) return Icons.local_taxi_outlined;
  if (n.contains('주유') || n.contains('차량')) return Icons.local_gas_station_outlined;
  if (n.contains('주차')) return Icons.local_parking_outlined;
  if (n.contains('생필품') || n.contains('마트') || n.contains('장보기')) return Icons.shopping_basket_outlined;
  if (n.contains('통신비')) return Icons.phone_android;
  if (n.contains('공과금')) return Icons.receipt_long_outlined;
  if (n.contains('주거비')) return Icons.home_outlined;
  if (n.contains('구독')) return Icons.subscriptions_outlined;
  if (n.contains('의류')) return Icons.checkroom_outlined;
  if (n.contains('신발') || n.contains('잡화')) return Icons.shopping_bag_outlined;
  if (n.contains('화장품') || n.contains('미용')) return Icons.face_retouching_natural_outlined;
  if (n.contains('전자기기')) return Icons.devices_outlined;
  if (n.contains('가구') || n.contains('인테리어')) return Icons.weekend_outlined;
  if (n.contains('쇼핑')) return Icons.shopping_cart_outlined;
  if (n.contains('영화') || n.contains('공연')) return Icons.theaters_outlined;
  if (n.contains('게임')) return Icons.sports_esports_outlined;
  if (n.contains('취미')) return Icons.palette_outlined;
  if (n.contains('여행')) return Icons.flight_takeoff_outlined;
  if (n.contains('스포츠')) return Icons.sports_soccer_outlined;
  if (n.contains('콘텐츠') || n.contains('여가') || n.contains('문화')) return Icons.movie_filter_outlined;
  if (n.contains('병원')) return Icons.local_hospital_outlined;
  if (n.contains('약국')) return Icons.medication_outlined;
  if (n.contains('운동')) return Icons.fitness_center_outlined;
  if (n.contains('건강')) return Icons.favorite_border;
  if (n.contains('도서')) return Icons.menu_book_outlined;
  if (n.contains('강의')) return Icons.school_outlined;
  if (n.contains('학원')) return Icons.cast_for_education_outlined;
  if (n.contains('자격증')) return Icons.workspace_premium_outlined;
  if (n.contains('학비') || n.contains('교육')) return Icons.school_outlined;
  if (n.contains('친구') || n.contains('모임')) return Icons.groups_outlined;
  if (n.contains('데이트')) return Icons.favorite_outline;
  if (n.contains('선물')) return Icons.card_giftcard_outlined;
  if (n.contains('경조사')) return Icons.celebration_outlined;
  if (n.contains('회비') || n.contains('관계')) return Icons.people_outline;
  if (n.contains('수수료')) return Icons.payments_outlined;
  if (n.contains('이자')) return Icons.percent_outlined;
  if (n.contains('세금')) return Icons.account_balance_outlined;
  if (n.contains('보험')) return Icons.shield_outlined;
  if (n.contains('대출') || n.contains('금융')) return Icons.account_balance_outlined;
  if (n.contains('투자')) return Icons.trending_up;
  if (n.contains('저축')) return Icons.savings_outlined;
  if (n.contains('수입')) return Icons.attach_money;
  if (n.contains('미분류') || n.contains('기타')) return Icons.more_horiz;
  return Icons.receipt_long_outlined;
}

/// The four "거래 유형" tab ids ([AddTransactionModal._selectedParentId]).
/// `core.expense` no longer exists as a literal category row - see
/// [majorCategoriesFor].
const typeRootIds = {'core.saving', 'core.investment', 'core.income', 'core.expense'};

/// 대분류 목록 조회. `저축`/`투자`/`수입`은 여전히 하나의 루트 카테고리
/// (`core.saving`/`core.investment`/`core.income`)의 자식으로 내려오지만,
/// `지출`의 대분류(식비/교통/생활/...)는 백엔드 카테고리 개편 이후
/// `parentCategoryId`가 없는 독립 루트 카테고리로 바뀌었다 - `core.expense`라는
/// 카테고리 행 자체가 더 이상 존재하지 않는다. 그래서 `parentTypeId`로 자식을
/// 찾지 못하면(=EXPENSE) `type == 'EXPENSE'`인 루트 카테고리들을 대신 대분류로
/// 취급한다.
List<Map<String, dynamic>> majorCategoriesFor(List<dynamic> categories, String parentTypeId) {
  final children = categories
      .whereType<Map>()
      .where((c) => c['parentCategoryId'] == parentTypeId)
      .map((c) => Map<String, dynamic>.from(c))
      .toList();
  if (children.isNotEmpty || parentTypeId != 'core.expense') return children;

  return categories
      .whereType<Map>()
      .where((c) => c['parentCategoryId'] == null && c['type'] == 'EXPENSE')
      .map((c) => Map<String, dynamic>.from(c))
      .toList();
}

/// 카테고리 한 건(`leaf`)이 속한 "거래 유형" 탭 id(core.expense/core.saving/
/// core.investment/core.income)를 되돌려준다. 부모 체인을 걸어 올라가는 대신
/// 카테고리 자체의 `type`/`purposeType`을 직접 보므로, 대분류가 몇 단계로
/// 중첩되어 있든 항상 맞는 탭을 찾는다.
String parentTypeIdFor(Map<String, dynamic> category) {
  final type = (category['type'] ?? '').toString();
  final purposeType = (category['purposeType'] ?? '').toString();
  if (type == 'INCOME') return 'core.income';
  if (purposeType == 'INVESTMENT') return 'core.investment';
  if (purposeType == 'SAVING') return 'core.saving';
  return 'core.expense';
}

class CategoryPickerResult {
  final String categoryId;
  final String categoryName;
  final String? majorName;

  CategoryPickerResult({required this.categoryId, required this.categoryName, this.majorName});
}

/// Two-step 대분류 → 소분류 picker as a bottom sheet (mockup:
/// handwriting_big_category / handwriting_small_category), matching the
/// drag-handle + title-row + icon-grid + "다음"/"저장" shell already
/// established by Home's `_DetailSheet` (`showModalBottomSheet` with a
/// vertical-top radius(24) shape). Both steps are still backed by the real
/// categories list - no data/logic changes beyond [majorCategoriesFor]
/// tolerating the EXPENSE root-category restructure above.
class CategoryPickerScreen extends StatefulWidget {
  final List<dynamic> categories;
  final String parentTypeId;

  const CategoryPickerScreen({super.key, required this.categories, required this.parentTypeId});

  @override
  State<CategoryPickerScreen> createState() => _CategoryPickerScreenState();
}

class _CategoryPickerScreenState extends State<CategoryPickerScreen> {
  Map<String, dynamic>? _selectedMajor;
  Map<String, dynamic>? _highlightedMajor;
  Map<String, dynamic>? _highlightedSub;

  List<Map<String, dynamic>> get _majors => majorCategoriesFor(widget.categories, widget.parentTypeId);

  List<Map<String, dynamic>> _childrenOf(String parentId) => widget.categories
      .whereType<Map>()
      .where((c) => c['parentCategoryId'] == parentId)
      .map((c) => Map<String, dynamic>.from(c))
      .toList();

  void _finishWithMajor(Map<String, dynamic> major) {
    Navigator.pop(
      context,
      CategoryPickerResult(categoryId: major['id'].toString(), categoryName: (major['name'] ?? '').toString()),
    );
  }

  void _goToSubStep(Map<String, dynamic> major) {
    setState(() {
      _selectedMajor = major;
      _highlightedSub = null;
    });
  }

  void _finishWithSub(Map<String, dynamic> sub) {
    Navigator.pop(
      context,
      CategoryPickerResult(
        categoryId: sub['id'].toString(),
        categoryName: (sub['name'] ?? '').toString(),
        majorName: (_selectedMajor?['name'] ?? '').toString(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSubStep = _selectedMajor != null;
    final items = isSubStep ? _childrenOf(_selectedMajor!['id'].toString()) : _majors;
    final highlighted = isSubStep ? _highlightedSub : _highlightedMajor;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (isSubStep)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: HomeTokens.textDark),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => setState(() {
                        _selectedMajor = null;
                        _highlightedMajor = null;
                      }),
                    ),
                  ),
                const Text('카테고리', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: HomeTokens.textDark)),
                if (isSubStep) ...[
                  const SizedBox(width: 6),
                  Text('- ${_selectedMajor!['name'] ?? ''}', style: const TextStyle(fontSize: 16, color: HomeTokens.textFaint)),
                ],
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: HomeTokens.textDark),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            items.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: Text('선택할 수 있는 항목이 없습니다.', style: TextStyle(color: HomeTokens.textMuted))),
                  )
                : GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final item = items[i];
                      final name = (item['name'] ?? '').toString();
                      final isSelected = highlighted != null && highlighted['id'] == item['id'];
                      return GestureDetector(
                        onTap: () => setState(() {
                          if (isSubStep) {
                            _highlightedSub = item;
                          } else {
                            _highlightedMajor = item;
                          }
                        }),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? HomeTokens.chipActiveBg : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isSelected ? HomeTokens.accent : HomeTokens.chipInactiveBorder, width: isSelected ? 1.5 : 1),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(categoryIconFor(name), size: 24, color: isSelected ? HomeTokens.accentDark : HomeTokens.textDark),
                              const SizedBox(height: 6),
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? HomeTokens.accentDark : HomeTokens.textDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            const SizedBox(height: 16),
            if (!isSubStep)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: HomeTokens.accent,
                        side: const BorderSide(color: HomeTokens.accent),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _highlightedMajor == null
                          ? null
                          : () {
                              final subs = _childrenOf(_highlightedMajor!['id'].toString());
                              if (subs.isEmpty) {
                                _finishWithMajor(_highlightedMajor!);
                              } else {
                                _goToSubStep(_highlightedMajor!);
                              }
                            },
                      child: const Text('다음', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HomeTokens.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: _highlightedMajor == null ? null : () => _finishWithMajor(_highlightedMajor!),
                      child: const Text('저장', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HomeTokens.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: _highlightedSub == null ? null : () => _finishWithSub(_highlightedSub!),
                  child: const Text('저장', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
