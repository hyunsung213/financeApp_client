import 'package:finance_client/core/app_lock/app_lock.dart';
import 'package:finance_client/core/format/money_format.dart';
import 'package:finance_client/core/providers/theme_mode_provider.dart';
import 'package:finance_client/core/theme.dart';
import 'package:finance_client/features/auth/providers/auth_provider.dart';
import 'package:finance_client/features/home/providers/home_section_visibility_provider.dart';
import 'package:finance_client/features/mypage/screens/app_settings_screen.dart';
import 'package:finance_client/features/mypage/screens/home_display_settings_screen.dart';
import 'package:finance_client/features/mypage/screens/language_settings_screen.dart';
import 'package:finance_client/features/mypage/screens/money_format_settings_screen.dart';
import 'package:finance_client/features/mypage/widgets/app_settings_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mirrors how `FinanceApp` wires the theme and money format, without the
/// router.
class _TestApp extends ConsumerWidget {
  const _TestApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moneyFormat = ref.watch(moneyDisplayFormatProvider);
    return MaterialApp(
      theme: appTheme,
      darkTheme: appDarkTheme,
      themeMode: ref.watch(themeModeProvider),
      builder: (context, child) =>
          MoneyFormatScope(format: moneyFormat, child: child!),
      home: const AppSettingsScreen(),
    );
  }
}

class _FakeAuthenticator extends AppLockAuthenticator {
  final bool platformSupported;
  final bool biometrics;
  final AppLockAuthResult result;
  final List<String> reasons = [];

  _FakeAuthenticator({
    this.platformSupported = true,
    this.biometrics = true,
    this.result = AppLockAuthResult.success,
  });

  @override
  bool get isPlatformSupported => platformSupported;

  @override
  Future<bool> canUseBiometrics() async => biometrics;

  @override
  Future<AppLockAuthResult> authenticate(String reason) async {
    reasons.add(reason);
    return result;
  }
}

