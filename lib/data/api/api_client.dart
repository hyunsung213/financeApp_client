import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
          // TODO: Use real Supabase token when Supabase is initialized.
          // For now, backend is configured to accept requests without Authorization header for development.
          // options.headers['Authorization'] = 'Bearer mock-jwt-token';
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
}
