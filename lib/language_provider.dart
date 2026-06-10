import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  Locale _locale = const Locale('fr'); // Default to French as it's common in Tunisia

  Locale get locale => _locale;

  LanguageProvider() {
    _loadLocale();
  }

  void _loadLocale() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? languageCode = prefs.getString('language_code');
    if (languageCode != null) {
      _locale = Locale(languageCode);
      notifyListeners();
    }
  }

  void changeLanguage(String languageCode) async {
    _locale = Locale(languageCode);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', languageCode);
    notifyListeners();
  }
}
