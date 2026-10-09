import 'package:dio/dio.dart';

import '../models/login_request.dart';
import '../models/login_response.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

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

    final loginResponse =
    LoginResponse.fromJson(response.data);

    await StorageService.saveAccessToken(
      loginResponse.accessToken,
    );

    await StorageService.saveRefreshToken(
      loginResponse.refreshToken,
    );

    return loginResponse;
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