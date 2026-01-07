import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../languages/app_strings.dart';

class LanguageProvider with ChangeNotifier {
  String _currentLanguage = 'en';

  String get currentLanguage => _currentLanguage;

  Future<void> loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLanguage = prefs.getString('language') ?? 'en';
    notifyListeners();
  }

  Future<void> setLanguage(String languageCode) async {
    _currentLanguage = languageCode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', languageCode);
    notifyListeners();
  }

  String get(String key) {
    try {
      return AppStrings.languages[_currentLanguage]?[key] ?? 
             AppStrings.languages['en']?[key] ?? 
             key;
    } catch (e) {
      return key;
    }
  }
}