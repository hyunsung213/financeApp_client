import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';

final transactionApiProvider = Provider<TransactionApi>((ref) {
  return TransactionApi(ref.watch(apiClientProvider));
});

class TransactionApi {
  final Dio _dio;

  TransactionApi(this._dio);

  Future<Map<String, dynamic>> getTransactions({
    String? startDate,
    String? endDate,
    String? categoryId,
    String? type,
    String? status,
    int page = 1,
    int limit = 50,
  }) async {
    final queryParameters = <String, dynamic>{
      'page': page,
      'limit': limit,
    };
    if (startDate != null) queryParameters['startDate'] = startDate;
    if (endDate != null) queryParameters['endDate'] = endDate;
    if (categoryId != null) queryParameters['categoryId'] = categoryId;
    if (type != null) queryParameters['type'] = type;
    if (status != null) queryParameters['status'] = status;

    final response = await _dio.get('/api/transactions', queryParameters: queryParameters);
    if (response.data['success'] == true) {
      return response.data['data'];
    } else {
      throw Exception(response.data['error']['message'] ?? 'Failed to get transactions');
    }
  }

  Future<Map<String, dynamic>> getTransaction(String id) async {
    final response = await _dio.get('/api/transactions/$id');
    if (response.data['success'] == true) {
      return response.data['data'];
    } else {
      throw Exception(response.data['error']['message'] ?? 'Failed to get transaction');
    }
  }

  Future<Map<String, dynamic>> createTransaction({
    required String categoryId,
    required String type,
    required int amount,
    required String occurredAt,
    required String merchantOrTitle,
    String? memo,
    required String source,
    required String status,
  }) async {
    final response = await _dio.post('/api/transactions', data: {
      'categoryId': categoryId,
      'type': type,
      'amount': amount,
      'occurredAt': occurredAt,
      'merchantOrTitle': merchantOrTitle,
      if (memo != null) 'memo': memo,
      'source': source,
      'status': status,
    });
    if (response.data['success'] == true) {
      return response.data['data'];
    } else {
      throw Exception(response.data['error']['message'] ?? 'Failed to create transaction');
    }
  }

  Future<void> updateTransaction(String id, {
    int? amount,
    String? memo,
    String? status,
  }) async {
    final data = <String, dynamic>{};
    if (amount != null) data['amount'] = amount;
    if (memo != null) data['memo'] = memo;
    if (status != null) data['status'] = status;

    final response = await _dio.patch('/api/transactions/$id', data: data);
    if (response.data['success'] != true) {
      throw Exception(response.data['error']['message'] ?? 'Failed to update transaction');
    }
  }

  Future<void> deleteTransaction(String id) async {
    final response = await _dio.delete('/api/transactions/$id');
    if (response.data['success'] != true) {
      throw Exception(response.data['error']['message'] ?? 'Failed to delete transaction');
    }
  }
}
