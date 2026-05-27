import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/clinic_data_store.dart';

class PatientSession {
  const PatientSession({
    required this.id,
    required this.email,
    required this.displayName,
    required this.usesFirebaseAuth,
  });

  final String id;
  final String email;
  final String displayName;
  final bool usesFirebaseAuth;
}

class LocalPatientAccountSummary {
  const LocalPatientAccountSummary({
    required this.email,
    required this.displayName,
    required this.lastLoginAtIso,
  });

  final String email;
  final String displayName;
  final String lastLoginAtIso;
}

class LocalBetaAuthException implements Exception {
  const LocalBetaAuthException(this.code);

  final String code;

  @override
  String toString() => 'LocalBetaAuthException($code)';
}

class BetaSessionService {
  BetaSessionService._();

  static const String _accountsKey = 'beta_local_accounts_v1';
  static const String _sessionEmailKey = 'beta_local_session_email_v1';
  static final StreamController<PatientSession?> _sessionController =
      StreamController<PatientSession?>.broadcast();

  static SharedPreferences? _prefs;
  static Future<void>? _initialization;
  static PatientSession? _localSession;

  static Future<void> initialize() => _ensureInitialized();

  static Stream<PatientSession?> watchSession() async* {
    await _ensureInitialized();
    yield currentSession;
    yield* _sessionController.stream;
  }

  static PatientSession? get currentSession => _localSession;

  static Future<PatientSession?> currentSessionAsync() async {
    await _ensureInitialized();
    return currentSession;
  }

  static Future<PatientSession> signUpLocally({
    required String name,
    required String email,
    required String password,
  }) async {
    await _ensureInitialized();

    final trimmedName = name.trim();
    final normalizedEmail = _normalizeEmail(email);
    final trimmedPassword = password.trim();
    if (!_looksLikeEmail(normalizedEmail)) {
      throw const LocalBetaAuthException('invalid-email');
    }
    if (trimmedPassword.length < 6) {
      throw const LocalBetaAuthException('weak-password');
    }

    final accounts = _readLocalAccounts();
    if (accounts.any((account) => account.email == normalizedEmail)) {
      throw const LocalBetaAuthException('email-already-in-use');
    }

    final now = DateTime.now().toIso8601String();
    final account = _LocalBetaAccount(
      id: _localUserIdForEmail(normalizedEmail),
      email: normalizedEmail,
      passwordHash: _passwordHash(trimmedPassword),
      name: trimmedName,
      createdAtIso: now,
      lastLoginAtIso: now,
    );
    accounts.add(account);
    await _saveLocalAccounts(accounts);

    _localSession = account.toSession();
    await _preferences().then(
      (prefs) => prefs.setString(_sessionEmailKey, normalizedEmail),
    );
    _emitSession();
    return _localSession!;
  }

  static Future<PatientSession> logInLocally({
    required String email,
    required String password,
  }) async {
    await _ensureInitialized();

    final normalizedEmail = _normalizeEmail(email);
    final trimmedPassword = password.trim();
    final accounts = _readLocalAccounts();
    final index = accounts.indexWhere(
      (account) => account.email == normalizedEmail,
    );
    if (index < 0) {
      throw const LocalBetaAuthException('user-not-found');
    }

    final account = accounts[index];
    if (account.passwordHash != _passwordHash(trimmedPassword)) {
      throw const LocalBetaAuthException('wrong-password');
    }

    final updated = account.copyWith(
      lastLoginAtIso: DateTime.now().toIso8601String(),
    );
    accounts[index] = updated;
    await _saveLocalAccounts(accounts);

    _localSession = updated.toSession();
    await _preferences().then(
      (prefs) => prefs.setString(_sessionEmailKey, normalizedEmail),
    );
    _emitSession();
    return _localSession!;
  }

  static Future<PatientSession> continueWithEmailLocally({
    required String email,
    String? name,
  }) async {
    await _ensureInitialized();

    final normalizedEmail = _normalizeEmail(email);
    final trimmedName = name?.trim() ?? '';
    if (!_looksLikeEmail(normalizedEmail)) {
      throw const LocalBetaAuthException('invalid-email');
    }

    final accounts = _readLocalAccounts();
    final now = DateTime.now().toIso8601String();
    final index = accounts.indexWhere(
      (account) => account.email == normalizedEmail,
    );
    late final _LocalBetaAccount account;
    if (index >= 0) {
      account = accounts[index].copyWith(
        name: trimmedName.isEmpty ? accounts[index].name : trimmedName,
        lastLoginAtIso: now,
      );
      accounts[index] = account;
    } else {
      account = _LocalBetaAccount(
        id: _localUserIdForEmail(normalizedEmail),
        email: normalizedEmail,
        passwordHash: '',
        name: trimmedName.isEmpty
            ? normalizedEmail.split('@').first
            : trimmedName,
        createdAtIso: now,
        lastLoginAtIso: now,
      );
      accounts.add(account);
    }
    await _saveLocalAccounts(accounts);

    _localSession = account.toSession();
    await _preferences().then(
      (prefs) => prefs.setString(_sessionEmailKey, normalizedEmail),
    );
    _emitSession();
    return _localSession!;
  }

