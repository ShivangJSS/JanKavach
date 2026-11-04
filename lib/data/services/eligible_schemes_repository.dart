import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';

import '../engine/offline_eligibility_engine.dart';
import '../engine/schemes_catalog_data.dart';
import '../local/app_database.dart';
import '../models/eligible_scheme_model.dart';
import '../repository/scheme_repository.dart';
import 'api_service.dart';
import 'beneficiary_sync_service.dart';

class EligibleSchemesRepository {
  final Dio _dio = ApiService().dio;
  final AppDatabase _appDatabase = AppDatabase.instance;

  bool _lastResultFromCache = false;

  bool get lastResultFromCache => _lastResultFromCache;
  Future<Database> get _db => _appDatabase.database;

  /// Evaluates eligibility online and caches the successful response.
  /// Cascades through candidate endpoints to ensure high reliability:
  /// 1. POST /beneficiaries/$beneficiaryId/eligible-schemes (as documented in PHP controller)
  /// 2. GET /beneficiaries/$beneficiaryId/eligible-schemes (as documented in PHP controller)
  /// 3. GET /followup/beneficiaries/$beneficiaryId (production-verified follow-up endpoint)
  /// If offline, seamlessly falls back to local cache or offline scheme evaluation.
  Future<EligibleSchemesResponse> checkEligibility({
    required int beneficiaryId,
    Map<String, dynamic>? beneficiaryProfile,
  }) async {
    _validateBeneficiaryId(beneficiaryId);

    int effectiveId = beneficiaryId;

    // For local offline beneficiary, attempt to sync to server first if online
    if (beneficiaryId < 0) {
      try {
        await BeneficiarySyncService.instance.syncPendingRegistrations();
        final db = await _db;
        final rows = await db.query(
          'beneficiary_records',
          columns: ['server_id', 'record_state'],
          where: 'local_id = ?',
          whereArgs: [beneficiaryId.abs()],
          limit: 1,
        );
        if (rows.isNotEmpty &&
            rows.first['record_state'] == 'synced' &&
            rows.first['server_id'] != null) {
          effectiveId = (rows.first['server_id'] as num).toInt();
        }
      } catch (_) {}
    }

    // Retrieve or merge beneficiary demographic profile
    Map<String, dynamic> bProfile = Map<String, dynamic>.from(
      beneficiaryProfile ?? await _getBeneficiaryData(beneficiaryId) ?? {},
    );
    if (bProfile.isEmpty && effectiveId != beneficiaryId) {
      bProfile = Map<String, dynamic>.from(
        await _getBeneficiaryData(effectiveId) ?? {},
      );
    }
    bProfile['id'] ??= (effectiveId > 0 ? effectiveId : beneficiaryId);

    dynamic responseData;
    DioException? lastDioError;

    // Only query server APIs if we have a positive server ID
    if (effectiveId > 0) {
      final Map<String, dynamic> requestPayload = {
        'status': 'both',
        'complete': true,
      };
      if (bProfile['answers'] is Map && (bProfile['answers'] as Map).isNotEmpty) {
        requestPayload['answers'] = Map<String, dynamic>.from(bProfile['answers'] as Map);
      }

      // 1. First attempt: POST /beneficiaries/$effectiveId/eligible-schemes
      try {
        final response = await _dio.post(
          '/beneficiaries/$effectiveId/eligible-schemes',
          data: requestPayload,
        );
        if (response.data is Map &&
            (response.data['success'] == true || response.data['data'] != null)) {
          responseData = response.data;
        }
      } on DioException catch (e) {
        lastDioError = e;
        debugPrint(
          'POST /beneficiaries/$effectiveId/eligible-schemes failed: ${e.message}',
        );
      } catch (e) {
        debugPrint('POST eligible-schemes unexpected error: $e');
      }

      // 2. Second attempt: GET /beneficiaries/$effectiveId/eligible-schemes
      if (responseData == null) {
        try {
          final response = await _dio.get(
            '/beneficiaries/$effectiveId/eligible-schemes',
            queryParameters: {'status': 'both'},
          );
          if (response.data is Map &&
              (response.data['success'] == true ||
                  response.data['data'] != null)) {
            responseData = response.data;
          }
        } on DioException catch (e) {
          lastDioError = e;
          debugPrint(
            'GET /beneficiaries/$effectiveId/eligible-schemes failed: ${e.message}',
          );
        } catch (e) {
          debugPrint('GET eligible-schemes unexpected error: $e');
        }
      }

      // 3. Third attempt: GET /followup/beneficiaries/$effectiveId (production-verified specification endpoint)
      if (responseData == null) {
        try {
          final response = await _dio.get(
            '/followup/beneficiaries/$effectiveId',
          );
          if (response.data is Map &&
              (response.data['success'] == true ||
                  response.data['data'] != null)) {
            responseData = response.data;
          }
        } on DioException catch (e) {
          lastDioError = e;
          debugPrint(
            'GET /followup/beneficiaries/$effectiveId failed: ${e.message}',
          );
        } catch (e) {
          debugPrint('GET followup/beneficiaries unexpected error: $e');
        }
      }
    }

    // If online succeeded, parse and save to cache safely
    if (responseData != null) {
      final parsed = _parseResponse(responseData);
      _lastResultFromCache = false;
      await _saveEligibilityCache(beneficiaryId, responseData);
      if (effectiveId != beneficiaryId) {
        await _saveEligibilityCache(effectiveId, responseData);
      }
      return parsed;
    }

    // If offline (or online failed), evaluate using local matching engine
    // ALWAYS evaluate the specific beneficiary profile dynamically!
    final offlineEvaluation = await _evaluateOfflineEligibility(
      beneficiaryId,
      beneficiaryProfile: bProfile,
    );
    if (offlineEvaluation != null) {
      _lastResultFromCache = true;
      return offlineEvaluation;
    }

    // Fallback: check offline cache if evaluation could not run
    final cached = await _readEligibilityCache(beneficiaryId);
    if (cached != null && !_isStaleOrIncompleteCache(cached)) {
      _lastResultFromCache = true;
      return _parseResponse(cached);
    }
    if (effectiveId > 0) {
      final serverCached = await _readEligibilityCache(effectiveId);
      if (serverCached != null && !_isStaleOrIncompleteCache(serverCached)) {
        _lastResultFromCache = true;
        return _parseResponse(serverCached);
      }
    }

    if (lastDioError != null) {
      throw lastDioError;
    }

    throw Exception('Unable to evaluate eligible schemes.');
  }

