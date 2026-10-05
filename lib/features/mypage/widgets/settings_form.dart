import 'package:flutter/material.dart';

import '../theme/my_tokens.dart';

/// Form building blocks shared by the 정기 수입 설정 and 예산 배분 설정 screens, so
/// both keep the exact same card/input/button look.

/// App bar used by the settings detail screens. [leading] replaces the
/// default back button (e.g. onboarding steps that aren't separate routes).
AppBar settingsAppBar(String title, {Widget? leading}) {
  return AppBar(
    leading: leading,
    title: Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: MyTokens.textPrimary,
      ),
    ),
    backgroundColor: MyTokens.pageBackground,
    surfaceTintColor: Colors.transparent,
    foregroundColor: MyTokens.textPrimary,
    elevation: 0,
  );
}

/// Optional section title above a white rounded card.
class SettingsSectionCard extends StatelessWidget {
  final String? title;
  final Widget child;

  const SettingsSectionCard({super.key, this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(
            title!,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: MyTokens.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: MyTokens.cardSurface,
            borderRadius: BorderRadius.circular(MyTokens.cardRadius),
            boxShadow: MyTokens.cardShadow,
          ),
          child: child,
        ),
      ],
    );
  }
}

InputDecoration settingsInputDecoration({
  String? labelText,
  String? suffixText,
  Widget? prefixIcon,
  bool? isDense,
  EdgeInsetsGeometry? contentPadding,
}) {
  OutlineInputBorder outline(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(MyTokens.inputRadius),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    labelText: labelText,
    suffixText: suffixText,
    prefixIcon: prefixIcon,
    isDense: isDense,
    contentPadding: contentPadding,
    filled: true,
    fillColor: Colors.white,
    labelStyle: const TextStyle(color: MyTokens.placeholder),
    floatingLabelStyle: const TextStyle(color: MyTokens.accent),
    hintStyle: const TextStyle(color: MyTokens.placeholder),
    suffixStyle: const TextStyle(color: MyTokens.textPrimary),
    prefixIconColor: MyTokens.placeholder,
    border: outline(MyTokens.borderNeutral),
    enabledBorder: outline(MyTokens.borderNeutral),
    focusedBorder: outline(MyTokens.accent, 1.5),
  );
}

/// Full-width 저장 button; [onPressed] null disables it.
class SettingsSaveButton extends StatelessWidget {
  final bool isSaving;
  final VoidCallback? onPressed;
  final String label;

  const SettingsSaveButton({
    super.key,
    required this.isSaving,
    required this.onPressed,
    this.label = '저장',
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isSaving ? null : onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: MyTokens.accent,
        foregroundColor: Colors.white,
        disabledBackgroundColor: MyTokens.placeholder,
        disabledForegroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MyTokens.buttonRadius),
        ),
        elevation: 0,
      ),
      child: isSaving
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
    );
  }
}
