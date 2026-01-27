import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile_model.dart';

class StaffService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Get all staff members
  static Stream<List<UserProfile>> getAllStaffStream() {
    return _db
        .collection('users')
        .where('userType', isEqualTo: 'staff') // Query based on string name of enum
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => UserProfile.fromFirestore(doc)).toList());
  }

  /// Get staff by role
  static Future<List<UserProfile>> getStaffByRole(StaffRole role) async {
    final snap = await _db
        .collection('users')
        .where('userType', isEqualTo: UserType.staff.name)
        .where('staffRole', isEqualTo: role.name)
        .get();
        
    return snap.docs.map((doc) => UserProfile.fromFirestore(doc)).toList();
  }

  /// Promote a user to staff
  static Future<void> promoteToStaff(String userId, StaffRole role, {double? hourlyRate}) async {
    await _db.collection('users').doc(userId).update({
      'userType': UserType.staff.name,
      'staffRole': role.name,
      'permissions': getDefaultPermissionsForRole(UserType.staff, role),
      'hourlyRate': hourlyRate,
      'isActive': true,
      'hireDate': Timestamp.now(),
    });
  }
  
  /// Update staff details
  static Future<void> updateStaffDetails(String userId, {
    StaffRole? role, 
    double? hourlyRate, 
    String? employeeId,
    bool? isActive
  }) async {
    final data = <String, dynamic>{};
    if (role != null) {
      data['staffRole'] = role.name;
      // Also update permissions to default for new role
      data['permissions'] = getDefaultPermissionsForRole(UserType.staff, role);
    }
    if (hourlyRate != null) data['hourlyRate'] = hourlyRate;
    if (employeeId != null) data['employeeId'] = employeeId;
    if (isActive != null) data['isActive'] = isActive;
    
    if (data.isNotEmpty) {
      await _db.collection('users').doc(userId).update(data);
    }
  }
}
