import 'package:dio/dio.dart';

import 'api_service.dart';
import 'storage_service.dart';

class AuthInterceptor extends Interceptor {
  bool _isRefreshing = false;

  String? _extractAccessToken(dynamic data) {
    if (data is! Map) return null;
    if (data['tokens'] is Map) {
      final tokens = data['tokens'] as Map;
      if (tokens['access_token'] != null) {
        return tokens['access_token'].toString();
      }
    }
    if (data['access_token'] != null) {
      return data['access_token'].toString();
    }
    return null;
  }

  String? _extractRefreshToken(dynamic data) {
    if (data is! Map) return null;
    if (data['tokens'] is Map) {
      final tokens = data['tokens'] as Map;
      if (tokens['refresh_token'] != null) {
        return tokens['refresh_token'].toString();
      }
    }
    if (data['refresh_token'] != null) {
      return data['refresh_token'].toString();
    }
    return null;
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip token handling for auth endpoints
    if (options.path.contains('/auth/login') ||
        options.path.contains('/auth/refresh')) {
      return handler.next(options);
    }

    String? token = await StorageService.getAccessToken();

    // If token is an offline placeholder, attempt silent background online login if credentials exist
    if (token == 'offline_session_token' || token == null || token.isEmpty) {
      final savedUser = await StorageService.getOfflineUsername();
      final savedPass = await StorageService.getOfflinePassword();

      if (savedUser != null && savedPass != null && !_isRefreshing) {
        try {
          final language = await StorageService.getLanguage();
          final loginResponse = await Dio().post(
            "${ApiService.baseUrl}/auth/login",
            data: {
              "username": savedUser,
              "password": savedPass,
              "language": language,
            },
            options: Options(
              headers: {
                "Accept": "application/json",
                "Content-Type": "application/json",
              },
              sendTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ),
          );

          if (loginResponse.data is Map && loginResponse.data["data"] is Map) {
            final data = Map<String, dynamic>.from(loginResponse.data["data"] as Map);
            final newAccessToken = _extractAccessToken(data);
            final newRefreshToken = _extractRefreshToken(data);

            if (newAccessToken != null && newAccessToken.isNotEmpty) {
              await StorageService.saveTokens(
                accessToken: newAccessToken,
                refreshToken: newRefreshToken ?? '',
              );
              token = newAccessToken;
            }
            if (data["user"] is Map) {
              await StorageService.saveUserProfile(
                Map<String, dynamic>.from(data["user"] as Map),
              );
            }
          }
        } catch (_) {}
      }
    }

    if (token != null && token.isNotEmpty && token != 'offline_session_token') {
      options.headers["Authorization"] = "Bearer $token";
    }

    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Skip for auth endpoints to prevent recursion
    if (err.requestOptions.path.contains('/auth/login') ||
        err.requestOptions.path.contains('/auth/refresh')) {
      return handler.next(err);
    }

    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }

    if (_isRefreshing) {
      return handler.next(err);
    }

    _isRefreshing = true;

    try {
      final language = await StorageService.getLanguage();
      String? newAccessToken;
      String? newRefreshToken;

      // 1. Try refresh token first if valid
      final refreshToken = await StorageService.getRefreshToken();
      if (refreshToken != null &&
          refreshToken.isNotEmpty &&
          refreshToken != 'offline_session_token') {
        try {
          final response = await Dio().post(
            "${ApiService.baseUrl}/auth/refresh",
            data: {
              "refresh_token": refreshToken,
              "language": language,
            },
            options: Options(
              headers: {
                "Accept": "application/json",
                "Content-Type": "application/json",
              },
              sendTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ),
          );

          if (response.data is Map && response.data["data"] is Map) {
            final data = Map<String, dynamic>.from(response.data["data"] as Map);
            newAccessToken = _extractAccessToken(data);
            newRefreshToken = _extractRefreshToken(data);
          }
        } catch (_) {}
      }

      // 2. If refresh token failed or was invalid, attempt silent re-login with saved credentials
      if (newAccessToken == null || newAccessToken.isEmpty) {
        final savedUser = await StorageService.getOfflineUsername();
        final savedPass = await StorageService.getOfflinePassword();

        if (savedUser != null && savedPass != null) {
          final loginResponse = await Dio().post(
            "${ApiService.baseUrl}/auth/login",
            data: {
              "username": savedUser,
              "password": savedPass,
              "language": language,
            },
            options: Options(
              headers: {
                "Accept": "application/json",
                "Content-Type": "application/json",
              },
              sendTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ),
          );

          if (loginResponse.data is Map && loginResponse.data["data"] is Map) {
            final data = Map<String, dynamic>.from(loginResponse.data["data"] as Map);
            newAccessToken = _extractAccessToken(data);
            newRefreshToken = _extractRefreshToken(data);
            if (data["user"] is Map) {
              await StorageService.saveUserProfile(
                Map<String, dynamic>.from(data["user"] as Map),
              );
            }
          }
        }
      }

      if (newAccessToken != null && newAccessToken.isNotEmpty) {
        await StorageService.saveTokens(
          accessToken: newAccessToken,
          refreshToken: newRefreshToken ?? '',
        );

        final request = err.requestOptions;
        request.headers["Authorization"] = "Bearer $newAccessToken";

        final retryResponse = await ApiService().dio.fetch(request);
        _isRefreshing = false;
        return handler.resolve(retryResponse);
      }

      _isRefreshing = false;
      return handler.next(err);
    } catch (e) {
      _isRefreshing = false;
      return handler.next(err);
    }
  }
}
