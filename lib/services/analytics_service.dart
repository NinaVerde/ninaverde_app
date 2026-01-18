import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<void> logEvent(String name, Map<String, dynamic> parameters) async {
    final user = _auth.currentUser;
    try {
      await _db.collection('analytics_events').add({
        'name': name,
        'parameters': parameters,
        'userId': user?.uid ?? 'guest',
        'timestamp': FieldValue.serverTimestamp(),
        // Add minimal user profile snapshot for easier pivoting without joins
        'userEmail': user?.email, 
      });
    } catch (e) {
      // Analytics should never crash the app
      debugPrint('Analytics Error: $e');
    }
  }

  static Future<void> logProductView(String productId, String productName) {
    return logEvent('view_item', {
      'content_type': 'product',
      'item_id': productId,
      'item_name': productName,
    });
  }

  static Future<void> logAddToCart(String productId, String productName, double price) {
    return logEvent('add_to_cart', {
      'content_type': 'product',
      'item_id': productId,
      'item_name': productName,
      'value': price,
      'currency': 'USD', // Base currency
    });
  }

  static Future<void> logPurchase({
    required String orderId, 
    required double value, 
    required int itemCount
  }) {
    return logEvent('purchase', {
      'transaction_id': orderId,
      'value': value,
      'currency': 'USD',
      'items_count': itemCount,
    });
  }
  
  static Future<void> logShare(String contentType, String itemId) {
    return logEvent('share', {
      'content_type': contentType,
      'item_id': itemId,
    });
  }
}
