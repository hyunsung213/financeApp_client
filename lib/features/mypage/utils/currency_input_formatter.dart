import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Formats a digits-only amount with thousands separators as it's typed
/// (월급 금액 in 월급 설정 and onboarding).
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue.copyWith(text: '');

    final cleanText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanText.isEmpty) return newValue.copyWith(text: '');

    final int value = int.parse(cleanText);
    final formatter = NumberFormat('#,###');
    final String newText = formatter.format(value);

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}
