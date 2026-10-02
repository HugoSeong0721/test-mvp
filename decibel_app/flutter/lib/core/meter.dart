import 'dart:math' as math;
import 'dart:typed_data';

/// 주파수 가중. A = 사람 귀 (소음 민원·NIOSH 기준), C = 저음 포함, Z = 평탄(가중 없음).
enum Weighting { a, c, z }

extension WeightingLabel on Weighting {
  String get unit => switch (this) {
    Weighting.a => 'dBA',
    Weighting.c => 'dBC',
    Weighting.z => 'dBZ',
  };
}

/// IEC 61672 가중 곡선의 아날로그 극점 주파수(Hz).
const _f1 = 20.598997, _f2 = 107.65265, _f3 = 737.86223, _f4 = 12194.217;

/// 2차 IIR 한 칸 (transposed direct form II).
class _Biquad {
  _Biquad(this.b0, this.b1, this.b2, this.a1, this.a2);
  double b0, b1, b2;
  final double a1, a2;
  double _s1 = 0, _s2 = 0;

  double process(double x) {
    final y = b0 * x + _s1;
    _s1 = b1 * x - a1 * y + _s2;
    _s2 = b2 * x - a2 * y;
    return y;
  }

  void reset() => _s1 = _s2 = 0;

  /// |H(e^jw)|
  double magnitude(double w) {
    // 분자·분모를 복소수로 계산: e^-jw = cos w - j sin w
    final c1 = math.cos(w), s1 = -math.sin(w);
    final c2 = math.cos(2 * w), s2 = -math.sin(2 * w);
    final nr = b0 + b1 * c1 + b2 * c2, ni = b1 * s1 + b2 * s2;
    final dr = 1 + a1 * c1 + a2 * c2, di = a1 * s1 + a2 * s2;
    return math.sqrt((nr * nr + ni * ni) / (dr * dr + di * di));
  }
}

/// 아날로그 가중 필터를 쌍일차 변환으로 디지털화한다 (샘플레이트마다 계수를 새로 계산).
/// 영점: s=0 → z=1, s=∞ → z=-1. 극점: s=-w → z=(2fs-w)/(2fs+w).
class WeightingFilter {
  WeightingFilter(this.weighting, this.sampleRate) {
    double pole(double f) {
      final w = 2 * math.pi * f, k = 2 * sampleRate;
      return (k - w) / (k + w);
    }

    _Biquad sos(double z1, double z2, double p1, double p2) =>
        _Biquad(1, -(z1 + z2), z1 * z2, -(p1 + p2), p1 * p2);

    final p1 = pole(_f1), p4 = pole(_f4);
    _stages = switch (weighting) {
      Weighting.a => [
        sos(1, 1, p1, p1),
        sos(1, 1, pole(_f2), pole(_f3)),
        sos(-1, -1, p4, p4),
      ],
      Weighting.c => [sos(1, 1, p1, p1), sos(-1, -1, p4, p4)],
      Weighting.z => const [],
    };
    // 1 kHz 에서 0 dB 가 되게 맞춘다 (가중 곡선의 정의).
    if (_stages.isNotEmpty) {
      final g = 1 / _magnitude(1000);
      final s = _stages.first;
      s.b0 *= g;
      s.b1 *= g;
      s.b2 *= g;
    }
  }

  final Weighting weighting;
  final double sampleRate;
  late final List<_Biquad> _stages;

  double process(double x) {
    var y = x;
    for (final s in _stages) {
      y = s.process(y);
    }
    return y;
  }

  void reset() {
    for (final s in _stages) {
      s.reset();
    }
  }

  double _magnitude(double f) {
    final w = 2 * math.pi * f / sampleRate;
    var m = 1.0;
    for (final s in _stages) {
      m *= s.magnitude(w);
    }
    return m;
  }

  /// 이 디지털 필터의 주파수 응답(dB). 테스트에서 표준 곡선과 비교한다.
  double responseDb(double f) => 20 * math.log(_magnitude(f)) / math.ln10;
}

/// 1초 단위 기록 한 칸: 그 1초의 평균(에너지 평균)과 최대(Fast).
class SecondStat {
  const SecondStat(this.leq, this.max);
  final double leq;
  final double max;
}

/// 마이크 샘플(−1..1)을 받아 소음 레벨을 계산한다. 화면·저장과 무관한 순수 계산.
///
/// - 현재값: IEC 61672 Fast(125 ms) 지수 시간 가중.
/// - 평균: 측정 전체의 에너지 평균(Leq). 최대·최소: Fast 레벨의 최대·최소.
/// - 보정값(offset)은 내부 값에 더하기만 한다 → 측정 중에 바꿔도 전체가 일관되게 움직인다.
/// - 처음 0.3초는 필터가 자리 잡는 시간이라 통계에서 뺀다.
class MeterEngine {
  MeterEngine({
    required this.sampleRate,
    this.weighting = Weighting.a,
    this.offset = 0,
  }) : _filter = WeightingFilter(weighting, sampleRate) {
    _alpha = 1 - math.exp(-1 / (sampleRate * fastTau));
    _tickLen = (sampleRate * tick.inMicroseconds / 1e6).round();
    _secLen = sampleRate.round();
    _warmup = (sampleRate * 0.3).round();
  }

