import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/schedule_model.dart';
import '../models/shift_model.dart';
import '../models/shift_swap_request_model.dart';
import '../models/user_profile_model.dart'; // Added missing import

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
  
  /// Get active requests for a user (either sent by them or targeted to them/open)
  static Stream<List<ShiftSwapRequestModel>> getSwapRequestsForUser(String userId) {
    // 1. Direct requests to me
    return _db.collection('shift_swaps')
        .where('targetUserId', isEqualTo: userId)
        .where('status', isEqualTo: SwapStatus.pending.name)
        .snapshots()
        .map((s) => s.docs.map((d) => ShiftSwapRequestModel.fromFirestore(d)).toList());
  }

  /// Peer accepts the swap (Step 2)
  static Future<void> acceptSwapByPeer(String requestId, String peerId, String peerName) async {
       await _db.collection('shift_swaps').doc(requestId).update({
           'status': SwapStatus.acceptedByPeer.name,
           'targetUserId': peerId, // Lock it in if it was "open"
           'targetUserName': peerName, // Lock it in
       });
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
  /// "Smart Fill": Auto-assign open shifts to eligible staff
  static Future<int> autoAssignShifts(String scheduleId) async {
    final batch = _db.batch();
    int assignedCount = 0;

    // 1. Get all OPEN shifts for this schedule
    final shiftsSnap = await _db
        .collection('shifts')
        .where('scheduleId', isEqualTo: scheduleId)
        .where('userId', isNull: true) // Only open shifts
        .get();

    if (shiftsSnap.docs.isEmpty) return 0;

    // 2. Get all ACTIVE staff
    final staffSnap = await _db
        .collection('users')
        .where('userType', isEqualTo: 'staff') // String 'staff'
        .where('isActive', isEqualTo: true)
        .get();
        
    final allStaff = staffSnap.docs.map((d) => UserProfile.fromFirestore(d)).toList();
    if (allStaff.isEmpty) return 0;

    // 3. Round-Robin Assignment Logic
    // Group staff by role for quick lookup
    final staffByRole = <StaffRole, List<UserProfile>>{};
    for (final s in allStaff) {
       if (s.staffRole != null) staffByRole.putIfAbsent(s.staffRole!, () => []).add(s);
    }

    // Shuffle staff for fairness
    for (final list in staffByRole.values) {
        list.shuffle();
    }
    
    // Track assignment counts to balance load
    final assignmentCounts = {for (var s in allStaff) s.uid: 0};

    for (final doc in shiftsSnap.docs) {
       final shift = ShiftModel.fromFirestore(doc);
       final candidates = staffByRole[shift.role] ?? [];
       
       if (candidates.isNotEmpty) {
           // Find candidate with lowest assignments so far (basic load balancing)
           candidates.sort((a, b) => assignmentCounts[a.uid]!.compareTo(assignmentCounts[b.uid]!));
           final bestCandidate = candidates.first;
           
           batch.update(doc.reference, {
               'userId': bestCandidate.uid,
               'assigneeName': bestCandidate.displayName,
               'status': ShiftStatus.assigned.name,
           });
           
           assignmentCounts[bestCandidate.uid] = assignmentCounts[bestCandidate.uid]! + 1;
           assignedCount++;
       }
    }

    await batch.commit();
    return assignedCount;
  }
}
