import 'package:flutter/material.dart';

import '../../../core/theme/app_radii.dart';
import '../../../core/theme/wallet_glass.dart';
import '../../../core/widgets/glass.dart';
import '../theme/my_tokens.dart';

/// Form building blocks shared by the 정기 수입 설정 and 예산 배분 설정 screens, so
/// both keep the exact same card/input/button look.

/// App bar used by the settings detail screens. [leading] replaces the
/// default back button (e.g. onboarding steps that aren't separate routes).
///
/// Transparent so the screen's [WalletBackground] shows through; the title
/// reads its color from the glass theme via a [Builder] (this helper has no
/// BuildContext of its own), the back arrow follows the AppBar theme.
AppBar settingsAppBar(String title, {Widget? leading}) {
  return AppBar(
    leading: leading,
    title: Builder(
      builder: (context) => Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: context.glass.textPrimary,
        ),
      ),
    ),
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    scrolledUnderElevation: 0,
    elevation: 0,
  );
}

/// Optional section title above a Level 2 glass card.
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
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: context.glass.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: glassDecoration(context, radius: AppRadii.lg),
          child: child,
        ),
      ],
    );
  }
}

/// Text-field decoration for the settings forms.
///
/// Pass [context] to get the glass look (theme-aware fill/border/text, works
/// in dark mode). Without it (callers outside My that have no context at
/// hand) it keeps the original light-only look.
InputDecoration settingsInputDecoration({
  String? labelText,
  String? suffixText,
  Widget? prefixIcon,
  bool? isDense,
  EdgeInsetsGeometry? contentPadding,
  BuildContext? context,
}) {
  final glass = context?.glass;
  final radius = glass == null ? MyTokens.inputRadius : AppRadii.sm;
  OutlineInputBorder outline(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: color, width: width),
      );
  final muted = glass?.textTertiary ?? MyTokens.placeholder;
  final border = glass?.divider ?? MyTokens.borderNeutral;
  return InputDecoration(
    labelText: labelText,
    suffixText: suffixText,
    prefixIcon: prefixIcon,
    isDense: isDense,
    contentPadding: contentPadding,
    filled: true,
    fillColor: glass?.insetFill ?? Colors.white,
    labelStyle: TextStyle(color: muted),
    floatingLabelStyle: TextStyle(color: glass?.accentText ?? MyTokens.accent),
    hintStyle: TextStyle(color: muted),
    suffixStyle: TextStyle(color: glass?.textPrimary ?? MyTokens.textPrimary),
    prefixIconColor: muted,
    border: outline(border),
    enabledBorder: outline(border),
    focusedBorder: outline(glass?.accent ?? MyTokens.accent, 1.5),
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
      // Colors (incl. the disabled state) come from the theme's
      // elevatedButtonTheme.
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        elevation: 0,
      ),
      child: isSaving
          // The button is disabled while saving, so the spinner sits on the
          // theme's muted disabled fill: use the brand green, not white.
          ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.glass.accent,
              ),
            )
          : Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
    );
  }
}
