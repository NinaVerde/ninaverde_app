import 'package:cloud_firestore/cloud_firestore.dart';

enum SwapStatus {
  pending,          // Requester asked, waiting for peer
  acceptedByPeer,   // Peer said yes, waiting for manager
  approved,         // Manager approved, shift updated
  rejected,         // Peer or manager said no
  cancelled,        // Requester changed mind
}

class ShiftSwapRequestModel {
  final String id;
  final String requesterId;
  final String? requesterName;
  final String shiftId; // The shift the requester wants to GIVE AWAY
  
  final String? targetUserId; // Specific person asked?
  final String? targetUserName;
  
  final String? targetShiftId; // Optional: The shift they want in RETURN (trade)
  
  final DateTime createdAt;
  final SwapStatus status;
  final String? managerNote; // Reason for rejection/approval

  ShiftSwapRequestModel({
    required this.id,
    required this.requesterId,
    this.requesterName,
    required this.shiftId,
    this.targetUserId,
    this.targetUserName,
    this.targetShiftId,
    required this.createdAt,
    this.status = SwapStatus.pending,
    this.managerNote,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'requesterId': requesterId,
      'requesterName': requesterName,
      'shiftId': shiftId,
      'targetUserId': targetUserId,
      'targetUserName': targetUserName,
      'targetShiftId': targetShiftId,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status.name,
      'managerNote': managerNote,
    };
  }

  factory ShiftSwapRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    DateTime? parseTimestamp(dynamic ts) {
      if (ts is Timestamp) return ts.toDate();
      return null;
    }

    return ShiftSwapRequestModel(
      id: doc.id,
      requesterId: data['requesterId'] ?? '',
      requesterName: data['requesterName'],
      shiftId: data['shiftId'] ?? '',
      targetUserId: data['targetUserId'],
      targetUserName: data['targetUserName'],
      targetShiftId: data['targetShiftId'],
      createdAt: parseTimestamp(data['createdAt']) ?? DateTime.now(),
      status: SwapStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => SwapStatus.pending,
      ),
      managerNote: data['managerNote'],
    );
  }

  ShiftSwapRequestModel copyWith({
    String? id,
    String? requesterId,
    String? requesterName,
    String? shiftId,
    String? targetUserId,
    String? targetUserName,
    String? targetShiftId,
    DateTime? createdAt,
    SwapStatus? status,
    String? managerNote,
  }) {
    return ShiftSwapRequestModel(
      id: id ?? this.id,
      requesterId: requesterId ?? this.requesterId,
      requesterName: requesterName ?? this.requesterName,
      shiftId: shiftId ?? this.shiftId,
      targetUserId: targetUserId ?? this.targetUserId,
      targetUserName: targetUserName ?? this.targetUserName,
      targetShiftId: targetShiftId ?? this.targetShiftId,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      managerNote: managerNote ?? this.managerNote,
    );
  }
}
