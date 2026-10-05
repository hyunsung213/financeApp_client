/// Border-radius tiers shared across features, named by where they're used
/// rather than by numeric size. Only the tiers proven to repeat across
/// multiple files are here - one-off radii (2, 4, 8, 10, 24, ...) stay as
/// local literals in whichever single file uses them.
class AppRadii {
  AppRadii._();

  // The 월릿 radius scale. New/restyled surfaces pick from these four:
  // sm - inset tiles, inputs, small badges
  // md - list items, chips-as-cards, settings sections
  // lg - section cards (Report/Calendar/Home)
  // xl - the hero card, bottom sheets
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;

  /// Chip/pill shapes.
  static const double pill = 30;

  /// Large/hero cards (e.g. Home's D-Day summary card).
  static const double hero = 20;

  /// Buttons and mid-size cards.
  static const double button = 16;

  /// The common "medium" tier - inputs and many report/transaction/policy
  /// cards.
  static const double input = 12;

  /// Auth/My's smaller card/input radius, also very common raw in
  /// report/policy cards.
  static const double compactInput = 6;
}
