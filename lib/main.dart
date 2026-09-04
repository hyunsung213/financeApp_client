import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme.dart';
import 'core/router.dart';
import 'core/services/notification_service.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR', null);

  // Sync initial notification backend config to native Android
  if (!kIsWeb && Platform.isAndroid) {
    await NotificationService.updateConfig(
      baseUrl: 'http://10.0.2.2:4000',
    );
  }

  runApp(const ProviderScope(child: FinanceApp()));
}

class NoOverscrollBehavior extends ScrollBehavior {
  const NoOverscrollBehavior();
  
  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

class FinanceApp extends ConsumerWidget {
  const FinanceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
