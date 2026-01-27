import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'user_profile_model.dart'; // For StaffRole

enum ShiftStatus {
  assigned,
  open,       // Up for grabs
  cancelled,
  completed,
}

class ShiftModel {
  final String id;
  final String scheduleId;
  final String? userId; // Null if open shift
  final String? assigneeName; // Denormalized for easy display
  final StaffRole role;
  final DateTime startTime;
  final DateTime endTime;
  final ShiftStatus status;
  final String? notes; // "Closing duties", "Patio section"
  
  // Metadata
  final bool isPublished;
  final DateTime? checkInTime; // Link to actual attendance
  final DateTime? checkOutTime;
  
  // Visuals
  final int? colorInt; // For color coding shifts (0xFF...)

  ShiftModel({
    required this.id,
    required this.scheduleId,
    this.userId,
    this.assigneeName,
    required this.role,
    required this.startTime,
    required this.endTime,
    this.status = ShiftStatus.assigned,
    this.notes,
    this.isPublished = false,
    this.checkInTime,
    this.checkOutTime,
    this.colorInt,
  });

  Duration get duration => endTime.difference(startTime);
  double get hours => duration.inMinutes / 60.0;
  
  Color? get color => colorInt != null ? Color(colorInt!) : null;

  bool get isOpen => userId == null || status == ShiftStatus.open;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'scheduleId': scheduleId,
      'userId': userId,
      'assigneeName': assigneeName,
      'role': role.name,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'status': status.name,
      'notes': notes,
      'isPublished': isPublished,
      'checkInTime': checkInTime != null ? Timestamp.fromDate(checkInTime!) : null,
      'checkOutTime': checkOutTime != null ? Timestamp.fromDate(checkOutTime!) : null,
      'colorInt': colorInt,
    };
  }

  factory ShiftModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    DateTime? parseTimestamp(dynamic ts) {
      if (ts is Timestamp) return ts.toDate();
      return null;
    }

    return ShiftModel(
      id: doc.id,
      scheduleId: data['scheduleId'] ?? '',
      userId: data['userId'],
      assigneeName: data['assigneeName'],
      role: StaffRole.values.firstWhere(
        (e) => e.name == data['role'],
        orElse: () => StaffRole.server,
      ),
      startTime: parseTimestamp(data['startTime']) ?? DateTime.now(),
      endTime: parseTimestamp(data['endTime']) ?? DateTime.now().add(const Duration(hours: 4)),
      status: ShiftStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => ShiftStatus.assigned,
      ),
      notes: data['notes'],
      isPublished: data['isPublished'] ?? false,
      checkInTime: parseTimestamp(data['checkInTime']),
      checkOutTime: parseTimestamp(data['checkOutTime']),
      colorInt: data['colorInt'],
    );
  }

  ShiftModel copyWith({
    String? id,
    String? scheduleId,
    String? userId,
    String? assigneeName,
    StaffRole? role,
    DateTime? startTime,
    DateTime? endTime,
    ShiftStatus? status,
    String? notes,
    bool? isPublished,
    DateTime? checkInTime,
    DateTime? checkOutTime,
    int? colorInt,
  }) {
    return ShiftModel(
      id: id ?? this.id,
      scheduleId: scheduleId ?? this.scheduleId,
      userId: userId ?? this.userId,
      assigneeName: assigneeName ?? this.assigneeName,
      role: role ?? this.role,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      isPublished: isPublished ?? this.isPublished,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      colorInt: colorInt ?? this.colorInt,
    );
  }
}
