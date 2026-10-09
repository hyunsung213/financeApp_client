import 'package:dio/dio.dart';
import 'package:finance_client/data/api/api_error.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_backend.dart';

void main() {
  final request = RequestOptions(path: '/api/home');

  DioException responseError(int status, Map<String, Object?> body) => DioException.badResponse(
    statusCode: status,
    requestOptions: request,
    response: Response(requestOptions: request, statusCode: status, data: body),
  );

  Object thrown(Never Function(RequestOptions) failure) {
    try {
      failure(request);
    } catch (e) {
      return e;
    }
  }

  test('a refused connection reads as "server unreachable", without transport details', () {
    final message = userErrorMessage(thrown(connectionRefused));
    expect(message, '서버에 연결할 수 없습니다. 잠시 후 다시 시도해주세요.');
    for (final fragment in rawErrorFragments) {
      expect(message, isNot(contains(fragment)));
    }
  });

  test('a timeout gets its own message', () {
    expect(userErrorMessage(thrown(receiveTimeout)), '요청 시간이 초과되었습니다. 다시 시도해주세요.');
  });

  test('a 401 means the login expired', () {
    expect(
      userErrorMessage(responseError(401, {'error': {'message': 'Invalid or expired token'}})),
      '로그인이 만료되었습니다. 다시 로그인해주세요.',
    );
  });

  test("a 5xx is a temporary error, never the server's own text", () {
    final error = responseError(500, {'error': {'code': 'INTERNAL_ERROR', 'message': 'Internal server error'}});
    expect(userErrorMessage(error), '일시적인 오류가 발생했습니다. 잠시 후 다시 시도해주세요.');
    expect(apiErrorMessage(error), isNull);
  });

  test("a rejected request keeps the backend's user-facing message", () {
    final error = responseError(409, {'error': {'code': 'CATEGORY_IN_USE', 'message': '사용 중인 카테고리는 삭제할 수 없어요.'}});
    expect(userErrorMessage(error), '사용 중인 카테고리는 삭제할 수 없어요.');
    expect(userErrorMessage(responseError(400, {})), '일시적인 오류가 발생했습니다. 잠시 후 다시 시도해주세요.');
  });

  test('provider retry: none for auth, rejected or timed-out requests; two quick ones for network/5xx', () {
    expect(apiRetry(0, responseError(401, {})), isNull);
    expect(apiRetry(0, responseError(400, {})), isNull);
    expect(apiRetry(0, thrown(receiveTimeout)), isNull);

    final refused = thrown(connectionRefused);
    expect(apiRetry(0, refused), const Duration(seconds: 1));
    expect(apiRetry(1, refused), const Duration(seconds: 2));
    expect(apiRetry(2, refused), isNull);
    expect(apiRetry(2, responseError(503, {})), isNull);
  });
}
