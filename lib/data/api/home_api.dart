import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';

final homeApiProvider = Provider<HomeApi>((ref) {
  return HomeApi(ref.watch(apiClientProvider));
});

class HomeApi {
  final Dio _dio;

  HomeApi(this._dio);

  Future<Map<String, dynamic>> getHomeDashboard() async {
    final response = await _dio.get('/api/home');
    if (response.data['success'] == true) {
      return response.data['data'];
    } else {
      throw Exception(response.data['error']['message'] ?? 'Failed to load home dashboard');
    }
  }
}
