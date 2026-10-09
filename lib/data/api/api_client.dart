import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/app_config.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../demo/demo_backend_adapter.dart';
import 'api_error.dart';

final apiClientProvider = Provider<Dio>((ref) {
  // One client per signed-in user: signing out (or in as someone else)
  // rebuilds every API-backed provider, so nothing cached for one session
  // outlives it.
  ref.watch(authProvider.select((s) => s.user?.id));
  final auth = ref.read(authProvider.notifier);
  final dio = ApiClient.create(
    session: AppConfig.authConfigured ? const SupabaseApiSession() : null,
    onSessionExpired: auth.expireSession,
  );
  ref.onDispose(dio.close);
  return dio;
});

class ApiClient {
  /// Without a [session] (local dev without Supabase) no token is sent and
  /// the backend must be running with DEV_AUTH_BYPASS=true.
  static Dio create({
    ApiSession? session,
    void Function()? onSessionExpired,
    HttpClientAdapter? adapter,
  }) {
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
    if (adapter != null) dio.httpClientAdapter = adapter;

    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException e, handler) {
          _logFailure(e);
          return handler.next(e);
        },
      ),
    );
    if (session != null) {
      dio.interceptors.add(
        SessionInterceptor(
          dio: dio,
          session: session,
          onSessionExpired: onSessionExpired ?? () {},
        ),
      );
    }

    return dio;
  }

  /// Diagnostics for developers only: the method, path and what failed. The
  /// headers (Bearer token) and bodies are never printed.
  static void _logFailure(DioException e) {
    if (!kDebugMode) return;
    final request = e.requestOptions;
    final status = e.response?.statusCode;
    final data = e.response?.data;
    final code = data is Map && data['error'] is Map
        ? (data['error'] as Map)['code']
        : null;
    final detail = status != null
        ? 'HTTP $status${code != null ? ' $code' : ''}'
        : '${e.type.name}${e.error != null ? ': ${e.error}' : ''}';
    debugPrint('[api] ${request.method} ${request.path} failed: $detail');
  }
}

enum SessionRefreshResult {
  /// A new access token is in place.
  refreshed,

  /// The auth server refused the session: it has to be signed in again.
  rejected,

  /// The auth server couldn't be reached; the session may still be valid.
  unavailable,

  /// There is no session (signed out meanwhile); nothing to refresh.
  signedOut,
}

/// The sign-in session as the API client sees it: Supabase in the app, a fake
/// in tests.
abstract class ApiSession {
  /// The current access token, or null when signed out.
  Future<String?> accessToken();

  /// Gets a new access token after the backend rejected the current one.
  Future<SessionRefreshResult> refresh();
}

class SupabaseApiSession implements ApiSession {
  const SupabaseApiSession();

  GoTrueClient get _auth => Supabase.instance.client.auth;

  /// Refreshed first if it has expired (supabase_flutter normally refreshes
  /// in the background; this covers a request fired right after the app
  /// resumes).
  @override
  Future<String?> accessToken() async {
    var session = _auth.currentSession;
    if (session != null && session.isExpired) {
      try {
        session = (await _auth.refreshSession()).session;
      } catch (_) {
        // Keep the expired token: the backend answers 401 and
        // SessionInterceptor decides whether to sign out.
      }
    }
    return session?.accessToken;
  }

  @override
  Future<SessionRefreshResult> refresh() async {
    if (_auth.currentSession == null) return SessionRefreshResult.signedOut;
    try {
      final session = (await _auth.refreshSession()).session;
      return session == null
          ? SessionRefreshResult.rejected
          : SessionRefreshResult.refreshed;
    } on AuthRetryableFetchException {
      return SessionRefreshResult.unavailable;
    } on AuthException {
      // Supabase has already removed the local session (signedOut event).
      return SessionRefreshResult.rejected;
    } catch (_) {
      return SessionRefreshResult.unavailable;
    }
  }
}

/// Sends the session's access token with every request and handles the
/// backend rejecting it (401):
///
/// - a token that changed since the request was sent is retried as is;
/// - otherwise the session is refreshed once (shared by concurrent 401s) and
///   the request retried once with the new token;
/// - a refresh the auth server refuses, or a second 401 right after a
///   refresh, ends the session through [onSessionExpired].
///
/// Each request is retried at most once, so a dead session can never loop.
/// Network errors, timeouts and 5xx pass through untouched: they say nothing
/// about the session.
class SessionInterceptor extends Interceptor {
  SessionInterceptor({
    required this.dio,
    required this.session,
    required this.onSessionExpired,
  });

  final Dio dio;
  final ApiSession session;
  final void Function() onSessionExpired;

  static const _retriedKey = 'session.retried';

  Future<SessionRefreshResult>? _refreshing;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // The backend identifies the user from this token alone (it never trusts
    // a userId in the request).
    final token = await session.accessToken();
    if (token == null) {
      return handler.reject(
        DioException(requestOptions: options, error: const ApiSessionMissing()),
      );
    }
    options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401) return handler.next(err);

    final request = err.requestOptions;
    if (request.extra[_retriedKey] == true) {
      onSessionExpired();
      return handler.next(err);
    }

    final current = await session.accessToken();
    final refreshedMeanwhile =
        current != null && request.headers['Authorization'] != 'Bearer $current';
    if (!refreshedMeanwhile) {
      final result = await (_refreshing ??= session.refresh().whenComplete(
        () => _refreshing = null,
      ));
      switch (result) {
        case SessionRefreshResult.refreshed:
          break;
        case SessionRefreshResult.rejected:
          onSessionExpired();
          return handler.next(err);
        case SessionRefreshResult.unavailable:
        case SessionRefreshResult.signedOut:
          return handler.next(err);
      }
    }

    request.extra[_retriedKey] = true;
    try {
      return handler.resolve(await dio.fetch(request));
    } on DioException catch (retryError) {
      return handler.next(retryError);
    }
  }
}
