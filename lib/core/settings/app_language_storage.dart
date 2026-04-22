import 'app_language_storage_stub.dart'
    if (dart.library.html) 'app_language_storage_web.dart';

class AppLanguageStorage {
  static Future<String?> getString(String key) =>
      AppLanguageStorageImpl.getString(key);

  static Future<void> setString(String key, String value) =>
      AppLanguageStorageImpl.setString(key, value);
}
