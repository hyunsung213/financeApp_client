import 'package:dio/dio.dart';
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
      throw Exception(response.data['error']['message'] ?? 'Failed to get finance setting');
    }
  }

  Future<void> updateSetting({
    required int salaryAmount,
    required int salaryDay,
    required int reportingStartDay,
  }) async {
    final response = await _dio.put('/api/finance/setting', data: {
      'salaryAmount': salaryAmount,
      'salaryDay': salaryDay,
      'reportingStartDay': reportingStartDay,
    });
    if (response.data['success'] != true) {
      throw Exception(response.data['error']['message'] ?? 'Failed to update finance setting');
    }
  }

  Future<List<dynamic>> getAllocations() async {
    final response = await _dio.get('/api/finance/allocations');
    if (response.data['success'] == true) {
      return response.data['data'];
    } else {
      throw Exception(response.data['error']['message'] ?? 'Failed to get allocations');
    }
  }

  Future<Map<String, dynamic>> createAllocation({
    required String name,
    required String allocationType,
    required double percentage,
    required String spendability,
    required bool active,
  }) async {
    final response = await _dio.post('/api/finance/allocations', data: {
      'name': name,
      'allocationType': allocationType,
      'percentage': percentage,
      'spendability': spendability,
      'active': active,
    });
    if (response.data['success'] == true) {
      return response.data['data'];
    } else {
      throw Exception(response.data['error']['message'] ?? 'Failed to create allocation');
    }
  }

  Future<void> updateAllocation(String id, {
    double? percentage,
    bool? active,
  }) async {
    final data = <String, dynamic>{};
    if (percentage != null) data['percentage'] = percentage;
    if (active != null) data['active'] = active;

    final response = await _dio.patch('/api/finance/allocations/$id', data: data);
    if (response.data['success'] != true) {
      throw Exception(response.data['error']['message'] ?? 'Failed to update allocation');
    }
  }
}
