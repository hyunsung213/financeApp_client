import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final apiClientProvider = Provider<Dio>((ref) {
  return ApiClient.create();
});

class ApiClient {
  static Dio create() {
    // 10.0.2.2 for Android Emulator, localhost for iOS/Web/Desktop
    String baseUrl = 'http://localhost:4000';
    try {
      if (Platform.isAndroid) {
        baseUrl = 'http://10.0.2.2:4000';
      }
    } catch (_) {
      // Platform.isAndroid throws in Web environment
    }

    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
        },
      ),
    );

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
