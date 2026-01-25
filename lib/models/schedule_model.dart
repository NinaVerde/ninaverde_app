import 'package:cloud_firestore/cloud_firestore.dart';

enum ScheduleStatus {
  draft,     // Created but not visible to staff
  published, // Visible to staff
  archived,  // Old schedule
}

class ScheduleModel {
  final String id;
  final String name; // e.g., "Week 42 - Regular"
  final DateTime startDate;
  final DateTime endDate;
  final ScheduleStatus status;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? departmentId; // Optional: separate schedules per department
  
  // Metadata for "Elite" features
  final double totalHoursBudgeted;
  final double laborCostBudgeted;

  ScheduleModel({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    this.status = ScheduleStatus.draft,
    this.createdBy,
    required this.createdAt,
    this.updatedAt,
    this.departmentId,
    this.totalHoursBudgeted = 0.0,
    this.laborCostBudgeted = 0.0,
  });

  bool get isPublished => status == ScheduleStatus.published;
  
  /// Check if a date falls within this schedule
  bool containsDate(DateTime date) {
    return date.isAfter(startDate.subtract(const Duration(seconds: 1))) && 
           date.isBefore(endDate.add(const Duration(days: 1)));
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'status': status.name,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'departmentId': departmentId,
      'totalHoursBudgeted': totalHoursBudgeted,
      'laborCostBudgeted': laborCostBudgeted,
    };
  }

  factory ScheduleModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    DateTime? parseTimestamp(dynamic ts) {
      if (ts is Timestamp) return ts.toDate();
      return null;
    }

    return ScheduleModel(
      id: doc.id,
      name: data['name'] ?? 'Untitled Schedule',
      startDate: parseTimestamp(data['startDate']) ?? DateTime.now(),
      endDate: parseTimestamp(data['endDate']) ?? DateTime.now().add(const Duration(days: 7)),
      status: ScheduleStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => ScheduleStatus.draft,
      ),
      createdBy: data['createdBy'],
      createdAt: parseTimestamp(data['createdAt']) ?? DateTime.now(),
      updatedAt: parseTimestamp(data['updatedAt']),
      departmentId: data['departmentId'],
      totalHoursBudgeted: (data['totalHoursBudgeted'] as num?)?.toDouble() ?? 0.0,
      laborCostBudgeted: (data['laborCostBudgeted'] as num?)?.toDouble() ?? 0.0,
    );
  }

  ScheduleModel copyWith({
    String? id,
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    ScheduleStatus? status,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? departmentId,
    double? totalHoursBudgeted,
    double? laborCostBudgeted,
  }) {
    return ScheduleModel(
      id: id ?? this.id,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      departmentId: departmentId ?? this.departmentId,
      totalHoursBudgeted: totalHoursBudgeted ?? this.totalHoursBudgeted,
      laborCostBudgeted: laborCostBudgeted ?? this.laborCostBudgeted,
    );
  }
}
