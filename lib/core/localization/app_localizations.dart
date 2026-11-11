import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  late Map<String, dynamic> _localizedStrings;

  /// Loads the language JSON file from assets/lang/{languageCode}.json
  Future<bool> load() async {
    String jsonString;
    try {
      jsonString = await rootBundle.loadString(
        'assets/lang/${locale.languageCode}.json',
      );
    } catch (_) {
      // Fallback to English if the specific language asset fails to load
      jsonString = await rootBundle.loadString('assets/lang/en.json');
    }

    final Map<String, dynamic> jsonMap = json.decode(jsonString);
    _localizedStrings = jsonMap;
    return true;
  }

  /// Translates a key using dot notation (e.g. 'registration.beneficiary_name').
  /// Supports dynamic variable replacement via [args] (e.g. { 'count': '5' }).
  String translate(String key, {Map<String, String>? args}) {
    final keys = key.split('.');
    dynamic current = _localizedStrings;

    for (final k in keys) {
      if (current is Map && current.containsKey(k)) {
        current = current[k];
      } else {
        return key; // Fallback to key if not found
      }
    }

    if (current is! String) {
      return key;
    }

    String result = current;
    if (args != null && args.isNotEmpty) {
      args.forEach((placeholder, value) {
        result = result.replaceAll('{$placeholder}', value);
      });
    }

    return result;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'hi', 'as'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

/// Convenience extension on BuildContext to allow `context.tr('key')`.
extension LocalizationExtension on BuildContext {
  String tr(String key, {Map<String, String>? args}) {
    return AppLocalizations.of(this)?.translate(key, args: args) ?? key;
  }
}
