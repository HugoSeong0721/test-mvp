// 측정 엔진 검증 — 가중 곡선이 IEC 61672 표준값과 맞는지, 레벨·평균·시간 가중이 수식대로인지.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:decibel/core/meter.dart';
import 'package:flutter_test/flutter_test.dart';

List<double> sine(double freq, double amp, double seconds, double fs) => [
  for (var i = 0; i < (seconds * fs).round(); i++)
    amp * math.sin(2 * math.pi * freq * i / fs),
];

double dbOf(double amp) => 10 * math.log(amp * amp / 2) / math.ln10;

void main() {
  // IEC 61672-1 표의 공칭값 (dB)
  final aTable = <double, double>{
    31.5: -39.4,
    63.0: -26.2,
    125.0: -16.1,
    250.0: -8.6,
    500.0: -3.2,
    1000.0: 0.0,
    2000.0: 1.2,
    4000.0: 1.0,
    8000.0: -1.1,
  };
  final cTable = <double, double>{
    31.5: -3.0,
    63.0: -0.8,
    125.0: -0.2,
    1000.0: 0.0,
    2000.0: -0.2,
    4000.0: -0.8,
    8000.0: -3.0,
  };

  for (final fs in [44100.0, 48000.0]) {
    test('A-weighting matches IEC 61672 at ${fs ~/ 1000} kHz', () {
      final f = WeightingFilter(Weighting.a, fs);
      aTable.forEach((hz, want) {
        final tol = hz >= 8000 ? 1.0 : 0.2;
        expect(f.responseDb(hz), closeTo(want, tol), reason: '$hz Hz');
      });
    });

    test('C-weighting matches IEC 61672 at ${fs ~/ 1000} kHz', () {
      final f = WeightingFilter(Weighting.c, fs);
      cTable.forEach((hz, want) {
        final tol = hz >= 8000 ? 1.0 : 0.2;
        expect(f.responseDb(hz), closeTo(want, tol), reason: '$hz Hz');
      });
    });
  }

  test('Z-weighting is flat', () {
    final f = WeightingFilter(Weighting.z, 48000);
    for (final hz in [31.5, 1000.0, 8000.0]) {
      expect(f.responseDb(hz), closeTo(0, 1e-9));
    }
  });

  test('1 kHz sine: current, average, max equal its RMS level (+offset)', () {
    const fs = 48000.0;
    final m = MeterEngine(sampleRate: fs, offset: 100);
    m.addSamples(sine(1000, 0.1, 2, fs));
    final want = dbOf(0.1) + 100; // ≈ 76.99
    expect(m.current, closeTo(want, 0.15));
    expect(m.average, closeTo(want, 0.15));
    expect(m.max, closeTo(want, 0.3));
    expect(m.min, closeTo(want, 0.3));
    expect(m.hasData, isTrue);
  });

  test('A-weighting lowers a 100 Hz hum by ~19 dB, Z does not', () {
    const fs = 48000.0;
    final a = MeterEngine(sampleRate: fs);
    final z = MeterEngine(sampleRate: fs, weighting: Weighting.z);
    final s = sine(100, 0.1, 2, fs);
    a.addSamples(s);
    z.addSamples(s);
    expect(z.average, closeTo(dbOf(0.1), 0.15));
    expect(z.average - a.average, closeTo(19.1, 0.4));
  });

  test(
    'Fast time weighting decays 4.34 dB per 125 ms after the sound stops',
    () {
      const fs = 48000.0;
      final m = MeterEngine(sampleRate: fs, weighting: Weighting.z);
      m.addSamples(sine(1000, 0.1, 1, fs));
      final loud = m.current;
      m.addSamples(List.filled((0.5 * fs).round(), 0.0));
      // 0.5 s = 4 τ → 10·log10(e^-4) = -17.37 dB
      expect(loud - m.current, closeTo(17.37, 0.3));
    },
  );

  test('average is an energy average, not a plain mean of dB', () {
    const fs = 48000.0;
    final m = MeterEngine(sampleRate: fs, weighting: Weighting.z);
    m.addSamples(sine(1000, 0.3, 2.3, fs)); // 0.3 s 워밍업 포함
    m.addSamples(sine(1000, 0.03, 2, fs)); // 20 dB 작음
    final loud = dbOf(0.3), quiet = dbOf(0.03);
    final want =
        10 *
        math.log((math.pow(10, loud / 10) + math.pow(10, quiet / 10)) / 2) /
        math.ln10;
    expect(
      m.average,
      closeTo(want, 0.2),
    ); // ≈ loud - 3 dB, 산술 평균(loud-10)과 확연히 다르다
    expect(m.max, closeTo(loud, 0.3));
    expect(m.min, closeTo(quiet, 0.5));
    expect(m.secondCount, 4);
    expect(m.seconds.first.leq, closeTo(loud, 0.2));
    expect(m.seconds.last.leq, closeTo(quiet, 0.2));
    expect(m.measured.inMilliseconds, closeTo(4000, 5));
  });

  test('recent buffer keeps one minute at 10 points per second', () {
    const fs = 8000.0;
    final m = MeterEngine(sampleRate: fs);
    m.addSamples(sine(1000, 0.1, 70.3, fs));
    expect(m.recent.length, MeterEngine.recentPoints);
  });

  test('PCM16 bytes decode to the same level as floats', () {
    const fs = 48000.0;
    final s = sine(1000, 0.25, 1.5, fs);
    final bytes = ByteData(s.length * 2);
    for (var i = 0; i < s.length; i++) {
      bytes.setInt16(i * 2, (s[i] * 32767).round(), Endian.little);
    }
    final m = MeterEngine(sampleRate: fs);
    m.addPcm16(bytes.buffer.asUint8List());
    expect(m.average, closeTo(dbOf(0.25), 0.15));
  });

  test('silence reads the floor, not NaN or -infinity', () {
    final m = MeterEngine(sampleRate: 48000, offset: 100);
    m.addSamples(List.filled(48000, 0.0));
    expect(m.current, MeterEngine.floorRaw + 100);
    expect(m.average.isFinite, isTrue);
  });

  test('offset change shifts everything consistently', () {
    const fs = 48000.0;
    final m = MeterEngine(sampleRate: fs, offset: 90);
    m.addSamples(sine(1000, 0.1, 2.3, fs));
    final avg = m.average, mx = m.max, s0 = m.seconds.first.leq;
    m.offset = 92.5;
    expect(m.average - avg, closeTo(2.5, 1e-9));
    expect(m.max - mx, closeTo(2.5, 1e-9));
    expect(m.seconds.first.leq - s0, closeTo(2.5, 1e-9));
  });

  test('energyAverage', () {
    expect(energyAverage([60, 60]), closeTo(60, 1e-9));
    expect(energyAverage([70, 50]), closeTo(67.03, 0.01));
  });
}
