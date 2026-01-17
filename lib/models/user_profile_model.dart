// lib/models/user_profile_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// User type categories
enum UserType {
  client,      // Regular customer
  staff,       // Employee
  associate,   // Business partner/external employer
  admin,       // System administrator
}

/// Staff role subcategories
enum StaffRole {
  driver,      // Delivery driver
  server,      // Server/waiter
  kitchen,     // Kitchen staff/chef
  manager,     // Manager
  cashier,     // Cashier/front desk
  hostess,     // Host/Hostess
}

/// User profile with role-based access control
class UserProfile {
  final String uid;
  final String email;
  final String displayName;
  final String? phoneNumber;
  final String? photoUrl;
  
  // Role-based access
  final UserType userType;
  final StaffRole? staffRole; // Only for staff users
  final List<String> permissions; // Fine-grained permissions
  
  // Staff-specific fields
  final String? employeeId;
  final DateTime? hireDate;
  final double? hourlyRate;
  final String? departmentId;
  final bool isActive;
  
  // Associate-specific fields
  final String? businessName;
  final String? businessId;
  
  // Metadata
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    this.phoneNumber,
    this.photoUrl,
    this.userType = UserType.client,
    this.staffRole,
    this.permissions = const [],
    this.employeeId,
    this.hireDate,
    this.hourlyRate,
    this.departmentId,
    this.isActive = true,
    this.businessName,
    this.businessId,
    required this.createdAt,
    this.lastLoginAt,
  });

  /// Check if user has a specific permission
  bool hasPermission(String permission) {
    return permissions.contains(permission) || 
           permissions.contains('admin') || 
           userType == UserType.admin;
  }

  /// Check if user is staff member
  bool get isStaff => userType == UserType.staff;

  /// Check if user is manager
  bool get isManager => staffRole == StaffRole.manager || userType == UserType.admin;

  /// Check if user can access kitchen display
  bool get canAccessKitchen => 
      staffRole == StaffRole.kitchen || 
      staffRole == StaffRole.manager || 
      userType == UserType.admin;

  /// Check if user is driver
  bool get isDriver => staffRole == StaffRole.driver;

  /// Check if user is server
  bool get isServer => staffRole == StaffRole.server;

  /// Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'photoUrl': photoUrl,
      'userType': userType.name,
      'staffRole': staffRole?.name,
      'permissions': permissions,
      'employeeId': employeeId,
      'hireDate': hireDate != null ? Timestamp.fromDate(hireDate!) : null,
      'hourlyRate': hourlyRate,
      'departmentId': departmentId,
      'isActive': isActive,
      'businessName': businessName,
      'businessId': businessId,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt': lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : null,
    };
  }

  /// Create from Firestore document
  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    DateTime? parseTimestamp(dynamic ts) {
      if (ts is Timestamp) return ts.toDate();
      return null;
    }

    return UserProfile(
      uid: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      phoneNumber: data['phoneNumber'],
      photoUrl: data['photoUrl'],
      userType: UserType.values.firstWhere(
        (e) => e.name == data['userType'],
        orElse: () => UserType.client,
      ),
      staffRole: data['staffRole'] != null
          ? StaffRole.values.firstWhere(
              (e) => e.name == data['staffRole'],
              orElse: () => StaffRole.server,
            )
          : null,
      permissions: (data['permissions'] as List?)?.cast<String>() ?? [],
      employeeId: data['employeeId'],
      hireDate: parseTimestamp(data['hireDate']),
      hourlyRate: (data['hourlyRate'] as num?)?.toDouble(),
      departmentId: data['departmentId'],
      isActive: data['isActive'] ?? true,
      businessName: data['businessName'],
      businessId: data['businessId'],
      createdAt: parseTimestamp(data['createdAt']) ?? DateTime.now(),
      lastLoginAt: parseTimestamp(data['lastLoginAt']),
    );
  }

  /// Create a copy with updated fields
  UserProfile copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? phoneNumber,
    String? photoUrl,
    UserType? userType,
    StaffRole? staffRole,
    List<String>? permissions,
    String? employeeId,
    DateTime? hireDate,
    double? hourlyRate,
    String? departmentId,
    bool? isActive,
    String? businessName,
    String? businessId,
    DateTime? createdAt,
    DateTime? lastLoginAt,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      userType: userType ?? this.userType,
      staffRole: staffRole ?? this.staffRole,
      permissions: permissions ?? this.permissions,
      employeeId: employeeId ?? this.employeeId,
      hireDate: hireDate ?? this.hireDate,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      departmentId: departmentId ?? this.departmentId,
      isActive: isActive ?? this.isActive,
      businessName: businessName ?? this.businessName,
      businessId: businessId ?? this.businessId,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }
}

/// Predefined permission constants
class Permissions {
  // Kitchen permissions
  static const String viewKitchen = 'kitchen.view';
  static const String manageOrders = 'kitchen.manage_orders';
  
  // Driver permissions
  static const String viewDeliveries = 'delivery.view';
  static const String acceptDeliveries = 'delivery.accept';
  
  // Manager permissions
  static const String viewReports = 'reports.view';
  static const String manageStaff = 'staff.manage';
  static const String manageSchedule = 'schedule.manage';
  static const String manageInventory = 'inventory.manage';
  
  // Admin permissions
  static const String admin = 'admin';
  static const String manageSettings = 'settings.manage';
  static const String managePayroll = 'payroll.manage';
  
  // Associate permissions
  static const String postJobs = 'jobs.post';
  static const String viewApplications = 'jobs.view_applications';
}

/// Helper to get default permissions for a staff role
List<String> getDefaultPermissionsForRole(UserType userType, StaffRole? staffRole) {
  if (userType == UserType.admin) {
    return [Permissions.admin];
  }
  
  if (userType != UserType.staff || staffRole == null) {
    return [];
  }
  
  switch (staffRole) {
    case StaffRole.kitchen:
      return [
        Permissions.viewKitchen,
        Permissions.manageOrders,
      ];
      
    case StaffRole.driver:
      return [
        Permissions.viewDeliveries,
        Permissions.acceptDeliveries,
      ];
      
    case StaffRole.server:
      return [
        Permissions.viewKitchen,
      ];
      
    case StaffRole.manager:
      return [
        Permissions.viewKitchen,
        Permissions.manageOrders,
        Permissions.viewDeliveries,
        Permissions.viewReports,
        Permissions.manageStaff,
        Permissions.manageSchedule,
        Permissions.manageInventory,
      ];
      
    case StaffRole.cashier:
      return [
        Permissions.viewReports,
      ];
      
    case StaffRole.hostess:
      return [];
  }
}
