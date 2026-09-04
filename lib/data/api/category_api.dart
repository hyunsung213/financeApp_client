import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';

final categoryApiProvider = Provider<CategoryApi>((ref) {
  return CategoryApi(ref.watch(apiClientProvider));
});

final categoriesProvider = FutureProvider<List<dynamic>>((ref) async {
  final api = ref.watch(categoryApiProvider);
  return await api.getCategories();
});

class CategoryApi {
  final Dio _dio;

  CategoryApi(this._dio);

  Future<List<dynamic>> getCategories() async {
    final response = await _dio.get('/api/categories');
    if (response.data['success'] == true) {
      return response.data['data'];
    } else {
      throw Exception(response.data['error']['message'] ?? 'Failed to get categories');
    }
  }

  Future<Map<String, dynamic>> createCategory({
    required String name,
    required String type,
    required String purposeType,
    required int sortOrder,
  }) async {
    final response = await _dio.post('/api/categories', data: {
      'name': name,
      'type': type,
      'purposeType': purposeType,
      'sortOrder': sortOrder,
    });
    if (response.data['success'] == true) {
      return response.data['data'];
    } else {
      throw Exception(response.data['error']['message'] ?? 'Failed to create category');
    }
  }
}
