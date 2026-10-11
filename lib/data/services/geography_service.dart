import 'package:dio/dio.dart';

import '../models/location_model.dart';
import 'api_service.dart';

class GeographyService {
  final Dio _dio = ApiService().dio;

  Future<List<LocationModel>> getLocations(
      String endpoint,
      ) async {
    final response = await _dio.get(endpoint);

    final body = Map<String, dynamic>.from(
      response.data as Map,
    );

    if (body['success'] != true) {
      throw Exception(
        body['message']?.toString() ?? 'Failed to load locations',
      );
    }

    final rawData = body['data'];

    if (rawData is! List) {
      throw Exception('Invalid location API response');
    }

    return rawData
        .map(
          (item) => LocationModel.fromJson(
        Map<String, dynamic>.from(item as Map),
      ),
    )
        .toList();
  }

  Future<List<LocationModel>> getStates() =>
      getLocations('/geography/states');

  Future<List<LocationModel>> getDistricts(int stateId) =>
      getLocations('/geography/districts/$stateId');

  Future<List<LocationModel>> getBlocks(int districtId) =>
      getLocations('/geography/blocks/$districtId');

  Future<List<LocationModel>> getGramPanchayats(int blockId) =>
      getLocations('/geography/gram-panchayats/$blockId');

  Future<List<LocationModel>> getVillages(int gpId) =>
      getLocations('/geography/villages/$gpId');
}