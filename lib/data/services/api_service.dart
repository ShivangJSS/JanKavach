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

    Future<Map<String, dynamic>> getBeneficiaryDetails(int id) async {
      final response = await ApiService().dio.get(
        '/beneficiaries/$id',
      );

      final body = Map<String, dynamic>.from(response.data);

      if (body['success'] != true) {
        throw Exception(
          body['message'] ?? 'Failed to fetch beneficiary details',
        );
      }

      return Map<String, dynamic>.from(body['data']);
    }

    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
      ),
    );
  }
}