import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';

final reportApiProvider = Provider<ReportApi>((ref) {
  return ReportApi(ref.watch(apiClientProvider));
});

class ReportApi {
  final Dio _dio;

  ReportApi(this._dio);

  Future<Map<String, dynamic>> getSummary({String? startDate, String? endDate}) async {
    final queryParameters = <String, dynamic>{};
    if (startDate != null) queryParameters['startDate'] = startDate;
    if (endDate != null) queryParameters['endDate'] = endDate;

    final response = await _dio.get('/api/reports/summary', queryParameters: queryParameters);
    if (response.data['success'] == true) {
      return response.data['data'];
    } else {
      throw Exception(response.data['error']['message'] ?? 'Failed to get report summary');
    }
  }

  /// Returns `{ period: {startDate,endDate}, summary: {totalIncome,totalExpense,noSpendDays,noActivityDays}, daily: [{date,income,expense,spent,recommended,difference}] }`.
  Future<Map<String, dynamic>> getDaily({String? startDate, String? endDate}) async {
    final queryParameters = <String, dynamic>{};
    if (startDate != null) queryParameters['startDate'] = startDate;
    if (endDate != null) queryParameters['endDate'] = endDate;

    final response = await _dio.get('/api/reports/daily', queryParameters: queryParameters);
    if (response.data['success'] == true) {
      return response.data['data'];
    } else {
      throw Exception(response.data['error']['message'] ?? 'Failed to get daily report');
    }
  }

  Future<List<dynamic>> getMonthly() async {
    final response = await _dio.get('/api/reports/monthly');
    if (response.data['success'] == true) {
      return response.data['data'];
    } else {
      throw Exception(response.data['error']['message'] ?? 'Failed to get monthly report');
    }
  }

  Future<List<dynamic>> getCategories({String? startDate, String? endDate}) async {
    final queryParameters = <String, dynamic>{};
    if (startDate != null) queryParameters['startDate'] = startDate;
    if (endDate != null) queryParameters['endDate'] = endDate;

    final response = await _dio.get('/api/reports/categories', queryParameters: queryParameters);
    if (response.data['success'] == true) {
      return response.data['data'];
    } else {
      throw Exception(response.data['error']['message'] ?? 'Failed to get categories report');
    }
  }

  Future<Map<String, dynamic>> getPace() async {
    final response = await _dio.get('/api/reports/pace');
    if (response.data['success'] == true) {
      return response.data['data'];
    } else {
      throw Exception(response.data['error']['message'] ?? 'Failed to get pace report');
    }
  }
}