  /// Fetches previously stored eligibility matches from the API.
  Future<EligibleSchemesResponse> getStoredEligibility({
    required int beneficiaryId,
    Map<String, dynamic>? beneficiaryProfile,
  }) async {
    _validateBeneficiaryId(beneficiaryId);

    dynamic responseData;
    DioException? lastDioError;

    if (beneficiaryId > 0) {
      // 1. Try GET /beneficiaries/$beneficiaryId/eligible-schemes
      try {
        final response = await _dio.get(
          '/beneficiaries/$beneficiaryId/eligible-schemes',
          queryParameters: {'status': 'both'},
        );
        if (response.data is Map &&
            (response.data['success'] == true || response.data['data'] != null)) {
          responseData = response.data;
        }
      } on DioException catch (e) {
        lastDioError = e;
      } catch (_) {}

      // 2. Try GET /followup/beneficiaries/$beneficiaryId
      if (responseData == null) {
        try {
          final response = await _dio.get(
            '/followup/beneficiaries/$beneficiaryId',
          );
          if (response.data is Map &&
              (response.data['success'] == true ||
                  response.data['data'] != null)) {
            responseData = response.data;
          }
        } on DioException catch (e) {
          lastDioError = e;
        } catch (_) {}
      }
    }

    if (responseData != null) {
      final parsed = _parseResponse(responseData);
      _lastResultFromCache = false;
      await _saveEligibilityCache(beneficiaryId, responseData);
      return parsed;
    }

    final offlineEvaluation = await _evaluateOfflineEligibility(
      beneficiaryId,
      beneficiaryProfile: beneficiaryProfile,
    );
    if (offlineEvaluation != null) {
      _lastResultFromCache = true;
      return offlineEvaluation;
    }

    final cached = await _readEligibilityCache(beneficiaryId);
    if (cached != null && !_isStaleOrIncompleteCache(cached)) {
      _lastResultFromCache = true;
      return _parseResponse(cached);
    }

    if (lastDioError != null) {
      throw lastDioError;
    }

    throw Exception('Unable to load stored eligibility.');
  }

