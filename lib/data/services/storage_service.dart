import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../local/app_database.dart';
import '../models/dashboard_response.dart';
import '../models/followup_model.dart';
import '../models/master_data_download_result.dart';

class UserAssignedLocation {
  final int? stateId;
  final int? districtId;
  final int? blockId;

  const UserAssignedLocation({
    this.stateId,
    this.districtId,
    this.blockId,
  });

  bool get hasAssignedState => stateId != null && stateId! > 0;
  bool get hasAssignedDistrict => districtId != null && districtId! > 0;
  bool get hasAssignedBlock => blockId != null && blockId! > 0;

  Map<String, int?> toMap() => {
    'state_id': stateId,
    'district_id': districtId,
    'block_id': blockId,
  };
}

class StorageService {
  // Keys
  static const String languageKey = "language_code";
  static const String accessTokenKey = "access_token";
  static const String refreshTokenKey = "refresh_token";

  // =============================
  // User details from login
  // =============================
  static const String userProfileKey = 'user_profile';
  static const String currentUserIdKey = 'current_active_user_id';
  static const String lastIsolatedUserIdKey = 'last_isolated_user_id';

  static Future<String?> getCurrentUserId() async {
    final profile = await getUserProfile();
    if (profile == null) return null;
    return profile['id']?.toString() ??
        profile['user_code']?.toString() ??
        profile['username']?.toString();
  }

  static Future<void> saveUserProfile(
    Map<String, dynamic> user,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final newId = user['id']?.toString() ??
        user['user_code']?.toString() ??
        user['username']?.toString();

    final previousId = prefs.getString(currentUserIdKey);
    if (previousId != null && newId != null && previousId != newId) {
      // User switch detected! Clear previous user's private cached data
      await clearUserScopedCache();
      await AppDatabase.instance.clearUserScopedData();
    }

    if (newId != null && newId.isNotEmpty) {
      await prefs.setString(currentUserIdKey, newId);
      await prefs.setString(lastIsolatedUserIdKey, newId);
    }

    // Preserve existing location if not present in new payload
    final existingJson = prefs.getString(userProfileKey);
    Map<String, dynamic> merged = {};
    if (existingJson != null && existingJson.isNotEmpty) {
      try {
        merged = Map<String, dynamic>.from(jsonDecode(existingJson) as Map);
      } catch (_) {}
    }
    merged.addAll(user);

    // If new user payload does not include 'location' or has null location,
    // preserve existing valid location from previously cached profile.
    if (user['location'] == null && merged['location'] == null) {
      if (user['state_id'] != null ||
          user['district_id'] != null ||
          user['block_id'] != null) {
        merged['location'] = {
          'state_id': user['state_id'],
          'district_id': user['district_id'],
          'block_id': user['block_id'],
        };
      }
    } else if (user['location'] == null && existingJson != null) {
      try {
        final existingMap = jsonDecode(existingJson) as Map;
        if (existingMap['location'] != null) {
          merged['location'] = existingMap['location'];
        }
      } catch (_) {}
    }

    await prefs.setString(
      userProfileKey,
      jsonEncode(merged),
    );
  }

  static Future<void> clearUserScopedCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(dashboardSummaryKey);
    await prefs.remove('${dashboardSummaryKey}_owner');
    await prefs.remove(followupDashboardKey);
    await prefs.remove('${followupDashboardKey}_owner');

