// lib/models/accounting_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum ExpenseCategory {
  inventory,    // Food/Drink stock
  supplies,     // Napkins, cleaning supplies, etc.
  staff,        // Salaries/Wages (if manual)
  overhead,     // Rent, Utilities
  marketing,    // Ads, Promos
  maintenance,  // Repairs
  other
}

/// Represents a single expense entry
class ExpenseModel {
  final String id;
  final ExpenseCategory category;
  final String description;
  final double amount;
  final String currencyCode; // USD or NIO
  final DateTime date;
  final String? recordedByUserId; // Who entered it
  final List<String> receiptUrls; // Images of receipts
  final String? relatedOrderId; // If tied to a specific supply order
  final bool isVerified; // Reviewed by admin/owner
  final List<String> complianceIssues; // e.g. "Missing Receipt", "High Amount"
  final Map<String, dynamic>? metadata;


  ExpenseModel({
    required this.id,
    required this.category,
    required this.description,
    required this.amount,
    required this.currencyCode,
    required this.date,
    this.recordedByUserId,
    this.receiptUrls = const [],
    this.relatedOrderId,
    this.metadata,
    this.isVerified = false,
    this.complianceIssues = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'category': category.name,
      'description': description,
      'amount': amount,
      'currencyCode': currencyCode,
      'date': Timestamp.fromDate(date),
      'recordedByUserId': recordedByUserId,
      'receiptUrls': receiptUrls,
      'relatedOrderId': relatedOrderId,
      'metadata': metadata,
      'isVerified': isVerified,
      'complianceIssues': complianceIssues,
    };
  }

  factory ExpenseModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ExpenseModel(
      id: doc.id,
      category: ExpenseCategory.values.firstWhere(
        (e) => e.name == data['category'],
        orElse: () => ExpenseCategory.other,
      ),
      description: data['description'] ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      currencyCode: data['currencyCode'] ?? 'USD',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      recordedByUserId: data['recordedByUserId'],
      receiptUrls: (data['receiptUrls'] as List?)?.cast<String>() ?? [],
      relatedOrderId: data['relatedOrderId'],
      metadata: data['metadata'],
      isVerified: data['isVerified'] ?? false,
      complianceIssues: (data['complianceIssues'] as List?)?.cast<String>() ?? [],
    );
  }
}

/// Represents a work shift or logged hours for staff cost calculation
class WorkLogModel {
  final String id;
  final String staffId;
  final String staffName;
  final DateTime startTime;
  final DateTime? endTime;
  final double hourlyRateSnapshot;
  final double? totalPay; // Calculated on completion
  final bool isPaid; // If this shift has been paid out

  WorkLogModel({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.startTime,
    this.endTime,
    required this.hourlyRateSnapshot,
    this.totalPay,
    this.isPaid = false,
  });
  
  // Basic serialization...
  Map<String, dynamic> toMap() {
    return {
        'staffId': staffId,
        'staffName': staffName,
        'startTime': Timestamp.fromDate(startTime),
        'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
        'hourlyRateSnapshot': hourlyRateSnapshot,
        'totalPay': totalPay,
        'isPaid': isPaid,
    };
  }

  factory WorkLogModel.fromFirestore(DocumentSnapshot doc) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      return WorkLogModel(
          id: doc.id,
          staffId: data['staffId'] ?? '',
          staffName: data['staffName'] ?? '',
          startTime: (data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
          endTime: (data['endTime'] as Timestamp?)?.toDate(),
          hourlyRateSnapshot: (data['hourlyRateSnapshot'] as num?)?.toDouble() ?? 0.0,
          totalPay: (data['totalPay'] as num?)?.toDouble(),
          isPaid: data['isPaid'] ?? false,
      );
  }
}