  void _validateBeneficiaryId(int beneficiaryId) {
    if (beneficiaryId == 0) {
      throw ArgumentError('Invalid beneficiary ID.');
    }
  }

  Future<void> _saveEligibilityCache(
    int beneficiaryId,
    dynamic responseData,
  ) async {
    try {
      if (responseData is! Map) return;

      final json = Map<String, dynamic>.from(responseData);
      if (json['success'] != true && json['data'] == null) return;

      final db = await _db;
      await db.insert('eligibility_cache', {
        'beneficiary_id': beneficiaryId,
        'data': jsonEncode(json),
        'cached_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      debugPrint('Failed to save eligibility cache: $e');
    }
  }

  Future<Map<String, dynamic>?> _readEligibilityCache(int beneficiaryId) async {
    try {
      final db = await _db;
      final rows = await db.query(
        'eligibility_cache',
        columns: ['data'],
        where: 'beneficiary_id = ?',
        whereArgs: [beneficiaryId],
        limit: 1,
      );

      if (rows.isEmpty) return null;

      return Map<String, dynamic>.from(
        jsonDecode(rows.first['data'] as String) as Map,
      );
    } catch (e) {
      debugPrint('Failed to read eligibility cache: $e');
      return null;
    }
  }

  /// Detects whether cached eligibility results are stale or incomplete.
  /// Rejects dummy 100/100 results and evaluations truncated due to partial single-page sync.
  bool _isStaleOrIncompleteCache(Map<String, dynamic> json) {
    try {
      final summary =
          json['summary'] as Map<String, dynamic>? ??
          (json['data'] is Map
              ? (json['data']['summary'] as Map<String, dynamic>? ?? {})
              : {});
      final total = (summary['total_evaluated'] as num?)?.toInt() ?? 0;
      final eligible = (summary['eligible_count'] as num?)?.toInt() ?? 0;
      // Discard dummy 100/100 caches
      if (total >= 50 && total == eligible) return true;
      // Discard incomplete / truncated evaluations (like the 51 schemes evaluation from single-page cache)
      if (total > 0 && total < 60) return true;
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> _getBeneficiaryData(int beneficiaryId) async {
    final db = await _db;
    final absId = beneficiaryId.abs();

    // 1. Try beneficiary_records in SQLite (supports local offline & synced)
    try {
      final rows = await db.query(
        'beneficiary_records',
        where: beneficiaryId < 0 ? 'local_id = ?' : 'server_id = ?',
        whereArgs: [beneficiaryId < 0 ? absId : beneficiaryId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final row = rows.first;
        Map<String, dynamic> bMap = {};
        if (row['form_data'] != null) {
          try {
            final formData = jsonDecode(row['form_data'] as String);
            if (formData is Map && formData['payload'] is Map) {
              bMap = Map<String, dynamic>.from(formData['payload'] as Map);
            } else if (formData is Map) {
              bMap = Map<String, dynamic>.from(formData);
            }
          } catch (_) {}
        }
        if (bMap['answers'] is Map) {
          final answers = Map<String, dynamic>.from(bMap['answers'] as Map);
          answers.forEach((k, v) {
            if (!bMap.containsKey(k) || bMap[k] == null) {
              bMap[k] = v;
            }
          });
        }
        // Fill from direct row columns
        for (final col in [
          'name',
          'dob',
          'gender',
          'mobile',
          'state_id',
          'district_id',
          'block_id',
          'gram_panchayat_id',
          'village_id',
          'village_name',
          'area_type',
          'beneficiary_code',
        ]) {
          if (row[col] != null &&
              (!bMap.containsKey(col) ||
                  bMap[col] == null ||
                  bMap[col].toString().trim().isEmpty)) {
            bMap[col] = row[col];
          }
        }
        return bMap;
      }
    } catch (_) {}

    // 2. Try beneficiary_cache in SQLite
    try {
      final rows = await db.query(
        'beneficiary_cache',
        where: 'server_id = ?',
        whereArgs: [beneficiaryId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final data = jsonDecode(rows.first['data'] as String);
        if (data is Map) return Map<String, dynamic>.from(data);
      }
    } catch (_) {}

    // 3. Try geography_cache for beneficiary_details_$beneficiaryId
    try {
      final rows = await db.query(
        'geography_cache',
        where: 'cache_key = ?',
        whereArgs: ['beneficiary_details_$beneficiaryId'],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final data = jsonDecode(rows.first['data'] as String);
        if (data is Map) return Map<String, dynamic>.from(data);
      }
    } catch (_) {}

    return null;
  }

  /// Evaluates eligibility offline by matching the beneficiary's actual demographic,
  /// vulnerability, and documentation profile against the scheme rules using
  /// the OfflineEligibilityEngine (1:1 replica of backend EligibilityEngine.php).
  Future<EligibleSchemesResponse?> _evaluateOfflineEligibility(
    int beneficiaryId, {
    Map<String, dynamic>? beneficiaryProfile,
  }) async {
    try {
      final db = await _db;
      var rows = await db.query('scheme_cache', columns: ['data']);

      // 1. If scheme_cache is empty, import from geography_cache
      if (rows.isEmpty) {
        try {
          final geoRows = await db.query(
            'geography_cache',
            where: "cache_key LIKE 'schemes_list_%'",
          );
          for (final gr in geoRows) {
            final decoded = jsonDecode(gr['data'] as String);
            if (decoded is Map && decoded['items'] is List) {
              final items = decoded['items'] as List;
              for (final item in items) {
                if (item is Map) {
                  await db.insert('scheme_cache', {
                    'scheme_id': item['id'],
                    'scheme_code': item['code'] ?? '',
                    'scheme_name': item['name'] ?? '',
                    'data': jsonEncode(item),
                    'cached_at': DateTime.now().toIso8601String(),
                  }, conflictAlgorithm: ConflictAlgorithm.replace);
                }
              }
            }
          }
          rows = await db.query('scheme_cache', columns: ['data']);
        } catch (_) {}
      }

      // 2. If still empty, attempt online fetch if connected
      if (rows.isEmpty) {
        try {
          await SchemeRepository().syncAllSchemesOnline();
          rows = await db.query('scheme_cache', columns: ['data']);
        } catch (_) {}
      }

      final Map<int, Map<String, dynamic>> schemesMap = {};
      // 1. Seed with all bundled schemes (all 164 schemes with their states)
      for (final s in kBundledSchemes) {
        final id = (s['id'] as num?)?.toInt();
        if (id != null) {
          schemesMap[id] = Map<String, dynamic>.from(s);
        }
      }

      // 2. Overlay any updated schemes from local SQLite scheme_cache
      for (final r in rows) {
        try {
          final decoded = jsonDecode(r['data'] as String);
          if (decoded is Map) {
            final id = (decoded['id'] as num?)?.toInt();
            if (id != null) {
              schemesMap[id] = Map<String, dynamic>.from(decoded);
            }
          }
        } catch (_) {}
      }

      final rawSchemes = schemesMap.values.toList();

      // Retrieve beneficiary demographic profile
      final b = Map<String, dynamic>.from(
        beneficiaryProfile ?? await _getBeneficiaryData(beneficiaryId) ?? {},
      );
      if (b.isEmpty) {
        b['id'] = beneficiaryId;
      }

      final engine = OfflineEligibilityEngine();
      final response = engine.evaluateBeneficiary(
        b,
        availableSchemes: rawSchemes,
      );

      // Save into eligibility cache for offline access
      await _saveEligibilityCache(beneficiaryId, {
        'success': true,
        'message': response.message,
        'data': {
          'beneficiary': response.beneficiary,
          'summary': response.summary,
          'eligible_schemes':
              response.eligibleSchemes.map((m) => m.toJson()).toList(),
          'potentially_eligible_schemes':
              response.potentiallyEligibleSchemes.map((m) => m.toJson()).toList(),
        },
      });

      return response;
    } catch (e) {
      debugPrint('Offline eligibility evaluation error: $e');
      return null;
    }
  }

  EligibleSchemesResponse _parseResponse(dynamic responseData) {
    if (responseData is! Map) {
      throw const FormatException('Invalid eligible schemes API response.');
    }

    final json = Map<String, dynamic>.from(responseData);

    if (json['success'] == false && json['data'] == null) {
      throw Exception(
        json['message']?.toString() ?? 'Unable to fetch eligible schemes.',
      );
    }

    return EligibleSchemesResponse.fromJson(json);
  }
}
