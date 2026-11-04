import 'package:dio/dio.dart';
import '../models/followup_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class FollowupRepository {
  final Dio _dio = ApiService().dio;

  /// Fetches follow-up summary cards, pending reason breakdown, and due buckets.
  Future<FollowupDashboardData> getDashboardMetrics() async {
    try {
      final response = await _dio.get('/followup/dashboard');
      final body = Map<String, dynamic>.from(response.data as Map);

      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Failed to load follow-up dashboard');
      }

      final data = FollowupDashboardData.fromJson(
        Map<String, dynamic>.from(body['data'] as Map),
      );

      await StorageService.saveFollowupDashboard(data);
      return data;
    } catch (e) {
      final cached = await StorageService.getFollowupDashboard();
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }

  /// Fetches paginated follow-up records with optional status, due date, and search filters.
  Future<FollowupRegisterResponse> getRegister({
    int page = 1,
    int perPage = 20,
    String status = 'all',
    String? search,
    String? pendingReason,
    String dueFilter = 'all',
  }) async {
    final Map<String, dynamic> query = {
      'page': page,
      'per_page': perPage,
    };

    if (status != 'all') {
      query['status'] = status;
    }

    if (dueFilter != 'all') {
      query['due'] = dueFilter;
      query['due_filter'] = dueFilter;
    }

    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }
    if (pendingReason != null && pendingReason.trim().isNotEmpty) {
      query['pending_reason'] = pendingReason.trim();
    }

    final response = await _dio.get(
      '/followup/register',
      queryParameters: query,
    );

    return FollowupRegisterResponse.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  /// Fetches full beneficiary details with eligible schemes, document requirements, and current follow-up status.
  Future<BeneficiaryFollowupProfile> getBeneficiaryFollowup(int beneficiaryId) async {
    final response = await _dio.get('/followup/beneficiaries/$beneficiaryId');
    return BeneficiaryFollowupProfile.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  /// Fetches master list of 42 document types for mobile form dropdowns.
  Future<List<FollowupDocumentType>> getDocumentTypes() async {
    final response = await _dio.get('/followup/document-types');
    final body = Map<String, dynamic>.from(response.data as Map);
    final list = body['data'] as List<dynamic>? ?? [];

    return list
        .map((e) => FollowupDocumentType.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetches scheme-specific checklist of mandatory and optional required documents.
  Future<List<RequiredDocumentItem>> getSchemeDocuments(int schemeId) async {
    final response = await _dio.get('/followup/schemes/$schemeId/documents');
    final body = Map<String, dynamic>.from(response.data as Map);
    final list = body['data'] as List<dynamic>? ?? [];

    return list
        .map((e) => RequiredDocumentItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Records or updates follow-up progress via the upsert endpoint.
  Future<Map<String, dynamic>> recordFollowup(RecordFollowupPayload payload) async {
    try {
      final response = await _dio.post(
        '/followup/record',
        data: payload.toJson(),
      );

      final body = Map<String, dynamic>.from(response.data as Map);

      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Failed to save follow-up record');
      }

      return Map<String, dynamic>.from(body['data'] as Map? ?? {});
    } on DioException catch (e) {
      final resData = e.response?.data;
      if (resData is Map && resData['message'] != null) {
        throw Exception(resData['message'].toString());
      }
      rethrow;
    }
  }
}
