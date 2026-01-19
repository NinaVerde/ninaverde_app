import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/cart_provider.dart'; // For CartItem

enum OrderType { delivery, pickup, dineIn }
enum OrderStatus { pending, paid, preparing, ready, delivering, completed, cancelled }
enum PaymentMethod { bac, paypal, cash }

class OrderModel {
  final String id;
  final String userId;
  final String userName; // Snapshot of user name at checkout
  final String userPhone;
  final OrderType orderType;
  final OrderStatus status;
  final PaymentMethod paymentMethod;
  
  // Fulfillment Details
  final String? deliveryAddress;
  final String? tableNumber; // For dine-in
  final String? notes;
  
  // Kitchen Workflow
  final String? assignedKitchenStaff; // Staff member preparing order
  final String? assignedDriver; // Driver for delivery
  final DateTime? prepStartedAt; // When kitchen started preparing
  final DateTime? prepCompletedAt; // When kitchen marked ready
  final DateTime? deliveryStartedAt; // When driver picked up
  final DateTime? deliveryCompletedAt; // When delivered/served

  // Financials
  final List<CartItemSnapshot> items;
  final double subtotal;
  final double tax; // IVA 15%
  final double serviceFee; // 10% for dine-in optional?
  final double tip;
  final double total;
  final String currencyCode; // USD or NIO
  final double exchangeRate; // At time of purchase

  final DateTime createdAt;

  OrderModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhone,
    required this.orderType,
    this.status = OrderStatus.pending,
    required this.paymentMethod,
    this.deliveryAddress,
    this.tableNumber,
    this.notes,
    this.assignedKitchenStaff,
    this.assignedDriver,
    this.prepStartedAt,
    this.prepCompletedAt,
    this.deliveryStartedAt,
    this.deliveryCompletedAt,
    required this.items,
    required this.subtotal,
    required this.tax,
    this.serviceFee = 0.0,
    required this.tip,
    required this.total,
    required this.currencyCode,
    required this.exchangeRate,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userPhone': userPhone,
      'orderType': orderType.name,
      'status': status.name,
      'paymentMethod': paymentMethod.name,
      'deliveryAddress': deliveryAddress,
      'tableNumber': tableNumber,
      'notes': notes,
      'assignedKitchenStaff': assignedKitchenStaff,
      'assignedDriver': assignedDriver,
      'prepStartedAt': prepStartedAt != null ? Timestamp.fromDate(prepStartedAt!) : null,
      'prepCompletedAt': prepCompletedAt != null ? Timestamp.fromDate(prepCompletedAt!) : null,
      'deliveryStartedAt': deliveryStartedAt != null ? Timestamp.fromDate(deliveryStartedAt!) : null,
      'deliveryCompletedAt': deliveryCompletedAt != null ? Timestamp.fromDate(deliveryCompletedAt!) : null,
      'items': items.map((x) => x.toMap()).toList(),
      'subtotal': subtotal,
      'tax': tax,
      'serviceFee': serviceFee,
      'tip': tip,
      'total': total,
      'currencyCode': currencyCode,
      'exchangeRate': exchangeRate,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
  
  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    DateTime? parseTimestamp(dynamic ts) {
      if (ts is Timestamp) return ts.toDate();
      return null;
    }
    
    List<CartItemSnapshot> parseItems(dynamic itemsData) {
      if (itemsData is! List) return [];
      return itemsData.map((item) {
        if (item is! Map<String, dynamic>) return null;
        return CartItemSnapshot(
          productId: item['productId'] ?? '',
          name: item['name'] ?? '',
          price: (item['price'] as num?)?.toDouble() ?? 0.0,
          quantity: item['quantity'] ?? 1,
          imageUrl: item['imageUrl'] ?? '',
        );
      }).whereType<CartItemSnapshot>().toList();
    }
    
    return OrderModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userPhone: data['userPhone'] ?? '',
      orderType: OrderType.values.firstWhere(
        (e) => e.name == data['orderType'],
        orElse: () => OrderType.pickup,
      ),
      status: OrderStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => OrderStatus.pending,
      ),
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) => e.name == data['paymentMethod'],
        orElse: () => PaymentMethod.cash,
      ),
      deliveryAddress: data['deliveryAddress'],
      tableNumber: data['tableNumber'],
      notes: data['notes'],
      assignedKitchenStaff: data['assignedKitchenStaff'],
      assignedDriver: data['assignedDriver'],
      prepStartedAt: parseTimestamp(data['prepStartedAt']),
      prepCompletedAt: parseTimestamp(data['prepCompletedAt']),
      deliveryStartedAt: parseTimestamp(data['deliveryStartedAt']),
      deliveryCompletedAt: parseTimestamp(data['deliveryCompletedAt']),
      items: parseItems(data['items']),
      subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0.0,
      tax: (data['tax'] as num?)?.toDouble() ?? 0.0,
      serviceFee: (data['serviceFee'] as num?)?.toDouble() ?? 0.0,
      tip: (data['tip'] as num?)?.toDouble() ?? 0.0,
      total: (data['total'] as num?)?.toDouble() ?? 0.0,
      currencyCode: data['currencyCode'] ?? 'USD',
      exchangeRate: (data['exchangeRate'] as num?)?.toDouble() ?? 1.0,
      createdAt: parseTimestamp(data['createdAt']) ?? DateTime.now(),
    );
  }
  
  OrderModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userPhone,
    OrderType? orderType,
    OrderStatus? status,
    PaymentMethod? paymentMethod,
    String? deliveryAddress,
    String? tableNumber,
    String? notes,
    String? assignedKitchenStaff,
    String? assignedDriver,
    DateTime? prepStartedAt,
    DateTime? prepCompletedAt,
    DateTime? deliveryStartedAt,
    DateTime? deliveryCompletedAt,
    List<CartItemSnapshot>? items,
    double? subtotal,
    double? tax,
    double? serviceFee,
    double? tip,
    double? total,
    String? currencyCode,
    double? exchangeRate,
    DateTime? createdAt,
  }) {
    return OrderModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userPhone: userPhone ?? this.userPhone,
      orderType: orderType ?? this.orderType,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      tableNumber: tableNumber ?? this.tableNumber,
      notes: notes ?? this.notes,
      assignedKitchenStaff: assignedKitchenStaff ?? this.assignedKitchenStaff,
      assignedDriver: assignedDriver ?? this.assignedDriver,
      prepStartedAt: prepStartedAt ?? this.prepStartedAt,
      prepCompletedAt: prepCompletedAt ?? this.prepCompletedAt,
      deliveryStartedAt: deliveryStartedAt ?? this.deliveryStartedAt,
      deliveryCompletedAt: deliveryCompletedAt ?? this.deliveryCompletedAt,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      tax: tax ?? this.tax,
      serviceFee: serviceFee ?? this.serviceFee,
      tip: tip ?? this.tip,
      total: total ?? this.total,
      currencyCode: currencyCode ?? this.currencyCode,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// A snapshot of a cart item at the time of purchase, preserving price/name 
/// even if product changes later.
class CartItemSnapshot {
  final String productId;
  final String name;
  final double price; // Unit price at time of purchase
  final int quantity;
  final String imageUrl;

  CartItemSnapshot({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.imageUrl,
  });

  factory CartItemSnapshot.fromCartItem(CartItem item) {
    return CartItemSnapshot(
      productId: item.product.id,
      name: item.product.name,
      price: item.product.price,
      quantity: item.quantity,
      imageUrl: item.product.imageUrl,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'name': name,
      'price': price,
      'quantity': quantity,
      'imageUrl': imageUrl,
    };
  }
}
