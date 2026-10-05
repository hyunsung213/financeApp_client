import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Type hierarchy shared by the tab screens (Home/Calendar/Report). Colors
/// mirror `HomeTokens.textDark`/`textFaint`/`textMuted` as literals so
/// `core/theme` doesn't depend on a feature folder.
class AppTextStyles {
  AppTextStyles._();

  static const Color _textDark = Color(0xFF2F2F2F);
  static const Color _textFaint = Color(0xFF6B7280);
  static const Color _textMuted = Color(0xFFADADAD);

  // On the green header.
  static const TextStyle headerTitle = TextStyle(
    color: Colors.white,
    fontSize: 22,
    fontWeight: FontWeight.w700,
  );
  static const TextStyle headerSubtitle = TextStyle(
    color: Color(0xD9FFFFFF),
    fontSize: 15,
  );
  static const TextStyle headerLabel = TextStyle(
    color: Color(0xD9FFFFFF),
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  /// The one key figure a header shows (Report's monthly total).
  static const TextStyle headerFigure = TextStyle(
    color: Colors.white,
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
  );

  // On the page / inside cards.
  /// Section heading that sits on the page background.
  static const TextStyle sectionTitle = TextStyle(
    color: _textDark,
    fontSize: 18,
    fontWeight: FontWeight.w700,
  );

  /// Heading inside a content card.
  static const TextStyle cardTitle = TextStyle(
    color: _textDark,
    fontSize: 16,
    fontWeight: FontWeight.w700,
  );

  /// Trailing "더보기"/count next to a section or card title.
  static const TextStyle sectionAction = TextStyle(
    color: _textFaint,
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle body = TextStyle(color: _textDark, fontSize: 14);
  static const TextStyle secondary = TextStyle(color: _textFaint, fontSize: 14);
  static const TextStyle caption = TextStyle(color: _textMuted, fontSize: 12);

  /// Emphasized amount inside a card.
  static const TextStyle cardFigure = TextStyle(
    color: _textDark,
    fontSize: 18,
    fontWeight: FontWeight.w800,
  );

  // Money. Tabular figures keep digits from shifting width as amounts
  // change, and the tighter tracking keeps big numbers compact.
  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  /// The one amount a screen is about (Home's "오늘 쓸 수 있는 돈").
  static const TextStyle amountHero = TextStyle(
    fontSize: 44,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.4,
    height: 1.1,
    fontFeatures: _tabular,
  );

  /// Second-tier amount (a card's key figure).
  static const TextStyle amountLarge = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
    height: 1.2,
    fontFeatures: _tabular,
  );

  /// Amount inside a list item / row.
  static const TextStyle amountMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    fontFeatures: _tabular,
  );

  /// Brand-green accent for an emphasized value inside running text.
  static const Color accent = AppColorTokens.accent;
}
