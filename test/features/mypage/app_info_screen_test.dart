import 'package:finance_client/core/branding/wallet_brand.dart';
import 'package:finance_client/core/theme.dart';
import 'package:finance_client/features/mypage/screens/app_info_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      // What package_info reports on web (pubspec name) - must not leak.
      appName: 'finance_client',
      packageName: 'com.example.finance_client',
      version: '2.3.4',
      buildNumber: '56',
      buildSignature: '',
    );
  });

  Future<void> pumpAppInfo(WidgetTester tester, ThemeMode mode) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        darkTheme: appDarkTheme,
        themeMode: mode,
        home: const AppInfoScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  String logoAsset(WidgetTester tester) {
    final image = tester.widget<Image>(
      find.descendant(
        of: find.byType(WalletLogo),
        matching: find.byType(Image),
      ),
    );
    return (image.image as AssetImage).assetName;
  }

  testWidgets('shows the 월릿 logo and the real package version', (tester) async {
    await pumpAppInfo(tester, ThemeMode.light);

    expect(find.byType(WalletLogo), findsOneWidget);
    expect(find.text('버전 2.3.4 (56)'), findsOneWidget);
    expect(find.textContaining('finance_client'), findsNothing);
    expect(find.textContaining('Finance Client'), findsNothing);
    for (final row in ['이용약관', '개인정보 처리방침', '오픈소스 라이선스', '문의하기']) {
      expect(find.text(row), findsOneWidget);
    }
  });

  testWidgets('uses the green logo in light mode', (tester) async {
    await pumpAppInfo(tester, ThemeMode.light);
    expect(logoAsset(tester), WalletBrand.logoGreenAsset);
  });

  testWidgets('uses the white logo in dark mode', (tester) async {
    await pumpAppInfo(tester, ThemeMode.dark);
    expect(logoAsset(tester), WalletBrand.logoWhiteAsset);
  });

  testWidgets('license page is titled 월릿', (tester) async {
    await pumpAppInfo(tester, ThemeMode.light);
    await tester.tap(find.text('오픈소스 라이선스'));
    await tester.pumpAndSettle();
    expect(find.text(WalletBrand.name), findsWidgets);
    expect(find.textContaining('finance_client'), findsNothing);
  });
}
