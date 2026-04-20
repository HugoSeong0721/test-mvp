import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/clinic_data_store.dart';

class PatientProfileService {
  PatientProfileService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

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
        sex: (data['sex'] as String?) ?? 'ë¯¸ìž…ë ¥',
        ethnicity: (data['ethnicity'] as String?) ?? 'ë¯¸ìž…ë ¥',
        memo: (data['memo'] as String?) ?? '',
      );
    });
  }

  static Future<void> ensureProfileForUser(User user, {String? nameHint}) async {
    final doc = _profiles.doc(user.uid);
    final snapshot = await doc.get();
    if (snapshot.exists) {
      await doc.set({
        'email': user.email ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
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
      'sex': 'ë¯¸ìž…ë ¥',
      'ethnicity': 'ë¯¸ìž…ë ¥',
      'memo': 'ë² íƒ€ íšŒì›ê°€ìž…ìœ¼ë¡œ ìƒì„±ëœ í”„ë¡œí•„',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> saveProfile(PatientProfile profile) async {
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
  }

  static Future<void> signOut() => _auth.signOut();
}

