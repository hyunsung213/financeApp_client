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

  /// [parentCategoryId] makes it a 소분류 of that 대분류 (one level only).
  Future<Map<String, dynamic>> createCategory({
    required String name,
    required String type,
    required String purposeType,
    required int sortOrder,
    String? parentCategoryId,
    String? icon,
    String? color,
  }) async {
    final response = await _dio.post('/api/categories', data: {
      'name': name,
      'type': type,
      'purposeType': purposeType,
      'sortOrder': sortOrder,
      'parentCategoryId': ?parentCategoryId,
      'icon': ?icon,
      'color': ?color,
    });
    if (response.data['success'] == true) {
      return response.data['data'];
    } else {
      throw Exception(response.data['error']['message'] ?? 'Failed to create category');
    }
  }

  /// Only the given fields change. For a system category the backend keeps
  /// them as this user's display override (id, parent and budget links stay);
  /// a custom category's name changes on its own row.
  Future<Map<String, dynamic>> updateCategory(
    String id, {
    String? name,
    String? icon,
    String? color,
  }) async {
    final response = await _dio.patch('/api/categories/$id', data: {
      'name': ?name,
      'icon': ?icon,
      'color': ?color,
    });
    if (response.data['success'] == true) {
      return response.data['data'];
    } else {
      throw Exception(response.data['error']['message'] ?? 'Failed to update category');
    }
  }

  /// 기본값으로 되돌리기: drops this user's name/icon/color override.
  Future<Map<String, dynamic>> resetCategoryAppearance(String id) async {
    final response = await _dio.delete('/api/categories/$id/preference');
    if (response.data['success'] == true) {
      return response.data['data'];
    } else {
      throw Exception(response.data['error']['message'] ?? 'Failed to reset category');
    }
  }

  /// The backend deactivates the category (`isActive: false`) rather than
  /// deleting the row, so transactions already on it keep their category.
  Future<void> deleteCategory(String id) async {
    final response = await _dio.delete('/api/categories/$id');
    if (response.data['success'] != true) {
      throw Exception(response.data['error']['message'] ?? 'Failed to delete category');
    }
  }
}
