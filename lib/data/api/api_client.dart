import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/app_config.dart';
import '../demo/demo_backend_adapter.dart';

final apiClientProvider = Provider<Dio>((ref) {
  return ApiClient.create();
});

class ApiClient {
  static Dio create() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    // DEMO_MODE answers every request in the browser from sample data, so
    // the public demo never reaches (or needs) a backend.
    if (AppConfig.demoMode) {
      dio.httpClientAdapter = DemoBackendAdapter();
    }

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // The backend identifies the user from this token alone (it never
          // trusts a userId in the request). Without Supabase configured
          // (local dev) no header is sent and the backend must be running
          // with DEV_AUTH_BYPASS=true.
          final token = await _accessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          // You can parse success flag here if you want globally
          return handler.next(response);
        },
        onError: (DioException e, handler) {
          // Custom error wrapper could be added here
          return handler.next(e);
        },
      ),
    );

    return dio;
  }

  /// The current session's access token, refreshed first if it has expired
  /// (supabase_flutter normally refreshes in the background; this covers a
  /// request fired right after the app resumes).
  static Future<String?> _accessToken() async {
    if (!AppConfig.authConfigured) return null;
    final auth = Supabase.instance.client.auth;
    var session = auth.currentSession;
    if (session != null && session.isExpired) {
      try {
        session = (await auth.refreshSession()).session;
      } catch (_) {
        // Keep the expired token: the backend answers 401 and the user is
        // asked to sign in again, instead of failing silently here.
      }
    }
    return session?.accessToken;
  }
}
