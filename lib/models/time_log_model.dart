import 'package:cloud_firestore/cloud_firestore.dart';

enum TimeLogStatus {
  active,    // Currently clocked in
  completed, // Clocked out
  edited,    // Manually adjusted by admin
  flagged,   // Suspicious activity (e.g. location mismatch)
}

class TimeLogModel {
  final String id;
  final String userId;
  final String? shiftId; // Link to scheduled shift (optional, can clock in unscheduled)
  
  final DateTime clockInTime;
  final DateTime? clockOutTime;
  
  final GeoPoint? clockInLocation;
  final GeoPoint? clockOutLocation;
  
  final TimeLogStatus status;
  final String? systemNotes; // "Auto-clocked via Geofence", "User manual override"
  final String? adminNotes;
  
  // Calculated only if completed
  final double? hoursWorked;

  TimeLogModel({
    required this.id,
    required this.userId,
    this.shiftId,
    required this.clockInTime,
    this.clockOutTime,
    this.clockInLocation,
    this.clockOutLocation,
    this.status = TimeLogStatus.active,
    this.systemNotes,
    this.adminNotes,
    this.hoursWorked,
  });

  bool get isActive => status == TimeLogStatus.active;

  Duration get duration {
    if (clockOutTime == null) {
      return DateTime.now().difference(clockInTime);
    }
    return clockOutTime!.difference(clockInTime);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'shiftId': shiftId,
      'clockInTime': Timestamp.fromDate(clockInTime),
      'clockOutTime': clockOutTime != null ? Timestamp.fromDate(clockOutTime!) : null,
      'clockInLocation': clockInLocation,
      'clockOutLocation': clockOutLocation,
      'status': status.name,
      'systemNotes': systemNotes,
      'adminNotes': adminNotes,
      'hoursWorked': hoursWorked,
    };
  }

  factory TimeLogModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    DateTime? parseTimestamp(dynamic ts) {
      if (ts is Timestamp) return ts.toDate();
      return null;
    }

    return TimeLogModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      shiftId: data['shiftId'],
      clockInTime: parseTimestamp(data['clockInTime']) ?? DateTime.now(),
      clockOutTime: parseTimestamp(data['clockOutTime']),
      clockInLocation: data['clockInLocation'] as GeoPoint?,
      clockOutLocation: data['clockOutLocation'] as GeoPoint?,
      status: TimeLogStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => TimeLogStatus.active,
      ),
      systemNotes: data['systemNotes'],
      adminNotes: data['adminNotes'],
      hoursWorked: (data['hoursWorked'] as num?)?.toDouble(),
    );
  }

  TimeLogModel copyWith({
    String? id,
    String? userId,
    String? shiftId,
    DateTime? clockInTime,
    DateTime? clockOutTime,
    GeoPoint? clockInLocation,
    GeoPoint? clockOutLocation,
    TimeLogStatus? status,
    String? systemNotes,
    String? adminNotes,
    double? hoursWorked,
  }) {
    return TimeLogModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      shiftId: shiftId ?? this.shiftId,
      clockInTime: clockInTime ?? this.clockInTime,
      clockOutTime: clockOutTime ?? this.clockOutTime,
      clockInLocation: clockInLocation ?? this.clockInLocation,
      clockOutLocation: clockOutLocation ?? this.clockOutLocation,
      status: status ?? this.status,
      systemNotes: systemNotes ?? this.systemNotes,
      adminNotes: adminNotes ?? this.adminNotes,
      hoursWorked: hoursWorked ?? this.hoursWorked,
    );
  }
}
