import 'dart:html' as html;

class AppLanguageStorageImpl {
  static Future<String?> getString(String key) async {
    return html.window.localStorage[key];
  }

  static Future<void> setString(String key, String value) async {
    html.window.localStorage[key] = value;
  }
}
