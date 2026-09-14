import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../theme/my_tokens.dart';

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
    final appName = _packageInfo?.appName ?? 'Finance Client';
    final version = _packageInfo?.version;
    final buildNumber = _packageInfo?.buildNumber;
    final versionText = version == null
        ? ''
        : (buildNumber == null || buildNumber.isEmpty
              ? version
              : '$version ($buildNumber)');

    return Scaffold(
      backgroundColor: MyTokens.pageBackground,
      appBar: AppBar(
        title: const Text(
          '앱 정보',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: MyTokens.textPrimary,
          ),
        ),
        backgroundColor: MyTokens.pageBackground,
        surfaceTintColor: Colors.transparent,
        foregroundColor: MyTokens.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: MyTokens.accent,
                    borderRadius: BorderRadius.circular(MyTokens.buttonRadius),
                  ),
                  child: const Icon(
                    Icons.savings_outlined,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  appName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: MyTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  versionText.isEmpty ? '버전 정보를 불러오는 중...' : '버전 $versionText',
                  style: const TextStyle(
                    color: MyTokens.textMuted,
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
              applicationName: appName,
              applicationVersion: versionText,
            ),
          ),
          _infoRow(context, '문의하기'),
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext context, String title, {VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: MyTokens.cardSurface,
        borderRadius: BorderRadius.circular(MyTokens.cardRadius),
        boxShadow: MyTokens.cardShadow,
      ),
      // Transparent Material so the ListTile ripple paints above the card
      // decoration instead of behind it.
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MyTokens.cardRadius),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: MyTokens.textPrimary,
            ),
          ),
          trailing: const Icon(Icons.chevron_right, color: MyTokens.textMuted),
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
