import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// 화면 꺼짐 방지·경고음·진동. 테스트에서는 가짜로 갈아끼운다.
abstract class DeviceIO {
  Future<void> keepAwake(bool on);
  Future<void> beep();
  Future<void> buzz();
}

class RealDeviceIO extends DeviceIO {
  AudioPlayer? _player;

  AudioPlayer get _p {
    final p = _player;
    if (p != null) return p;
    final n = AudioPlayer();
    // 음악·내비 소리를 끊지 않고 섞어서 낸다.
    n.setAudioContext(
      AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const {AVAudioSessionOptions.mixWithOthers},
        ),
        android: const AudioContextAndroid(
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.assistanceNavigationGuidance,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
      ),
    );
    n.setReleaseMode(ReleaseMode.stop);
    return _player = n;
  }

  @override
  Future<void> keepAwake(bool on) async {
    try {
      await WakelockPlus.toggle(enable: on);
    } catch (e) {
      debugPrint('wakelock: $e');
    }
  }

  @override
  Future<void> beep() async {
    try {
      await _p.stop();
      await _p.play(AssetSource('sounds/alert.wav'));
    } catch (e) {
      debugPrint('beep: $e');
    }
  }

  @override
  Future<void> buzz() => HapticFeedback.heavyImpact();
}

class FakeDeviceIO extends DeviceIO {
  bool awake = false;
  int beeps = 0;
  int buzzes = 0;

  @override
  Future<void> keepAwake(bool on) async => awake = on;

  @override
  Future<void> beep() async => beeps++;

  @override
  Future<void> buzz() async => buzzes++;
}
