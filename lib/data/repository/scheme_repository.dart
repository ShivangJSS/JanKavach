import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../local/app_database.dart';
import '../models/scheme_model.dart';
import '../services/api_service.dart';
import '../engine/schemes_catalog_data.dart';
import '../engine/scheme_rules_data.dart';

class SchemeRepository {
  final _dio = ApiService().dio;
  final _appDatabase = AppDatabase.instance;

  Future<Database> get _db => _appDatabase.database;

  String _now() => DateTime.now().toIso8601String();

  String _listCacheKey({
    required int page,
    required int perPage,
    String? search,
  }) {
    return 'schemes_list'
        '_page_$page'
        '_perPage_$perPage'
        '_search_${Uri.encodeComponent(search?.trim().toLowerCase() ?? '')}';
  }

  Future<void> _saveCache(String key, dynamic value) async {
    try {
      final db = await _db;
      await db.insert('geography_cache', {
        'cache_key': key,
        'data': jsonEncode(value),
        'updated_at': _now(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      debugPrint('Failed to save geography_cache: $e');
    }
  }

  Future<Map<String, dynamic>?> _readCache(String key) async {
    try {
      final db = await _db;
      final rows = await db.query(
        'geography_cache',
        where: 'cache_key = ?',
        whereArgs: [key],
        limit: 1,
      );

      if (rows.isEmpty) return null;

      return Map<String, dynamic>.from(
        jsonDecode(rows.first['data'] as String) as Map,
      );
    } catch (_) {
      return null;
    }
  }

  /// Caches schemes into the dedicated `scheme_cache` table in SQLite.
  Future<void> _cacheSchemesLocally(List<SchemeModel> schemes) async {
    try {
      final db = await _db;
      await db.transaction((txn) async {
        for (final scheme in schemes) {
          await txn.insert('scheme_cache', {
            'scheme_id': scheme.id,
            'scheme_code': scheme.code,
            'scheme_name': scheme.name,
            'data': jsonEncode(scheme.toJson()),
            'cached_at': _now(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });
    } catch (e) {
      debugPrint('Failed to save scheme_cache: $e');
    }
  }

  /// Syncs all schemes when internet is available.
  /// Paginates through the entire scheme catalogue so all pages are cached.
  /// If schemes are added, they are saved locally.
  /// If schemes are removed on the server, they are purged from the local cache.
  Future<void> syncAllSchemesOnline() async {
    try {
      int currentPage = 1;
      int totalPages = 1;
      final List<Map<String, dynamic>> allRawItems = [];

      do {
        final response = await _dio.get(
          '/schemes',
          queryParameters: {'page': currentPage, 'per_page': 100},
        );

        final body = Map<String, dynamic>.from(response.data as Map);
        if (body['success'] != true) break;

        final data = Map<String, dynamic>.from(body['data'] as Map);
        final rawItems = data['items'] as List? ?? [];
        for (final item in rawItems) {
          if (item is Map) {
            allRawItems.add(Map<String, dynamic>.from(item));
          }
        }

        final pagination = data['pagination'] as Map? ?? {};
        totalPages = (pagination['total_pages'] as num?)?.toInt() ?? 1;
        currentPage++;
      } while (currentPage <= totalPages);

      if (allRawItems.isEmpty) return;

      final schemes = allRawItems
          .map(
            (item) => SchemeModel.fromJson(item),
          )
          .toList();

      final db = await _db;
      final activeServerIds = schemes.map((s) => s.id).toSet();

      await db.transaction((txn) async {
        for (int i = 0; i < schemes.length; i++) {
          final scheme = schemes[i];
          final rawMap = (i < allRawItems.length)
              ? allRawItems[i]
              : scheme.toJson();

          await txn.insert('scheme_cache', {
            'scheme_id': scheme.id,
            'scheme_code': scheme.code,
            'scheme_name': scheme.name,
            'data': jsonEncode(rawMap),
            'cached_at': _now(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }

        // Remove schemes locally that no longer exist on the server
        if (activeServerIds.isNotEmpty) {
          final placeholders = List.filled(
            activeServerIds.length,
            '?',
          ).join(',');
          await txn.delete(
            'scheme_cache',
            where: 'scheme_id NOT IN ($placeholders)',
            whereArgs: activeServerIds.toList(),
          );
        }
      });
    } catch (e) {
      debugPrint('Background scheme sync error: $e');
    }
  }

  /// Fetches schemes offline directly from the SQLite `scheme_cache` table.
  /// Supports offline keyword searching on scheme name, code, and description.
  Future<Map<String, dynamic>> getSchemesOffline({
    int page = 1,
    int perPage = 20,
    String? search,
  }) async {
    final db = await _db;
    List<Map<String, dynamic>> rows;

    final trimmedSearch = search?.trim();

    if (trimmedSearch != null && trimmedSearch.isNotEmpty) {
      final term = '%${trimmedSearch.toLowerCase()}%';
      rows = await db.rawQuery(
        'SELECT data FROM scheme_cache WHERE LOWER(scheme_name) LIKE ? OR LOWER(scheme_code) LIKE ? OR LOWER(data) LIKE ? ORDER BY scheme_id ASC',
        [term, term, term],
      );
    } else {
      rows = await db.query(
        'scheme_cache',
        columns: ['data'],
        orderBy: 'scheme_id ASC',
      );
    }

    final allItems = rows
        .map((row) {
          try {
            final json =
                jsonDecode(row['data'] as String) as Map<String, dynamic>;
            return SchemeModel.fromJson(json);
          } catch (_) {
            return null;
          }
        })
        .whereType<SchemeModel>()
        .toList();

    final total = allItems.length;
    final totalPages = (total / perPage).ceil().clamp(1, 9999);
    final startIndex = (page - 1) * perPage;
    final items = (startIndex < total)
        ? allItems.skip(startIndex).take(perPage).toList()
        : <SchemeModel>[];

    return {
      'items': items,
      'page': page,
      'totalPages': totalPages,
      'total': total,
    };
  }

  Future<Map<String, dynamic>> getSchemes({
    int page = 1,
    int perPage = 20,
    String? search,
  }) async {
    final normalizedSearch = search?.trim();
    final cacheKey = _listCacheKey(
      page: page,
      perPage: perPage,
      search: normalizedSearch,
    );

    try {
      final response = await _dio.get(
        '/schemes',
        queryParameters: {
          'page': page,
          'per_page': perPage,
          if (normalizedSearch != null && normalizedSearch.isNotEmpty)
            'search': normalizedSearch,
        },
      );

      final body = Map<String, dynamic>.from(response.data as Map);

      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Unable to load schemes');
      }

      final data = Map<String, dynamic>.from(body['data'] as Map);

      final items = (data['items'] as List? ?? [])
          .map(
            (item) =>
                SchemeModel.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();

      final pagination = Map<String, dynamic>.from(
        data['pagination'] as Map? ?? {},
      );

      final result = <String, dynamic>{
        'items': items,
        'page': (pagination['page'] as num?)?.toInt() ?? page,
        'totalPages': (pagination['total_pages'] as num?)?.toInt() ?? 1,
        'total': (pagination['total'] as num?)?.toInt() ?? items.length,
      };

      // Save to dedicated SQLite table scheme_cache
      await _cacheSchemesLocally(items);

      // On initial unsearched load, sync all active schemes to reflect additions & removals
      if (page == 1 && (normalizedSearch == null || normalizedSearch.isEmpty)) {
        syncAllSchemesOnline();
      }

      // Also backup the exact page in geography_cache
      await _saveCache(cacheKey, {
        'items': items.map((item) => item.toJson()).toList(),
        'page': result['page'],
        'totalPages': result['totalPages'],
        'total': result['total'],
      });

      return result;
    } catch (error) {
      // Offline fallback: Search from SQLite scheme_cache
      final offlineResult = await getSchemesOffline(
        page: page,
        perPage: perPage,
        search: normalizedSearch,
      );

      if ((offlineResult['items'] as List).isNotEmpty ||
          (normalizedSearch != null && normalizedSearch.isNotEmpty)) {
        return offlineResult;
      }

      // Secondary fallback to page-level cache if scheme_cache is empty
      final cached = await _readCache(cacheKey);
      if (cached != null) {
        final items = (cached['items'] as List? ?? [])
            .map(
              (item) =>
                  SchemeModel.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList();

        return {
          'items': items,
          'page': (cached['page'] as num?)?.toInt() ?? page,
          'totalPages': (cached['totalPages'] as num?)?.toInt() ?? 1,
          'total': (cached['total'] as num?)?.toInt() ?? items.length,
        };
      }

      throw Exception(
        'Unable to load schemes. No cached results are available. '
        'Details: $error',
      );
    }
  }

  /// Immediately builds an offline scheme details map from the bundled catalog
  /// or SchemeModel so the screen renders instantly without waiting for network.
  Map<String, dynamic> getImmediateOfflineDetails(SchemeModel scheme) {
    final bundled = kBundledSchemes.cast<Map<String, dynamic>?>().firstWhere(
      (s) => s != null && (s['id'] == scheme.id || s['scheme_code'] == scheme.code),
      orElse: () => null,
    );

    return normalizeSchemeDetails(bundled ?? scheme.toJson(), fallbackScheme: scheme);
  }

  /// Normalizes any scheme representation (bundled, scheme_cache, or fallback)
  /// into the full detail structure expected by SchemeDetailScreen.
  Map<String, dynamic> normalizeSchemeDetails(
    Map<String, dynamic> raw, {
    SchemeModel? fallbackScheme,
  }) {
    // If it is already a full detail response from GET /schemes/{id}
    if (raw['classification'] is Map &&
        raw['benefits'] is List &&
        raw['application'] is Map) {
      return raw;
    }

    final id = (raw['id'] as num?)?.toInt() ?? fallbackScheme?.id ?? 0;
    final bundled = kBundledSchemes.cast<Map<String, dynamic>?>().firstWhere(
      (s) => s != null && (s['id'] == id || (raw['scheme_code'] != null && s['scheme_code'] == raw['scheme_code'])),
      orElse: () => null,
    );

    final name = raw['name']?.toString() ??
        bundled?['name']?.toString() ??
        fallbackScheme?.name ??
        'Scheme';
    final code = raw['scheme_code']?.toString() ??
        raw['code']?.toString() ??
        bundled?['scheme_code']?.toString() ??
        fallbackScheme?.code ??
        '';
    final shortName = raw['short_name']?.toString() ??
        bundled?['short_name']?.toString() ??
        fallbackScheme?.shortName;
    final description = raw['description']?.toString() ??
        bundled?['description']?.toString() ??
        fallbackScheme?.description;

    final level = raw['scheme_level']?.toString() ??
        raw['level']?.toString() ??
        bundled?['scheme_level']?.toString() ??
        fallbackScheme?.level ??
        'National';
    final status = raw['scheme_status']?.toString() ??
        raw['status']?.toString() ??
        bundled?['scheme_status']?.toString() ??
        fallbackScheme?.status ??
        'Active';
    final activeEnrollment = raw['active_enrollment'] == true ||
        bundled?['active_enrollment'] == true ||
        fallbackScheme?.activeEnrollment == true;
    final launchYear = raw['launch_year'] ?? bundled?['launch_year'];

    final stateName = raw['state_name']?.toString() ??
        (raw['state'] is Map ? raw['state']['name']?.toString() : null) ??
        fallbackScheme?.stateName;
    final applicableStates = raw['applicable_states'] is List
        ? (raw['applicable_states'] as List)
        : (bundled?['applicable_states'] as List? ?? []);

    final themeName = raw['theme_name']?.toString() ??
        (raw['theme'] is Map ? raw['theme']['name']?.toString() : null) ??
        fallbackScheme?.themeName;
    final themeColor = raw['theme_color']?.toString() ??
        (raw['theme'] is Map ? raw['theme']['color']?.toString() : null) ??
        fallbackScheme?.themeColor;

    final targetGroupSummary = raw['target_group_summary']?.toString() ??
        bundled?['target_group_summary']?.toString() ??
        fallbackScheme?.targetGroupSummary;
    final eligibilitySummary = raw['eligibility_summary']?.toString() ??
        bundled?['eligibility_summary']?.toString() ??
        fallbackScheme?.eligibilitySummary;

    final benefitType = raw['benefit_type']?.toString() ??
        (raw['benefit'] is Map ? raw['benefit']['type']?.toString() : null) ??
        bundled?['benefit_type']?.toString() ??
        fallbackScheme?.benefitType;
    final benefitDesc = raw['benefit_description']?.toString() ??
        (raw['benefit'] is Map ? raw['benefit']['description']?.toString() : null) ??
        bundled?['benefit_description']?.toString() ??
        fallbackScheme?.benefitDescription;
    final benefitAmount = raw['benefit_amount'] ??
        (raw['benefit'] is Map ? raw['benefit']['amount'] : null) ??
        bundled?['benefit_amount'] ??
        fallbackScheme?.benefitAmount;
    final benefitAmountText = raw['benefit_amount_text']?.toString() ??
        (raw['benefit'] is Map ? raw['benefit']['amount_text']?.toString() : null) ??
        bundled?['benefit_amount_text']?.toString() ??
        fallbackScheme?.benefitAmountText;

    final appMode = raw['application_mode']?.toString() ??
        bundled?['application_mode']?.toString() ??
        fallbackScheme?.applicationMode ??
        'Offline';
    final appProcess = raw['application_process']?.toString() ??
        bundled?['application_process']?.toString();
    final portalUrl = raw['portal_url']?.toString() ??
        bundled?['portal_url']?.toString() ??
        fallbackScheme?.portalUrl;
    final helpline = raw['helpline_number']?.toString() ??
        bundled?['helpline_number']?.toString();
    final sourceUrl = raw['source_url']?.toString() ??
        bundled?['source_url']?.toString() ??
        fallbackScheme?.sourceUrl;
    final sourceWebsite = raw['source_website']?.toString() ??
        bundled?['source_website']?.toString();

    // Eligibility rules from kBundledSchemeRules
    final rules = kBundledSchemeRules
        .where((r) => r.schemeId == id && r.isActive)
        .map((r) => {
              'name': r.attributeKey,
              'description': r.description ?? r.attributeKey,
              'mandatory': r.isMandatory,
            })
        .toList();

    // Documents from raw or extracted from eligibility summary
    List<dynamic> docs = raw['documents'] is List ? (raw['documents'] as List) : [];
    if (docs.isEmpty && eligibilitySummary != null && eligibilitySummary.isNotEmpty) {
      final lines = eligibilitySummary.split(RegExp(r'\n+|\r+|(?<=\.)\s*(?=\d+\.|\d+\)|\-)'));
      for (final line in lines) {
        final clean = line.replaceFirst(RegExp(r'^\s*(\d+[\.\)]|\-|\*)\s*'), '').trim();
        if (clean.length > 3 && clean.length < 120 && !clean.toLowerCase().contains('years old')) {
          docs.add({'name': clean, 'mandatory': true});
        }
      }
    }

    return {
      'id': id,
      'code': code,
      'name': name,
      'short_name': shortName,
      'description': description,
      'classification': {
        'level': level,
        'status': status,
        'active_enrollment': activeEnrollment,
        'launch_year': launchYear,
      },
      'geography': {
        'primary_state': stateName != null ? {'name': stateName} : null,
        'applicable_states': applicableStates,
      },
      'service_approach': {
        'name': raw['service_approach_name'] ?? 'Direct Benefit / Service',
      },
      'themes': themeName != null ? [{'name': themeName, 'color': themeColor}] : [],
      'beneficiary_types': raw['beneficiary_types'] is List ? raw['beneficiary_types'] : [],
      'target_groups': raw['target_groups'] is List ? raw['target_groups'] : [],
      'target_group_summary': targetGroupSummary,
      'eligibility_summary': eligibilitySummary,
      'eligibility_rules': raw['eligibility_rules'] is List ? raw['eligibility_rules'] : rules,
      'benefits': raw['benefits'] is List
          ? raw['benefits']
          : [
              if (benefitDesc != null || benefitType != null || benefitAmount != null)
                {
                  'type': benefitType ?? 'Benefit',
                  'description': benefitDesc,
                  'amount': benefitAmount,
                  'amount_text': benefitAmountText,
                }
            ],
      'documents': docs,
      'application': {
        'mode': appMode,
        'process': appProcess,
        'instructions': raw['application_instructions'],
        'csc_available': raw['csc_available'] == true,
        'physical_office': raw['physical_office'],
        'helpline': helpline,
        'portal_url': portalUrl,
      },
      'source': {
        'url': sourceUrl,
        'website': sourceWebsite,
      },
    };
  }

  Future<Map<String, dynamic>> getSchemeDetails(
    int id, {
    SchemeModel? fallbackScheme,
  }) async {
    final cacheKey = 'scheme_details_$id';

    try {
      final response = await _dio.get('/schemes/$id');
      final body = Map<String, dynamic>.from(response.data as Map);

      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Unable to load scheme details');
      }

      final data = Map<String, dynamic>.from(body['data'] as Map);

      await _saveCache(cacheKey, data);

      return data;
    } catch (error) {
      debugPrint('Scheme details API request failed for $id: $error');

      // Offline fallback 1: Check geography_cache for direct /schemes/$id cached response
      final cached = await _readCache(cacheKey);
      if (cached != null) return cached;

      // Offline fallback 2: Check SQLite scheme_cache
      try {
        final db = await _db;
        final rows = await db.query(
          'scheme_cache',
          columns: ['data'],
          where: 'scheme_id = ?',
          whereArgs: [id],
          limit: 1,
        );

        if (rows.isNotEmpty) {
          final map = Map<String, dynamic>.from(
            jsonDecode(rows.first['data'] as String) as Map,
          );
          return normalizeSchemeDetails(map, fallbackScheme: fallbackScheme);
        }
      } catch (_) {}

      // Offline fallback 3: Synthesize from kBundledSchemes or fallbackScheme
      final bundled = kBundledSchemes.cast<Map<String, dynamic>?>().firstWhere(
        (s) => s != null && (s['id'] == id || (fallbackScheme != null && s['scheme_code'] == fallbackScheme.code)),
        orElse: () => null,
      );

      if (bundled != null) {
        return normalizeSchemeDetails(bundled, fallbackScheme: fallbackScheme);
      }

      if (fallbackScheme != null) {
        return normalizeSchemeDetails(fallbackScheme.toJson(), fallbackScheme: fallbackScheme);
      }

      throw Exception(
        'Unable to load scheme details. No cached details are available. Details: $error',
      );
    }
  }
}
