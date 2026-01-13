import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CommsPrefs {
  final bool optInEmail;
  final bool optInSms;
  final bool optInPush;

  const CommsPrefs({
    required this.optInEmail,
    required this.optInSms,
    required this.optInPush,
  });
}

class CommsPrefsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DocumentReference<Map<String, dynamic>>? _userRef() {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _db.collection('users').doc(user.uid);
  }

  Stream<CommsPrefs> prefsStream() {
    final ref = _userRef();
    if (ref == null) return const Stream.empty();
    return ref.snapshots().map((doc) {
      final data = doc.data() ?? {};
      return CommsPrefs(
        optInEmail: (data['optInEmail'] as bool?) ?? true,
        optInSms: (data['optInSms'] as bool?) ?? true,
        optInPush: (data['optInPush'] as bool?) ?? false,
      );
    });
  }

  Future<void> update({
    bool? optInEmail,
    bool? optInSms,
    bool? optInPush,
  }) async {
    final ref = _userRef();
    if (ref == null) return;
    await ref.set({
      if (optInEmail != null) 'optInEmail': optInEmail,
      if (optInSms != null) 'optInSms': optInSms,
      if (optInPush != null) 'optInPush': optInPush,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
