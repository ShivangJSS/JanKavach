import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../data/models/login_request.dart';
import '../data/repository/auth_repository.dart';
import '../data/services/storage_service.dart';

class LoginViewModel extends ChangeNotifier {
  final AuthRepository _repository = AuthRepository();

  bool isLoading = false;
  String? errorMessage;

  Future<bool> login(
      String username,
      String password,
      ) async {
    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();

      final language = await StorageService.getLanguage();

      final request = LoginRequest(
        username: username,
        password: password,
        language: language,
      );

      final response = await _repository.login(request);

      if (response.success) {
        return true;
      }

      errorMessage = response.message;
      return false;
    } catch (e) {
      bool isOffline = false;

      if (e is DioException) {
        if (e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.error is SocketException ||
            e.response == null) {
          isOffline = true;
        }
      } else if (e is SocketException) {
        isOffline = true;
      }

      if (isOffline) {
        final canLoginOffline = await StorageService.verifyOfflineCredentials(
          username,
          password,
        );

        if (canLoginOffline) {
          final currentToken = await StorageService.getAccessToken();
          if (currentToken == null || currentToken.isEmpty) {
            await StorageService.saveAccessToken('offline_session_token');
          }
          final profile = await StorageService.getUserProfile();
          if (profile == null) {
            await StorageService.saveUserProfile({
              'username': username,
              'name': username,
            });
          }
          return true;
        } else {
          final hasSavedCredentials = await StorageService.isOfflineLoginAvailable();
          if (hasSavedCredentials) {
            errorMessage =
            'No internet connection. Please enter the credentials used during your last online login.';
          } else {
            errorMessage =
            'No internet connection. Please connect to the internet to log in for the first time.';
          }
          return false;
        }
      }

      if (e is DioException) {
        if (e.response?.statusCode == 401 || e.response?.statusCode == 422) {
          final data = e.response?.data;
          errorMessage = (data is Map && data['message'] != null)
              ? data['message'].toString()
              : 'Invalid username or password.';
        } else {
          final data = e.response?.data;
          errorMessage = (data is Map && data['message'] != null)
              ? data['message'].toString()
              : (e.message ?? 'Server error. Please try again later.');
        }
      } else {
        errorMessage = e.toString();
      }

      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _repository.logout();
  }
}
