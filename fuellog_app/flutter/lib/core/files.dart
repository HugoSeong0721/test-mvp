/// CSV 를 밖으로 보내고(공유 시트·다운로드) 안으로 들여오기(파일 고르기). 테스트는 [FakeFiles].
library;

import 'dart:convert';
import 'dart:ui';

import 'package:file_selector/file_selector.dart';

import 'files_web.dart' if (dart.library.io) 'files_io.dart' as impl;

abstract class Files {
  static Files i = PlatformFiles();

  /// 공유 시트(아이폰: 파일에 저장·메일·AirDrop) 또는 다운로드(웹). 보냈으면 true.
  Future<bool> shareCsv(String fileName, String text, Rect? origin);

  /// CSV 파일을 고르면 내용, 취소하면 null.
  Future<String?> pickCsv();
}

class PlatformFiles extends Files {
  @override
  Future<bool> shareCsv(String fileName, String text, Rect? origin) => impl.shareCsv(fileName, text, origin);

  @override
  Future<String?> pickCsv() async {
    const group = XTypeGroup(
      label: 'CSV',
      extensions: ['csv', 'txt'],
      mimeTypes: ['text/csv', 'text/plain', 'text/comma-separated-values'],
      uniformTypeIdentifiers: ['public.comma-separated-values-text', 'public.plain-text', 'public.text'],
    );
    final f = await openFile(acceptedTypeGroups: const [group]);
    if (f == null) return null;
    final bytes = await f.readAsBytes();
    // 대부분 UTF-8. 깨진 글자가 있어도 숫자는 읽히게 allowMalformed.
    return utf8.decode(bytes, allowMalformed: true);
  }
}

class FakeFiles extends Files {
  String? nextPick;
  final shared = <(String, String)>[];

  @override
  Future<bool> shareCsv(String fileName, String text, Rect? origin) async {
    shared.add((fileName, text));
    return true;
  }

  @override
  Future<String?> pickCsv() async => nextPick;
}
