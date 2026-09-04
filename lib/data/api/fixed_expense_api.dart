import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';

final fixedExpenseApiProvider = Provider<FixedExpenseApi>((ref) {
  return FixedExpenseApi(ref.watch(apiClientProvider));
});

class FixedExpenseApi {
  final Dio _dio;

  FixedExpenseApi(this._dio);

  Future<Map<String, dynamic>> getFixedExpenses() async {
    final response = await _dio.get('/api/fixed-expenses');
    if (response.data['success'] == true) {
      return response.data['data'];
    } else {
      throw Exception(response.data['error']['message'] ?? 'Failed to get fixed expenses');
    }
  }

  Future<Map<String, dynamic>> createFixedExpense({
    required String categoryId,
    required String name,
    required int expectedAmount,
    required int billingDay,
    required String recurrenceType,
    required String startDate,
    required String endDate,
  }) async {
    final response = await _dio.post('/api/fixed-expenses', data: {
      'categoryId': categoryId,
      'name': name,
      'expectedAmount': expectedAmount,
      'billingDay': billingDay,
      'recurrenceType': recurrenceType,
      'startDate': startDate,
      'endDate': endDate,
    });
    if (response.data['success'] == true) {
      return response.data['data'];
    } else {
      throw Exception(response.data['error']['message'] ?? 'Failed to create fixed expense');
    }
  }

  Future<void> matchOccurrence(String occurrenceId, String transactionId) async {
    final response = await _dio.post('/api/fixed-expenses/occurrences/$occurrenceId/match', data: {
      'transactionId': transactionId,
    });
    if (response.data['success'] != true) {
      throw Exception(response.data['error']['message'] ?? 'Failed to match occurrence');
    }
  }
}
