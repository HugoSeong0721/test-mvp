class AppLanguageStorageImpl {
  static final Map<String, String> _memory = <String, String>{};

  static Future<String?> getString(String key) async => _memory[key];

  static Future<void> setString(String key, String value) async {
    _memory[key] = value;
  }
}
