import 'dart:js_interop';
import 'dart:ui';

import 'package:web/web.dart' as web;

/// 웹 미리보기: 파일로 내려받기.
Future<bool> shareCsv(String fileName, String text, Rect? origin) async {
  final blob = web.Blob([text.toJS].toJS, web.BlobPropertyBag(type: 'text/csv'));
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName;
  web.document.body?.append(a);
  a.click();
  a.remove();
  web.URL.revokeObjectURL(url);
  return true;
}