  static const fastTau = 0.125;
  static const tick = Duration(milliseconds: 100);

  /// 최근 그래프에 남기는 점 수 (0.1초 × 600 = 1분).
  static const recentPoints = 600;

  /// 아무 소리도 없을 때(디지털 0) 바닥값.
  static const floorRaw = -120.0;

  final double sampleRate;
  final Weighting weighting;
  double offset;
  final WeightingFilter _filter;

  late final double _alpha;
  late final int _tickLen, _secLen, _warmup;

  double _e = 0; // Fast 평균 제곱
  bool _primed = false;
  int _samples = 0; // 지금까지 받은 샘플 수 (워밍업 포함)

  // 측정 전체
  double _sumSq = 0;
  int _n = 0;
  double _maxRaw = double.negativeInfinity;
  double _minRaw = double.infinity;

  // 0.1초·1초 단위
  int _tickCount = 0;
  double _secSum = 0;
  int _secN = 0;
  double _secMax = double.negativeInfinity;

  /// 최근 1분 Fast 레벨 (보정 전 값, 0.1초 간격).
  final List<double> _recent = [];

  /// 1초 단위 기록 (보정 전 값).
  final List<SecondStat> _seconds = [];

  static double _db(double meanSquare) =>
      meanSquare <= 1e-12 ? floorRaw : 10 * math.log(meanSquare) / math.ln10;

  /// PCM16 little-endian 바이트를 받아 처리한다.
  void addPcm16(Uint8List bytes) {
    final n = bytes.length ~/ 2;
    if (n == 0) return;
    final view = ByteData.sublistView(bytes, 0, n * 2);
    final out = Float64List(n);
    for (var i = 0; i < n; i++) {
      out[i] = view.getInt16(i * 2, Endian.little) / 32768.0;
    }
    addSamples(out);
  }

  void addSamples(List<double> xs) {
    for (final x in xs) {
      final y = _filter.process(x);
      final sq = y * y;
      if (!_primed) {
        _e = sq;
        _primed = true;
      } else {
        _e += _alpha * (sq - _e);
      }
      _samples++;
      if (_samples <= _warmup) continue;

      _sumSq += sq;
      _n++;
      _secSum += sq;
      _secN++;
      _tickCount++;
      if (_tickCount >= _tickLen) {
        _tickCount = 0;
        final f = _db(_e);
        if (f > _maxRaw) _maxRaw = f;
        if (f < _minRaw) _minRaw = f;
        if (f > _secMax) _secMax = f;
        _recent.add(f);
        if (_recent.length > recentPoints) _recent.removeAt(0);
      }
      if (_secN >= _secLen) {
        _seconds.add(
          SecondStat(
            _db(_secSum / _secN),
            _secMax.isFinite ? _secMax : _db(_secSum / _secN),
          ),
        );
        _secSum = 0;
        _secN = 0;
        _secMax = double.negativeInfinity;
      }
    }
  }

  /// 소리를 받기 시작했나 (워밍업이 끝나 숫자를 보여 줄 수 있나).
  bool get hasData => _recent.isNotEmpty;

  /// 측정한 시간 (워밍업 제외, 오디오 샘플 기준이라 타이머 오차가 없다).
  Duration get measured =>
      Duration(microseconds: (_n / sampleRate * 1e6).round());

  double get current => _db(_e) + offset;
  double get average => (_n == 0 ? floorRaw : _db(_sumSq / _n)) + offset;
  double get max => (_maxRaw.isFinite ? _maxRaw : floorRaw) + offset;
  double get min => (_minRaw.isFinite ? _minRaw : floorRaw) + offset;

  /// 최근 1분 레벨(보정 포함), 오래된 것부터.
  List<double> get recent => [for (final v in _recent) v + offset];

  /// 1초 단위 기록(보정 포함).
  List<SecondStat> get seconds => [
    for (final s in _seconds) SecondStat(s.leq + offset, s.max + offset),
  ];

  int get secondCount => _seconds.length;

  /// 잠깐 멈췄다 다시 켤 때: 필터 상태만 지우고 통계는 이어 간다.
  void resume() {
    _filter.reset();
    _primed = false;
    _samples = 0;
    _tickCount = 0;
  }
}

/// 여러 1초 레벨의 에너지 평균 (Leq).
double energyAverage(Iterable<double> levels) {
  var sum = 0.0;
  var n = 0;
  for (final l in levels) {
    sum += math.pow(10, l / 10);
    n++;
  }
  if (n == 0) return MeterEngine.floorRaw;
  return 10 * math.log(sum / n) / math.ln10;
}
