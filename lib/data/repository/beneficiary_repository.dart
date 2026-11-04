import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../local/app_database.dart';
import '../models/ beneficiary_model.dart';

import '../models/dashboard_response.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class BeneficiaryRepository {
  final _dio = ApiService().dio;
  final _appDatabase = AppDatabase.instance;

  Future<Database> get _db => _appDatabase.database;

  String _now() => DateTime.now().toIso8601String();

  // Cache a response in the existing geography_cache table.
  // The table is generic, so it can also store beneficiary API responses.
  Future<void> _saveCache(String key, dynamic data) async {
    final db = await _db;

    await db.insert('geography_cache', {
      'cache_key': key,
      'data': jsonEncode(data),
      'updated_at': _now(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> _readCache(String key) async {
    final db = await _db;

    final rows = await db.query(
      'geography_cache',
      where: 'cache_key = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    try {
      return Map<String, dynamic>.from(
        jsonDecode(rows.first['data'] as String) as Map,
      );
    } catch (_) {
      return null;
    }
  }

  // Cache individual registered beneficiaries for offline access.
  Future<void> _cacheBeneficiaries(List<BeneficiaryModel> beneficiaries) async {
    final db = await _db;
    final currentUserId = await StorageService.getCurrentUserId();

    await db.transaction((txn) async {
      for (final beneficiary in beneficiaries) {
        await txn.insert('beneficiary_cache', {
          'server_id': beneficiary.id,
          if (currentUserId != null) 'user_id': currentUserId,
          'beneficiary_code': beneficiary.beneficiaryCode,
          'name': beneficiary.name,
          'data': jsonEncode(beneficiary.toJson()),
          'cached_at': _now(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });

    for (final beneficiary in beneficiaries) {
      try {
        await _saveCache(
          'beneficiary_details_${beneficiary.id}',
          beneficiary.toJson(),
        );
      } catch (_) {}
    }
  }

  Future<void> cacheSingleBeneficiary(BeneficiaryModel beneficiary) async {
    final db = await _db;
    final currentUserId = await StorageService.getCurrentUserId();

    await db.insert('beneficiary_cache', {
      'server_id': beneficiary.id,
      if (currentUserId != null) 'user_id': currentUserId,
      'beneficiary_code': beneficiary.beneficiaryCode,
      'name': beneficiary.name,
      'data': jsonEncode(beneficiary.toJson()),
      'cached_at': _now(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await _saveCache(
      'beneficiary_details_${beneficiary.id}',
      beneficiary.toJson(),
    );
  }

  Future<List<BeneficiaryModel>> _getLocalRegisteredBeneficiaries() async {
    final List<BeneficiaryModel> results = [];
    try {
      final db = await _db;
      final currentUserId = await StorageService.getCurrentUserId();

      final whereClause = currentUserId != null && currentUserId.isNotEmpty
          ? "record_state != 'draft' AND (user_id = ? OR user_id IS NULL)"
          : "record_state != 'draft'";
      final whereArgs = currentUserId != null && currentUserId.isNotEmpty
          ? [currentUserId]
          : null;

      final rows = await db.query(
        'beneficiary_records',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'local_id DESC',
      );

      for (final row in rows) {
        try {
          final localId = row['local_id'] as int;
          final serverId = row['server_id'] as int?;
          final state = row['record_state']?.toString() ?? 'pending_sync';

          Map<String, dynamic> payload = {};
          if (row['form_data'] != null) {
            final formData = jsonDecode(row['form_data'] as String);
            if (formData is Map && formData['payload'] is Map) {
              payload = Map<String, dynamic>.from(formData['payload'] as Map);
            } else if (formData is Map) {
              payload = Map<String, dynamic>.from(formData);
            }
          }

          final code = row['beneficiary_code']?.toString() ??
              payload['beneficiary_code']?.toString() ??
              'LOCAL-${localId.toString().padLeft(4, '0')}';

          final name = payload['name']?.toString() ?? 'Unnamed Beneficiary';
          final status = state == 'synced'
              ? 'Active'
              : (state == 'sync_failed'
                  ? 'Sync Failed (Offline)'
                  : 'Pending Sync (Offline)');

          results.add(
            BeneficiaryModel(
              id: (state == 'synced' && serverId != null && serverId > 0)
                  ? serverId
                  : -localId,
              beneficiaryCode: code,
              name: name,
              gender: payload['gender']?.toString(),
              dob: payload['dob']?.toString(),
              age: payload['age'] is num
                  ? (payload['age'] as num).toInt()
                  : int.tryParse('${payload['age']}'),
              mobile: payload['mobile']?.toString(),
              stateId: payload['state_id'] as int?,
              districtId: payload['district_id'] as int?,
              blockId: payload['block_id'] as int?,
              gramPanchayatId: payload['gram_panchayat_id'] as int?,
              villageId: payload['village_id'] as int?,
              villageName: payload['village_name']?.toString(),
              recordStatus: status,
              assessmentStatus: 'Registered',
              registrationDate: payload['registration_date']?.toString() ??
                  row['created_at']?.toString(),
              journeyStage: 1,
              applicationCount: 0,
            ),
          );
        } catch (_) {}
      }
    } catch (_) {}
    return results;
  }

  Future<List<BeneficiaryModel>> _getCachedServerBeneficiaries() async {
    final List<BeneficiaryModel> results = [];
    try {
      final db = await _db;
      final currentUserId = await StorageService.getCurrentUserId();

      final whereClause = currentUserId != null && currentUserId.isNotEmpty
          ? 'user_id = ? OR user_id IS NULL'
          : null;
      final whereArgs = currentUserId != null && currentUserId.isNotEmpty
          ? [currentUserId]
          : null;

      final rows = await db.query(
        'beneficiary_cache',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'server_id DESC',
      );

      for (final row in rows) {
        try {
          final data = jsonDecode(row['data'] as String);
          if (data is Map) {
            results.add(
              BeneficiaryModel.fromJson(Map<String, dynamic>.from(data)),
            );
          }
        } catch (_) {}
      }
    } catch (_) {}
    return results;
  }

  bool _matchesSearch(BeneficiaryModel item, String? query) {
    if (query == null || query.trim().isEmpty) return true;
    final q = query.trim().toLowerCase();
    if (item.name.toLowerCase().contains(q)) return true;
    if (item.beneficiaryCode.toLowerCase().contains(q)) return true;
    if (item.mobile?.contains(q) == true) return true;
    return false;
  }

  // Read the exact cached page and filters, if available.
  Future<Map<String, dynamic>?> _getCachedBeneficiaries({
    required int page,
    required int perPage,
    String? search,
    int? villageId,
    String? journeyStage,
  }) async {
    final key = _beneficiaryListCacheKey(
      page: page,
      perPage: perPage,
      search: search,
      villageId: villageId,
      journeyStage: journeyStage,
    );

    return _readCache(key);
  }

  String _beneficiaryListCacheKey({
    required int page,
    required int perPage,
    String? search,
    int? villageId,
    String? journeyStage,
  }) {
    return 'beneficiaries_list'
        '_page_$page'
        '_perPage_$perPage'
        '_search_${Uri.encodeComponent(search?.trim().toLowerCase() ?? '')}'
        '_village_${villageId ?? 'all'}'
        '_stage_${journeyStage ?? 'all'}';
  }

  Future<Map<String, dynamic>> getBeneficiaries({
    int page = 1,
    int perPage = 20,
    String? search,
    int? villageId,
    String? journeyStage,
  }) async {
    final normalizedSearch = search?.trim();

    final cacheKey = _beneficiaryListCacheKey(
      page: page,
      perPage: perPage,
      search: normalizedSearch,
      villageId: villageId,
      journeyStage: journeyStage,
    );

    final localRegistrations = await _getLocalRegisteredBeneficiaries();

    try {
      final response = await _dio.get(
        '/beneficiaries',
        queryParameters: {
          'page': page,
          'per_page': perPage,
          if (normalizedSearch != null && normalizedSearch.isNotEmpty)
            'search': normalizedSearch,
          if (villageId != null) 'village_id': villageId,
          if (journeyStage != null) 'journey_stage': journeyStage,
        },
      );

      final body = Map<String, dynamic>.from(response.data as Map);

      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Unable to load beneficiaries');
      }

      final data = Map<String, dynamic>.from(body['data'] as Map);

      final serverItems = (data['items'] as List? ?? [])
          .map(
            (item) => BeneficiaryModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();

      final pagination = Map<String, dynamic>.from(
        data['pagination'] as Map? ?? {},
      );

      // Save server items in beneficiary_cache
      await _cacheBeneficiaries(serverItems);

      // Merge local pending items that haven't been confirmed synced on server yet
      final List<BeneficiaryModel> mergedItems = [];
      final Set<dynamic> seenIds = {};
      final Set<String> seenCodes = {};

      if (page == 1) {
        for (final local in localRegistrations) {
          if (local.recordStatus?.toLowerCase().contains('offline') == true ||
              local.recordStatus?.toLowerCase().contains('pending') == true ||
              local.recordStatus?.toLowerCase().contains('failed') == true ||
              local.id < 0) {
            if (_matchesSearch(local, normalizedSearch)) {
              mergedItems.add(local);
              seenIds.add(local.id);
              if (local.beneficiaryCode.isNotEmpty) {
                seenCodes.add(local.beneficiaryCode.toLowerCase());
              }
            }
          }
        }
      }

      for (final item in serverItems) {
        if (!seenIds.contains(item.id) &&
            (item.beneficiaryCode.isEmpty ||
                !seenCodes.contains(item.beneficiaryCode.toLowerCase()))) {
          mergedItems.add(item);
          seenIds.add(item.id);
          if (item.beneficiaryCode.isNotEmpty) {
            seenCodes.add(item.beneficiaryCode.toLowerCase());
          }
        }
      }

      final serverTotal =
          (pagination['total'] as num?)?.toInt() ?? serverItems.length;
      final totalRecords = serverTotal +
          (page == 1 ? (mergedItems.length - serverItems.length) : 0);

      final result = <String, dynamic>{
        'items': mergedItems,
        'page': (pagination['page'] as num?)?.toInt() ?? page,
        'perPage': (pagination['per_page'] as num?)?.toInt() ?? perPage,
        'total': totalRecords,
        'totalPages': (pagination['total_pages'] as num?)?.toInt() ?? 1,
      };

      // Save response for offline use
      await _saveCache(cacheKey, {
        'items': mergedItems.map((item) => item.toJson()).toList(),
        'page': result['page'],
        'perPage': result['perPage'],
        'total': result['total'],
        'totalPages': result['totalPages'],
      });

      // Update dashboard summary
      try {
        final existingSummary = await StorageService.getDashboardSummary();
        if (page == 1 &&
            (normalizedSearch == null || normalizedSearch.isEmpty)) {
          await StorageService.saveDashboardSummary(
            (existingSummary ?? const DashboardSummary()).copyWith(
              beneficiariesRegistered: totalRecords,
            ),
          );
        }
      } catch (_) {}

      return result;
    } catch (error) {
      debugPrint('Beneficiaries API failed ($error), building offline list...');

      final cached = await _getCachedBeneficiaries(
        page: page,
        perPage: perPage,
        search: normalizedSearch,
        villageId: villageId,
        journeyStage: journeyStage,
      );

      final List<BeneficiaryModel> offlineList = [];
      final Set<dynamic> seenIds = {};
      final Set<String> seenCodes = {};

      for (final local in localRegistrations) {
        if (_matchesSearch(local, normalizedSearch)) {
          offlineList.add(local);
          seenIds.add(local.id);
          if (local.beneficiaryCode.isNotEmpty) {
            seenCodes.add(local.beneficiaryCode.toLowerCase());
          }
        }
      }

      if (cached != null) {
        final cachedItems = (cached['items'] as List? ?? [])
            .map(
              (item) => BeneficiaryModel.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList();

        for (final item in cachedItems) {
          if (!seenIds.contains(item.id) &&
              (item.beneficiaryCode.isEmpty ||
                  !seenCodes.contains(item.beneficiaryCode.toLowerCase()))) {
            if (_matchesSearch(item, normalizedSearch)) {
              offlineList.add(item);
              seenIds.add(item.id);
              if (item.beneficiaryCode.isNotEmpty) {
                seenCodes.add(item.beneficiaryCode.toLowerCase());
              }
            }
          }
        }
      } else {
        final serverCached = await _getCachedServerBeneficiaries();
        for (final item in serverCached) {
          if (!seenIds.contains(item.id) &&
              (item.beneficiaryCode.isEmpty ||
                  !seenCodes.contains(item.beneficiaryCode.toLowerCase()))) {
            if (_matchesSearch(item, normalizedSearch)) {
              offlineList.add(item);
              seenIds.add(item.id);
              if (item.beneficiaryCode.isNotEmpty) {
                seenCodes.add(item.beneficiaryCode.toLowerCase());
              }
            }
          }
        }
      }

      return {
        'items': offlineList,
        'page': page,
        'perPage': perPage,
        'total': offlineList.length,
        'totalPages': 1,
      };
    }
  }

  Future<Map<String, dynamic>> getBeneficiaryDetails(int id) async {
    final cacheKey = 'beneficiary_details_$id';

    if (id <= 0) {
      // Local offline beneficiary - load directly from SQLite beneficiary_records
      try {
        final db = await _db;
        final rows = await db.query(
          'beneficiary_records',
          where: 'local_id = ?',
          whereArgs: [id.abs()],
          limit: 1,
        );
        if (rows.isNotEmpty) {
          final row = rows.first;
          if (row['form_data'] != null) {
            final formData = Map<String, dynamic>.from(
              jsonDecode(row['form_data'] as String) as Map,
            );
            final payload = formData['payload'] is Map
                ? Map<String, dynamic>.from(formData['payload'] as Map)
                : formData;
            payload['id'] = id;
            payload['beneficiary_code'] = row['beneficiary_code']?.toString() ??
                payload['beneficiary_code']?.toString() ??
                'LOCAL-${id.abs().toString().padLeft(4, '0')}';
            return payload;
          }
        }
      } catch (_) {}
    }

    try {
      final response = await _dio.get('/beneficiaries/$id');
      final body = Map<String, dynamic>.from(response.data as Map);

      if (body['success'] != true) {
        throw Exception(
          body['message'] ?? 'Unable to load beneficiary details',
        );
      }

      final data = Map<String, dynamic>.from(body['data'] as Map);

      await _saveCache(cacheKey, data);

      return data;
    } catch (error) {
      // 1. Try exact details cache key
      final cached = await _readCache(cacheKey);
      if (cached != null) {
        return cached;
      }

      // 2. Try beneficiary_cache SQLite table
      try {
        final db = await _db;
        final rows = await db.query(
          'beneficiary_cache',
          where: 'server_id = ?',
          whereArgs: [id],
          limit: 1,
        );
        if (rows.isNotEmpty) {
          final raw = rows.first['data'] as String;
          final json = Map<String, dynamic>.from(jsonDecode(raw) as Map);
          await _saveCache(cacheKey, json);
          return json;
        }
      } catch (_) {}

      // 3. Try local offline registrations in beneficiary_records
      try {
        final db = await _db;
        final rows = await db.query(
          'beneficiary_records',
          where: 'server_id = ? OR local_id = ?',
          whereArgs: [id, id.abs()],
          limit: 1,
        );
        if (rows.isNotEmpty) {
          final row = rows.first;
          if (row['form_data'] != null) {
            final formData = Map<String, dynamic>.from(
              jsonDecode(row['form_data'] as String) as Map,
            );
            final payload = formData['payload'] is Map
                ? Map<String, dynamic>.from(formData['payload'] as Map)
                : formData;
            await _saveCache(cacheKey, payload);
            return payload;
          }
        }
      } catch (_) {}

      // 4. Try scanning cached beneficiary lists
      try {
        final db = await _db;
        final rows = await db.query(
          'geography_cache',
          where: "key LIKE 'beneficiaries_list_%'",
        );
        for (final row in rows) {
          final raw = row['data'] as String;
          final json = jsonDecode(raw);
          if (json is Map && json['items'] is List) {
            for (final item in json['items']) {
              if (item is Map &&
                  (item['id'] == id || item['server_id'] == id)) {
                final match = Map<String, dynamic>.from(item);
                await _saveCache(cacheKey, match);
                return match;
              }
            }
          }
        }
      } catch (_) {}

      throw Exception(
        'Unable to load beneficiary details. '
        'No cached details are available. Details: $error',
      );
    }
  }
}
