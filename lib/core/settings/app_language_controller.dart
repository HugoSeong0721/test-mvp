import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { english, korean }

class AppLanguageController extends ChangeNotifier {
  AppLanguageController._();

  static const _storageKey = 'app_language';
  static final AppLanguageController instance = AppLanguageController._();

  AppLanguage _language = AppLanguage.english;

  AppLanguage get language => _language;
  bool get isEnglish => _language == AppLanguage.english;
  bool get isKorean => _language == AppLanguage.korean;

  String tr(String english, String korean) {
    return isEnglish ? english : korean;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_storageKey);
    if (saved == 'korean') {
      _language = AppLanguage.korean;
    } else {
      _language = AppLanguage.english;
    }
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (_language == language) {
      return;
    }
    _language = language;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      language == AppLanguage.korean ? 'korean' : 'english',
    );
  }
}
