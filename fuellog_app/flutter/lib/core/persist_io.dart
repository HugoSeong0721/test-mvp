import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'persist.dart';

Persist createPersist() => FilePersist();
Persist createDemoPersist() => MemoryPersist();

/// 앱 지원 폴더(Library/Application Support) — 아이폰 iCloud·컴퓨터 백업에 들어가고, 사용자 파일 앱에는 안 보인다.
/// 쓰기: 임시 파일에 다 쓴 뒤 이름 바꾸기 → 쓰다 꺼져도 반쯤 쓴 파일이 남지 않는다. 직전 본은 .bak 으로 남긴다.
class FilePersist implements Persist {
  Directory? _dir;

  Future<File> _file(String name) async {
    _dir ??= await getApplicationSupportDirectory();
    await _dir!.create(recursive: true);
    return File('${_dir!.path}/$name');
  }

  Future<String?> _readOf(String name) async {
    final f = await _file(name);
    return await f.exists() ? f.readAsString() : null;
  }

  @override
  Future<String?> read() => _readOf('fuellog.json');

  @override
  Future<String?> readBackup() => _readOf('fuellog.bak.json');

  @override
  Future<void> write(String data) async {
    final main = await _file('fuellog.json');
    final tmp = await _file('fuellog.tmp.json');
    await tmp.writeAsString(data, flush: true);
    if (await main.exists()) {
      await main.rename((await _file('fuellog.bak.json')).path);
    }
    await tmp.rename(main.path);
  }
}
