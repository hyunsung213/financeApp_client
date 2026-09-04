import 'package:flutter/material.dart';
import '../../../core/theme.dart';

IconData categoryIconFor(String? name) {
  final n = (name ?? '').toLowerCase();
  if (n.contains('식비') || n.contains('식사') || n.contains('배달') || n.contains('간식')) return Icons.restaurant;
  if (n.contains('카페') || n.contains('술')) return Icons.local_cafe_outlined;
  if (n.contains('편의점')) return Icons.local_convenience_store_outlined;
  if (n.contains('교통') || n.contains('대중교통') || n.contains('기차') || n.contains('버스')) return Icons.directions_bus_outlined;
  if (n.contains('택시')) return Icons.local_taxi_outlined;
  if (n.contains('주유') || n.contains('차량')) return Icons.local_gas_station_outlined;
  if (n.contains('주차')) return Icons.local_parking_outlined;
  if (n.contains('생필품') || n.contains('마트') || n.contains('장보기')) return Icons.shopping_basket_outlined;
  if (n.contains('통신비')) return Icons.phone_android;
  if (n.contains('공과금')) return Icons.receipt_long_outlined;
  if (n.contains('주거비')) return Icons.home_outlined;
  if (n.contains('구독')) return Icons.subscriptions_outlined;
  if (n.contains('생활')) return Icons.checkroom_outlined;
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

class CategoryPickerResult {
  final String categoryId;
  final String categoryName;
  final String? majorName;

  CategoryPickerResult({required this.categoryId, required this.categoryName, this.majorName});
}

/// Two-step 대분류 → 소분류 picker. Both steps are backed by the real
/// categories list (major = categories whose parentCategoryId == parentTypeId,
/// sub = categories whose parentCategoryId == the chosen major's id).
/// If a major has no children it's treated as a leaf and returned directly.
class CategoryPickerScreen extends StatefulWidget {
  final List<dynamic> categories;
  final String parentTypeId;

  const CategoryPickerScreen({super.key, required this.categories, required this.parentTypeId});

  @override
  State<CategoryPickerScreen> createState() => _CategoryPickerScreenState();
}

class _CategoryPickerScreenState extends State<CategoryPickerScreen> {
  Map<String, dynamic>? _selectedMajor;

  List<Map<String, dynamic>> get _majors => widget.categories
      .whereType<Map>()
      .where((c) => c['parentCategoryId'] == widget.parentTypeId)
      .map((c) => Map<String, dynamic>.from(c))
      .toList();

  List<Map<String, dynamic>> _childrenOf(String parentId) => widget.categories
      .whereType<Map>()
      .where((c) => c['parentCategoryId'] == parentId)
      .map((c) => Map<String, dynamic>.from(c))
      .toList();

  void _pickMajor(Map<String, dynamic> major) {
    final subs = _childrenOf(major['id'].toString());
    if (subs.isEmpty) {
      Navigator.pop(
        context,
        CategoryPickerResult(categoryId: major['id'].toString(), categoryName: (major['name'] ?? '').toString()),
      );
      return;
    }
    setState(() => _selectedMajor = major);
  }

  void _pickSub(Map<String, dynamic> sub) {
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () {
            if (isSubStep) {
              setState(() => _selectedMajor = null);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(isSubStep ? '지출 소분류 선택' : '지출 대분류 선택', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
      ),
      body: Column(
        children: [
          if (isSubStep)
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                children: [
                  Icon(categoryIconFor(_selectedMajor!['name']?.toString()), color: AppColors.primary, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    (_selectedMajor!['name'] ?? '').toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
                  ),
                ],
              ),
            ),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('선택할 수 있는 항목이 없습니다.', style: TextStyle(color: AppColors.textSecondary)))
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (context, i) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, i) {
                      final item = items[i];
                      final name = (item['name'] ?? '').toString();
                      return ListTile(
                        tileColor: Colors.white,
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
                          child: Icon(categoryIconFor(name), color: AppColors.primary, size: 20),
                        ),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                        trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
                        onTap: () => isSubStep ? _pickSub(item) : _pickMajor(item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
