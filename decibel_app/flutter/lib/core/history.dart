import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'levels.dart';
import 'meter.dart';

/// 측정 한 번의 기록 (리포트·기록 목록에 쓰인다). 소리는 없고 숫자만 남는다.
///
/// 1초마다 평균·최대 레벨을 0.5 dB 단위 1바이트로 담는다 → 12시간이어도 약 85 KB.
class NoiseRecord {
  NoiseRecord({
    required this.id,
    required this.startedAt,
    required this.weighting,
    required this.offset,
    required this.average,
    required this.max,
    required this.min,
    required this.leq,
    required this.peaks,
    required this.segments,
    this.note = '',
  });

  /// 측정을 시작한 순간(ms) — 저장 키로도 쓴다.
  final int id;
  final DateTime startedAt;
  final Weighting weighting;

  /// 측정 당시 보정값 (리포트 바닥글에 적는다).
  final double offset;
  final double average, max, min;

  /// 1초 단위 평균·최대 (보정 포함, dB).
  final List<double> leq, peaks;

  /// 멈췄다 다시 켠 지점: (몇 번째 초부터, 그 순간의 실제 시각).
  /// 리포트의 "가장 시끄러웠던 시각"을 멈춘 시간까지 맞게 계산하려고 둔다.
  final List<(int, DateTime)> segments;
  String note;

  Duration get duration => Duration(seconds: leq.length);

  DateTime get endedAt =>
      timeOfSecond(math.max(0, leq.length - 1)).add(const Duration(seconds: 1));

  /// i 번째 초의 실제 시각.
  DateTime timeOfSecond(int i) {
    var base = (0, startedAt);
    for (final s in segments) {
      if (s.$1 <= i) base = s;
    }
    return base.$2.add(Duration(seconds: i - base.$1));
  }

  /// 가장 시끄러웠던 순간 (초 번호). 기록이 없으면 null.
  int? get loudestSecond {
    if (peaks.isEmpty) return null;
    var best = 0;
    for (var i = 1; i < peaks.length; i++) {
      if (peaks[i] > peaks[best]) best = i;
    }
    return best;
  }

  /// 구간(Quiet·Moderate…)별로 머문 초.
  Map<Band, int> secondsPerBand() {
    final m = {for (final b in bands) b: 0};
    for (final l in leq) {
      final b = bandOf(l);
      m[b] = m[b]! + 1;
    }
    return m;
  }

  static List<double> _unpack(String s) => [
    for (final b in base64Decode(s)) b / 2,
  ];
  static String _pack(List<double> xs) => base64Encode(
    Uint8List.fromList([for (final x in xs) (x * 2).round().clamp(0, 255)]),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'start': startedAt.millisecondsSinceEpoch,
    'w': weighting.name,
    'off': offset,
    'avg': _r1(average),
    'max': _r1(max),
    'min': _r1(min),
    'leq': _pack(leq),
    'pk': _pack(peaks),
    'seg': [
      for (final s in segments) [s.$1, s.$2.millisecondsSinceEpoch],
    ],
    'note': note,
  };

  static NoiseRecord? fromJson(Map<String, Object?> j) {
    try {
      return NoiseRecord(
        id: j['id'] as int,
        startedAt: DateTime.fromMillisecondsSinceEpoch(j['start'] as int),
        weighting: Weighting.values.byName(j['w'] as String),
        offset: (j['off'] as num).toDouble(),
        average: (j['avg'] as num).toDouble(),
        max: (j['max'] as num).toDouble(),
        min: (j['min'] as num).toDouble(),
        leq: _unpack(j['leq'] as String),
        peaks: _unpack(j['pk'] as String),
        segments: [
          for (final s in (j['seg'] as List? ?? const []))
            (
              (s as List)[0] as int,
              DateTime.fromMillisecondsSinceEpoch(s[1] as int),
            ),
        ],
        note: j['note'] as String? ?? '',
      );
    } catch (_) {
      return null; // 깨진 기록은 건너뛴다 (앱이 죽지 않게)
    }
  }

  static double _r1(double v) => (v * 10).roundToDouble() / 10;
}

/// 리포트 그래프용으로 줄이기: n 개 이하 막대로 묶는다 (평균은 에너지 평균, 최대는 최대).
List<SecondStat> downsample(List<double> leq, List<double> peaks, int n) {
  if (leq.length <= n) {
    return [for (var i = 0; i < leq.length; i++) SecondStat(leq[i], peaks[i])];
  }
  final out = <SecondStat>[];
  for (var k = 0; k < n; k++) {
    final a = k * leq.length ~/ n, b = (k + 1) * leq.length ~/ n;
    if (b <= a) continue;
    out.add(
      SecondStat(
        energyAverage(leq.sublist(a, b)),
        peaks.sublist(a, b).reduce(math.max),
      ),
    );
  }
  return out;
}

String encodeRecords(List<NoiseRecord> rs) =>
    jsonEncode([for (final r in rs) r.toJson()]);

List<NoiseRecord> decodeRecords(String? raw) {
  if (raw == null || raw.isEmpty) return [];
  try {
    final list = jsonDecode(raw) as List;
    return [
      for (final j in list)
        ?NoiseRecord.fromJson((j as Map).cast<String, Object?>()),
    ];
  } catch (_) {
    return [];
  }
}
