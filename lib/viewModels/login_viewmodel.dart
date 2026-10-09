import 'package:flutter/material.dart';

import '../data/models/login_request.dart';
import '../data/repository/auth_repository.dart';

import '../data/services/storage_service.dart';

class LoginViewModel extends ChangeNotifier {
  final AuthRepository _repository =
  AuthRepository();

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

      final language =
      await StorageService.getLanguage();

      final request = LoginRequest(
        username: username,
        password: password,
        language: language,
      );

      final response =
      await _repository.login(request);

      if (response.success) {
        return true;
      }

      errorMessage = response.message;

      return false;
    } catch (e) {
      errorMessage = e.toString();

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