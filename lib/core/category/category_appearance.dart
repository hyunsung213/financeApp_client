import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/category_api.dart';

/// Icons a category can show, by the key stored in its `icon` field
/// (`PATCH /api/categories/:id`). Keys are the Material icon names, so the
/// backend only ever sees short strings and the app keeps const IconData.
const categoryIconsByKey = <String, IconData>{
  'pets_outlined': Icons.pets_outlined,
  'restaurant': Icons.restaurant,
  'local_cafe_outlined': Icons.local_cafe_outlined,
  'coffee': Icons.coffee,
  'local_convenience_store_outlined': Icons.local_convenience_store_outlined,
  'build_outlined': Icons.build_outlined,
  'directions_bus_outlined': Icons.directions_bus_outlined,
  'local_taxi_outlined': Icons.local_taxi_outlined,
  'local_gas_station_outlined': Icons.local_gas_station_outlined,
  'local_parking_outlined': Icons.local_parking_outlined,
  'shopping_basket_outlined': Icons.shopping_basket_outlined,
  'phone_android': Icons.phone_android,
  'receipt_long_outlined': Icons.receipt_long_outlined,
  'home_outlined': Icons.home_outlined,
  'home_work_outlined': Icons.home_work_outlined,
  'subscriptions_outlined': Icons.subscriptions_outlined,
  'checkroom_outlined': Icons.checkroom_outlined,
  'shopping_bag_outlined': Icons.shopping_bag_outlined,
  'face_retouching_natural_outlined': Icons.face_retouching_natural_outlined,
  'devices_outlined': Icons.devices_outlined,
  'weekend_outlined': Icons.weekend_outlined,
  'shopping_cart_outlined': Icons.shopping_cart_outlined,
  'theaters_outlined': Icons.theaters_outlined,
  'sports_esports_outlined': Icons.sports_esports_outlined,
  'palette_outlined': Icons.palette_outlined,
  'flight_takeoff_outlined': Icons.flight_takeoff_outlined,
  'sports_soccer_outlined': Icons.sports_soccer_outlined,
  'movie_filter_outlined': Icons.movie_filter_outlined,
  'local_hospital_outlined': Icons.local_hospital_outlined,
  'medication_outlined': Icons.medication_outlined,
  'fitness_center_outlined': Icons.fitness_center_outlined,
  'favorite_border': Icons.favorite_border,
  'menu_book_outlined': Icons.menu_book_outlined,
  'school_outlined': Icons.school_outlined,
  'cast_for_education_outlined': Icons.cast_for_education_outlined,
  'workspace_premium_outlined': Icons.workspace_premium_outlined,
  'groups_outlined': Icons.groups_outlined,
  'card_giftcard_outlined': Icons.card_giftcard_outlined,
  'celebration_outlined': Icons.celebration_outlined,
  'people_outline': Icons.people_outline,
  'payments_outlined': Icons.payments_outlined,
  'percent_outlined': Icons.percent_outlined,
  'account_balance_outlined': Icons.account_balance_outlined,
  'shield_outlined': Icons.shield_outlined,
  'trending_up': Icons.trending_up,
  'savings_outlined': Icons.savings_outlined,
  'attach_money': Icons.attach_money,
  'more_horiz': Icons.more_horiz,
};

/// Figma Frame 109 icon candidates (keys of [categoryIconsByKey]).
const categoryIconChoiceKeys = <String>[
  'pets_outlined',
  'restaurant',
  'local_cafe_outlined',
  'directions_bus_outlined',
  'shopping_bag_outlined',
  'home_outlined',
  'favorite_border',
  'school_outlined',
  'card_giftcard_outlined',
  'sports_esports_outlined',
  'flight_takeoff_outlined',
  'attach_money',
];

/// Figma Frame 109 color palette.
const categoryColorChoices = <Color>[
  Color(0xFFED5564),
  Color(0xFFFB6E52),
  Color(0xFFFFCE55),
  Color(0xFF00AE76),
  Color(0xFF4FC0E8),
  Color(0xFF5D9CEC),
  Color(0xFFAC92ED),
];

