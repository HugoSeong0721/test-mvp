import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 숫자를 몰라도 읽히게 — 레벨 구간 이름과 색.
class Band {
  const Band(this.name, this.from, this.color);
  final String name;
  final double from;
  final Color color;
}

const bands = [
  Band('Quiet', -999, Color(0xFF3DDC97)),
  Band('Moderate', 40, Color(0xFF9BE15D)),
  Band('Loud', 65, Color(0xFFFFD43B)),
  Band('Very loud', 80, Color(0xFFFF9F43)),
  Band('Dangerous', 95, Color(0xFFFF6B5B)),
  Band('Painful', 120, Color(0xFFE8457C)),
];

Band bandOf(double db) {
  var b = bands.first;
  for (final x in bands) {
    if (db >= x.from) b = x;
  }
  return b;
}

/// "어느 정도 소리인가" 비유 표. 값은 CDC·NIDCD 가 쓰는 대표값 (dBA).
class Ref {
  const Ref(this.db, this.title, this.like, this.icon);
  final int db;
  final String title;

  /// 측정 화면에 뜨는 한 줄 비유.
  final String like;
  final IconData icon;
}

const refs = [
  Ref(10, 'Normal breathing', 'Like breathing', Icons.air),
  Ref(
    20,
    'Rustling leaves, ticking watch',
    'Like rustling leaves',
    Icons.eco_outlined,
  ),
  Ref(30, 'Soft whisper', 'Like a soft whisper', Icons.hearing),
  Ref(
    40,
    'Quiet library, fridge hum',
    'Like a quiet library',
    Icons.local_library_outlined,
  ),
  Ref(
    50,
    'Moderate rain, quiet office',
    'Like moderate rain',
    Icons.water_drop_outlined,
  ),
  Ref(
    60,
    'Normal conversation',
    'Like normal conversation',
    Icons.forum_outlined,
  ),
  Ref(
    70,
    'Washing machine, vacuum',
    'Like a vacuum cleaner',
    Icons.local_laundry_service_outlined,
  ),
  Ref(80, 'City traffic, lawnmower', 'Like a lawnmower', Icons.grass),
  Ref(
    90,
    'Power tools, leaf blower up close',
    'Like power tools',
    Icons.handyman_outlined,
  ),
  Ref(95, 'Motorcycle', 'Like a motorcycle', Icons.two_wheeler),
  Ref(
    100,
    'Subway train, car horn',
    'Like a subway train',
    Icons.train_outlined,
  ),
  Ref(
    110,
    'Rock concert, shouting in your ear',
    'Like a rock concert',
    Icons.speaker_outlined,
  ),
  Ref(
    120,
    'Siren up close, thunder',
    'Like a siren up close',
    Icons.campaign_outlined,
  ),
  Ref(140, 'Fireworks, gunshot', 'Like fireworks', Icons.celebration_outlined),
];

/// 지금 레벨에 가장 가까운 비유 (아래쪽 기준, 5 dB 여유).
Ref? refOf(double db) {
  if (db < 7) return null;
  Ref best = refs.first;
  for (final r in refs) {
    if (db + 5 >= r.db) best = r;
  }
  return best;
}

/// 지금 레벨을 한 줄 비유로: "Like normal conversation".
String likeText(double db) => refOf(db)?.like ?? 'Almost silent';

/// NIOSH 권고(85 dBA 8시간, 3 dB 마다 절반)에 따른 하루 허용 시간.
/// 85 dBA 미만이면 null (제한 없음).
Duration? nioshDailyLimit(double dba) {
  if (dba < 85) return null;
  final hours = 8 / math.pow(2, (dba - 85) / 3);
  return Duration(seconds: (hours * 3600).round());
}

String fmtLimit(Duration d) {
  if (d.inMinutes >= 60) {
    final h = d.inMinutes / 60;
    return h >= 2 || h == h.roundToDouble()
        ? '${h.round()} hr'
        : '${h.toStringAsFixed(1)} hr';
  }
  if (d.inMinutes >= 1) return '${d.inMinutes} min';
  return '${math.max(1, d.inSeconds)} sec';
}
