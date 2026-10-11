
import '../models/scheme_model.dart';
import '../services/api_service.dart';

class SchemeRepository {
  final _dio = ApiService().dio;

  Future<Map<String, dynamic>> getSchemes({
    int page = 1,
    int perPage = 20,
    String? search,
  }) async {
    final response = await _dio.get(
      '/schemes',
      queryParameters: {
        'page': page,
        'per_page': perPage,
        if (search != null && search.trim().isNotEmpty)
          'search': search.trim(),
      },
    );

    final body = Map<String, dynamic>.from(response.data as Map);
    if (body['success'] != true) {
      throw Exception(body['message'] ?? 'Unable to load schemes');
    }

    final data = Map<String, dynamic>.from(body['data'] as Map);
    final items = (data['items'] as List? ?? [])
        .map((item) => SchemeModel.fromJson(
      Map<String, dynamic>.from(item as Map),
    ))
        .toList();

    final pagination = Map<String, dynamic>.from(
      data['pagination'] as Map? ?? {},
    );

    return {
      'items': items,
      'page': (pagination['page'] as num?)?.toInt() ?? page,
      'totalPages':
      (pagination['total_pages'] as num?)?.toInt() ?? 1,
      'total': (pagination['total'] as num?)?.toInt() ?? items.length,
    };
  }

  Future<Map<String, dynamic>> getSchemeDetails(int id) async {
    final response = await _dio.get('/schemes/$id');
    final body = Map<String, dynamic>.from(response.data as Map);

    if (body['success'] != true) {
      throw Exception(body['message'] ?? 'Unable to load scheme details');
    }

    return Map<String, dynamic>.from(body['data'] as Map);
  }
}
