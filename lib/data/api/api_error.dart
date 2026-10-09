import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The user-facing message the backend put in its error envelope
/// (`{ success: false, error: { code, message } }`), or null when [error]
/// isn't a backend error response, so callers can fall back to their own text
/// instead of showing a raw `DioException [bad response]...` dump. A 5xx's
/// message ("Internal server error") is not for users and gives null too.
String? apiErrorMessage(Object error) {
  if (error is! DioException) return null;
  if ((error.response?.statusCode ?? 0) >= 500) return null;
  final data = error.response?.data;
  if (data is! Map) return null;
  final message = (data['error'] is Map ? (data['error'] as Map)['message'] : null)?.toString().trim();
  return message == null || message.isEmpty ? null : message;
}

/// Carried by the [DioException] of a backend call attempted while signed
/// out: every backend route needs a Bearer token, so the call is not sent.
class ApiSessionMissing implements Exception {
  const ApiSessionMissing();

  @override
  String toString() => 'ApiSessionMissing';
}

enum ApiFailureKind { network, timeout, unauthorized, server, validation, unknown }

/// What went wrong with a backend call, in the terms the UI cares about.
///
/// Screens show [userMessage], never the error itself: a [DioException]'s text
/// carries the host, port and socket details. The API client logs the full
/// exception in debug builds instead.
class ApiFailure {
  const ApiFailure(this.kind, {this.serverMessage});

  final ApiFailureKind kind;

  /// The backend's own message for a rejected request (a 4xx other than 401).
  final String? serverMessage;

  factory ApiFailure.from(Object error) {
    if (error is! DioException) return const ApiFailure(ApiFailureKind.unknown);
    if (error.error is ApiSessionMissing) {
      return const ApiFailure(ApiFailureKind.unauthorized);
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiFailure(ApiFailureKind.timeout);
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
        return const ApiFailure(ApiFailureKind.network);
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode ?? 0;
        if (status == 401) return const ApiFailure(ApiFailureKind.unauthorized);
        if (status >= 500) return const ApiFailure(ApiFailureKind.server);
        if (status >= 400) {
          return ApiFailure(ApiFailureKind.validation, serverMessage: apiErrorMessage(error));
        }
        return const ApiFailure(ApiFailureKind.unknown);
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        return const ApiFailure(ApiFailureKind.unknown);
    }
  }

  String get userMessage => switch (kind) {
    ApiFailureKind.network => '서버에 연결할 수 없습니다. 잠시 후 다시 시도해주세요.',
    ApiFailureKind.timeout => '요청 시간이 초과되었습니다. 다시 시도해주세요.',
    ApiFailureKind.unauthorized => '로그인이 만료되었습니다. 다시 로그인해주세요.',
    ApiFailureKind.validation when serverMessage != null => serverMessage!,
    _ => '일시적인 오류가 발생했습니다. 잠시 후 다시 시도해주세요.',
  };
}

/// The text to show for any error from a backend call.
String userErrorMessage(Object error) => ApiFailure.from(error).userMessage;

/// Riverpod's automatic retry of failed providers, set on the app's
/// [ProviderScope].
///
/// Riverpod's default retries every exception up to 10 times, backing off to
/// 6.4s, which turned a 401 into a request every few seconds. Here a rejected
/// request (401 or another 4xx) or a timeout is not retried at all, and a
/// connection failure or 5xx gets two quick retries for a momentary blip;
/// after that the screen shows its error and the user retries. Errors that
/// aren't from a backend call keep the default.
Duration? apiRetry(int retryCount, Object error) {
  if (error is! DioException) {
    return ProviderContainer.defaultRetry(retryCount, error);
  }
  switch (ApiFailure.from(error).kind) {
    case ApiFailureKind.network:
    case ApiFailureKind.server:
      return retryCount < 2 ? Duration(seconds: 1 << retryCount) : null;
    case ApiFailureKind.timeout:
    case ApiFailureKind.unauthorized:
    case ApiFailureKind.validation:
    case ApiFailureKind.unknown:
      return null;
  }
}
