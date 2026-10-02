import 'package:shared_preferences/shared_preferences.dart';

import 'persist.dart';

Persist createPersist() => PrefsPersist();
Persist createDemoPersist() => PrefsPersist('fuellog.demo');

/// 웹 미리보기: 브라우저 저장소(localStorage). 이 브라우저에만 남는다.
class PrefsPersist implements Persist {
  PrefsPersist([this.key = 'fuellog']);
  final String key;
  SharedPreferences? _p;
  Future<SharedPreferences> get _prefs async => _p ??= await SharedPreferences.getInstance();

  @override
  Future<String?> read() async => (await _prefs).getString(key);

  @override
  Future<String?> readBackup() async => (await _prefs).getString('$key.bak');

  @override
  Future<void> write(String data) async {
    final p = await _prefs;
    final old = p.getString(key);
    if (old != null) await p.setString('$key.bak', old);
    await p.setString(key, data);
  }
}
