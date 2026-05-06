import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/clinic_data_store.dart';

class PractitionerSession {
  const PractitionerSession({
    required this.id,
    required this.loginId,
    required this.displayName,
    required this.clinicId,
  });

  final String id;
  final String loginId;
  final String displayName;
  final String? clinicId;
}

class LocalPractitionerAuthException implements Exception {
  const LocalPractitionerAuthException(this.code);

  final String code;

  @override
  String toString() => 'LocalPractitionerAuthException($code)';
}

class PractitionerSessionService {
  PractitionerSessionService._();

  static const String _accountsKey = 'practitioner_local_accounts_v1';
  static const String _sessionLoginIdKey = 'practitioner_local_session_v1';

  static final ClinicDataStore _store = ClinicDataStore.instance;
  static final StreamController<PractitionerSession?> _sessionController =
      StreamController<PractitionerSession?>.broadcast();

  static SharedPreferences? _prefs;
  static Future<void>? _initialization;
  static PractitionerSession? _currentSession;

  static Future<void> initialize() => _ensureInitialized();

  static Stream<PractitionerSession?> watchSession() async* {
    await _ensureInitialized();
    yield _currentSession;
    yield* _sessionController.stream;
  }

  static PractitionerSession? get currentSession => _currentSession;

  static Future<PractitionerSession?> currentSessionAsync() async {
    await _ensureInitialized();
    return _currentSession;
  }

  static Future<PractitionerSession> signUpLocally({
    required String loginId,
    required String password,
    required String displayName,
    required String clinicName,
  }) async {
    await _ensureInitialized();

    final normalizedLoginId = _normalizeLoginId(loginId);
    final trimmedPassword = password.trim();
    final trimmedName = displayName.trim();
    final trimmedClinicName = clinicName.trim();

    if (!_looksLikeLoginId(normalizedLoginId)) {
      throw const LocalPractitionerAuthException('invalid-login-id');
    }
    if (trimmedPassword.length < 4) {
      throw const LocalPractitionerAuthException('weak-password');
    }
    if (trimmedName.isEmpty) {
      throw const LocalPractitionerAuthException('missing-display-name');
    }
    if (trimmedClinicName.isEmpty) {
      throw const LocalPractitionerAuthException('missing-clinic-name');
    }

    final accounts = _readLocalAccounts();
    if (accounts.any((account) => account.loginId == normalizedLoginId)) {
      throw const LocalPractitionerAuthException('login-id-already-in-use');
    }

    final accountId = _localPractitionerIdForLogin(normalizedLoginId);
    final clinicId = _store.suggestClinicId(trimmedClinicName);
    final now = DateTime.now().toIso8601String();
    final account = _LocalPractitionerAccount(
      id: accountId,
      loginId: normalizedLoginId,
      passwordHash: _passwordHash(trimmedPassword),
      displayName: trimmedName,
      clinicId: clinicId,
      createdAtIso: now,
      lastLoginAtIso: now,
    );
    accounts.add(account);
    await _saveLocalAccounts(accounts);

    await _store.saveClinicCenter(
      ClinicCenter(
        id: clinicId,
        name: trimmedClinicName,
        practitionerName: trimmedName,
        location: '',
        patientNote:
            'Patients who log in through this clinic can choose it as their center and continue intake here.',
        searchKeywords: '$trimmedClinicName $trimmedName',
      ),
    );
    await _store.setClinicForPractitioner(
      practitionerId: accountId,
      clinicId: clinicId,
    );

    _currentSession = account.toSession();
    await _preferences().then(
      (prefs) => prefs.setString(_sessionLoginIdKey, normalizedLoginId),
    );
    _emitSession();
    return _currentSession!;
  }

  static Future<PractitionerSession> logInLocally({
    required String loginId,
    required String password,
  }) async {
    await _ensureInitialized();

    final normalizedLoginId = _normalizeLoginId(loginId);
    final trimmedPassword = password.trim();
    final accounts = _readLocalAccounts();
    final index = accounts.indexWhere(
      (account) => account.loginId == normalizedLoginId,
    );
    if (index < 0) {
      throw const LocalPractitionerAuthException('user-not-found');
    }

    final account = accounts[index];
    if (account.passwordHash != _passwordHash(trimmedPassword)) {
      throw const LocalPractitionerAuthException('wrong-password');
    }

    final syncedClinicId =
        _store.clinicIdForPractitioner(account.id) ?? account.clinicId;
    final updated = account.copyWith(
      clinicId: syncedClinicId,
      lastLoginAtIso: DateTime.now().toIso8601String(),
    );
    accounts[index] = updated;
    await _saveLocalAccounts(accounts);

    _currentSession = updated.toSession();
    await _preferences().then(
      (prefs) => prefs.setString(_sessionLoginIdKey, normalizedLoginId),
    );
    _emitSession();
    return _currentSession!;
  }

  static Future<void> signOut() async {
    await _ensureInitialized();
    _currentSession = null;
    await _preferences().then((prefs) => prefs.remove(_sessionLoginIdKey));
    _emitSession();
  }

