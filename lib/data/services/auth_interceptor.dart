import 'package:dio/dio.dart';

import 'api_service.dart';
import 'storage_service.dart';

class AuthInterceptor extends Interceptor {

  bool _isRefreshing = false;

  @override
  Future<void> onRequest(
      RequestOptions options,
      RequestInterceptorHandler handler,
      ) async {

    final token =
    await StorageService.getAccessToken();

    if (token != null &&
        token.isNotEmpty) {
      options.headers["Authorization"] =
      "Bearer $token";
    }

    handler.next(options);
  }

  @override
  Future<void> onError(
      DioException err,
      ErrorInterceptorHandler handler,
      ) async {

    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }

    if (_isRefreshing) {
      return handler.next(err);
    }

    _isRefreshing = true;

    try {

      final refreshToken =
      await StorageService.getRefreshToken();

      final language =
      await StorageService.getLanguage();

      if (refreshToken == null) {
        _isRefreshing = false;
        return handler.next(err);
      }

      print("=========== TOKEN EXPIRED ===========");
      print("Calling Refresh API...");

      final response = await Dio().post(
        "${ApiService.baseUrl}/auth/refresh",
        data: {
          "refresh_token": refreshToken,
          "language": language,
        },
      );

      final data = response.data["data"];

      final newAccessToken =
      data["access_token"];

      final newRefreshToken =
      data["refresh_token"];

      await StorageService.saveTokens(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
      );

      final request =
          err.requestOptions;

      request.headers["Authorization"] =
      "Bearer $newAccessToken";

      final retryResponse =
      await ApiService()
          .dio
          .fetch(request);

      _isRefreshing = false;

      return handler.resolve(
        retryResponse,
      );

    } catch (e) {

      _isRefreshing = false;

      await StorageService.clearSession();

      return handler.next(err);
    }
  }
}