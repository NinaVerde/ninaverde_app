import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserPrefsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DocumentReference<Map<String, dynamic>>? _prefsRef() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('prefs').doc('home');
  }

  Stream<Map<String, dynamic>> prefsStream() {
    final ref = _prefsRef();
    if (ref == null) return const Stream.empty();
    return ref.snapshots().map((snap) => snap.data() ?? {});
  }

  Future<Map<String, dynamic>> getPrefs() async {
    final ref = _prefsRef();
    if (ref == null) return {};
    final snap = await ref.get();
    return snap.data() ?? {};
  }

  Future<void> saveCategoryOrder(List<String> order) async {
    final ref = _prefsRef();
    if (ref == null) return;
    await ref.set({
      'categoryOrder': order,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> saveFavorites(Set<String> favorites) async {
    final ref = _prefsRef();
    if (ref == null) return;
    await ref.set({
      'favorites': favorites.toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> toggleFavorite({
    required String productId,
    required bool isFavorite,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final productRef = _db.collection('products').doc(productId);
    final summaryRef = _db.collection('crm_favorites').doc(productId);
    final eventRef = _db.collection('crm_favorites_events').doc();

    final delta = isFavorite ? 1 : -1;

    await _db.runTransaction((txn) async {
      txn.set(
        productRef,
        {
          'favoritesCount': FieldValue.increment(delta),
          'favoritesUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      txn.set(
        summaryRef,
        {
          'productId': productId,
          'count': FieldValue.increment(delta),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      txn.set(eventRef, {
        'productId': productId,
        'userId': uid,
        'isFavorite': isFavorite,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
