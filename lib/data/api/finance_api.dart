import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';

final financeApiProvider = Provider<FinanceApi>((ref) {
  return FinanceApi(ref.watch(apiClientProvider));
});

class FinanceApi {
  final Dio _dio;

  FinanceApi(this._dio);

  Future<Map<String, dynamic>> getSetting() async {
    final response = await _dio.get('/api/finance/setting');
    if (response.data['success'] == true) {
      return response.data['data'];
    } else {
      throw Exception(
        response.data['error']['message'] ?? 'Failed to get finance setting',
      );
    }
  }

  Future<void> updateSetting({
    required int salaryAmount,
    required int salaryDay,
    required int reportingStartDay,
  }) async {
    final response = await _dio.put(
      '/api/finance/setting',
      data: {
        'salaryAmount': salaryAmount,
        'salaryDay': salaryDay,
        'reportingStartDay': reportingStartDay,
      },
    );
    if (response.data['success'] != true) {
      throw Exception(
        response.data['error']['message'] ?? 'Failed to update finance setting',
      );
    }
  }

  /// The user's 12-item budget plan (저축/투자 + 10 지출 대분류), each item
  /// `{categoryId, name, percentage}`. `isConfigured` is false while the
  /// backend is still serving its default plan.
  Future<Map<String, dynamic>> getBudgetPlan() async {
    final response = await _dio.get('/api/finance/budget-plan');
    if (response.data['success'] == true) {
      return Map<String, dynamic>.from(response.data['data']);
    } else {
      throw Exception(
        response.data['error']['message'] ?? 'Failed to get budget plan',
      );
    }
  }

  /// Replaces the whole plan in one request (the backend validates 12 items
  /// totalling 100%). Returns `effectiveFrom` (`CURRENT_CYCLE`: the
  /// active salary cycle is re-budgeted immediately).
  Future<Map<String, dynamic>> updateBudgetPlan(
    List<Map<String, dynamic>> allocations,
  ) async {
    if (kDebugMode) {
      final total = allocations.fold<num>(
        0,
        (sum, a) => sum + ((a['percentage'] as num?) ?? 0),
      );
      debugPrint(
        '[budget-plan] PUT sending ${allocations.length} items, total $total%',
      );
    }
    final Response response;
    try {
      response = await _dio.put(
        '/api/finance/budget-plan',
        data: {'allocations': allocations},
      );
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[budget-plan] PUT failed status=${e.response?.statusCode} body=${e.response?.data}',
        );
      }
      rethrow;
    }
    if (kDebugMode) {
      final saved = (response.data['data']?['allocations'] as List?)
          ?.map((a) => '${a['name']}:${a['percentage']}')
          .join(', ');
      debugPrint(
        '[budget-plan] PUT status=${response.statusCode} saved=[$saved]',
      );
    }
    if (response.data['success'] == true) {
      return Map<String, dynamic>.from(response.data['data']);
    } else {
      throw Exception(
        response.data['error']['message'] ?? 'Failed to update budget plan',
      );
    }
  }
}