    final allKeys = prefs.getKeys();
    for (final key in allKeys) {
      if (key.startsWith('${dashboardSummaryKey}_') ||
          key.startsWith('${followupDashboardKey}_')) {
        await prefs.remove(key);
      }
    }
  }

  static Future<void> ensureUserCacheIsolation() async {
    final profile = await getUserProfile();
    if (profile == null) return;

    final currentId = profile['id']?.toString() ??
        profile['user_code']?.toString() ??
        profile['username']?.toString();

    if (currentId == null || currentId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final lastIsolatedId = prefs.getString(lastIsolatedUserIdKey);

    // Always ensure foreign drafts from other users or un-owned legacy records are purged!
    await AppDatabase.instance.clearUserScopedData(keepUserId: currentId);

    if (lastIsolatedId != currentId) {
      // First run for this user or user identity switch detected!
      // Clear old user's leaked cache and bind to current user
      await clearUserScopedCache();
      await AppDatabase.instance.clearUserScopedData();
      await prefs.setString(lastIsolatedUserIdKey, currentId);
      await prefs.setString(currentUserIdKey, currentId);
    }
  }

  static Future<Map<String, dynamic>?> getUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(userProfileKey);

    if (json == null || json.isEmpty) {
      return null;
    }

    try {
      return Map<String, dynamic>.from(
        jsonDecode(json) as Map,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<UserAssignedLocation?> getUserAssignedLocation() async {
    final profile = await getUserProfile();
    if (profile == null) return null;

    int? parseInt(dynamic val) {
      if (val == null) return null;
      if (val is int) return val;
      if (val is num) return val.toInt();
      return int.tryParse(val.toString());
    }

    int? stateId;
    int? districtId;
    int? blockId;

    if (profile['location'] is Map) {
      final loc = Map<String, dynamic>.from(profile['location'] as Map);
      stateId = parseInt(loc['state_id']);
      districtId = parseInt(loc['district_id']);
      blockId = parseInt(loc['block_id']);
    }

    stateId ??= parseInt(profile['state_id']);
    districtId ??= parseInt(profile['district_id']);
    blockId ??= parseInt(profile['block_id']);

    if (stateId == null && districtId == null && blockId == null) {
      return null;
    }

    return UserAssignedLocation(
      stateId: stateId,
      districtId: districtId,
      blockId: blockId,
    );
  }

  // ==========================
  // Language
  // ==========================
  static Future<void> saveLanguage(
      String language,
      ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      languageKey,
      language,
    );
  }

  static Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(
      languageKey,
    ) ?? "en";
  }

  // ==========================
  // Access Token
  // ==========================
  static Future<void> saveAccessToken(
      String token,
      ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      accessTokenKey,
      token,
    );
  }

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(
      accessTokenKey,
    );
  }

  // ==========================
  // Refresh Token
  // ==========================
  static Future<void> saveRefreshToken(
      String token,
      ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      refreshTokenKey,
      token,
    );
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(
      refreshTokenKey,
    );
  }

  // ==========================
  // Login Status
  // ==========================
  static Future<bool> isLoggedIn() async {
    final token = await getAccessToken();

    return token != null && token.isNotEmpty;
  }

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await saveAccessToken(accessToken);
    await saveRefreshToken(refreshToken);
  }

  // ==========================
  // Offline Login Credentials
  // ==========================
  static const String offlineUsernameKey = "offline_username";
  static const String offlinePasswordKey = "offline_password";

  static Future<void> saveOfflineCredentials({
    required String username,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(offlineUsernameKey, username.trim().toLowerCase());
    await prefs.setString(offlinePasswordKey, password);
  }

  static Future<String?> getOfflineUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(offlineUsernameKey);
  }

  static Future<String?> getOfflinePassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(offlinePasswordKey);
  }

  static Future<bool> isOfflineLoginAvailable() async {
    final prefs = await SharedPreferences.getInstance();
    final user = prefs.getString(offlineUsernameKey);
    final pass = prefs.getString(offlinePasswordKey);
    return user != null && user.isNotEmpty && pass != null && pass.isNotEmpty;
  }

  static Future<bool> verifyOfflineCredentials(
      String username,
      String password,
      ) async {
    final prefs = await SharedPreferences.getInstance();
    final savedUser = prefs.getString(offlineUsernameKey);
    final savedPass = prefs.getString(offlinePasswordKey);

    if (savedUser == null || savedPass == null) return false;

    return savedUser.trim().toLowerCase() == username.trim().toLowerCase() &&
        savedPass == password;
  }

  // ==========================
  // Dashboard Summary & Metrics Caching
  // ==========================
  static const String dashboardSummaryKey = 'dashboard_summary_cache';
  static const String followupDashboardKey = 'followup_dashboard_cache';

  static Future<void> saveDashboardSummary(
    DashboardSummary summary, {
    String? userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = userId ?? await getCurrentUserId();
    final encoded = jsonEncode(summary.toJson());

    await prefs.setString(dashboardSummaryKey, encoded);
    if (uid != null && uid.isNotEmpty) {
      await prefs.setString('${dashboardSummaryKey}_$uid', encoded);
      await prefs.setString('${dashboardSummaryKey}_owner', uid);
    }
  }

  static Future<DashboardSummary?> getDashboardSummary({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = userId ?? await getCurrentUserId();

    if (uid != null && uid.isNotEmpty) {
      final userSpecific = prefs.getString('${dashboardSummaryKey}_$uid');
      if (userSpecific != null && userSpecific.isNotEmpty) {
        try {
          final map = Map<String, dynamic>.from(jsonDecode(userSpecific) as Map);
          return DashboardSummary.fromJson(map);
        } catch (_) {}
      }

      final owner = prefs.getString('${dashboardSummaryKey}_owner');
      if (owner != null && owner != uid) {
        return null;
      }
    }

    final jsonStr = prefs.getString(dashboardSummaryKey);
    if (jsonStr == null || jsonStr.isEmpty) {
      return null;
    }
    try {
      final map = Map<String, dynamic>.from(jsonDecode(jsonStr) as Map);
      return DashboardSummary.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveFollowupDashboard(
    FollowupDashboardData data, {
    String? userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = userId ?? await getCurrentUserId();
    final encoded = jsonEncode(data.toJson());

    await prefs.setString(followupDashboardKey, encoded);
    if (uid != null && uid.isNotEmpty) {
      await prefs.setString('${followupDashboardKey}_$uid', encoded);
      await prefs.setString('${followupDashboardKey}_owner', uid);
    }
  }

  static Future<FollowupDashboardData?> getFollowupDashboard({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = userId ?? await getCurrentUserId();

    if (uid != null && uid.isNotEmpty) {
      final userSpecific = prefs.getString('${followupDashboardKey}_$uid');
      if (userSpecific != null && userSpecific.isNotEmpty) {
        try {
          final map = Map<String, dynamic>.from(jsonDecode(userSpecific) as Map);
          return FollowupDashboardData.fromJson(map);
        } catch (_) {}
      }

      final owner = prefs.getString('${followupDashboardKey}_owner');
      if (owner != null && owner != uid) {
        return null;
      }
    }

    final jsonStr = prefs.getString(followupDashboardKey);
    if (jsonStr == null || jsonStr.isEmpty) {
      return null;
    }
    try {
      final map = Map<String, dynamic>.from(jsonDecode(jsonStr) as Map);
      return FollowupDashboardData.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  // ==========================
  // Master Data Download Cache
  // ==========================
  static const String masterDataSummaryKey = 'master_data_download_summary';

  static Future<void> saveMasterDataDownloadSummary(MasterDataDownloadResult result) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(masterDataSummaryKey, jsonEncode(result.toJson()));
  }

  static Future<MasterDataDownloadResult?> getMasterDataDownloadSummary() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(masterDataSummaryKey);
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      final map = Map<String, dynamic>.from(jsonDecode(jsonStr) as Map);
      return MasterDataDownloadResult.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  // ==========================
  // Already Applied Schemes per Beneficiary
  // ==========================
  static String _appliedSchemesKey(int beneficiaryId, [String? beneficiaryCode]) {
    if (beneficiaryCode != null && beneficiaryCode.trim().isNotEmpty) {
      return 'applied_schemes_code_${beneficiaryCode.trim()}';
    }
    return 'applied_schemes_id_$beneficiaryId';
  }

  static String _appliedSurveyCompletedKey(int beneficiaryId, [String? beneficiaryCode]) {
    if (beneficiaryCode != null && beneficiaryCode.trim().isNotEmpty) {
      return 'applied_survey_completed_code_${beneficiaryCode.trim()}';
    }
    return 'applied_survey_completed_id_$beneficiaryId';
  }

  static Future<Set<String>> getAppliedSchemeCodes(
    int beneficiaryId, [
    String? beneficiaryCode,
  ]) async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? list;
    if (beneficiaryCode != null && beneficiaryCode.trim().isNotEmpty) {
      list = prefs.getStringList(_appliedSchemesKey(beneficiaryId, beneficiaryCode));
    }
    list ??= prefs.getStringList(_appliedSchemesKey(beneficiaryId));
    return list?.toSet() ?? <String>{};
  }

  static Future<void> saveAppliedSchemeCodes(
    int beneficiaryId,
    Set<String> schemeCodes, [
    String? beneficiaryCode,
  ]) async {
    final prefs = await SharedPreferences.getInstance();
    final list = schemeCodes.toList();
    await prefs.setStringList(_appliedSchemesKey(beneficiaryId), list);
    await prefs.setBool(_appliedSurveyCompletedKey(beneficiaryId), true);
    if (beneficiaryCode != null && beneficiaryCode.trim().isNotEmpty) {
      await prefs.setStringList(
        _appliedSchemesKey(beneficiaryId, beneficiaryCode),
        list,
      );
      await prefs.setBool(
        _appliedSurveyCompletedKey(beneficiaryId, beneficiaryCode),
        true,
      );
    }
  }

  static Future<bool> hasCompletedAppliedSurvey(
    int beneficiaryId, [
    String? beneficiaryCode,
  ]) async {
    final prefs = await SharedPreferences.getInstance();
    if (beneficiaryCode != null && beneficiaryCode.trim().isNotEmpty) {
      final codeCompleted = prefs.getBool(
        _appliedSurveyCompletedKey(beneficiaryId, beneficiaryCode),
      );
      if (codeCompleted != null) return codeCompleted;
    }
    return prefs.getBool(_appliedSurveyCompletedKey(beneficiaryId)) ?? false;
  }

  static Future<void> resetAppliedSurvey(
    int beneficiaryId, [
    String? beneficiaryCode,
  ]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_appliedSurveyCompletedKey(beneficiaryId));
    await prefs.remove(_appliedSchemesKey(beneficiaryId));
    if (beneficiaryCode != null && beneficiaryCode.trim().isNotEmpty) {
      await prefs.remove(_appliedSurveyCompletedKey(beneficiaryId, beneficiaryCode));
      await prefs.remove(_appliedSchemesKey(beneficiaryId, beneficiaryCode));
    }
  }

  // ==========================
  // Logout / Clear Session
  // ==========================
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(accessTokenKey);
    await prefs.remove(refreshTokenKey);
  }
}
