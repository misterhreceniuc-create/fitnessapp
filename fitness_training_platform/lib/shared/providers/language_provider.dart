/// @file language_provider.dart
/// @brief Provider for managing application language
/// @details Manages current language state and provides translation helper

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/localization_service.dart';

class LanguageProvider with ChangeNotifier {
  String _currentLanguage = 'en';

  String get currentLanguage => _currentLanguage;

  LanguageProvider() {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentLanguage = prefs.getString('language') ?? 'en';
      notifyListeners();
    } catch (e) {
      print('Error loading language: $e');
    }
  }

  Future<void> setLanguage(String languageCode) async {
    if (_currentLanguage != languageCode) {
      _currentLanguage = languageCode;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('language', languageCode);
      } catch (e) {
        print('Error saving language: $e');
      }
      notifyListeners();
    }
  }

  String translate(String key, {Map<String, String>? params}) {
    return LocalizationService.translate(key, _currentLanguage, params: params);
  }

  // Convenience getter for shorter syntax
  String tr(String key, {Map<String, String>? params}) => translate(key, params: params);
}
