// lib/services/reservation_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/reservation_model.dart';

/// Service for managing reservations
class ReservationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  
  static const String reservationsCollection = 'reservations';
  static const String tablesCollection = 'tables';

  /// Initialize notifications
  Future<void> initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOS = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: iOS);
    await _notifications.initialize(settings);
  }

  /// Create a new reservation
  Future<String> createReservation(ReservationModel reservation) async {
    final docRef = await _firestore
        .collection(reservationsCollection)
        .add(reservation.toMap());
    
    // Send confirmation
    await _sendReservationNotification(
      'Reservation Created',
      'Your reservation for ${reservation.partySize} on ${reservation.reservationTime} is pending confirmation.',
    );
    
    return docRef.id;
  }

  /// Get reservations stream for a user
  Stream<List<ReservationModel>> getUserReservationsStream(String userId) {
    return _firestore
        .collection(reservationsCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('reservationTime', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ReservationModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Get all reservations for a specific date
  Stream<List<ReservationModel>> getReservationsByDateStream(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    return _firestore
        .collection(reservationsCollection)
        .where('reservationTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('reservationTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .orderBy('reservationTime')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ReservationModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Get active reservations
  Stream<List<ReservationModel>> getActiveReservationsStream() {
    return _firestore
        .collection(reservationsCollection)
        .where('status', whereIn: ['pending', 'confirmed', 'seated'])
        .orderBy('reservationTime')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ReservationModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Confirm a reservation
  Future<void> confirmReservation(String reservationId, {String? staffId, String? staffName}) async {
    await _firestore.collection(reservationsCollection).doc(reservationId).update({
      'status': ReservationStatus.confirmed.name,
      'confirmedAt': FieldValue.serverTimestamp(),
      if (staffId != null) 'assignedStaffId': staffId,
      if (staffName != null) 'assignedStaffName': staffName,
    });
    
    await _sendReservationNotification(
      'Reservation Confirmed ✅',
      'Your reservation has been confirmed!',
    );
  }

  /// Mark customer as seated (table reservations)
  Future<void> markSeated(String reservationId) async {
    await _firestore.collection(reservationsCollection).doc(reservationId).update({
      'status': ReservationStatus.seated.name,
    });
  }

  /// Complete a reservation
  Future<void> completeReservation(String reservationId) async {
    await _firestore.collection(reservationsCollection).doc(reservationId).update({
      'status': ReservationStatus.completed.name,
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Cancel a reservation
  Future<void> cancelReservation(String reservationId, String reason) async {
    await _firestore.collection(reservationsCollection).doc(reservationId).update({
      'status': ReservationStatus.cancelled.name,
      'cancelledAt': FieldValue.serverTimestamp(),
      'cancellationReason': reason,
    });
    
    await _sendReservationNotification(
      'Reservation Cancelled',
      'Your reservation has been cancelled.',
    );
  }

  /// Mark as no-show
  Future<void> markNoShow(String reservationId) async {
    await _firestore.collection(reservationsCollection).doc(reservationId).update({
      'status': ReservationStatus.noShow.name,
    });
  }

  /// Assign staff to reservation
  Future<void> assignStaff(String reservationId, String staffId, String staffName) async {
    await _firestore.collection(reservationsCollection).doc(reservationId).update({
      'assignedStaffId': staffId,
      'assignedStaffName': staffName,
    });
  }

  /// Get available tables for a time slot
  Future<List<TableModel>> getAvailableTables(DateTime time, int partySize) async {
    // Get all tables
    final tablesSnapshot = await _firestore
        .collection(tablesCollection)
        .where('isAvailable', isEqualTo: true)
        .where('capacity', isGreaterThanOrEqualTo: partySize)
        .get();

    final allTables = tablesSnapshot.docs
        .map((doc) => TableModel.fromFirestore(doc))
        .toList();

    // Check which tables are reserved at this time (2-hour window)
    final timeStart = time.subtract(const Duration(hours: 2));
    final timeEnd = time.add(const Duration(hours: 2));

    final reservationsSnapshot = await _firestore
        .collection(reservationsCollection)
        .where('type', isEqualTo: ReservationType.table.name)
        .where('status', whereIn: ['confirmed', 'seated'])
        .where('reservationTime', isGreaterThanOrEqualTo: Timestamp.fromDate(timeStart))
        .where('reservationTime', isLessThanOrEqualTo: Timestamp.fromDate(timeEnd))
        .get();

    final reservedTableNumbers = reservationsSnapshot.docs
        .map((doc) => doc['tableNumber'] as String?)
        .where((num) => num != null)
        .toSet();

    // Filter out reserved tables
    return allTables.where((table) => !reservedTableNumbers.contains(table.number)).toList();
  }

  /// Send reservation reminders
  Future<void> sendReminder(String reservationId) async {
    await _firestore.collection(reservationsCollection).doc(reservationId).update({
      'reminderSent': true,
      'reminderSentAt': FieldValue.serverTimestamp(),
    });
    
    await _sendReservationNotification(
      'Reminder: Upcoming Reservation 📅',
      'Your reservation is coming up soon!',
    );
  }

  /// Get reservation statistics
  Future<Map<String, int>> getReservationStats(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final snapshot = await _firestore
        .collection(reservationsCollection)
        .where('reservationTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('reservationTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .get();

    final reservations = snapshot.docs
        .map((doc) => ReservationModel.fromFirestore(doc))
        .toList();

    return {
      'total': reservations.length,
      'pending': reservations.where((r) => r.status == ReservationStatus.pending).length,
      'confirmed': reservations.where((r) => r.status == ReservationStatus.confirmed).length,
      'seated': reservations.where((r) => r.status == ReservationStatus.seated).length,
      'completed': reservations.where((r) => r.status == ReservationStatus.completed).length,
      'cancelled': reservations.where((r) => r.status == ReservationStatus.cancelled).length,
      'noShow': reservations.where((r) => r.status == ReservationStatus.noShow).length,
    };
  }

  /// Check for conflicts
  Future<bool> hasConflict(DateTime time, String? tableNumber) async {
    if (tableNumber == null) return false;

    final timeStart = time.subtract(const Duration(hours: 1, minutes: 30));
    final timeEnd = time.add(const Duration(hours: 1, minutes: 30));

    final snapshot = await _firestore
        .collection(reservationsCollection)
        .where('tableNumber', isEqualTo: tableNumber)
        .where('status', whereIn: ['confirmed', 'seated'])
        .where('reservationTime', isGreaterThanOrEqualTo: Timestamp.fromDate(timeStart))
        .where('reservationTime', isLessThanOrEqualTo: Timestamp.fromDate(timeEnd))
        .get();

    return snapshot.docs.isNotEmpty;
  }

  /// Send local notification
  Future<void> _sendReservationNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'reservations',
      'Reservations',
      channelDescription: 'Reservation updates and reminders',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }

  /// Create or update table
  Future<void> saveTable(TableModel table) async {
    await _firestore
        .collection(tablesCollection)
        .doc(table.id)
        .set(table.toMap(), SetOptions(merge: true));
  }

  /// Get all tables
  Stream<List<TableModel>> getTablesStream() {
    return _firestore
        .collection(tablesCollection)
        .orderBy('number')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => TableModel.fromFirestore(doc)).toList();
    });
  }

  /// Delete table
  Future<void> deleteTable(String tableId) async {
    await _firestore.collection(tablesCollection).doc(tableId).delete();
  }
}
