import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  // Keys
  static const String languageKey = "language_code";
  static const String accessTokenKey = "access_token";
  static const String refreshTokenKey = "refresh_token";

  // ==========================
  // Language
  // ==========================

  static Future<void> saveLanguage(
      String language,
      ) async {
    final prefs =
    await SharedPreferences.getInstance();

    await prefs.setString(
      languageKey,
      language,
    );
  }

  static Future<String> getLanguage() async {
    final prefs =
    await SharedPreferences.getInstance();

    return prefs.getString(
      languageKey,
    ) ??
        "en";
  }

  // ==========================
  // Access Token
  // ==========================

  static Future<void> saveAccessToken(
      String token,
      ) async {
    final prefs =
    await SharedPreferences.getInstance();

    await prefs.setString(
      accessTokenKey,
      token,
    );
  }

  static Future<String?> getAccessToken() async {
    final prefs =
    await SharedPreferences.getInstance();

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
    final prefs =
    await SharedPreferences.getInstance();

    await prefs.setString(
      refreshTokenKey,
      token,
    );
  }

  static Future<String?> getRefreshToken() async {
    final prefs =
    await SharedPreferences.getInstance();

    return prefs.getString(
      refreshTokenKey,
    );
  }

  // ==========================
  // Login Status
  // ==========================

  static Future<bool> isLoggedIn() async {
    final token =
    await getAccessToken();

    return token != null &&
        token.isNotEmpty;
  }


  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await saveAccessToken(accessToken);
    await saveRefreshToken(refreshToken);
  }

  // ==========================
  // Logout / Clear Session
  // ==========================

  static Future<void> clearSession() async {
    final prefs =
    await SharedPreferences.getInstance();

    await prefs.remove(
      accessTokenKey,
    );

    await prefs.remove(
      refreshTokenKey,
    );
  }
}