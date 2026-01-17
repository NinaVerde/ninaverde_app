import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String id;
  final String productId;
  final String userId;
  final String userName;
  final int rating;
  final String comment;
  final String status;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.productId,
    required this.userId,
    required this.userName,
    required this.rating,
    required this.comment,
    required this.status,
    required this.createdAt,
  });

  factory Review.fromFirestore(DocumentSnapshot doc, String productId) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final createdTs = data['createdAt'] as Timestamp?;
    return Review(
      id: doc.id,
      productId: productId,
      userId: (data['userId'] as String?) ?? '',
      userName: (data['userName'] as String?) ?? '',
      rating: (data['rating'] as num?)?.toInt() ?? 0,
      comment: (data['comment'] as String?) ?? '',
      status: (data['status'] as String?) ?? 'pending',
      createdAt:
          createdTs != null ? createdTs.toDate() : DateTime.now(),
    );
  }
}
