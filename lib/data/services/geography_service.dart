import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:sqflite/sqflite.dart';

import '../local/app_database.dart';
import '../models/location_model.dart';
import '../models/master_data_download_result.dart';
import '../repository/scheme_repository.dart';
import 'api_service.dart';
import 'connectivity_sync_service.dart';
import 'storage_service.dart';

class GeographyService {
  final Dio _dio = ApiService().dio;
  final AppDatabase _database = AppDatabase.instance;

  /// Fetches locations from the given endpoint.
  /// If offline, immediately returns from local cache (< 5ms) without network latency.
  /// If online, loads from API with a fast timeout (3s) and updates local cache.
  /// If online network request fails or times out, falls back to local SQLite cache.
  Future<List<LocationModel>> getLocations(String endpoint) async {
    // 1. If offline, immediately load from local cache (<5ms)
    bool isOnline = false;
    try {
      isOnline = await ConnectivitySyncService.instance.isConnected();
    } catch (_) {
      isOnline = false;
    }

    if (!isOnline) {
      try {
        final cachedLocations = await _readFromCache(endpoint);
        if (cachedLocations != null) {
          debugPrint('Offline: loaded ${cachedLocations.length} locations for $endpoint from cache in <5ms');
          return cachedLocations;
        }
      } catch (cacheError) {
        debugPrint('Geography offline cache read error for $endpoint: $cacheError');
      }
      return [];
    }

    // 2. If online, fetch from API with a fast timeout (3s) so poor network does not hang the UI.
    try {
      final response = await _dio.get(
        endpoint,
        options: Options(
          sendTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
        ),
      );

      dynamic rawBody = response.data;
      if (rawBody is String) {
        rawBody = jsonDecode(rawBody);
      }

      final body = Map<String, dynamic>.from(
        rawBody as Map,
      );

      if (body['success'] != true) {
        throw Exception(
          body['message']?.toString() ??
              'Failed to load locations',
        );
      }

      final rawData = body['data'];

      if (rawData is! List) {
        throw Exception('Invalid location API response');
      }

      final locations = rawData
          .map(
            (item) => LocationModel.fromJson(
          Map<String, dynamic>.from(item as Map),
        ),
      )
          .toList();

      // A cache failure should not prevent fresh API data from loading.
      try {
        await _saveToCache(endpoint, locations);
      } catch (cacheError, stackTrace) {
        debugPrint('Geography cache save failed: $cacheError');
        debugPrintStack(stackTrace: stackTrace);
      }

      return locations;
    } catch (error, stackTrace) {
      debugPrint('Geography API request failed for $endpoint: $error');
      debugPrintStack(stackTrace: stackTrace);

      try {
        final cachedLocations = await _readFromCache(endpoint);

        if (cachedLocations != null) {
          debugPrint('Using cached locations for $endpoint (${cachedLocations.length} items)');
          return cachedLocations;
        }
      } catch (cacheError, cacheStackTrace) {
        debugPrint('Geography cache read failed: $cacheError');
        debugPrintStack(stackTrace: cacheStackTrace);
      }

      return [];
    }
  }

