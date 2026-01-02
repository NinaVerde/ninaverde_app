// lib/services/user_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service to manage user documents in Firestore.
/// Called after login to ensure a record always exists for the current user.
class UserService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Upsert the current user into Firestore.
  /// Creates or updates a user document with basic profile info.
  static Future<void> upsertCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userRef = _db.collection('users').doc(user.uid);

    await userRef.set({
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'photoURL': user.photoURL,
      'phoneNumber': user.phoneNumber,
      'lastSignIn': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
