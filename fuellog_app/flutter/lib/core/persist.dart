/// 기록 파일을 어디에 두나. 아이폰: 앱 지원 폴더의 JSON 파일(+ 직전 사본), 웹 미리보기: 브라우저 저장소.
/// 테스트는 [MemoryPersist].
library;

import 'persist_web.dart' if (dart.library.io) 'persist_io.dart' as impl;

abstract class Persist {
  static Persist create() => impl.createPersist();

  /// 웹 미리보기 `?demo=1` 전용 칸 — 예시 기록이 진짜 기록 칸을 덮지 않게.
  static Persist demo() => impl.createDemoPersist();

  /// 저장된 글. 없으면 null.
  Future<String?> read();

  /// 직전에 저장됐던 글 (본 파일이 깨졌을 때 살리는 용도).
  Future<String?> readBackup();

  Future<void> write(String data);
}

class MemoryPersist implements Persist {
  MemoryPersist([this.data]);
  String? data;
  String? backup;
  int writes = 0;

  @override
  Future<String?> read() async => data;

  @override
  Future<String?> readBackup() async => backup;

  @override
  Future<void> write(String d) async {
    backup = data;
    data = d;
    writes++;
  }
}