  /// Downloads all geography master data in one go from `/geography/master-data`
  /// and stores it locally so states, districts, blocks, gram panchayats, and
  /// villages are completely available offline during beneficiary registration.
  Future<MasterDataDownloadResult> downloadMasterData() async {
    final response = await _dio.get('/geography/master-data');

    dynamic rawBody = response.data;
    if (rawBody is String) {
      rawBody = jsonDecode(rawBody);
    }

    if (rawBody is! Map) {
      throw Exception('Invalid master data response format');
    }

    final body = Map<String, dynamic>.from(rawBody);

    if (body['success'] != true) {
      throw Exception(
        body['message']?.toString() ?? 'Failed to download master data',
      );
    }

    final rawData = body['data'];
    if (rawData is! Map) {
      throw Exception('Invalid master data payload: expected data object');
    }

    final dataMap = Map<String, dynamic>.from(rawData);

    final rawStates = (dataMap['states'] as List? ?? []);
    final rawDistricts = (dataMap['districts'] as List? ?? []);
    final rawBlocks = (dataMap['blocks'] as List? ?? []);
    final rawGps = (dataMap['gram_panchayats'] as List? ?? []);
    final rawVillages = (dataMap['villages'] as List? ?? []);

    final db = await _database.database;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    await db.transaction((txn) async {
      final batch = txn.batch();

      // 1. Store the complete master data blob
      batch.insert(
        'geography_cache',
        {
          'cache_key': '/geography/master-data',
          'data': jsonEncode(dataMap),
          'updated_at': nowIso,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 2. Store /geography/states
      final statesList = rawStates.map((item) {
        final m = Map<String, dynamic>.from(item as Map);
        return {
          'id': m['id'],
          'name': m['name']?.toString() ?? '',
        };
      }).toList();

      batch.insert(
        'geography_cache',
        {
          'cache_key': '/geography/states',
          'data': jsonEncode(statesList),
          'updated_at': nowIso,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 3. Group districts by state_id
      final districtsByState = <int, List<Map<String, dynamic>>>{};
      for (final item in rawDistricts) {
        if (item is Map) {
          final m = Map<String, dynamic>.from(item);
          final stateId = int.tryParse(m['state_id']?.toString() ?? '');
          if (stateId != null) {
            districtsByState.putIfAbsent(stateId, () => []).add({
              'id': m['id'],
              'state_id': stateId,
              'name': m['name']?.toString() ?? '',
            });
          }
        }
      }

      for (final entry in districtsByState.entries) {
        batch.insert(
          'geography_cache',
          {
            'cache_key': '/geography/districts/${entry.key}',
            'data': jsonEncode(entry.value),
            'updated_at': nowIso,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // 4. Group blocks by district_id
      final blocksByDistrict = <int, List<Map<String, dynamic>>>{};
      for (final item in rawBlocks) {
        if (item is Map) {
          final m = Map<String, dynamic>.from(item);
          final districtId = int.tryParse(m['district_id']?.toString() ?? '');
          if (districtId != null) {
            blocksByDistrict.putIfAbsent(districtId, () => []).add({
              'id': m['id'],
              'district_id': districtId,
              'name': m['name']?.toString() ?? '',
            });
          }
        }
      }

      for (final entry in blocksByDistrict.entries) {
        batch.insert(
          'geography_cache',
          {
            'cache_key': '/geography/blocks/${entry.key}',
            'data': jsonEncode(entry.value),
            'updated_at': nowIso,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // 5. Group gram panchayats by block_id
      final gpsByBlock = <int, List<Map<String, dynamic>>>{};
      for (final item in rawGps) {
        if (item is Map) {
          final m = Map<String, dynamic>.from(item);
          final blockId = int.tryParse(m['block_id']?.toString() ?? '');
          if (blockId != null) {
            gpsByBlock.putIfAbsent(blockId, () => []).add({
              'id': m['id'],
              'block_id': blockId,
              'name': m['name']?.toString() ?? '',
            });
          }
        }
      }

      for (final entry in gpsByBlock.entries) {
        batch.insert(
          'geography_cache',
          {
            'cache_key': '/geography/gram-panchayats/${entry.key}',
            'data': jsonEncode(entry.value),
            'updated_at': nowIso,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // 6. Group villages by gram_panchayat_id and by block_id
      final villagesByGp = <int, List<Map<String, dynamic>>>{};
      final villagesByBlock = <int, List<Map<String, dynamic>>>{};

      for (final item in rawVillages) {
        if (item is Map) {
          final m = Map<String, dynamic>.from(item);
          final villageObj = {
            'id': m['id'],
            'name': m['name']?.toString() ?? '',
            'area_type': m['area_type']?.toString(),
            'pincode': m['pincode']?.toString(),
          };

          final gpId = int.tryParse(m['gram_panchayat_id']?.toString() ?? '');
          if (gpId != null) {
            villagesByGp.putIfAbsent(gpId, () => []).add(villageObj);
          }

          final blockId = int.tryParse(m['block_id']?.toString() ?? '');
          if (blockId != null) {
            villagesByBlock.putIfAbsent(blockId, () => []).add(villageObj);
          }
        }
      }

      for (final entry in villagesByGp.entries) {
        batch.insert(
          'geography_cache',
          {
            'cache_key': '/geography/villages/${entry.key}',
            'data': jsonEncode(entry.value),
            'updated_at': nowIso,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final entry in villagesByBlock.entries) {
        batch.insert(
          'geography_cache',
          {
            'cache_key': '/geography/villages_by_block/${entry.key}',
            'data': jsonEncode(entry.value),
            'updated_at': nowIso,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
    });

    final result = MasterDataDownloadResult(
      success: true,
      message: 'Geography master data downloaded successfully',
      stateCount: rawStates.length,
      districtCount: rawDistricts.length,
      blockCount: rawBlocks.length,
      gramPanchayatCount: rawGps.length,
      villageCount: rawVillages.length,
      downloadedAt: DateTime.now(),
    );

    // Persist summary metadata
    await StorageService.saveMasterDataDownloadSummary(result);

    // Also sync and pre-cache schemes so scheme details are always available offline
    try {
      await SchemeRepository().syncAllSchemesOnline();
    } catch (e) {
      debugPrint('Syncing schemes during master data download: $e');
    }

    return result;
  }

  Future<void> _saveToCache(
      String endpoint,
      List<LocationModel> locations,
      ) async {
    final db = await _database.database;

    final data = jsonEncode(
      locations.map((location) => location.toJson()).toList(),
    );

    await db.insert(
      'geography_cache',
      {
        'cache_key': endpoint,
        'data': data,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<LocationModel>?> _readFromCache(
      String endpoint,
      ) async {
    final db = await _database.database;

    final rows = await db.query(
      'geography_cache',
      where: 'cache_key = ?',
      whereArgs: [endpoint],
      limit: 1,
    );

    if (rows.isNotEmpty) {
      try {
        final decoded = jsonDecode(rows.first['data'] as String);

        if (decoded is List) {
          return decoded
              .map(
                (item) => LocationModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
              .toList();
        }
      } catch (e) {
        debugPrint('Failed to decode cached data for $endpoint: $e');
      }
    }

    // Fallback: extract dynamically from the full master-data cache
    return _extractFromMasterDataCache(db, endpoint);
  }

  /// Dynamic extraction from the master-data JSON blob in case an individual
  /// endpoint key was not previously written.
  Future<List<LocationModel>?> _extractFromMasterDataCache(
    Database db,
    String endpoint,
  ) async {
    try {
      final rows = await db.query(
        'geography_cache',
        where: 'cache_key = ?',
        whereArgs: ['/geography/master-data'],
        limit: 1,
      );

      if (rows.isEmpty) return null;

      final decoded = jsonDecode(rows.first['data'] as String);
      if (decoded is! Map) return null;

      final dataMap = Map<String, dynamic>.from(decoded);

      if (endpoint == '/geography/states') {
        final states = (dataMap['states'] as List? ?? []);
        return states
            .map((item) => LocationModel.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      }

      final uriParts = endpoint.split('/');
      if (uriParts.length >= 4) {
        final entity = uriParts[2];
        final id = int.tryParse(uriParts[3]);
        if (id == null) return null;

        if (entity == 'districts') {
          final districts = (dataMap['districts'] as List? ?? []);
          return districts
              .where((item) => item is Map && int.tryParse(item['state_id']?.toString() ?? '') == id)
              .map((item) => LocationModel.fromJson(Map<String, dynamic>.from(item as Map)))
              .toList();
        }

        if (entity == 'blocks') {
          final blocks = (dataMap['blocks'] as List? ?? []);
          return blocks
              .where((item) => item is Map && int.tryParse(item['district_id']?.toString() ?? '') == id)
              .map((item) => LocationModel.fromJson(Map<String, dynamic>.from(item as Map)))
              .toList();
        }

        if (entity == 'gram-panchayats') {
          final gps = (dataMap['gram_panchayats'] as List? ?? []);
          return gps
              .where((item) => item is Map && int.tryParse(item['block_id']?.toString() ?? '') == id)
              .map((item) => LocationModel.fromJson(Map<String, dynamic>.from(item as Map)))
              .toList();
        }

        if (entity == 'villages') {
          final villages = (dataMap['villages'] as List? ?? []);
          return villages
              .where((item) => item is Map && int.tryParse(item['gram_panchayat_id']?.toString() ?? '') == id)
              .map((item) => LocationModel.fromJson(Map<String, dynamic>.from(item as Map)))
              .toList();
        }

        if (entity == 'villages_by_block') {
          final villages = (dataMap['villages'] as List? ?? []);
          return villages
              .where((item) => item is Map && int.tryParse(item['block_id']?.toString() ?? '') == id)
              .map((item) => LocationModel.fromJson(Map<String, dynamic>.from(item as Map)))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Failed to extract $endpoint from master-data cache: $e');
    }

    return null;
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

  /// Fetches villages by block ID from local cache / master data.
  Future<List<LocationModel>> getVillagesByBlock(int blockId) async {
    final cached = await _readFromCache('/geography/villages_by_block/$blockId');
    return cached ?? [];
  }
}
