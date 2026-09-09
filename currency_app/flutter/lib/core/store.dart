import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'currencies.dart';
import 'format.dart';
import 'rate_service.dart';

/// 앱 상태.
///
/// base    = 맨 위에 고정되는 기준 통화
/// targets = 아래에 깔리는 변환 대상 국가들
/// active  = 지금 숫자를 입력 중인 통화 (기준이든 아래 행이든 아무거나)
/// buf     = active 통화의 입력 버퍼 — 나머지 금액은 여기서 환산된다
class AppStore extends ChangeNotifier {
  AppStore._();
  static final AppStore i = AppStore._();

  static const _key = 'fx-app-v1';

  String base = 'KGS';
  String buf = '1000';
  List<String> targets = ['USD', 'KRW'];
  String active = 'KGS';
  String chartTo = 'USD';
  List<String> recents = ['USD', 'KRW'];

  /// 첫 실행 온보딩(기준 통화 선택)을 마쳤는지
  bool onboarded = false;

  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_key);
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final b = j['base'] as String?;
      final t = (j['targets'] as List?)?.cast<String>();
      if (b == null || !currencyByCode.containsKey(b)) return;
      if (t == null || !t.every(currencyByCode.containsKey)) return;
      base = b;
      targets = List.of(t);
      buf = (j['buf'] as String?) ?? buf;
      active = (j['active'] as String?) ?? base;
      if (!currencyByCode.containsKey(active)) active = base;
      chartTo = (j['chartTo'] as String?) ?? chartTo;
      recents = (j['recents'] as List?)?.cast<String>() ?? recents;
      onboarded = (j['onboarded'] as bool?) ?? true; // 저장된 설정이 있으면 이미 골랐던 것
    } catch (_) {}
  }

  void _save() {
    _prefs?.setString(
      _key,
      jsonEncode({
        'base': base,
        'buf': buf,
        'targets': targets,
        'active': active,
        'chartTo': chartTo,
        'recents': recents,
        'onboarded': onboarded,
      }),
    );
  }

  void _commit() {
    _keepActiveValid();
    _save();
    notifyListeners();
  }

  // ---------- 금액 ----------

  double get bufValueNum => bufValue(buf);

  /// [code] 통화로 본 현재 금액. 입력 중인 통화면 버퍼 그대로, 아니면 환산.
  double amountIn(String code) {
    final v = bufValueNum;
    return code == active ? v : RateService.i.convert(v, active, code);
  }

  /// 입력 중이던 통화가 목록에서 사라졌으면 그 금액을 기준 통화로 옮겨 담는다.
  void _keepActiveValid() {
    if (active == base || targets.contains(active)) return;
    if (!currencyByCode.containsKey(active)) {
      active = base;
      return;
    }
    buf = rawStr(amountIn(base));
    active = base;
  }

  /// 어느 행이든 금액을 누르면 그 통화로 입력. 보이던 숫자를 그대로 이어받는다.
  void startEdit(String code) {
    if (active == code) return;
    buf = rawStr(amountIn(code));
    active = code;
    _commit();
  }

  void typeDigit(String d) {
    if (buf == '0') buf = '';
    if (buf.replaceAll('.', '').length >= 12) return;
    buf += d;
    _commit();
  }

  void typeDot() {
    if (buf.contains('.')) return;
    buf = '${buf.isEmpty ? '0' : buf}.';
    _commit();
  }

  void backspace() {
    if (buf.isEmpty) return;
    buf = buf.substring(0, buf.length - 1);
    _commit();
  }

  void clearBuf() {
    buf = '';
    _commit();
  }

  // ---------- 통화 ----------

  void _pushRecent(String code) {
    recents = [code, ...recents.where((x) => x != code)].take(4).toList();
  }

  /// 새 기준이 대상 목록에 있으면 그 자리에 기존 기준을 넣어 자연스럽게 맞교환
  void setBase(String code) {
    _pushRecent(code);
    final at = targets.indexOf(code);
    if (at >= 0) targets[at] = base;
    base = code;
    if (chartTo == code) chartTo = targets.isNotEmpty ? targets.first : 'USD';
    _commit();
  }

  void addTarget(String code) {
    if (targets.contains(code) || code == base) return;
    _pushRecent(code);
    targets = [...targets, code];
    _commit();
  }

  void replaceTarget(int index, String code) {
    if (index < 0 || index >= targets.length) return;
    _pushRecent(code);
    targets[index] = code;
    _commit();
  }

  void removeTarget(int index) {
    if (index < 0 || index >= targets.length || targets.length <= 1) return;
    targets = [...targets]..removeAt(index);
    _commit();
  }

  void setChartTo(String code) {
    chartTo = code;
    _commit();
  }

  /// 온보딩에서 고른 통화를 기준으로 올리고, 비교 통화는 겹치지 않게 2개 채운다.
  void completeOnboarding(String code) {
    base = code;
    targets = ['USD', 'KRW', 'EUR'].where((x) => x != code).take(2).toList();
    active = code;
    buf = '1000';
    chartTo = targets.first;
    recents = [code, ...targets];
    onboarded = true;
    _commit();
  }
}
