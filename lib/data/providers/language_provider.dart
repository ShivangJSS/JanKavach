import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class LanguageOption {
  final String code;
  final String name;
  final String nativeName;
  final String flag;

  const LanguageOption({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.flag,
  });
}

class LanguageProvider extends ChangeNotifier {
  static const List<LanguageOption> supportedLanguages = [
    LanguageOption(
      code: 'en',
      name: 'English',
      nativeName: 'English',
      flag: '🇬🇧',
    ),
    LanguageOption(
      code: 'hi',
      name: 'Hindi',
      nativeName: 'हिन्दी',
      flag: '🇮🇳',
    ),
    LanguageOption(
      code: 'as',
      name: 'Assamese',
      nativeName: 'অসমীয়া',
      flag: '🇮🇳',
    ),
  ];

  Locale _currentLocale = const Locale('en');

  Locale get currentLocale => _currentLocale;
  String get currentLanguageCode => _currentLocale.languageCode;

  LanguageOption get currentLanguageOption =>
      supportedLanguages.firstWhere(
        (lang) => lang.code == _currentLocale.languageCode,
        orElse: () => supportedLanguages.first,
      );

  LanguageProvider() {
    _loadSavedLanguage();
  }

  Future<void> _loadSavedLanguage() async {
    try {
      final savedCode = await StorageService.getLanguage();
      if (['en', 'hi', 'as'].contains(savedCode)) {
        _currentLocale = Locale(savedCode);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> setLanguage(String code) async {
    if (!['en', 'hi', 'as'].contains(code)) return;
    if (_currentLocale.languageCode == code) return;

    _currentLocale = Locale(code);
    await StorageService.saveLanguage(code);
    notifyListeners();
  }
}
