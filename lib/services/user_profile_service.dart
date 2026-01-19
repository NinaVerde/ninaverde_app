// lib/services/user_profile_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile_model.dart';

/// Service for managing user profiles and roles
class UserProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  static const String usersCollection = 'users';

  /// Get current user's profile
  Future<UserProfile?> getCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    
    return getUserProfile(user.uid);
  }

  /// Get user profile by UID
  Future<UserProfile?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection(usersCollection).doc(uid).get();
      if (!doc.exists) return null;
      return UserProfile.fromFirestore(doc);
    } catch (e) {
      return null;
    }
  }

  /// Create or update user profile
  Future<void> saveUserProfile(UserProfile profile) async {
    await _firestore
        .collection(usersCollection)
        .doc(profile.uid)
        .set(profile.toMap(), SetOptions(merge: true));
  }

  /// Update user type and role
  Future<void> updateUserRole({
    required String uid,
    required UserType userType,
    StaffRole? staffRole,
  }) async {
    final permissions = getDefaultPermissionsForRole(userType, staffRole);
    
    await _firestore.collection(usersCollection).doc(uid).update({
      'userType': userType.name,
      'staffRole': staffRole?.name,
      'permissions': permissions,
    });
  }

  /// Add custom permission to user
  Future<void> addPermission(String uid, String permission) async {
    await _firestore.collection(usersCollection).doc(uid).update({
      'permissions': FieldValue.arrayUnion([permission]),
    });
  }

  /// Remove permission from user
  Future<void> removePermission(String uid, String permission) async {
    await _firestore.collection(usersCollection).doc(uid).update({
      'permissions': FieldValue.arrayRemove([permission]),
    });
  }

  /// Get all staff members
  Stream<List<UserProfile>> getStaffStream() {
    return _firestore
        .collection(usersCollection)
        .where('userType', isEqualTo: UserType.staff.name)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => UserProfile.fromFirestore(doc)).toList();
    });
  }

  /// Get staff by role
  Stream<List<UserProfile>> getStaffByRoleStream(StaffRole role) {
    return _firestore
        .collection(usersCollection)
        .where('userType', isEqualTo: UserType.staff.name)
        .where('staffRole', isEqualTo: role.name)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => UserProfile.fromFirestore(doc)).toList();
    });
  }

  /// Get all drivers
  Stream<List<UserProfile>> getDriversStream() {
    return getStaffByRoleStream(StaffRole.driver);
  }

  /// Get all kitchen staff
  Stream<List<UserProfile>> getKitchenStaffStream() {
    return getStaffByRoleStream(StaffRole.kitchen);
  }

  /// Activate/deactivate employee
  Future<void> setEmployeeActive(String uid, bool isActive) async {
    await _firestore.collection(usersCollection).doc(uid).update({
      'isActive': isActive,
    });
  }

  /// Update last login time
  Future<void> updateLastLogin(String uid) async {
    await _firestore.collection(usersCollection).doc(uid).update({
      'lastLoginAt': FieldValue.serverTimestamp(),
    });
  }

  /// Create initial profile for new user
  Future<void> createInitialProfile(User user, {UserType userType = UserType.client}) async {
    final profile = UserProfile(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName ?? 'User',
      phoneNumber: user.phoneNumber,
      photoUrl: user.photoURL,
      userType: userType,
      permissions: getDefaultPermissionsForRole(userType, null),
      createdAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
    );
    
    await saveUserProfile(profile);
  }

  /// Get associates (business partners/external employers)
  Stream<List<UserProfile>> getAssociatesStream() {
    return _firestore
        .collection(usersCollection)
        .where('userType', isEqualTo: UserType.associate.name)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => UserProfile.fromFirestore(doc)).toList();
    });
  }
}
