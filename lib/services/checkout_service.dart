import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';
import '../services/config_service.dart';

class CheckoutService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Calculate totals based on cart, order type, and configuration
  static Future<OrderTotals> calculateTotals({
    required double subtotal,
    required OrderType type,
    required double tipAmount,
  }) async {
    final config = await ConfigService.getPaymentConfig();
    
    // Tax (IVA 15%)
    final tax = subtotal * config.taxRate;
    
    // Service Fee (10% optional for Dine-In, enforced for now for simplicity)
    double serviceFee = 0.0;
    if (type == OrderType.dineIn) {
      serviceFee = subtotal * config.dineInServiceFeeRate;
    }

    final total = subtotal + tax + serviceFee + tipAmount;

    return OrderTotals(
      subtotal: subtotal,
      tax: tax,
      serviceFee: serviceFee,
      tip: tipAmount,
      total: total,
    );
  }

  /// Process payment with simulated BAC Credomatic gateway
  /// Returns a transaction ID if successful, throws error otherwise.
  static Future<String> processBacPayment({
    required String cardNumber,
    required String expiry,
    required String cvv,
    required String holderName,
    required double amount,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));

    // Basic mock validation
    if (cardNumber.replaceAll(' ', '').length < 13) {
      throw Exception('Invalid card number');
    }
    
    // Simulate gateway success
    return 'BAC-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}';
  }

  /// Process payment simulation for PayPal
  static Future<String> processPaypalPayment({
    required double amount,
  }) async {
    // In a real app, this would handle the webview flow result
    await Future.delayed(const Duration(seconds: 2));
    return 'PP-${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Submit order to Firestore
  static Future<void> submitOrder(OrderModel order) async {
    await _db.collection('orders').doc(order.id).set(order.toMap());
  }
}

class OrderTotals {
  final double subtotal;
  final double tax;
  final double serviceFee;
  final double tip;
  final double total;

  OrderTotals({
    required this.subtotal,
    required this.tax,
    required this.serviceFee,
    required this.tip,
    required this.total,
  });
}