const _fallbackIconKey = 'receipt_long_outlined';

/// Canonical-name keywords to icon keys, first match wins (order matters:
/// e.g. 차량관리 before 차량, 대중교통 before 택시).
const _iconKeyByNameKeyword = <(List<String>, String)>[
  (['식비', '식사', '배달', '간식'], 'restaurant'),
  (['카페', '술'], 'local_cafe_outlined'),
  (['편의점'], 'local_convenience_store_outlined'),
  (['차량관리'], 'build_outlined'),
  (['교통', '대중교통', '기차', '버스'], 'directions_bus_outlined'),
  (['택시'], 'local_taxi_outlined'),
  (['주유', '차량'], 'local_gas_station_outlined'),
  (['주차'], 'local_parking_outlined'),
  (['생필품', '마트', '장보기'], 'shopping_basket_outlined'),
  (['통신비'], 'phone_android'),
  (['공과금'], 'receipt_long_outlined'),
  (['주거비'], 'home_outlined'),
  (['구독'], 'subscriptions_outlined'),
  (['의류'], 'checkroom_outlined'),
  (['신발', '잡화'], 'shopping_bag_outlined'),
  (['화장품', '미용'], 'face_retouching_natural_outlined'),
  (['전자기기'], 'devices_outlined'),
  (['가구', '인테리어'], 'weekend_outlined'),
  (['쇼핑'], 'shopping_cart_outlined'),
  (['영화', '공연'], 'theaters_outlined'),
  (['게임'], 'sports_esports_outlined'),
  (['취미'], 'palette_outlined'),
  (['여행'], 'flight_takeoff_outlined'),
  (['스포츠'], 'sports_soccer_outlined'),
  (['콘텐츠', '여가', '문화'], 'movie_filter_outlined'),
  (['병원'], 'local_hospital_outlined'),
  (['약국'], 'medication_outlined'),
  (['운동'], 'fitness_center_outlined'),
  (['건강'], 'favorite_border'),
  (['도서'], 'menu_book_outlined'),
  (['강의'], 'school_outlined'),
  (['학원'], 'cast_for_education_outlined'),
  (['자격증'], 'workspace_premium_outlined'),
  (['학비', '교육'], 'school_outlined'),
  (['친구', '모임'], 'groups_outlined'),
  (['데이트'], 'favorite_border'),
  (['선물'], 'card_giftcard_outlined'),
  (['경조사'], 'celebration_outlined'),
  (['회비', '관계'], 'people_outline'),
  (['수수료'], 'payments_outlined'),
  (['이자'], 'percent_outlined'),
  (['세금'], 'account_balance_outlined'),
  (['보험'], 'shield_outlined'),
  (['대출', '금융'], 'account_balance_outlined'),
  (['투자'], 'trending_up'),
  (['저축'], 'savings_outlined'),
  (['급여'], 'payments_outlined'),
  (['수입'], 'attach_money'),
  (['미분류', '기타'], 'more_horiz'),
];

/// Fallback by id segment when the name matches nothing above.
const _iconKeyByIdKeyword = <(String, String)>[
  ('food', 'restaurant'),
  ('cafe', 'coffee'),
  ('transport', 'directions_bus_outlined'),
  ('housing', 'home_outlined'),
  ('communication', 'phone_android'),
  ('invest', 'trending_up'),
  ('saving', 'savings_outlined'),
];

/// The icon a category shows until the user picks one. It is derived from
/// the category's id and *canonical* name - never from a user's display
/// name - so renaming 택시 to 카카오택시 (or 이동) keeps the taxi icon.
String defaultCategoryIconKey({String? categoryId, String? canonicalName}) {
  final name = (canonicalName ?? '').toLowerCase();
  if (name == '생활') return 'home_work_outlined';
  for (final (keywords, key) in _iconKeyByNameKeyword) {
    if (keywords.any(name.contains)) return key;
  }
  final id = (categoryId ?? '').toLowerCase();
  for (final (keyword, key) in _iconKeyByIdKeyword) {
    if (id.contains(keyword)) return key;
  }
  return _fallbackIconKey;
}

