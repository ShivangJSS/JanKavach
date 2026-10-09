import 'package:dio/dio.dart';
import 'auth_interceptor.dart';

class ApiService {
  static final ApiService _instance =
  ApiService._internal();

  factory ApiService() => _instance;

  static const String baseUrl =
      "https://jankavach.indevconsultancy.in/public/api/mobile/user";

  late final Dio dio;

  ApiService._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
        },
      ),
    );

    dio.interceptors.add(
      AuthInterceptor(),
    );

    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
      ),
    );
  }
}