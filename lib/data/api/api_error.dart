import 'package:dio/dio.dart';

/// The user-facing message the backend put in its error envelope
/// (`{ success: false, error: { code, message } }`), or null when [error]
/// isn't a backend error response, so callers can fall back to their own text
/// instead of showing a raw `DioException [bad response]...` dump.
String? apiErrorMessage(Object error) {
  if (error is! DioException) return null;
  final data = error.response?.data;
  if (data is! Map) return null;
  final message = (data['error'] is Map ? (data['error'] as Map)['message'] : null)?.toString().trim();
  return message == null || message.isEmpty ? null : message;
}
