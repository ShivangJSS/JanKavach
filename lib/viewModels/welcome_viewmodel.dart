import 'package:flutter/material.dart';

import '../data/services/storage_service.dart';

class WelcomeViewModel extends ChangeNotifier {
  String selectedLanguage = "en";

  bool isCheckingAuth = true;
  bool isLoggedIn = false;

  WelcomeViewModel() {
    initialize();
  }

  Future<void> initialize() async {
    await loadLanguage();
    await checkAuth();
  }

  // ==========================
  // LANGUAGE
  // ==========================

  Future<void> loadLanguage() async {
    selectedLanguage =
    await StorageService.getLanguage();

    notifyListeners();
  }

  Future<void> setLanguage(
      String language,
      ) async {
    selectedLanguage = language;

    await StorageService.saveLanguage(
      language,
    );

    notifyListeners();
  }

  // ==========================
  // AUTH CHECK
  // ==========================

  Future<void> checkAuth() async {
    isCheckingAuth = true;
    notifyListeners();

    isLoggedIn =
    await StorageService.isLoggedIn();

    isCheckingAuth = false;

    notifyListeners();
  }
}