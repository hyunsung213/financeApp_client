import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/branding/wallet_brand.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/wallet_glass.dart';
import '../../../core/widgets/glass.dart';

/// 앱 정보: final 월릿 lockup + the real version/build from the platform
/// (pubspec `version`), then the policy/contact rows.
///
/// Colors come from `context.glass`, so the screen and the logo tone
/// follow dark mode.

class AppInfoScreen extends StatefulWidget {
  const AppInfoScreen({super.key});

  @override
  State<AppInfoScreen> createState() => _AppInfoScreenState();
}

class _AppInfoScreenState extends State<AppInfoScreen> {
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _packageInfo = info);
    });
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final version = _packageInfo?.version;
    final buildNumber = _packageInfo?.buildNumber;
    final versionText = version == null
        ? ''
        : (buildNumber == null || buildNumber.isEmpty
              ? version
              : '$version ($buildNumber)');

    return WalletBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            '앱 정보',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: glass.textPrimary,
            ),
          ),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          foregroundColor: glass.textPrimary,
          elevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Column(
                children: [
                  // The lockup already spells "월릿", so no separate name text.
                  const WalletLogo(height: 40),
                  const SizedBox(height: 12),
                  Text(
                    versionText.isEmpty
                        ? '버전 정보를 불러오는 중...'
                        : '버전 $versionText',
                    style: TextStyle(
                      color: glass.textTertiary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _infoRow(context, '이용약관'),
            _infoRow(context, '개인정보 처리방침'),
            _infoRow(
              context,
              '오픈소스 라이선스',
              onTap: () => showLicensePage(
                context: context,
                applicationName: WalletBrand.name,
                applicationVersion: versionText,
                applicationIcon: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: WalletLogo(),
                ),
              ),
            ),
            _infoRow(context, '문의하기'),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, String title, {VoidCallback? onTap}) {
    final glass = context.glass;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: glassDecoration(context, radius: AppRadii.md),
      // Transparent Material so the ListTile ripple paints above the card
      // decoration instead of behind it.
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: glass.textPrimary,
            ),
          ),
          trailing: Icon(Icons.chevron_right, color: glass.textTertiary),
          onTap:
              onTap ??
              () => ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('$title 페이지는 준비 중이에요.'))),
        ),
      ),
    );
  }
}
