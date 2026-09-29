import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme.dart';
import 'core/router.dart';
import 'core/providers/current_date_provider.dart';
import 'core/services/notification_service.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/auth/providers/auth_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR', null);

  // Sync initial notification backend config to native Android
  if (!kIsWeb && Platform.isAndroid) {
    await NotificationService.updateConfig(
      baseUrl: 'http://10.0.2.2:4000',
    );
  }

  // Loaded before the first frame so the saved sign-in (자동 로그인) is known
  // when the router picks the start screen.
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
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

    return MaterialApp.router(
      title: 'Finance Client',
      theme: appTheme,
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
                color: appTheme.scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20),
                ],
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
