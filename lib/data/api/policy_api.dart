import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';

final policyApiProvider = Provider<PolicyApi>((ref) {
  return PolicyApi(ref.watch(apiClientProvider));
});

class PolicyApi {
  final Dio _dio;

  PolicyApi(this._dio);

  // Backend returns `data` as a plain array of Policy rows here (no
  // `{items: [...]}` wrapper - confirmed against
  // financeApp_backend/src/controllers/policyController.ts and
  // policyService.ts `list()`, which resolves straight to
  // `Policy.findAll(...)`). The previous `Future<Map<String, dynamic>>`
  // signature would have thrown a cast error the first time this hit a real
  // backend; fixed while wiring Policy Main's fallback to this call.
  Future<List<dynamic>> getPolicies({
    String? category,
    String? region,
    int? age,
    String? providerType,
    String? keyword,
    String? applicationStatus,
  }) async {
    final queryParameters = <String, dynamic>{};
    if (category != null) queryParameters['category'] = category;
    if (region != null) queryParameters['region'] = region;
    if (age != null) queryParameters['age'] = age;
    if (providerType != null) queryParameters['providerType'] = providerType;
    if (keyword != null) queryParameters['keyword'] = keyword;
    if (applicationStatus != null) queryParameters['applicationStatus'] = applicationStatus;

    // No auth token required typically, but interceptor will add it if logged in.
    final response = await _dio.get('/api/policies', queryParameters: queryParameters);
    if (response.data['success'] == true) {
      return response.data['data'] as List<dynamic>? ?? [];
    } else {
      throw Exception(response.data['error']['message'] ?? 'Failed to get policies');
    }
  }

  Future<Map<String, dynamic>> getPolicy(String id) async {
    final response = await _dio.get('/api/policies/$id');
    if (response.data['success'] == true) {
      return response.data['data'];
    } else {
      throw Exception(response.data['error']['message'] ?? 'Failed to get policy');
    }
  }

  Future<void> addBookmark(String id) async {
    final response = await _dio.post('/api/policies/$id/bookmark');
    if (response.data['success'] != true) {
      throw Exception(response.data['error']['message'] ?? 'Failed to add bookmark');
    }
  }

  Future<void> removeBookmark(String id) async {
    final response = await _dio.delete('/api/policies/$id/bookmark');
    if (response.data['success'] != true) {
      throw Exception(response.data['error']['message'] ?? 'Failed to remove bookmark');
    }
  }

  Future<List<dynamic>> getBookmarks() async {
    final response = await _dio.get('/api/policies/bookmarks');
    if (response.data['success'] == true) {
      return response.data['data'];
    } else {
      throw Exception(response.data['error']['message'] ?? 'Failed to get bookmarks');
    }
  }

  Future<Map<String, dynamic>> getProfile() async {
    final response = await _dio.get('/api/profile');
    if (response.data['success'] == true) {
      return response.data['data'];
    } else {
      throw Exception(response.data['error']['message'] ?? 'Failed to get profile');
    }
  }

  Future<void> updateProfile({int? age, String? region}) async {
    final data = <String, dynamic>{};
    if (age != null) data['age'] = age;
    if (region != null) data['region'] = region;

    final response = await _dio.put('/api/profile', data: data);
    if (response.data['success'] != true) {
      throw Exception(response.data['error']['message'] ?? 'Failed to update profile');
    }
  }

  Future<Map<String, dynamic>> getRecommendedPolicies() async {
    try {
      final response = await _dio.get('/api/policies/recommended');
      if (response.data['success'] == true) {
        return response.data['data'];
      } else {
        throw Exception(response.data['error']['message'] ?? 'Failed to get recommended policies');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        // PROFILE_REQUIRED
        throw Exception('PROFILE_REQUIRED');
      }
      rethrow;
    }
  }
}
