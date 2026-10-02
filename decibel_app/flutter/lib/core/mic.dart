import 'dart:async';
import 'dart:math' as math;

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

/// 마이크를 갈아끼울 수 있게 감싼다 — 테스트에서는 가짜 소리를 넣는다.
/// 소리는 숫자로만 바꾸고 어디에도 저장하지 않는다 (녹음 파일 없음).
abstract class SoundSource {
  static SoundSource i = RecordSource();

  /// 실제로 들어오는 샘플레이트 (가중 필터 계수를 여기에 맞춘다).
  double get sampleRate;

  /// 마이크 권한. [request] 면 처음 한 번 시스템 창을 띄운다.
  Future<bool> hasPermission({bool request = true});

  /// PCM16 바이트를 [onData] 로 흘려보낸다. 전화가 오는 등으로 끊기면 [onStopped].
  Future<void> start({
    required void Function(Uint8List pcm16) onData,
    required void Function() onStopped,
  });

  Future<void> stop();
}

class RecordSource extends SoundSource {
  AudioRecorder? _rec;
  StreamSubscription<Uint8List>? _sub;
  StreamSubscription<RecordState>? _state;
  StreamSubscription<AudioInterruptionEvent>? _interrupt;
  bool _running = false;

  static const _rate = 48000;

  @override
  double get sampleRate => _rate.toDouble();

  AudioRecorder get _r => _rec ??= AudioRecorder();

  @override
  Future<bool> hasPermission({bool request = true}) async {
    try {
      return await _r.hasPermission(request: request);
    } catch (e) {
      debugPrint('mic permission check failed: $e');
      return false;
    }
  }

  @override
  Future<void> start({
    required void Function(Uint8List pcm16) onData,
    required void Function() onStopped,
  }) async {
    if (_running) return;
    final ios = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    if (ios) {
      // iOS 'measurement' 모드: 자동 음량 보정·음성 처리를 꺼서 소리 크기를 그대로 받는다.
      await _r.ios?.manageAudioSession(false);
      final s = await AudioSession.instance;
      await s.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.record,
          avAudioSessionMode: AVAudioSessionMode.measurement,
        ),
      );
      await s.setActive(true);
      _interrupt = s.interruptionEventStream.listen((e) {
        if (e.begin && _running) onStopped();
      });
    }
    final stream = await _r.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _rate,
        numChannels: 1,
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
        androidConfig: AndroidRecordConfig(
          audioSource: AndroidAudioSource.unprocessed,
        ),
      ),
    );
    _running = true;
    var carry = Uint8List(0);
    _sub = stream.listen(
      (bytes) {
        // 바이트가 홀수로 잘려 오면 다음 묶음에 붙인다
        var b = bytes;
        if (carry.isNotEmpty) {
          b = Uint8List(carry.length + bytes.length)
            ..setAll(0, carry)
            ..setAll(carry.length, bytes);
          carry = Uint8List(0);
        }
        if (b.length.isOdd) {
          carry = Uint8List.fromList([b.last]);
          b = Uint8List.sublistView(b, 0, b.length - 1);
        }
        onData(b);
      },
      onError: (Object e) {
        debugPrint('mic stream error: $e');
        if (_running) onStopped();
      },
    );
    _state = _r.onStateChanged().listen((s) {
      if (s == RecordState.stop && _running) onStopped();
    });
  }

  @override
  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    await _sub?.cancel();
    await _state?.cancel();
    await _interrupt?.cancel();
    _sub = null;
    _state = null;
    _interrupt = null;
    try {
      await _r.stop();
    } catch (e) {
      debugPrint('mic stop failed: $e');
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        await (await AudioSession.instance).setActive(false);
      } catch (_) {}
    }
  }
}

/// 테스트용 가짜 마이크: 정해 둔 크기(dBFS)의 1 kHz 사인파를 0.05초마다 흘린다.
class FakeSource extends SoundSource {
  FakeSource({this.granted = true, this.level = -40});

  bool granted;

  /// 지금 내는 소리 크기 (dBFS, 사인파 RMS 기준). 테스트 중에 바꿀 수 있다.
  double level;

  bool asked = false;
  int starts = 0;
  bool get running => _timer != null;
  Timer? _timer;
  void Function()? _onStopped;
  int _phase = 0;

  static const rate = 8000.0;

  @override
  double get sampleRate => rate;

  @override
  Future<bool> hasPermission({bool request = true}) async {
    if (request) asked = true;
    return granted;
  }

  @override
  Future<void> start({
    required void Function(Uint8List pcm16) onData,
    required void Function() onStopped,
  }) async {
    starts++;
    _onStopped = onStopped;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      const n = 400; // 0.05 s
      final amp = math.sqrt(2) * math.pow(10, level / 20);
      final b = ByteData(n * 2);
      for (var i = 0; i < n; i++) {
        final v = amp * math.sin(2 * math.pi * 1000 * (_phase + i) / rate);
        b.setInt16(
          i * 2,
          (v * 32767).round().clamp(-32768, 32767),
          Endian.little,
        );
      }
      _phase += n;
      onData(b.buffer.asUint8List());
    });
  }

  /// 전화가 온 것처럼 마이크가 끊기게 한다.
  void interrupt() {
    _timer?.cancel();
    _timer = null;
    _onStopped?.call();
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
  }
}
