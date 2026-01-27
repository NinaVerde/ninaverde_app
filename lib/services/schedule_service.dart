import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/schedule_model.dart';
import '../models/shift_model.dart';
import '../models/shift_swap_request_model.dart';

class ScheduleService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- Schedules ---

  /// Create a new schedule container (e.g., "Week 42")
  static Future<String> createSchedule(ScheduleModel schedule) async {
    final doc = _db.collection('schedules').doc();
    final newSchedule = schedule.copyWith(id: doc.id);
    await doc.set(newSchedule.toMap());
    return doc.id;
  }

  /// Update an existing schedule
  static Future<void> updateSchedule(ScheduleModel schedule) async {
    await _db
        .collection('schedules')
        .doc(schedule.id)
        .update(schedule.toMap());
  }

  /// Get all schedules, ordered by start date descending
  static Stream<List<ScheduleModel>> getSchedulesStream() {
    return _db
        .collection('schedules')
        .orderBy('startDate', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ScheduleModel.fromFirestore(doc)).toList());
  }
  
  /// Get a single schedule by ID
  static Future<ScheduleModel?> getSchedule(String id) async {
    final doc = await _db.collection('schedules').doc(id).get();
    if (!doc.exists) return null;
    return ScheduleModel.fromFirestore(doc);
  }

  // --- Shifts ---

  /// Add a shift to a schedule
  static Future<void> addShift(ShiftModel shift) async {
    final doc = shift.id.isEmpty
        ? _db.collection('shifts').doc()
        : _db.collection('shifts').doc(shift.id);
    
    final newShift = shift.copyWith(id: doc.id);
    await doc.set(newShift.toMap());
  }

  /// Update an existing shift
  static Future<void> updateShift(ShiftModel shift) async {
    await _db.collection('shifts').doc(shift.id).update(shift.toMap());
  }
  
  /// Delete a shift
  static Future<void> deleteShift(String shiftId) async {
    await _db.collection('shifts').doc(shiftId).delete();
  }

  /// Get all shifts for a specific schedule
  static Stream<List<ShiftModel>> getShiftsForSchedule(String scheduleId) {
    return _db
        .collection('shifts')
        .where('scheduleId', isEqualTo: scheduleId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ShiftModel.fromFirestore(doc)).toList());
  }
  
  /// Get upcoming shifts for a specific user
  static Stream<List<ShiftModel>> getUpcomingShiftsForUser(String userId) {
    final now = DateTime.now();
    return _db
        .collection('shifts')
        .where('userId', isEqualTo: userId)
        .where('startTime', isGreaterThan: Timestamp.fromDate(now))
        .orderBy('startTime')
        .limit(20)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ShiftModel.fromFirestore(doc)).toList());
  }

  /// Publish all shifts in a schedule
  static Future<void> publishSchedule(String scheduleId) async {
    final batch = _db.batch();
    
    // 1. Update Schedule status
    final scheduleRef = _db.collection('schedules').doc(scheduleId);
    batch.update(scheduleRef, {'status': ScheduleStatus.published.name});
    
    // 2. Update all associated shifts to published
    final shiftsQuery = await _db
        .collection('shifts')
        .where('scheduleId', isEqualTo: scheduleId)
        .get();
        
    for (final doc in shiftsQuery.docs) {
      batch.update(doc.reference, {'isPublished': true});
    }
    
    await batch.commit();
  }

  // --- Swaps ---

  /// Request a shift swap
  static Future<void> requestSwap(ShiftSwapRequestModel request) async {
    final doc = _db.collection('shift_swaps').doc();
    final newRequest = request.copyWith(id: doc.id);
    await doc.set(newRequest.toMap());
  }

  /// Get pending swaps for a manager to review
  static Stream<List<ShiftSwapRequestModel>> getPendingSwapsForManager() {
    return _db
        .collection('shift_swaps')
        .where('status', isEqualTo: SwapStatus.acceptedByPeer.name)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ShiftSwapRequestModel.fromFirestore(doc))
            .toList());
  }
  
  /// Get active requests for a user (either sent by them or targeted to them)
  static Stream<List<ShiftSwapRequestModel>> getSwapRequestsForUser(String userId) {
    // Note: Firestore OR queries are limited. We might need two queries or valueChanges.
    // For now, let's just fetch all recent and filter client side if needed, or index properly.
    // Simpler approach: Look where userId is target
    return _db.collection('shift_swaps')
        .where('targetUserId', isEqualTo: userId)
        .where('status', isEqualTo: SwapStatus.pending.name)
        .snapshots()
        .map((s) => s.docs.map((d) => ShiftSwapRequestModel.fromFirestore(d)).toList());
  }

  /// Approve or Reject a swap
  static Future<void> processSwapResolution(ShiftSwapRequestModel request, bool approved, String? managerNote) async {
    final batch = _db.batch();
    
    // 1. Update request status
    final requestRef = _db.collection('shift_swaps').doc(request.id);
    batch.update(requestRef, {
      'status': approved ? SwapStatus.approved.name : SwapStatus.rejected.name,
      'managerNote': managerNote,
    });
    
    if (approved) {
        // 2. Perform the swap on the shifts
        // Get the shift to be given away
        final shiftRef = _db.collection('shifts').doc(request.shiftId);
        
        // If there is a target user, assign to them
        if (request.targetUserId != null) {
            batch.update(shiftRef, {
                'userId': request.targetUserId,
                'assigneeName': request.targetUserName ?? 'Unknown', // Ideally fetch fresh name
            });
        }
        
        // If it was a two-way trade (targetShiftId exists), swap that too
        if (request.targetShiftId != null) {
            final targetShiftRef = _db.collection('shifts').doc(request.targetShiftId);
            batch.update(targetShiftRef, {
                'userId': request.requesterId,
                'assigneeName': request.requesterName ?? 'Unknown',
            });
        }
    }
    
    await batch.commit();
  }
}
