import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile_model.dart';
import '../models/time_log_model.dart';
import 'staff_service.dart';

class PayrollService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Generate a Payroll Report for a given date range
  static Future<PayrollReport> generateReport(DateTime start, DateTime end) async {
      // 1. Fetch all staff
      final staffStream = StaffService.getAllStaffStream();
      final allStaff = await staffStream.first;
      
      // 2. Fetch all logs in range
      final logsSnap = await _db.collection('time_logs')
          .where('clockInTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('clockInTime', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();
          
      final logs = logsSnap.docs.map((d) => TimeLogModel.fromFirestore(d)).toList();
      
      // 3. Aggregate
      double totalCost = 0;
      final List<StaffPayStub> stubs = [];
      
      for (final staff in allStaff) {
          final staffLogs = logs.where((l) => l.userId == staff.uid && l.status == TimeLogStatus.completed).toList();
          
          double regularHours = 0;
          double overtimeHours = 0;
          
          for (final log in staffLogs) {
              // Basic logic: > 8 hours in a day is OT? Or weekly?
              // Let's do simple sum for MVP
              regularHours += log.hoursWorked ?? 0;
          }
          
          // Mock overtime logic: if total > 40
          if (regularHours > 40) {
              overtimeHours = regularHours - 40;
              regularHours = 40;
          }
          
          final rate = staff.hourlyRate ?? 15.0; // Default min wage
          final regularPay = regularHours * rate;
          final overtimePay = overtimeHours * (rate * 1.5);
          final totalPay = regularPay + overtimePay;
          
          if (totalPay > 0) {
              stubs.add(StaffPayStub(
                  staff: staff,
                  regularHours: regularHours,
                  overtimeHours: overtimeHours,
                  regularPay: regularPay,
                  overtimePay: overtimePay,
                  totalPay: totalPay,
              ));
              totalCost += totalPay;
          }
      }
      
      return PayrollReport(
          startDate: start,
          endDate: end,
          totalLaborCost: totalCost,
          stubs: stubs,
      );
  }
}

class PayrollReport {
    final DateTime startDate;
    final DateTime endDate;
    final double totalLaborCost;
    final List<StaffPayStub> stubs;
    
    PayrollReport({required this.startDate, required this.endDate, required this.totalLaborCost, required this.stubs});
}

class StaffPayStub {
    final UserProfile staff;
    final double regularHours;
    final double overtimeHours;
    final double regularPay;
    final double overtimePay;
    final double totalPay;
    
    StaffPayStub({
        required this.staff, 
        required this.regularHours, 
        required this.overtimeHours, 
        required this.regularPay, 
        required this.overtimePay, 
        required this.totalPay
    });
}