  static Future<void> updateCurrentPractitioner({
    String? displayName,
    String? clinicId,
  }) async {
    await _ensureInitialized();
    final session = _currentSession;
    if (session == null) {
      return;
    }

    final accounts = _readLocalAccounts();
    final index = accounts.indexWhere((account) => account.id == session.id);
    if (index < 0) {
      return;
    }

    final updated = accounts[index].copyWith(
      displayName: displayName?.trim().isEmpty ?? true
          ? null
          : displayName!.trim(),
      clinicId: clinicId,
    );
    accounts[index] = updated;
    await _saveLocalAccounts(accounts);

    if (clinicId != null && clinicId.trim().isNotEmpty) {
      await _store.setClinicForPractitioner(
        practitionerId: session.id,
        clinicId: clinicId,
      );
    }

    _currentSession = updated.toSession();
    _emitSession();
  }

  static Future<void> _ensureInitialized() {
    return _initialization ??= _initializeInternal();
  }

  static Future<void> _initializeInternal() async {
    await _preferences();
    await _restoreLocalSession();
    _emitSession();
  }

  static Future<void> _restoreLocalSession() async {
    final savedLoginId = (await _preferences()).getString(_sessionLoginIdKey);
    if (savedLoginId == null || savedLoginId.trim().isEmpty) {
      _currentSession = null;
      return;
    }

    final normalizedLoginId = _normalizeLoginId(savedLoginId);
    final account = _readLocalAccounts().cast<_LocalPractitionerAccount?>()
        .firstWhere(
          (item) => item?.loginId == normalizedLoginId,
          orElse: () => null,
        );
    if (account == null) {
      _currentSession = null;
      return;
    }

    final syncedClinicId =
        _store.clinicIdForPractitioner(account.id) ?? account.clinicId;
    _currentSession = account.copyWith(clinicId: syncedClinicId).toSession();
  }

  static List<_LocalPractitionerAccount> _readLocalAccounts() {
    final raw = _prefs?.getString(_accountsKey);
    if (raw == null || raw.trim().isEmpty) {
      return <_LocalPractitionerAccount>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <_LocalPractitionerAccount>[];
      }
      return decoded
          .whereType<Map>()
          .map(
            (item) => _LocalPractitionerAccount.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList();
    } catch (_) {
      return <_LocalPractitionerAccount>[];
    }
  }

  static Future<void> _saveLocalAccounts(
    List<_LocalPractitionerAccount> accounts,
  ) async {
    await _preferences().then(
      (prefs) => prefs.setString(
        _accountsKey,
        jsonEncode(accounts.map((account) => account.toJson()).toList()),
      ),
    );
  }

  static Future<SharedPreferences> _preferences() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  static String _normalizeLoginId(String value) =>
      value.trim().toLowerCase().replaceAll(' ', '');

  static bool _looksLikeLoginId(String value) {
    return RegExp(r'^[a-z0-9._-]{3,}$').hasMatch(value);
  }

  static String _localPractitionerIdForLogin(String loginId) {
    final encoded = base64UrlEncode(utf8.encode(loginId)).replaceAll('=', '');
    return 'practitioner_$encoded';
  }

  static String _passwordHash(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  static void _emitSession() {
    if (!_sessionController.isClosed) {
      _sessionController.add(_currentSession);
    }
  }
}

class _LocalPractitionerAccount {
  const _LocalPractitionerAccount({
    required this.id,
    required this.loginId,
    required this.passwordHash,
    required this.displayName,
    required this.clinicId,
    required this.createdAtIso,
    required this.lastLoginAtIso,
  });

  final String id;
  final String loginId;
  final String passwordHash;
  final String displayName;
  final String? clinicId;
  final String createdAtIso;
  final String lastLoginAtIso;

  factory _LocalPractitionerAccount.fromJson(Map<String, dynamic> json) {
    return _LocalPractitionerAccount(
      id: (json['id'] ?? '').toString(),
      loginId: (json['loginId'] ?? '').toString(),
      passwordHash: (json['passwordHash'] ?? '').toString(),
      displayName: (json['displayName'] ?? '').toString(),
      clinicId: json['clinicId']?.toString(),
      createdAtIso: (json['createdAtIso'] ?? '').toString(),
      lastLoginAtIso: (json['lastLoginAtIso'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'loginId': loginId,
      'passwordHash': passwordHash,
      'displayName': displayName,
      'clinicId': clinicId,
      'createdAtIso': createdAtIso,
      'lastLoginAtIso': lastLoginAtIso,
    };
  }

  _LocalPractitionerAccount copyWith({
    String? displayName,
    String? clinicId,
    String? lastLoginAtIso,
  }) {
    return _LocalPractitionerAccount(
      id: id,
      loginId: loginId,
      passwordHash: passwordHash,
      displayName: displayName ?? this.displayName,
      clinicId: clinicId ?? this.clinicId,
      createdAtIso: createdAtIso,
      lastLoginAtIso: lastLoginAtIso ?? this.lastLoginAtIso,
    );
  }

  PractitionerSession toSession() {
    return PractitionerSession(
      id: id,
      loginId: loginId,
      displayName: displayName,
      clinicId: clinicId,
    );
  }
}
