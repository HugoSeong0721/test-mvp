import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/clinic_data_store.dart';
import 'beta_session_service.dart';

class PatientProfileService {
  PatientProfileService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final ClinicDataStore _store = ClinicDataStore.instance;
  static final Map<String, StreamController<PatientProfile?>>
  _localProfileControllers = <String, StreamController<PatientProfile?>>{};
  static SharedPreferences? _prefs;

  static CollectionReference<Map<String, dynamic>> get _profiles =>
      _db.collection('patients');

  static Stream<PatientProfile?> watchProfile(String uid) {
    return _profiles.doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }
      final data = snapshot.data() ?? <String, dynamic>{};
      final savedName = (data['name'] as String?)?.trim() ?? '';
      return PatientProfile(
        id: uid,
        name: savedName.isEmpty ? 'New Patient' : savedName,
        phone: (data['phone'] as String?) ?? '',
        email: (data['email'] as String?) ?? '',
        birthYear: (data['birthYear'] as num?)?.toInt() ?? 1990,
        sex: (data['sex'] as String?) ?? 'Not entered',
        ethnicity: (data['ethnicity'] as String?) ?? 'Not entered',
        memo: (data['memo'] as String?) ?? '',
      );
    });
  }

  static Future<void> ensureProfileForUser(
    User user, {
    String? nameHint,
  }) async {
    final doc = _profiles.doc(user.uid);
    final snapshot = await doc.get();
    if (snapshot.exists) {
      await doc.set({
        'email': user.email ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _store.markPatientPortalRegistered(user.uid);
      return;
    }

    await doc.set({
      'name': nameHint?.trim().isNotEmpty == true
          ? nameHint!.trim()
          : (user.displayName?.trim().isNotEmpty == true
                ? user.displayName!.trim()
                : 'New Patient'),
      'phone': '',
      'email': user.email ?? '',
      'birthYear': 1990,
      'sex': 'Not entered',
      'ethnicity': 'Not entered',
      'memo': 'Profile created from beta sign-up',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _store.markPatientPortalRegistered(user.uid);
  }

  static Future<void> ensureProfileForSession(
    PatientSession session, {
    String? nameHint,
  }) async {
    if (session.usesFirebaseAuth) {
      final user = _auth.currentUser;
      if (user != null && user.uid == session.id) {
        await ensureProfileForUser(user, nameHint: nameHint);
      }
      return;
    }

    final existing = await loadLocalProfile(session.id);
    if (existing != null) {
      final resolvedName = existing.name.trim().isEmpty
          ? _resolvedProfileName(session: session, nameHint: nameHint)
          : existing.name;
      final updated = existing.copyWith(
        name: resolvedName,
        email: existing.email.trim().isEmpty ? session.email : existing.email,
      );
      if (updated != existing) {
        await saveLocalProfile(updated);
      } else {
        _syncLocalProfileToStore(existing);
      }
      return;
    }

    await saveLocalProfile(
      PatientProfile(
        id: session.id,
        name: _resolvedProfileName(session: session, nameHint: nameHint),
        phone: '',
        email: session.email,
        birthYear: 1990,
        sex: 'Not entered',
        ethnicity: 'Not entered',
        memo: 'Profile created from beta sign-up',
      ),
    );
  }

  static Stream<PatientProfile?> watchProfileForSession(
    PatientSession session,
  ) {
    return session.usesFirebaseAuth
        ? watchProfile(session.id)
        : watchLocalProfile(session.id);
  }

  static Stream<PatientProfile?> watchLocalProfile(String uid) async* {
    yield await loadLocalProfile(uid);
    yield* _localControllerFor(uid).stream;
  }

  static Future<PatientProfile?> loadLocalProfile(String uid) async {
    final raw = (await _preferences()).getString(_localProfileKey(uid));
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final profile = _profileFromMap(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
      _syncLocalProfileToStore(profile);
      return profile;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveProfile(PatientProfile profile) async {
    final session = await BetaSessionService.currentSessionAsync();
    if (session != null &&
        !session.usesFirebaseAuth &&
        session.id == profile.id) {
      await saveLocalProfile(profile);
      return;
    }

    await _profiles.doc(profile.id).set({
      'name': profile.name,
      'phone': profile.phone,
      'email': profile.email,
      'birthYear': profile.birthYear,
      'sex': profile.sex,
      'ethnicity': profile.ethnicity,
      'memo': profile.memo,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (session != null && session.id == profile.id) {
      await _store.markPatientPortalRegistered(profile.id);
    }
  }

  static Future<void> saveLocalProfile(PatientProfile profile) async {
    await (await _preferences()).setString(
      _localProfileKey(profile.id),
      jsonEncode(_profileToMap(profile)),
    );
    _syncLocalProfileToStore(profile);
    await _store.markPatientPortalRegistered(profile.id);
    await BetaSessionService.syncLocalAccountProfile(profile);
    _localControllerFor(profile.id).add(profile);
  }

  static Future<void> signOut() => BetaSessionService.signOut();

  static StreamController<PatientProfile?> _localControllerFor(String uid) {
    return _localProfileControllers.putIfAbsent(
      uid,
      () => StreamController<PatientProfile?>.broadcast(),
    );
  }

  static Future<SharedPreferences> _preferences() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  static String _localProfileKey(String uid) => 'beta_local_profile_v1_$uid';

  static String _resolvedProfileName({
    required PatientSession session,
    String? nameHint,
  }) {
    final trimmedHint = nameHint?.trim() ?? '';
    if (trimmedHint.isNotEmpty) {
      return trimmedHint;
    }
    final trimmedDisplayName = session.displayName.trim();
    if (trimmedDisplayName.isNotEmpty) {
      return trimmedDisplayName;
    }
    return 'New Patient';
  }

  static PatientProfile _profileFromMap(Map<String, dynamic> data) {
    final savedName = (data['name'] as String?)?.trim() ?? '';
    return PatientProfile(
      id: (data['id'] ?? '').toString(),
      name: savedName.isEmpty ? 'New Patient' : savedName,
      phone: (data['phone'] ?? '').toString(),
      email: (data['email'] ?? '').toString(),
      birthYear: (data['birthYear'] as num?)?.toInt() ?? 1990,
      sex: (data['sex'] ?? 'Not entered').toString(),
      ethnicity: (data['ethnicity'] ?? 'Not entered').toString(),
      memo: (data['memo'] ?? '').toString(),
    );
  }

  static Map<String, dynamic> _profileToMap(PatientProfile profile) {
    return {
      'id': profile.id,
      'name': profile.name,
      'phone': profile.phone,
      'email': profile.email,
      'birthYear': profile.birthYear,
      'sex': profile.sex,
      'ethnicity': profile.ethnicity,
      'memo': profile.memo,
    };
  }

  static void _syncLocalProfileToStore(PatientProfile profile) {
    _store.saveProfile(profile);
    _store.setCurrentPatientProfile(profile.id);
    unawaited(_store.markPatientPortalRegistered(profile.id));
  }
}
