import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// 공유 시트·외부 링크를 갈아끼울 수 있게 감싼다 (테스트에서는 기록만).
abstract class Outside {
  static Outside i = PlatformOutside();

  /// 리포트 이미지를 공유 시트로 (iOS 공유 시트의 "Save Image" 로 사진에 저장된다).
  Future<bool> shareImage(
    Uint8List png,
    String fileName,
    String text,
    Rect? origin,
  );

  Future<bool> openUrl(String url);

  /// iOS 설정 앱의 이 앱 화면 (마이크 권한 켜기).
  Future<bool> openAppSettings() => openUrl('app-settings:');
}

class PlatformOutside extends Outside {
  @override
  Future<bool> shareImage(
    Uint8List png,
    String fileName,
    String text,
    Rect? origin,
  ) async {
    try {
      final r = await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(png, mimeType: 'image/png', name: fileName)],
          fileNameOverrides: [fileName],
          subject: text,
          sharePositionOrigin: origin,
          downloadFallbackEnabled: true,
        ),
      );
      return r.status != ShareResultStatus.unavailable;
    } catch (e) {
      debugPrint('share failed: $e');
      return false;
    }
  }

  @override
  Future<bool> openUrl(String url) async {
    try {
      return await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('open $url failed: $e');
      return false;
    }
  }
}

class FakeOutside extends Outside {
  final List<String> calls = [];
  Uint8List? lastImage;
  bool ok = true;

  @override
  Future<bool> shareImage(
    Uint8List png,
    String fileName,
    String text,
    Rect? origin,
  ) async {
    lastImage = png;
    calls.add('share:$fileName');
    return ok;
  }

  @override
  Future<bool> openUrl(String url) async {
    calls.add('open:$url');
    return ok;
  }
}