  static Future<void> signOut() async {
    await _ensureInitialized();
    _localSession = null;
    await _preferences().then((prefs) => prefs.remove(_sessionEmailKey));
    _emitSession();
  }

  static Future<void> syncLocalAccountProfile(PatientProfile profile) async {
    await _ensureInitialized();
    final accounts = _readLocalAccounts();
    final index = accounts.indexWhere((account) => account.id == profile.id);
    if (index < 0) {
      return;
    }

    final updated = accounts[index].copyWith(
      name: profile.name.trim().isEmpty ? accounts[index].name : profile.name,
    );
    accounts[index] = updated;
    await _saveLocalAccounts(accounts);

    if (_localSession?.id == profile.id) {
      _localSession = updated.toSession();
      _emitSession();
    }
  }

  static Future<List<LocalPatientAccountSummary>>
  localAccountSummaries() async {
    await _ensureInitialized();
    final accounts = _readLocalAccounts()
      ..sort((a, b) => b.lastLoginAtIso.compareTo(a.lastLoginAtIso));
    return accounts
        .map(
          (account) => LocalPatientAccountSummary(
            email: account.email,
            displayName: account.name,
            lastLoginAtIso: account.lastLoginAtIso,
          ),
        )
        .toList(growable: false);
  }

  static Future<void> resetLocalPassword({
    required String email,
    required String newPassword,
  }) async {
    await _ensureInitialized();
    final normalizedEmail = _normalizeEmail(email);
    final trimmedPassword = newPassword.trim();
    if (!_looksLikeEmail(normalizedEmail)) {
      throw const LocalBetaAuthException('invalid-email');
    }
    if (trimmedPassword.length < 6) {
      throw const LocalBetaAuthException('weak-password');
    }

    final accounts = _readLocalAccounts();
    final index = accounts.indexWhere(
      (account) => account.email == normalizedEmail,
    );
    if (index < 0) {
      throw const LocalBetaAuthException('user-not-found');
    }

    final updated = accounts[index].copyWith(
      passwordHash: _passwordHash(trimmedPassword),
      lastLoginAtIso: DateTime.now().toIso8601String(),
    );
    accounts[index] = updated;
    await _saveLocalAccounts(accounts);
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
    final savedEmail = (await _preferences()).getString(_sessionEmailKey);
    if (savedEmail == null || savedEmail.trim().isEmpty) {
      _localSession = null;
      return;
    }

    final normalizedEmail = _normalizeEmail(savedEmail);
    final account = _readLocalAccounts().cast<_LocalBetaAccount?>().firstWhere(
      (item) => item?.email == normalizedEmail,
      orElse: () => null,
    );
    _localSession = account?.toSession();
  }

  static List<_LocalBetaAccount> _readLocalAccounts() {
    final raw = _prefs?.getString(_accountsKey);
    if (raw == null || raw.trim().isEmpty) {
      return <_LocalBetaAccount>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <_LocalBetaAccount>[];
      }
      return decoded
          .whereType<Map>()
          .map(
            (item) => _LocalBetaAccount.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList();
    } catch (_) {
      return <_LocalBetaAccount>[];
    }
  }

  static Future<void> _saveLocalAccounts(
    List<_LocalBetaAccount> accounts,
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

  static String _normalizeEmail(String email) => email.trim().toLowerCase();

  static bool _looksLikeEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  static String _localUserIdForEmail(String email) {
    final encoded = base64UrlEncode(utf8.encode(email)).replaceAll('=', '');
    return 'beta_$encoded';
  }

  static String _passwordHash(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  static void _emitSession() {
    if (!_sessionController.isClosed) {
      _sessionController.add(currentSession);
    }
  }
}

class _LocalBetaAccount {
  const _LocalBetaAccount({
    required this.id,
    required this.email,
    required this.passwordHash,
    required this.name,
    required this.createdAtIso,
    required this.lastLoginAtIso,
  });

  final String id;
  final String email;
  final String passwordHash;
  final String name;
  final String createdAtIso;
  final String lastLoginAtIso;

  factory _LocalBetaAccount.fromJson(Map<String, dynamic> json) {
    return _LocalBetaAccount(
      id: (json['id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      passwordHash: (json['passwordHash'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      createdAtIso: (json['createdAtIso'] ?? '').toString(),
      lastLoginAtIso: (json['lastLoginAtIso'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'passwordHash': passwordHash,
      'name': name,
      'createdAtIso': createdAtIso,
      'lastLoginAtIso': lastLoginAtIso,
    };
  }

  _LocalBetaAccount copyWith({
    String? name,
    String? passwordHash,
    String? lastLoginAtIso,
  }) {
    return _LocalBetaAccount(
      id: id,
      email: email,
      passwordHash: passwordHash ?? this.passwordHash,
      name: name ?? this.name,
      createdAtIso: createdAtIso,
      lastLoginAtIso: lastLoginAtIso ?? this.lastLoginAtIso,
    );
  }

  PatientSession toSession() {
    return PatientSession(
      id: id,
      email: email,
      displayName: name.trim(),
      usesFirebaseAuth: false,
    );
  }
}
