import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'puzzle.dart';

/// 기기에 남는 진행 상황. 서버 없음 — 오프라인에서도 그대로 동작한다.
class AppStore extends ChangeNotifier {
  AppStore._();
  static final AppStore i = AppStore._();

  late SharedPreferences _p;

  /// 테스트에서 날짜를 고정할 수 있게 시계를 바꿔 끼운다.
  DateTime Function() clock = DateTime.now;

  String get todayKey => dayKeyOf(clock());

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
  }

  // ── 단계 모드 ──
  // 1~30단계 무료 → 이후 20단계 묶음마다 영상 1개로 열거나, $1.99 한 번으로 전부 + 배너 제거.
  // (사용자 결정 2026-10-03: "영상 or $1.99")
  static const totalLevels = 500;
  static const freeLevels = 30;
  static const packSize = 20;

  /// 지금 풀 차례인 단계 (1부터). 500단계를 다 깨면 501.
  int get level => _p.getInt('level') ?? 1;
  int get levelsSolved => (level - 1).clamp(0, totalLevels);
  bool get allLevelsDone => level > totalLevels;

  /// 결제(전부 열기 + 배너 제거) 했나.
  bool get premium => _p.getBool('premium') ?? false;
  Future<void> setPremium(bool v) async {
    if (premium == v) return;
    await _p.setBool('premium', v);
    notifyListeners();
  }

  /// 몇 단계까지 열려 있나.
  int get unlockedThrough => premium
      ? totalLevels
      : (_p.getInt('unlockedThrough') ?? freeLevels).clamp(
          freeLevels,
          totalLevels,
        );
  bool isOpen(int lv) => lv <= unlockedThrough;

  /// 다음 묶음(20단계)을 연다 — 영상 1개 보상.
  Future<void> unlockNextPack() async {
    final next = (unlockedThrough + packSize).clamp(freeLevels, totalLevels);
    await _p.setInt('unlockedThrough', next);
    notifyListeners();
  }

  /// lv 가 들어 있는 묶음의 [첫 단계, 끝 단계].
  static (int, int) packOf(int lv) {
    if (lv <= freeLevels) return (1, freeLevels);
    final k = (lv - freeLevels - 1) ~/ packSize;
    final a = freeLevels + k * packSize + 1;
    return (a, (a + packSize - 1).clamp(a, totalLevels));
  }

  Future<void> completeLevel(int lv) async {
    await _p.remove(levelBoardKey(lv));
    if (lv >= level) {
      await _p.setInt('level', lv + 1);
      notifyListeners();
    }
  }

  // ── 오늘의 퍼즐 ──
  /// 오늘 처음 푼 기록(초). 아직 못 풀었으면 0.
  int solvedTime(String day) => _p.getInt('dailySolved_$day') ?? 0;

  /// 아직 못 푼 날의 누적 시간(초) — 실패하고 다시 해도 시계는 이어진다.
  int carriedTime(String day) => _p.getInt('dailyCarry_$day') ?? 0;
  Future<void> setCarriedTime(String day, int s) async {
    if (carriedTime(day) == s) return;
    await _p.setInt('dailyCarry_$day', s);
    notifyListeners();
  }

  // ── 하던 판 ── 뒤로 갔다 와도 놓은 고양이·✕·하트가 그대로 남게.
  static String dailyBoardKey(String day) => 'board_daily_$day';
  static String levelBoardKey(int lv) => 'board_level_$lv';

  Map<String, dynamic>? loadBoard(String key) {
    final raw = _p.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveBoard(String key, Map<String, Object> snap) =>
      _p.setString(key, jsonEncode(snap));

  Future<void> clearBoard(String key) => _p.remove(key);

  Future<void> markDailySolved(String day, int seconds) async {
    if (solvedTime(day) > 0) return;
    await _p.setInt('dailySolved_$day', seconds);
    await _p.remove('dailyCarry_$day');
    await _p.remove(dailyBoardKey(day));
    // 연속 기록: 어제 풀었으면 이어 가고, 아니면 1부터
    final yesterday = dayKeyOf(
      DateTime.parse(_iso(day)).subtract(const Duration(days: 1)),
    );
    final last = _p.getString('streakDay');
    final s = last == yesterday ? streakRaw + 1 : 1;
    await _p.setInt('streak', s);
    await _p.setString('streakDay', day);
    if (s > bestStreak) await _p.setInt('bestStreak', s);
    await _p.setInt('dailyTotal', dailyTotal + 1);
    notifyListeners();
  }

  int get streakRaw => _p.getInt('streak') ?? 0;

  /// 화면에 보이는 연속 일수 — 어제나 오늘 풀었을 때만 살아 있다.
  int get streak {
    final last = _p.getString('streakDay');
    if (last == null) return 0;
    final today = todayKey;
    final yesterday = dayKeyOf(
      DateTime.parse(_iso(today)).subtract(const Duration(days: 1)),
    );
    return (last == today || last == yesterday) ? streakRaw : 0;
  }

  int get bestStreak => _p.getInt('bestStreak') ?? 0;
  int get dailyTotal => _p.getInt('dailyTotal') ?? 0;

  // ── 설정 ──
  bool get sound => _p.getBool('sound') ?? true;
  Future<void> setSound(bool v) async {
    await _p.setBool('sound', v);
    notifyListeners();
  }

  bool get seenHowTo => _p.getBool('seenHowTo') ?? false;
  Future<void> setSeenHowTo() => _p.setBool('seenHowTo', true);

  static String _iso(String k) =>
      '${k.substring(0, 4)}-${k.substring(4, 6)}-${k.substring(6, 8)}';
}