void main() {
  late SharedPreferences prefs;

  Future<void> pumpScreen(
    WidgetTester tester, {
    Map<String, Object> stored = const {},
    AppLockAuthenticator? authenticator,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(stored);
    prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appLockAuthenticatorProvider.overrideWithValue(
            authenticator ?? _FakeAuthenticator(),
          ),
        ],
        child: const _TestApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  // The page is painted by WalletBackground behind a transparent Scaffold,
  // so check which theme the screen actually resolved.
  Brightness scaffoldColor(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(Scaffold).last)).brightness;

  bool appLockToggleValue(WidgetTester tester) =>
      tester.widget<WalletToggle>(find.byType(WalletToggle)).value;

  testWidgets('shows the Frame 106 layout', (tester) async {
    await pumpScreen(tester);

    expect(find.text('앱 설정'), findsOneWidget);
    expect(find.text('테마 설정'), findsOneWidget);
    expect(find.text('라이트'), findsOneWidget);
    expect(find.text('다크'), findsOneWidget);
    expect(find.text('시스템'), findsOneWidget);
    expect(find.text('화면 표시'), findsOneWidget);
    expect(find.text('금액 표시 형식'), findsOneWidget);
    expect(find.text('123,456원'), findsOneWidget);
    expect(find.text('언어 설정'), findsOneWidget);
    expect(find.text('한국어'), findsOneWidget);
    expect(find.text('홈 화면 설정'), findsOneWidget);
    expect(find.text('홈 첫 화면 관리'), findsOneWidget);
    expect(find.text('기타'), findsOneWidget);
    expect(find.text('앱 잠금'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNWidgets(3));
    expect(find.text('아직 준비 중이에요.'), findsNothing);
  });

  group('테마 설정', () {
    testWidgets('defaults to light when nothing is saved', (tester) async {
      await pumpScreen(tester);

      expect(scaffoldColor(tester), Brightness.light);
    });

    testWidgets('selecting 다크 switches to the dark theme and saves it', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.tap(find.text('다크'));
      await tester.pumpAndSettle();

      expect(scaffoldColor(tester), Brightness.dark);
      expect(prefs.getString(ThemeModeNotifier.storageKey), 'dark');

      await tester.tap(find.text('라이트'));
      await tester.pumpAndSettle();

      expect(scaffoldColor(tester), Brightness.light);
      expect(prefs.getString(ThemeModeNotifier.storageKey), 'light');
    });

    testWidgets('시스템 follows the platform brightness', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await pumpScreen(tester);

      await tester.tap(find.text('시스템'));
      await tester.pumpAndSettle();

      expect(prefs.getString(ThemeModeNotifier.storageKey), 'system');
      expect(scaffoldColor(tester), Brightness.dark);

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();

      expect(scaffoldColor(tester), Brightness.light);
    });

    testWidgets('restores the saved choice on the next launch', (tester) async {
      await pumpScreen(tester, stored: {ThemeModeNotifier.storageKey: 'dark'});

      expect(scaffoldColor(tester), Brightness.dark);
    });
  });

  group('금액 표시 형식', () {
    testWidgets('choosing 간단하게 updates the preview, row and storage', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.tap(find.text('금액 표시 형식'));
      await tester.pumpAndSettle();
      expect(find.byType(MoneyFormatSettingsScreen), findsOneWidget);

      Text preview() => tester.widget<Text>(
        find.byKey(const ValueKey('money-format-preview')),
      );
      expect(preview().data, '1,234,567원');
      expect(find.text('정확하게 표시'), findsOneWidget);
      expect(find.text('간단하게 표시'), findsOneWidget);

      await tester.tap(find.text('간단하게 표시'));
      await tester.pumpAndSettle();

      expect(preview().data, '123.5만원');
      expect(prefs.getString(MoneyDisplayFormatNotifier.storageKey), 'compact');

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('12.3만원'), findsOneWidget);
    });

    testWidgets('a saved format is restored', (tester) async {
      await pumpScreen(
        tester,
        stored: {MoneyDisplayFormatNotifier.storageKey: 'compact'},
      );

      expect(find.text('12.3만원'), findsOneWidget);
    });
  });

  testWidgets('언어 설정 shows Korean only, with no other language to pick', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.text('언어 설정'));
    await tester.pumpAndSettle();

    expect(find.byType(LanguageSettingsScreen), findsOneWidget);
    expect(find.text('한국어'), findsOneWidget);
    expect(find.text(LanguageSettingsScreen.koreanOnlyMessage), findsOneWidget);
    expect(find.text('English'), findsNothing);
    expect(find.byType(AppSettingsChoiceCard), findsOneWidget);
  });

  testWidgets('홈 화면 설정 toggles Home sections and saves them', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('홈 화면 설정'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeDisplaySettingsScreen), findsOneWidget);

    List<bool> toggles() => tester
        .widgetList<WalletToggle>(find.byType(WalletToggle))
        .map((t) => t.value)
        .toList();
    expect(toggles(), [true, true]);

    await tester.tap(find.text('실시간 거래 내역'));
    await tester.pumpAndSettle();
    expect(toggles(), [false, true]);
    expect(
      prefs.getBool(HomeSectionVisibilityNotifier.recentTransactionsKey),
      false,
    );

    await tester.tap(find.byType(WalletToggle).last);
    await tester.pumpAndSettle();
    expect(toggles(), [false, false]);
    expect(prefs.getBool(HomeSectionVisibilityNotifier.regretReviewKey), false);

    await tester.tap(find.text('실시간 거래 내역'));
    await tester.pumpAndSettle();
    expect(toggles(), [true, false]);
  });

  group('앱 잠금', () {
    testWidgets('turns on only after a successful OS prompt', (tester) async {
      final auth = _FakeAuthenticator();
      await pumpScreen(tester, authenticator: auth);
      expect(appLockToggleValue(tester), isFalse);

      await tester.tap(find.byType(WalletToggle));
      await tester.pumpAndSettle();

      expect(auth.reasons, [AppLockEnabledNotifier.enableReason]);
      expect(appLockToggleValue(tester), isTrue);
      expect(prefs.getBool(AppLockEnabledNotifier.storageKey), isTrue);
      expect(find.text(AppSettingsScreen.appLockOnMessage), findsOneWidget);
    });

    testWidgets('stays off when the prompt fails', (tester) async {
      await pumpScreen(
        tester,
        authenticator: _FakeAuthenticator(result: AppLockAuthResult.failed),
      );

      await tester.tap(find.text('앱 잠금'));
      await tester.pumpAndSettle();

      expect(appLockToggleValue(tester), isFalse);
      expect(prefs.getBool(AppLockEnabledNotifier.storageKey), isNull);
      expect(find.text(AppSettingsScreen.appLockFailedMessage), findsOneWidget);
    });

    testWidgets('stays off without biometrics and says so', (tester) async {
      final auth = _FakeAuthenticator(biometrics: false);
      await pumpScreen(tester, authenticator: auth);

      await tester.tap(find.byType(WalletToggle));
      await tester.pumpAndSettle();

      expect(auth.reasons, isEmpty);
      expect(appLockToggleValue(tester), isFalse);
      expect(find.text(AppSettingsScreen.noBiometricsMessage), findsOneWidget);
    });

    testWidgets('turning off needs no prompt', (tester) async {
      final auth = _FakeAuthenticator();
      await pumpScreen(
        tester,
        authenticator: auth,
        stored: {AppLockEnabledNotifier.storageKey: true},
      );
      expect(appLockToggleValue(tester), isTrue);

      await tester.tap(find.byType(WalletToggle));
      await tester.pumpAndSettle();

      expect(auth.reasons, isEmpty);
      expect(appLockToggleValue(tester), isFalse);
      expect(prefs.getBool(AppLockEnabledNotifier.storageKey), isFalse);
    });

    testWidgets('is disabled with a notice where unsupported (web)', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        authenticator: _FakeAuthenticator(platformSupported: false),
        stored: {AppLockEnabledNotifier.storageKey: true},
      );

      final toggle = tester.widget<WalletToggle>(find.byType(WalletToggle));
      expect(toggle.onChanged, isNull);
      expect(toggle.value, isFalse);

      await tester.tap(find.text('앱 잠금'));
      await tester.pumpAndSettle();
      expect(find.text(AppSettingsScreen.webAppLockMessage), findsOneWidget);
    });
  });
}
