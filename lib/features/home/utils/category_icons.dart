import 'package:flutter/material.dart';

/// Maps a transaction/category to a Material pictogram.
///
/// Figma's designs reference brand icon packs (fluent/hugeicons/iconoir) and
/// merchant logos; per product direction those are replaced with Material
/// Icons everywhere in the app. Category matching stays name/id based since
/// that's what the existing `/api/categories` payload provides today.
IconData categoryIconFor(String? categoryId, String? name) {
  final cat = (categoryId ?? '').toLowerCase();
  final n = (name ?? '').toLowerCase();

  if (cat.contains('food') || n.contains('식비')) return Icons.restaurant;
  if (cat.contains('cafe') || n.contains('카페')) return Icons.coffee;
  if (cat.contains('transport') || n.contains('교통')) return Icons.directions_bus_outlined;
  if (cat.contains('housing') || n.contains('주거') || n.contains('생활')) return Icons.home_outlined;
  if (cat.contains('communication') || n.contains('통신')) return Icons.phone_android;
  if (cat.contains('invest') || n.contains('투자')) return Icons.trending_up;
  if (cat.contains('saving') || n.contains('저축')) return Icons.savings_outlined;
  if (n.contains('여가') || n.contains('문화')) return Icons.movie_outlined;
  if (n.contains('건강')) return Icons.favorite_border;
  if (n.contains('개발') || n.contains('교육')) return Icons.school_outlined;
  if (n.contains('관계')) return Icons.people_outline;
  if (n.contains('금융')) return Icons.account_balance_outlined;

  return Icons.receipt_long_outlined;
}
