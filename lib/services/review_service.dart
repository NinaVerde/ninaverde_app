import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/review_model.dart';

class ReviewSettings {
  final bool autoApproveEnabled;
  final int autoApproveMinRating;

  const ReviewSettings({
    required this.autoApproveEnabled,
    required this.autoApproveMinRating,
  });
}

class ReviewService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _cfgCol = 'app_config';
  static const String _settingsDoc = 'reviews';

  DocumentReference<Map<String, dynamic>> get _settingsRef =>
      _db.collection(_cfgCol).doc(_settingsDoc);

  CollectionReference<Map<String, dynamic>> _reviewsRoot(String productId) =>
      _db.collection('product_reviews').doc(productId).collection('items');

  DocumentReference<Map<String, dynamic>> _productRef(String productId) =>
      _db.collection('products').doc(productId);

  Stream<ReviewSettings> settingsStream() {
    return _settingsRef.snapshots().map((doc) {
      final data = doc.data() ?? {};
      return ReviewSettings(
        autoApproveEnabled: (data['autoApproveEnabled'] as bool?) ?? true,
        autoApproveMinRating: (data['autoApproveMinRating'] as num?)?.toInt() ?? 3,
      );
    });
  }

  Future<ReviewSettings> getSettings() async {
    final doc = await _settingsRef.get();
    final data = doc.data() ?? {};
    return ReviewSettings(
      autoApproveEnabled: (data['autoApproveEnabled'] as bool?) ?? true,
      autoApproveMinRating: (data['autoApproveMinRating'] as num?)?.toInt() ?? 3,
    );
  }

  Future<void> saveSettings(ReviewSettings settings) async {
    await _settingsRef.set({
      'autoApproveEnabled': settings.autoApproveEnabled,
      'autoApproveMinRating': settings.autoApproveMinRating,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<List<Review>> approvedReviews(String productId) {
    return _reviewsRoot(productId)
        .where('status', isEqualTo: 'approved')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => Review.fromFirestore(doc, productId)).toList());
  }

  Stream<List<Review>> moderationQueue() {
    return _db
        .collectionGroup('items')
        .where('status', whereIn: const ['pending', 'flagged'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
      return snap.docs.map((doc) {
        final productId = doc.reference.parent.parent?.id ?? '';
        return Review.fromFirestore(doc, productId);
      }).toList();
    });
  }

  Future<void> submitReview({
    required String productId,
    required int rating,
    required String comment,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final settings = await getSettings();
    final isFlagged = rating <= 2;
    final shouldAutoApprove =
        settings.autoApproveEnabled && rating >= settings.autoApproveMinRating;
    final status = isFlagged
        ? 'flagged'
        : shouldAutoApprove
            ? 'approved'
            : 'pending';

    final reviewRef = _reviewsRoot(productId).doc();
    await _db.runTransaction((txn) async {
      // READ FIRST (Firestore Rule: All reads must come before any writes)
      Map<String, dynamic> productData = {};
      
      if (status == 'approved') {
        final productRef = _productRef(productId);
        final productSnap = await txn.get(productRef);
        productData = productSnap.data() ?? {};
      }

      // WRITES
      txn.set(reviewRef, {
        'productId': productId,
        'userId': user.uid,
        'userName': user.displayName ?? user.email ?? 'Guest',
        'rating': rating,
        'comment': comment.trim(),
        'status': status,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (status == 'approved') {
        final productRef = _productRef(productId);
        final ratingSum = (productData['ratingSum'] as num?)?.toDouble() ?? 0.0;
        final ratingCount = (productData['ratingCount'] as num?)?.toInt() ?? 0;
        final nextSum = ratingSum + rating;
        final nextCount = ratingCount + 1;
        
        txn.set(productRef, {
          'ratingSum': nextSum,
          'ratingCount': nextCount,
          'ratingAvg': nextCount == 0 ? 0 : nextSum / nextCount,
          'reviewsUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    });
  }

  Future<void> approveReview(Review review) async {
    final ref = _reviewsRoot(review.productId).doc(review.id);
    await _db.runTransaction((txn) async {
      final snap = await txn.get(ref);
      final data = snap.data() ?? {};
      if (data['status'] == 'approved') return;

      txn.set(ref, {
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final productRef = _productRef(review.productId);
      final productSnap = await txn.get(productRef);
      final prod = productSnap.data() ?? {};
      final ratingSum = (prod['ratingSum'] as num?)?.toDouble() ?? 0.0;
      final ratingCount = (prod['ratingCount'] as num?)?.toInt() ?? 0;
      final nextSum = ratingSum + review.rating;
      final nextCount = ratingCount + 1;
      txn.set(productRef, {
        'ratingSum': nextSum,
        'ratingCount': nextCount,
        'ratingAvg': nextCount == 0 ? 0 : nextSum / nextCount,
        'reviewsUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> rejectReview(Review review, {String? reason}) async {
    final ref = _reviewsRoot(review.productId).doc(review.id);
    await ref.set({
      'status': 'rejected',
      'rejectionReason': reason,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> resolveFlaggedReview(Review review, String notes) async {
    final ref = _reviewsRoot(review.productId).doc(review.id);
    await ref.set({
      'resolved': true,
      'managerNotes': notes,
      'status': 'resolved', // Or keep as flagged but resolved
      'resolvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<List<Review>> allReviews() {
    return _db
        .collectionGroup('items')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
      return snap.docs.map((doc) {
        final productId = doc.reference.parent.parent?.id ?? '';
        return Review.fromFirestore(doc, productId);
      }).toList();
    });
  }
}