IconData categoryIconForKey(String? key) =>
    categoryIconsByKey[key] ?? categoryIconsByKey[_fallbackIconKey]!;

/// `#RRGGBB` (the API's form) to a Color; null for anything else.
Color? parseCategoryColor(Object? value) {
  final hex = value?.toString() ?? '';
  if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(hex)) return null;
  return Color(int.parse('FF${hex.substring(1)}', radix: 16));
}

String categoryColorHex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// How one category looks to the signed-in user, from a
/// `GET /api/categories` row. [name] is the display name (the user's rename
/// for a system category); [id] and [canonicalName] are what budgets,
/// reports and auto-categorisation keep using.
class CategoryAppearance {
  const CategoryAppearance({
    required this.id,
    required this.name,
    required this.canonicalName,
    required this.iconKey,
    required this.color,
    required this.hasCustomIcon,
    required this.isCustomized,
    required this.isSystem,
  });

  factory CategoryAppearance.fromJson(Map<dynamic, dynamic> json) {
    final id = '${json['id']}';
    final name = '${json['name'] ?? ''}';
    final canonicalName = '${json['canonicalName'] ?? name}';
    final storedIcon = json['icon']?.toString();
    final hasCustomIcon = categoryIconsByKey.containsKey(storedIcon);
    return CategoryAppearance(
      id: id,
      name: name,
      canonicalName: canonicalName,
      iconKey: hasCustomIcon
          ? storedIcon!
          : defaultCategoryIconKey(
              categoryId: id,
              canonicalName: canonicalName,
            ),
      color: parseCategoryColor(json['color']),
      hasCustomIcon: hasCustomIcon,
      isCustomized: json['isCustomized'] == true,
      isSystem: json['isSystem'] == true,
    );
  }

  final String id;
  final String name;
  final String canonicalName;
  final String iconKey;

  /// The user's color, or null for the screen's default icon color.
  final Color? color;
  final bool hasCustomIcon;
  final bool isCustomized;
  final bool isSystem;

  IconData get icon => categoryIconForKey(iconKey);
}

/// Category display lookup by id. Screens that only have a transaction's
/// `categoryId` and the backend's embedded (canonical) `category.name` go
/// through this, so a rename shows everywhere without ever matching on name
/// strings. Unknown ids (not loaded yet, or a deleted custom category) fall
/// back to the name the payload carried.
class CategoryDirectory {
  CategoryDirectory(Iterable<dynamic> categories)
    : _byId = {
        for (final c in categories.whereType<Map>())
          '${c['id']}': CategoryAppearance.fromJson(c),
      };

  static final empty = CategoryDirectory(const []);

  final Map<String, CategoryAppearance> _byId;

  CategoryAppearance? operator [](String? id) => id == null ? null : _byId[id];

  String? nameOf(String? id, [String? fallback]) => this[id]?.name ?? fallback;

  IconData iconOf(String? id, [String? fallbackName]) =>
      this[id]?.icon ??
      categoryIconForKey(
        defaultCategoryIconKey(categoryId: id, canonicalName: fallbackName),
      );

  Color? colorOf(String? id) => this[id]?.color;

  static String? _embeddedName(Map<dynamic, dynamic> tx) =>
      tx['category'] is Map ? tx['category']['name']?.toString() : null;

  /// A transaction's category name as this user sees it.
  String? nameForTransaction(Map<dynamic, dynamic> tx) =>
      nameOf(tx['categoryId']?.toString(), _embeddedName(tx));

  IconData iconForTransaction(Map<dynamic, dynamic> tx) =>
      iconOf(tx['categoryId']?.toString(), _embeddedName(tx));
}

/// [CategoryDirectory] over the current user's categories; empty until
/// `GET /api/categories` loads.
final categoryDirectoryProvider = Provider<CategoryDirectory>((ref) {
  final categories = ref.watch(categoriesProvider).asData?.value;
  return categories == null
      ? CategoryDirectory.empty
      : CategoryDirectory(categories);
});
