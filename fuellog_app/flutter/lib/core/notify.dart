/// 정비 알림을 아이폰 로컬 알림으로 예약한다. 서버 없음 — 기록이 바뀔 때마다 전부 다시 예약.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class PlannedNotice {
  const PlannedNotice(this.id, this.when, this.title, this.body);
  final int id;
  final DateTime when;
  final String title, body;

  @override
  String toString() => '$id @ $when: $title — $body';
}

abstract class Notifier {
  static Notifier i = kIsWeb ? FakeNotifier(supported: false) : LocalNotifier();

  /// 이 기기에서 알림이 뜨나 (웹 미리보기는 안 뜬다 → 화면에 그렇게 적는다).
  bool get supported;

  Future<void> init();

  /// 알림 허락을 묻는다 (이미 정했으면 그 답). 허락이면 true.
  Future<bool> requestPermission();

  /// 예약을 이 목록으로 통째로 바꾼다.
  Future<void> sync(List<PlannedNotice> notices);
}

/// iOS 는 앱 하나당 예약 64개까지 — 넉넉히 60개.
const maxNotices = 60;

class LocalNotifier extends Notifier {
  final _p = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  @override
  bool get supported => true;

  @override
  Future<void> init() async {
    try {
      await _p.initialize(
        settings: const InitializationSettings(
          // 처음 켤 때 묻지 않는다 — 알림을 처음 만들 때 묻는다
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('notifications init failed: $e');
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (!_ready) return false;
    try {
      final ios = _p.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      return await ios?.requestPermissions(alert: true, sound: true) ?? false;
    } catch (e) {
      debugPrint('notification permission failed: $e');
      return false;
    }
  }

  @override
  Future<void> sync(List<PlannedNotice> notices) async {
    if (!_ready) return;
    try {
      await _p.cancelAll();
      for (final n in notices.take(maxNotices)) {
        await _p.zonedSchedule(
          id: n.id,
          title: n.title,
          body: n.body,
          // 그 순간(절대 시각)에 울린다 — 시간대 데이터 없이 UTC 로 넘긴다
          scheduledDate: tz.TZDateTime.from(n.when, tz.UTC),
          notificationDetails: const NotificationDetails(iOS: DarwinNotificationDetails()),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (e) {
      debugPrint('notification schedule failed: $e');
    }
  }
}

/// 테스트·웹 미리보기용 — 예약한 목록만 기억한다.
class FakeNotifier extends Notifier {
  FakeNotifier({this.supported = true, this.allow = true});

  @override
  final bool supported;
  bool allow;
  int asked = 0;
  List<PlannedNotice> scheduled = [];

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async {
    asked++;
    return allow;
  }

  @override
  Future<void> sync(List<PlannedNotice> notices) async {
    scheduled = notices.take(maxNotices).toList();
  }
}
