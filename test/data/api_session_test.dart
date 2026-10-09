import 'package:dio/dio.dart';
import 'package:finance_client/data/api/api_client.dart';
import 'package:finance_client/data/api/api_error.dart';
import 'package:finance_client/features/auth/providers/auth_provider.dart';
import 'package:finance_client/features/home/providers/home_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_backend.dart';

void main() {
  group('SessionInterceptor', () {
    late FakeBackend backend;
    late FakeSession session;
    late int expired;
    late Dio dio;

    void build() {
      expired = 0;
      dio = ApiClient.create(
        session: session,
        onSessionExpired: () => expired++,
        adapter: backend,
      );
    }

    test('a 401 whose refresh is refused ends the session once and is not retried', () async {
      backend = FakeBackend((_) async => unauthorized());
      session = FakeSession(onRefresh: (_) => SessionRefreshResult.rejected);
      build();

      await expectLater(dio.get('/api/home'), throwsA(isA<DioException>()));

      expect(backend.count('/api/home'), 1);
      expect(session.refreshCalls, 1);
      expect(expired, 1);
    });

    test('a 401 with a refreshable session is retried once with the new token', () async {
      backend = FakeBackend(
        (r) async => r.headers['Authorization'] == 'Bearer token-2'
            ? ok({'today': {}})
            : unauthorized(),
      );
      session = FakeSession(
        onRefresh: (s) {
          s.token = 'token-2';
          return SessionRefreshResult.refreshed;
        },
      );
      build();

      final response = await dio.get('/api/home');

      expect(response.statusCode, 200);
      expect(backend.authorizations, [
        'Bearer token-1',
        'Bearer token-2',
      ]);
      expect(expired, 0);
    });

    test('a second 401 right after a successful refresh ends the session: at most one retry', () async {
      backend = FakeBackend((_) async => unauthorized());
      var n = 1;
      session = FakeSession(
        onRefresh: (s) {
          s.token = 'token-${++n}';
          return SessionRefreshResult.refreshed;
        },
      );
      build();

      await expectLater(dio.get('/api/home'), throwsA(isA<DioException>()));

      expect(backend.count('/api/home'), 2);
      expect(session.refreshCalls, 1);
      expect(expired, 1);
    });

    test('concurrent 401s share one refresh', () async {
      backend = FakeBackend((_) async => unauthorized());
      session = FakeSession(onRefresh: (_) => SessionRefreshResult.rejected);
      build();

      await Future.wait([
        for (final path in ['/api/home', '/api/transactions', '/api/categories'])
          dio.get(path).then((_) {}, onError: (_) {}),
      ]);

      expect(session.refreshCalls, 1);
      expect(backend.requests, hasLength(3));
    });

    test('an unreachable auth server does not sign the user out', () async {
      backend = FakeBackend((_) async => unauthorized());
      session = FakeSession(onRefresh: (_) => SessionRefreshResult.unavailable);
      build();

      await expectLater(dio.get('/api/home'), throwsA(isA<DioException>()));
      expect(expired, 0);
    });

    test('network errors, timeouts and 5xx never touch the session', () async {
      session = FakeSession(onRefresh: (_) => fail('refresh must not be called'));
      for (final failure in <Future<ResponseBody> Function(RequestOptions)>[
        (r) async => connectionRefused(r),
        (r) async => receiveTimeout(r),
        (r) async => jsonBody(500, {
          'success': false,
          'error': {'code': 'INTERNAL_ERROR', 'message': 'Internal server error'},
        }),
      ]) {
        backend = FakeBackend(failure);
        build();
        await expectLater(dio.get('/api/home'), throwsA(isA<DioException>()));
        expect(backend.count('/api/home'), 1);
        expect(expired, 0);
      }
    });

    test('without a session no request is sent', () async {
      backend = FakeBackend((_) async => ok({}));
      session = FakeSession(token: null);
      build();

      final error = await dio.get('/api/home').then<Object?>((_) => null, onError: (Object e) => e);

      expect(backend.requests, isEmpty);
      expect(ApiFailure.from(error!).kind, ApiFailureKind.unauthorized);
    });
  });

  group('protected providers', () {
    late FakeBackend backend;

    ProviderContainer containerFor(FakeSession session) {
      final container = ProviderContainer(
        retry: apiRetry,
        overrides: [
          authProvider.overrideWith(SignedInAuth.new),
          apiClientProvider.overrideWith(
            (ref) => ApiClient.create(
              session: session,
              onSessionExpired: ref.read(authProvider.notifier).expireSession,
              adapter: backend,
            ),
          ),
        ],
      );
      return container;
    }

    testWidgets('a 401 on a protected API signs out once and does not keep requesting', (tester) async {
      backend = FakeBackend((_) async => unauthorized());
      final container = containerFor(
        FakeSession(onRefresh: (_) => SessionRefreshResult.rejected),
      );
      container.listen(homeDataProvider, (_, _) {});

      // Far longer than Riverpod's default retry would keep going (~38s).
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      expect(backend.count('/api/home'), 1);
      final auth = container.read(authProvider);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.user, isNull);
      expect(auth.sessionExpired, isTrue);
      container.dispose();
    });

    testWidgets('a 401 that cannot be resolved yet is not retried by the provider', (tester) async {
      backend = FakeBackend((_) async => unauthorized());
      final container = containerFor(
        FakeSession(onRefresh: (_) => SessionRefreshResult.unavailable),
      );
      container.listen(homeDataProvider, (_, _) {});

      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      expect(backend.count('/api/home'), 1);
      expect(container.read(homeDataProvider).hasError, isTrue);
      container.dispose();
    });

    testWidgets('a network error keeps the user signed in and stops after two retries', (tester) async {
      backend = FakeBackend((r) async => connectionRefused(r));
      final container = containerFor(FakeSession());
      container.listen(homeDataProvider, (_, _) {});

      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      expect(backend.count('/api/home'), 3);
      expect(container.read(homeDataProvider).hasError, isTrue);
      expect(container.read(authProvider).isAuthenticated, isTrue);
      expect(container.read(authProvider).sessionExpired, isFalse);
      container.dispose();
    });
  });
}
