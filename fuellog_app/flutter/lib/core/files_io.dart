import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:share_plus/share_plus.dart';

Future<bool> shareCsv(String fileName, String text, Rect? origin) async {
  final bytes = Uint8List.fromList(utf8.encode(text));
  final r = await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, mimeType: 'text/csv', name: fileName)],
      fileNameOverrides: [fileName],
      sharePositionOrigin: origin,
    ),
  );
  return r.status != ShareResultStatus.dismissed;
}
