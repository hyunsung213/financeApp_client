import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/branding/wallet_brand.dart';
import 'core/app_lock/app_lock_gate.dart';
import 'core/config/app_config.dart';
import 'core/format/money_format.dart';
import 'core/theme.dart';
import 'core/router.dart';
import 'core/providers/current_date_provider.dart';
import 'core/providers/theme_mode_provider.dart';
import 'core/services/notification_service.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/auth/providers/auth_provider.dart';
import 'data/api/api_error.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR', null);

  // Restores the saved Supabase session (if any) before the router picks the
  // start screen; `AuthNotifier` then follows every auth change.
  if (AppConfig.authConfigured) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );
  }

  // Sync initial notification backend config (and the current access token,
  // which the native sync worker sends as a Bearer token) to native Android.
  if (!kIsWeb && Platform.isAndroid) {
    await NotificationService.updateConfig(
      baseUrl: AppConfig.apiBaseUrl,
      authToken: AppConfig.authConfigured
          ? Supabase.instance.client.auth.currentSession?.accessToken
          : null,
    );
  }

  // Loaded before the first frame so the saved sign-in (자동 로그인) is known
  // when the router picks the start screen.
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      // Failed backend calls are not retried in a loop (see apiRetry).
      retry: apiRetry,
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const FinanceApp(),
    ),
  );
}

class NoOverscrollBehavior extends ScrollBehavior {
  const NoOverscrollBehavior();
  
  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

class FinanceApp extends ConsumerStatefulWidget {
  const FinanceApp({super.key});

  @override
  ConsumerState<FinanceApp> createState() => _FinanceAppState();
}

class _FinanceAppState extends ConsumerState<FinanceApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App date pill / D-Day can otherwise stay stuck at whatever date was
    // current when the app was backgrounded, since Home has no other
    // trigger to rebuild once its data has loaded (see
    // core/providers/current_date_provider.dart).
    if (state == AppLifecycleState.resumed) {
      ref.read(currentDateProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final moneyFormat = ref.watch(moneyDisplayFormatProvider);

    return MaterialApp.router(
      // Browser tab title on the web, task title in Android's recents.
      title: WalletBrand.name,
      theme: appTheme,
      darkTheme: appDarkTheme,
      themeMode: ref.watch(themeModeProvider),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      scrollBehavior: const NoOverscrollBehavior(),
      builder: (context, child) {
        return Container(
          color: Colors.black12, // Background for outside the phone area
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 430), // Pro Max width approx
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20),
                ],
              ),
              // Report the phone column's size as the screen size, so layouts
              // that read MediaQuery (e.g. the draggable manual-input button)
              // stay inside it on a wide desktop browser. On a phone the
              // column is the whole screen and nothing changes.
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final media = MediaQuery.of(context);
                  return MediaQuery(
                    data: media.copyWith(
                      size: Size(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      ),
                    ),
                    child: MoneyFormatScope(
                      format: moneyFormat,
                      child: AppLockGate(child: child!),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
