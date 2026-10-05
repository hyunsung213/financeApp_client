import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../features/auth/providers/auth_provider.dart';

/// How amounts are shown (앱 설정 > 화면 표시 > 금액 표시 형식).
///
/// Display only: stored/calculated amounts, API values and amount inputs are
/// always exact won and never go through this.
enum MoneyDisplayFormat {
  /// `1,234,567원`
  exact,

  /// `123.5만원`; amounts under 10,000 stay exact (`5,000원`).
  compact,
}

final NumberFormat _grouped = NumberFormat('#,###');
final NumberFormat _manUnits = NumberFormat('#,##0.#');

/// Formats [amount] in won. [withUnit] false drops the trailing `원` for
/// spots that show the unit separately (e.g. Home's big hero number).
String formatMoney(
  int amount,
  MoneyDisplayFormat format, {
  bool withUnit = true,
}) {
  final unit = withUnit ? '원' : '';
  if (format == MoneyDisplayFormat.compact && amount.abs() >= 10000) {
    return '${_manUnits.format(amount / 10000)}만$unit';
  }
  return '${_grouped.format(amount)}$unit';
}

/// Saved [MoneyDisplayFormat], kept on the device only.
class MoneyDisplayFormatNotifier extends Notifier<MoneyDisplayFormat> {
  static const storageKey = 'settings.moneyDisplayFormat';

  @override
  MoneyDisplayFormat build() {
    final saved = ref.read(sharedPreferencesProvider)?.getString(storageKey);
    return MoneyDisplayFormat.values.asNameMap()[saved] ??
        MoneyDisplayFormat.exact;
  }

  void setFormat(MoneyDisplayFormat format) {
    state = format;
    ref.read(sharedPreferencesProvider)?.setString(storageKey, format.name);
  }
}

final moneyDisplayFormatProvider =
    NotifierProvider<MoneyDisplayFormatNotifier, MoneyDisplayFormat>(
      MoneyDisplayFormatNotifier.new,
    );

/// Puts the current [MoneyDisplayFormat] above every route (see
/// `FinanceApp`'s `MaterialApp.builder`), so any widget can format amounts
/// with `context.formatWon(...)` and rebuilds when the setting changes -
/// including screens kept alive in other tabs.
class MoneyFormatScope extends InheritedWidget {
  final MoneyDisplayFormat format;

  const MoneyFormatScope({
    super.key,
    required this.format,
    required super.child,
  });

  @override
  bool updateShouldNotify(MoneyFormatScope oldWidget) =>
      format != oldWidget.format;
}

extension MoneyFormatContext on BuildContext {
  /// Exact when there is no [MoneyFormatScope] (e.g. a widget test).
  MoneyDisplayFormat get moneyDisplayFormat =>
      dependOnInheritedWidgetOfExactType<MoneyFormatScope>()?.format ??
      MoneyDisplayFormat.exact;

  String formatWon(int amount, {bool withUnit = true}) =>
      formatMoney(amount, moneyDisplayFormat, withUnit: withUnit);
}
