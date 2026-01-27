// lib/models/reservation_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Type of reservation
enum ReservationType {
  table,      // Reserve a table for dining
  event,      // Reserve a spot at an event
  preOrder,   // Pre-order food for pickup/delivery
}

/// Status of a reservation
enum ReservationStatus {
  pending,     // Awaiting confirmation
  confirmed,   // Confirmed by staff
  seated,      // Customer has arrived (table only)
  completed,   // Reservation fulfilled
  cancelled,   // Cancelled by customer or staff
  noShow,      // Customer didn't show up
}

/// Comprehensive reservation model
class ReservationModel {
  final String id;
  final String userId;
  final String userName;
  final String userPhone;
  final String userEmail;
  
  // Reservation details
  final ReservationType type;
  final ReservationStatus status;
  final DateTime reservationTime;
  final int partySize; // Number of people
  
  // Table reservation specific
  final String? tableNumber;
  final String? seatingPreference; // indoor, outdoor, bar, etc.
  
  // Event reservation specific
  final String? eventId;
  final String? eventName;
  final int? ticketCount;
  
  // Pre-order specific
  final String? orderId;  // Reference to the order
  final DateTime? pickupTime;
  
  // Common fields
  final String? specialRequests;
  final String? dietaryRestrictions;
  final bool isVIP;
  final double? depositAmount;
  final bool depositPaid;
  
  // Staff assignment
  final String? assignedStaffId;
  final String? assignedStaffName;
  
  // Metadata
  final DateTime createdAt;
  final DateTime? confirmedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  
  // Reminders
  final bool reminderSent;
  final DateTime? reminderSentAt;

  ReservationModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhone,
    required this.userEmail,
    required this.type,
    required this.status,
    required this.reservationTime,
    required this.partySize,
    this.tableNumber,
    this.seatingPreference,
    this.eventId,
    this.eventName,
    this.ticketCount,
    this.orderId,
    this.pickupTime,
    this.specialRequests,
    this.dietaryRestrictions,
    this.isVIP = false,
    this.depositAmount,
    this.depositPaid = false,
    this.assignedStaffId,
    this.assignedStaffName,
    required this.createdAt,
    this.confirmedAt,
    this.completedAt,
    this.cancelledAt,
    this.cancellationReason,
    this.reminderSent = false,
    this.reminderSentAt,
  });

  /// Check if reservation is active
  bool get isActive =>
      status == ReservationStatus.pending ||
      status == ReservationStatus.confirmed ||
      status == ReservationStatus.seated;

  /// Check if reservation is in the future
  bool get isFuture => reservationTime.isAfter(DateTime.now());

  /// Check if reservation is today
  bool get isToday {
    final now = DateTime.now();
    final resDate = reservationTime;
    return now.year == resDate.year &&
        now.month == resDate.month &&
        now.day == resDate.day;
  }

  /// Minutes until reservation
  int get minutesUntil => reservationTime.difference(DateTime.now()).inMinutes;

  /// Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userPhone': userPhone,
      'userEmail': userEmail,
      'type': type.name,
      'status': status.name,
      'reservationTime': Timestamp.fromDate(reservationTime),
      'partySize': partySize,
      'tableNumber': tableNumber,
      'seatingPreference': seatingPreference,
      'eventId': eventId,
      'eventName': eventName,
      'ticketCount': ticketCount,
      'orderId': orderId,
      'pickupTime': pickupTime != null ? Timestamp.fromDate(pickupTime!) : null,
      'specialRequests': specialRequests,
      'dietaryRestrictions': dietaryRestrictions,
      'isVIP': isVIP,
      'depositAmount': depositAmount,
      'depositPaid': depositPaid,
      'assignedStaffId': assignedStaffId,
      'assignedStaffName': assignedStaffName,
      'createdAt': Timestamp.fromDate(createdAt),
      'confirmedAt': confirmedAt != null ? Timestamp.fromDate(confirmedAt!) : null,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'cancelledAt': cancelledAt != null ? Timestamp.fromDate(cancelledAt!) : null,
      'cancellationReason': cancellationReason,
      'reminderSent': reminderSent,
      'reminderSentAt': reminderSentAt != null ? Timestamp.fromDate(reminderSentAt!) : null,
    };
  }

  /// Create from Firestore document
  factory ReservationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    DateTime? parseTimestamp(dynamic ts) {
      if (ts is Timestamp) return ts.toDate();
      return null;
    }

    return ReservationModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userPhone: data['userPhone'] ?? '',
      userEmail: data['userEmail'] ?? '',
      type: ReservationType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => ReservationType.table,
      ),
      status: ReservationStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => ReservationStatus.pending,
      ),
      reservationTime: parseTimestamp(data['reservationTime']) ?? DateTime.now(),
      partySize: data['partySize'] ?? 1,
      tableNumber: data['tableNumber'],
      seatingPreference: data['seatingPreference'],
      eventId: data['eventId'],
      eventName: data['eventName'],
      ticketCount: data['ticketCount'],
      orderId: data['orderId'],
      pickupTime: parseTimestamp(data['pickupTime']),
      specialRequests: data['specialRequests'],
      dietaryRestrictions: data['dietaryRestrictions'],
      isVIP: data['isVIP'] ?? false,
      depositAmount: (data['depositAmount'] as num?)?.toDouble(),
      depositPaid: data['depositPaid'] ?? false,
      assignedStaffId: data['assignedStaffId'],
      assignedStaffName: data['assignedStaffName'],
      createdAt: parseTimestamp(data['createdAt']) ?? DateTime.now(),
      confirmedAt: parseTimestamp(data['confirmedAt']),
      completedAt: parseTimestamp(data['completedAt']),
      cancelledAt: parseTimestamp(data['cancelledAt']),
      cancellationReason: data['cancellationReason'],
      reminderSent: data['reminderSent'] ?? false,
      reminderSentAt: parseTimestamp(data['reminderSentAt']),
    );
  }

  /// Create a copy with modifications
  ReservationModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userPhone,
    String? userEmail,
    ReservationType? type,
    ReservationStatus? status,
    DateTime? reservationTime,
    int? partySize,
    String? tableNumber,
    String? seatingPreference,
    String? eventId,
    String? eventName,
    int? ticketCount,
    String? orderId,
    DateTime? pickupTime,
    String? specialRequests,
    String? dietaryRestrictions,
    bool? isVIP,
    double? depositAmount,
    bool? depositPaid,
    String? assignedStaffId,
    String? assignedStaffName,
    DateTime? createdAt,
    DateTime? confirmedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    String? cancellationReason,
    bool? reminderSent,
    DateTime? reminderSentAt,
  }) {
    return ReservationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userPhone: userPhone ?? this.userPhone,
      userEmail: userEmail ?? this.userEmail,
      type: type ?? this.type,
      status: status ?? this.status,
      reservationTime: reservationTime ?? this.reservationTime,
      partySize: partySize ?? this.partySize,
      tableNumber: tableNumber ?? this.tableNumber,
      seatingPreference: seatingPreference ?? this.seatingPreference,
      eventId: eventId ?? this.eventId,
      eventName: eventName ?? this.eventName,
      ticketCount: ticketCount ?? this.ticketCount,
      orderId: orderId ?? this.orderId,
      pickupTime: pickupTime ?? this.pickupTime,
      specialRequests: specialRequests ?? this.specialRequests,
      dietaryRestrictions: dietaryRestrictions ?? this.dietaryRestrictions,
      isVIP: isVIP ?? this.isVIP,
      depositAmount: depositAmount ?? this.depositAmount,
      depositPaid: depositPaid ?? this.depositPaid,
      assignedStaffId: assignedStaffId ?? this.assignedStaffId,
      assignedStaffName: assignedStaffName ?? this.assignedStaffName,
      createdAt: createdAt ?? this.createdAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      reminderSent: reminderSent ?? this.reminderSent,
      reminderSentAt: reminderSentAt ?? this.reminderSentAt,
    );
  }
}

/// Table configuration model
class TableModel {
  final String id;
  final String number;
  final int capacity;
  final String location; // indoor, outdoor, patio, bar
  final bool isAvailable;
  final List<String> features; // window, booth, private, etc.
  
  TableModel({
    required this.id,
    required this.number,
    required this.capacity,
    required this.location,
    this.isAvailable = true,
    this.features = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'number': number,
      'capacity': capacity,
      'location': location,
      'isAvailable': isAvailable,
      'features': features,
    };
  }

  factory TableModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return TableModel(
      id: doc.id,
      number: data['number'] ?? '',
      capacity: data['capacity'] ?? 2,
      location: data['location'] ?? 'indoor',
      isAvailable: data['isAvailable'] ?? true,
      features: (data['features'] as List?)?.cast<String>() ?? [],
    );
  }
}
