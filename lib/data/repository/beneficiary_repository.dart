
import '../models/ beneficiary_model.dart';
import '../services/api_service.dart';

class BeneficiaryRepository {
  final _dio = ApiService().dio;

  Future<Map<String, dynamic>> getBeneficiaries({
    int page = 1,
    int perPage = 20,
    String? search,
    int? villageId,
    int? journeyStage,
  }) async {
    final response = await _dio.get(
      '/beneficiaries',
      queryParameters: {
        'page': page,
        'per_page': perPage,
        if (search != null && search.trim().isNotEmpty)
          'search': search.trim(),
        if (villageId != null) 'village_id': villageId,
        if (journeyStage != null) 'journey_stage': journeyStage,
      },
    );

    final body = Map<String, dynamic>.from(response.data as Map);

    if (body['success'] != true) {
      throw Exception(body['message'] ?? 'Unable to load beneficiaries');
    }

    final data = Map<String, dynamic>.from(body['data'] as Map);
    final items = (data['items'] as List? ?? [])
        .map(
          (item) => BeneficiaryModel.fromJson(
        Map<String, dynamic>.from(item as Map),
      ),
    )
        .toList();

    final pagination = Map<String, dynamic>.from(
      data['pagination'] as Map? ?? {},
    );

    return {
      'items': items,
      'page': (pagination['page'] as num?)?.toInt() ?? page,
      'perPage': (pagination['per_page'] as num?)?.toInt() ?? perPage,
      'total': (pagination['total'] as num?)?.toInt() ?? items.length,
      'totalPages':
      (pagination['total_pages'] as num?)?.toInt() ?? 1,
    };
  }

  Future<Map<String, dynamic>> getBeneficiaryDetails(int id) async {
    final response = await _dio.get('/beneficiaries/$id');
    final body = Map<String, dynamic>.from(response.data as Map);

    if (body['success'] != true) {
      throw Exception(
        body['message'] ?? 'Unable to load beneficiary details',
      );
    }

    return Map<String, dynamic>.from(body['data'] as Map);
  }
}
