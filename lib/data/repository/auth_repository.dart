import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/dashboard_response.dart';
import '../models/login_request.dart';
import '../models/login_response.dart';
import '../models/master_data_download_result.dart';
import '../services/api_service.dart';
import '../services/geography_service.dart';
import '../services/storage_service.dart';
import 'followup_repository.dart';

class AuthRepository {
  final ApiService _apiService = ApiService();

  // ==========================
  // LOGIN
  // ==========================
  Future<LoginResponse> login(
      LoginRequest request,
      ) async {
    final response = await _apiService.dio.post(
      "/auth/login",
      data: request.toJson(),
    );

    final data = Map<String, dynamic>.from(
      response.data['data'] as Map,
    );

    final user = Map<String, dynamic>.from(
      data['user'] as Map,
    );

    await StorageService.saveUserProfile(user);

    final loginResponse =
    LoginResponse.fromJson(response.data);

    await StorageService.saveAccessToken(
      loginResponse.accessToken,
    );

    await StorageService.saveRefreshToken(
      loginResponse.refreshToken,
    );

    // Persist credentials for offline authentication
    await StorageService.saveOfflineCredentials(
      username: request.username,
      password: request.password,
    );

    // Pre-fetch dashboard to retrieve full user location assignment
    try {
      final dashRes = await _apiService.dio.get('/dashboard');
      if (dashRes.data is Map && dashRes.data['data'] is Map) {
        final dashData = Map<String, dynamic>.from(dashRes.data['data'] as Map);
        if (dashData['user'] is Map) {
          await StorageService.saveUserProfile(
            Map<String, dynamic>.from(dashData['user'] as Map),
          );
        }
        if (dashData['summary'] is Map) {
          var summary = DashboardSummary.fromJson(
            Map<String, dynamic>.from(dashData['summary'] as Map),
          );
          try {
            final followupMetrics = await FollowupRepository().getDashboardMetrics();
            final dueTotal = followupMetrics.today + followupMetrics.upcoming + followupMetrics.overdue;
            final effectiveDue = dueTotal > 0
                ? dueTotal
                : (followupMetrics.pending > 0 ? followupMetrics.pending : summary.followupsDone);
            summary = summary.copyWith(
              beneficiariesRegistered: summary.beneficiariesRegistered > 0
                  ? summary.beneficiariesRegistered
                  : followupMetrics.totalUsersRegistered,
              applicationsSubmitted: followupMetrics.totalApplied > 0
                  ? followupMetrics.totalApplied
                  : summary.applicationsSubmitted,
              applicationsApproved: followupMetrics.complete > 0
                  ? followupMetrics.complete
                  : summary.applicationsApproved,
              followupsDone: effectiveDue > 0 ? effectiveDue : summary.followupsDone,
            );
            await StorageService.saveFollowupDashboard(followupMetrics);
          } catch (_) {}
          await StorageService.saveDashboardSummary(summary);
        }
      }
    } catch (e) {
      debugPrint('Pre-fetching user location during login: $e');
    }

    // Opportunistically download master data in background so offline registration is ready
    GeographyService().downloadMasterData().catchError((e) {
      debugPrint('Background master data download on login: $e');
      return MasterDataDownloadResult(
        success: false,
        message: e.toString(),
        stateCount: 0,
        districtCount: 0,
        blockCount: 0,
        gramPanchayatCount: 0,
        villageCount: 0,
        downloadedAt: DateTime.now(),
      );
    });

    return loginResponse;
  }

  // ==========================
  // SILENT RE-LOGIN WITH SAVED CREDENTIALS
  // ==========================
  Future<bool> loginSilentWithSavedCredentials() async {
    try {
      final username = await StorageService.getOfflineUsername();
      final password = await StorageService.getOfflinePassword();

      if (username == null || password == null || username.isEmpty || password.isEmpty) {
        return false;
      }

      final language = await StorageService.getLanguage();
      final response = await _apiService.dio.post(
        "/auth/login",
        data: {
          "username": username,
          "password": password,
          "language": language,
        },
      );

      final body = Map<String, dynamic>.from(response.data as Map);
      if (body['data'] is! Map) return false;

      final data = Map<String, dynamic>.from(body['data'] as Map);
      String? accessToken;
      String? refreshToken;

      if (data['tokens'] is Map) {
        final tokens = data['tokens'] as Map;
        accessToken = tokens['access_token']?.toString();
        refreshToken = tokens['refresh_token']?.toString();
      } else {
        accessToken = data['access_token']?.toString();
        refreshToken = data['refresh_token']?.toString();
      }

      if (accessToken == null || accessToken.isEmpty) {
        return false;
      }

      await StorageService.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken ?? '',
      );

      if (data['user'] is Map) {
        final user = Map<String, dynamic>.from(data['user'] as Map);
        await StorageService.saveUserProfile(user);
      }

      return true;
    } catch (e) {
      debugPrint('Silent re-authentication failed: $e');
      return false;
    }
  }

  // ==========================
  // REFRESH TOKEN
  // ==========================
  Future<bool> refreshToken() async {
    try {
      final refreshToken =
      await StorageService.getRefreshToken();

      if (refreshToken == null) {
        return false;
      }

      final language =
      await StorageService.getLanguage();

      final response =
      await _apiService.dio.post(
        "/auth/refresh",
        data: {
          "refresh_token": refreshToken,
          "language": language,
        },
      );

      final data = response.data["data"];

      await StorageService.saveAccessToken(
        data["access_token"],
      );

      await StorageService.saveRefreshToken(
        data["refresh_token"],
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  // ==========================
  // LOGOUT
  // ==========================
  Future<void> logout() async {
    try {
      final accessToken =
      await StorageService.getAccessToken();

      await _apiService.dio.post(
        "/auth/logout",
        options: Options(
          headers: {
            "Authorization":
            "Bearer $accessToken",
          },
        ),
      );
    } catch (_) {
      // ignore api error
    }

    await StorageService.clearSession();
  }
}
