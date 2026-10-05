import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/widgets/glass.dart';
import '../theme/my_tokens.dart';

/// Building blocks shared by 앱 설정 (Figma Frame 106) and its sub-screens,
/// so they all keep the same card/row/toggle look. Colors come from
/// `context.palette`, so these follow the dark theme.

TextStyle appSettingsTitleStyle(AppPalette palette) => TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w600,
  height: 1.3,
  letterSpacing: -0.45,
  color: palette.textPrimary,
);

TextStyle appSettingsSubtitleStyle(AppPalette palette) => TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w400,
  height: 1.3,
  letterSpacing: -0.45,
  color: palette.textPrimary,
);

/// Level 2 glass card, same as the rest of the app's cards.
BoxDecoration appSettingsCardDecoration(BuildContext context) =>
    glassDecoration(context, radius: _cardRadius);

const double _cardRadius = AppRadii.md;

void showAppSettingsNotice(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Page frame: 20px bold title next to the back arrow, #F7F7F7-style
/// background and a 14px side gutter.
class AppSettingsScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const AppSettingsScaffold({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // The ambient background sits behind the whole Scaffold, so the
    // transparent app bar and the list share one continuous backdrop.
    return WalletBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          // Figma keeps the title next to the back arrow on every platform
          // (web/iOS would otherwise center it).
          centerTitle: false,
          title: Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              height: 1.3,
              letterSpacing: -0.45,
              color: palette.textPrimary,
            ),
          ),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          foregroundColor: palette.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
            children: children,
          ),
        ),
      ),
    );
  }
}

/// A tappable card row: title, optional subtitle, optional green [value]
/// and a chevron (or [trailing] in its place).
class AppSettingsRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final double? minHeight;
  final VoidCallback? onTap;

  const AppSettingsRow({
    super.key,
    required this.title,
    this.onTap,
    this.subtitle,
    this.value,
    this.trailing,
    this.minHeight,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      decoration: appSettingsCardDecoration(context),
      // Transparent Material so the InkWell ripple paints above the card
      // decoration instead of behind it.
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(_cardRadius),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: minHeight ?? (subtitle == null ? 55 : 73),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: appSettingsTitleStyle(palette)),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: appSettingsSubtitleStyle(palette),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (value != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      value!,
                      style: appSettingsTitleStyle(
                        palette,
                      ).copyWith(color: palette.accent),
                    ),
                    const SizedBox(width: 6),
                  ],
                  trailing ??
                      Icon(
                        Icons.chevron_right,
                        size: 24,
                        color: palette.textPrimary,
                      ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Figma 51×30 pill toggle (176:5681). [onChanged] null shows it disabled.
class WalletToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const WalletToggle({super.key, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final enabled = onChanged != null;
    return Semantics(
      toggled: value,
      enabled: enabled,
      child: GestureDetector(
        onTap: enabled ? () => onChanged!(!value) : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 51,
            height: 30,
            decoration: BoxDecoration(
              color: value ? null : palette.border,
              gradient: value ? MyTokens.primaryGradient : null,
              border: Border.all(
                color: value ? MyTokens.accentSoftBorder : palette.border,
                width: 1.244,
              ),
              borderRadius: BorderRadius.circular(MyTokens.chipRadius),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 150),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 25,
                height: 25,
                margin: const EdgeInsets.symmetric(horizontal: 1.3),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 2.4,
                      offset: Offset(0, 0.8),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Selectable option card with a green radio mark, used for single-choice
/// settings (금액 표시 형식, 언어).
class AppSettingsChoiceCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback? onTap;

  const AppSettingsChoiceCard({
    super.key,
    required this.title,
    required this.selected,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = BorderRadius.circular(_cardRadius);
    return Semantics(
      selected: selected,
      button: onTap != null,
      child: Container(
        decoration: appSettingsCardDecoration(context).copyWith(
          border: Border.all(
            color: selected ? palette.accent : Colors.transparent,
            width: 2,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: appSettingsTitleStyle(palette)),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            style: appSettingsTitleStyle(
                              palette,
                            ).copyWith(color: palette.accent),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 24,
                    color: selected ? palette.accent : palette.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small muted caption under a group of cards.
class AppSettingsCaption extends StatelessWidget {
  final String text;

  const AppSettingsCaption(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          height: 1.4,
          letterSpacing: -0.3,
          color: palette.textMuted,
        ),
      ),
    );
  }
}
