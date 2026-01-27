// lib/services/kitchen_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/order_model.dart';

/// Service for managing kitchen operations and order workflow
class KitchenService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  
  static const String ordersCollection = 'orders';
  
  KitchenService() {
    _initializeNotifications();
  }
  
  /// Initialize local notifications for kitchen alerts
  Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _notifications.initialize(settings: initSettings);
  }
  
  /// Get stream of active orders for kitchen display
  Stream<List<OrderModel>> getActiveOrdersStream() {
    return _firestore
        .collection(ordersCollection)
        .where('status', whereIn: ['paid', 'preparing', 'ready'])
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
    });
  }
  
  /// Get stream of orders ready for delivery/serving
  Stream<List<OrderModel>> getReadyOrdersStream() {
    return _firestore
        .collection(ordersCollection)
        .where('status', isEqualTo: 'ready')
        .orderBy('prepCompletedAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
    });
  }
  
  /// Get driver's active deliveries
  Stream<List<OrderModel>> getDriverOrdersStream(String driverId) {
    return _firestore
        .collection(ordersCollection)
        .where('assignedDriver', isEqualTo: driverId)
        .where('status', whereIn: ['ready', 'delivering'])
        .orderBy('deliveryStartedAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
    });
  }
  
  /// Start preparing an order (kitchen accepts it)
  Future<void> startPreparingOrder(String orderId, String kitchenStaffId) async {
    await _firestore.collection(ordersCollection).doc(orderId).update({
      'status': OrderStatus.preparing.name,
      'assignedKitchenStaff': kitchenStaffId,
      'prepStartedAt': FieldValue.serverTimestamp(),
    });
    
    await _sendNotification(
      'Order Started',
      'Kitchen has started preparing order #${orderId.substring(0, 8)}',
    );
  }
  
  /// Mark order as ready for pickup/delivery
  Future<void> markOrderReady(String orderId) async {
    final orderDoc = await _firestore.collection(ordersCollection).doc(orderId).get();
    final order = OrderModel.fromFirestore(orderDoc);
    
    await _firestore.collection(ordersCollection).doc(orderId).update({
      'status': OrderStatus.ready.name,
      'prepCompletedAt': FieldValue.serverTimestamp(),
    });
    
    // Notify drivers or servers
    await _sendNotification(
      'Order Ready! 🔔',
      'Order #${orderId.substring(0, 8)} is ready for ${order.orderType == OrderType.delivery ? 'pickup' : 'serving'}',
    );
  }
  
  /// Assign driver and start delivery
  Future<void> startDelivery(String orderId, String driverId) async {
    await _firestore.collection(ordersCollection).doc(orderId).update({
      'status': OrderStatus.delivering.name,
      'assignedDriver': driverId,
      'deliveryStartedAt': FieldValue.serverTimestamp(),
    });
    
    await _sendNotification(
      'Out for Delivery 🚗',
      'Order #${orderId.substring(0, 8)} is now being delivered',
    );
  }
  
  /// Complete order (delivered or served)
  Future<void> completeOrder(String orderId) async {
    await _firestore.collection(ordersCollection).doc(orderId).update({
      'status': OrderStatus.completed.name,
      'deliveryCompletedAt': FieldValue.serverTimestamp(),
    });
    
    await _sendNotification(
      'Order Completed ✅',
      'Order #${orderId.substring(0, 8)} has been completed',
    );
  }
  
  /// Cancel an order
  Future<void> cancelOrder(String orderId, String reason) async {
    await _firestore.collection(ordersCollection).doc(orderId).update({
      'status': OrderStatus.cancelled.name,
      'notes': reason,
    });
  }
  
  /// Reassign order to different kitchen staff
  Future<void> reassignKitchenStaff(String orderId, String newStaffId) async {
    await _firestore.collection(ordersCollection).doc(orderId).update({
      'assignedKitchenStaff': newStaffId,
    });
  }
  
  /// Get order statistics for kitchen dashboard
  Future<Map<String, int>> getKitchenStats() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    
    final ordersQuery = await _firestore
        .collection(ordersCollection)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .get();
    
    final orders = ordersQuery.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
    
    return {
      'total': orders.length,
      'pending': orders.where((o) => o.status == OrderStatus.pending || o.status == OrderStatus.paid).length,
      'preparing': orders.where((o) => o.status == OrderStatus.preparing).length,
      'ready': orders.where((o) => o.status == OrderStatus.ready).length,
      'delivering': orders.where((o) => o.status == OrderStatus.delivering).length,
      'completed': orders.where((o) => o.status == OrderStatus.completed).length,
      'cancelled': orders.where((o) => o.status == OrderStatus.cancelled).length,
    };
  }
  
  /// Calculate average preparation time
  Future<Duration?> getAveragePrepTime() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    
    final ordersQuery = await _firestore
        .collection(ordersCollection)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('status', whereIn: ['ready', 'delivering', 'completed'])
        .get();
    
    final orders = ordersQuery.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
    
    final completedOrders = orders.where((o) => 
      o.prepStartedAt != null && o.prepCompletedAt != null
    ).toList();
    
    if (completedOrders.isEmpty) return null;
    
    final totalMinutes = completedOrders.fold<int>(0, (total, order) {
      final duration = order.prepCompletedAt!.difference(order.prepStartedAt!);
      return total + duration.inMinutes;
    });
    
    final avgMinutes = totalMinutes ~/ completedOrders.length;
    return Duration(minutes: avgMinutes);
  }
  
  /// Send local notification
  Future<void> _sendNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'kitchen_orders',
      'Kitchen Orders',
      channelDescription: 'Notifications for kitchen order updates',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _notifications.show(
      id: DateTime.now().millisecondsSinceEpoch % 100000,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }
}
