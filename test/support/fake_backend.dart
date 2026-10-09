import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:finance_client/data/api/api_client.dart';
import 'package:finance_client/data/mocks/db.dart';
import 'package:finance_client/features/auth/providers/auth_provider.dart';

/// A backend scripted per test: [handler] answers each request (or throws the
/// [DioException] a real transport failure would), and every request that
/// reached the "network" is recorded.
class FakeBackend implements HttpClientAdapter {
  FakeBackend(this.handler);

  Future<ResponseBody> Function(RequestOptions request) handler;
  final List<RequestOptions> requests = [];

  /// The Authorization header of each request as it was sent (a retry reuses
  /// and updates the same [RequestOptions]).
  final List<Object?> authorizations = [];

  int count(String path) => requests.where((r) => r.path == path).length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    authorizations.add(options.headers['Authorization']);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(int status, Object body) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

ResponseBody ok(Object data) => jsonBody(200, {'success': true, 'data': data});

ResponseBody unauthorized() => jsonBody(401, {
  'success': false,
  'error': {'code': 'UNAUTHORIZED', 'message': 'Invalid or expired token'},
});

/// What the Android emulator gets while the local backend is down.
Never connectionRefused(RequestOptions request) => throw DioException.connectionError(
  requestOptions: request,
  reason: 'Connection refused',
  error:
      'SocketException: Connection refused (OS Error: Connection refused, '
      'errno = 111), address = 10.0.2.2, port = 43120',
);

Never receiveTimeout(RequestOptions request) => throw DioException.receiveTimeout(
  timeout: const Duration(seconds: 10),
  requestOptions: request,
);

/// Raw transport details that must never reach the screen.
const rawErrorFragments = [
  'DioException',
  'SocketException',
  'Connection refused',
  '10.0.2.2',
  'errno',
];

/// A session whose token and refresh outcome each test controls.
class FakeSession implements ApiSession {
  FakeSession({this.token = 'token-1', this.onRefresh});

  String? token;
  SessionRefreshResult Function(FakeSession session)? onRefresh;
  int refreshCalls = 0;

  @override
  Future<String?> accessToken() async => token;

  @override
  Future<SessionRefreshResult> refresh() async {
    refreshCalls++;
    await Future<void>.delayed(Duration.zero);
    return onRefresh?.call(this) ?? SessionRefreshResult.rejected;
  }
}

/// Signed in as a fixed user, without Supabase or SharedPreferences.
class SignedInAuth extends AuthNotifier {
  @override
  AuthState build() => AuthState(
    isAuthenticated: true,
    user: MockUser(id: 'user-1', email: 'user@example.com', name: 'user'),
  );
}
