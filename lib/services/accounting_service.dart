// lib/services/accounting_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/accounting_model.dart';
import '../models/order_model.dart';

class AccountingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collections
  CollectionReference get _expensesRef => _firestore.collection('accounting_expenses');
  CollectionReference get _workLogsRef => _firestore.collection('accounting_work_logs');
  CollectionReference get _ordersRef => _firestore.collection('orders');

  /// Add a new expense
  Future<void> addExpense(ExpenseModel expense) async {
    // Run pre-save compliance check
    List<String> issues = [];
    if (expense.amount > 50 && expense.receiptUrls.isEmpty) {
      issues.add('missing_receipt');
    }
    if (expense.description.length < 5) {
      issues.add('vague_description');
    }
    
    // Create map but inject issues logic locally before saving? 
    // Or just save what we have. Ideally we assume model is immutable so we should reconstruct or use toMap modification.
    var map = expense.toMap();
    map['complianceIssues'] = issues; // Overlay auto-detected issues
    
    await _expensesRef.add(map);
  }

  /// Get expenses for a date range
  Future<List<ExpenseModel>> getExpenses({
    required DateTime start,
    required DateTime end,
    ExpenseCategory? category,
  }) async {
    Query query = _expensesRef
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThanOrEqualTo: end)
        .orderBy('date', descending: true);

    if (category != null) {
      query = query.where('category', isEqualTo: category.name);
    }

    final querySnapshot = await query.get();
    return querySnapshot.docs
        .map((doc) => ExpenseModel.fromFirestore(doc))
        .toList();
  }

  /// Log a work shift manually
  Future<void> logWorkShift(WorkLogModel log) async {
    await _workLogsRef.add(log.toMap());
  }

  /// Get work logs for a date range
  Future<List<WorkLogModel>> getWorkLogs({
    required DateTime start,
    required DateTime end,
    String? staffId,
  }) async {
    Query query = _workLogsRef
        .where('startTime', isGreaterThanOrEqualTo: start)
        .where('startTime', isLessThanOrEqualTo: end)
        .orderBy('startTime', descending: true);

    if (staffId != null) {
      query = query.where('staffId', isEqualTo: staffId);
    }

    final querySnapshot = await query.get();
    return querySnapshot.docs
        .map((doc) => WorkLogModel.fromFirestore(doc))
        .toList();
  }

  /// Calculate comprehensive financial summary
  Future<FinancialSummary> getFinancialSummary({
    required DateTime start,
    required DateTime end,
  }) async {
    // 1. Calculate Revenue from Orders
    // Note: In a real app with huge data, this should be done via Cloud Functions aggregation
    // For now, we query. Optimizing by only querying 'completed' or 'paid' orders.
    final orderQuery = await _ordersRef
        .where('createdAt', isGreaterThanOrEqualTo: start)
        .where('createdAt', isLessThanOrEqualTo: end)
        .where('status', whereIn: ['paid', 'completed', 'delivering', 'ready']) 
        .get();

    double totalRevenue = 0.0;
    double totalTips = 0.0;
    double totalTax = 0.0;

    for (var doc in orderQuery.docs) {
      final order = OrderModel.fromFirestore(doc);
      // Assuming 'total' is what the customer acted, 'subtotal' is revenue before tax/tip
      // Adjust per business logic. Let's use subtotal as pure revenue for now, or total if we include tax handling elsewhere.
      // Simplification: Revenue = Total - Tip - Tax (if tax is pass-through)
      // Let's stick to Total for Gross Revenue, and track Tax/Tip separately.
      totalRevenue += order.total; 
      totalTips += order.tip;
      totalTax += order.tax;
    }

    // 2. Calculate Expenses
    final expenses = await getExpenses(start: start, end: end);
    double totalExpenses = 0.0;
    Map<ExpenseCategory, double> expensesByCategory = {};

    for (var expense in expenses) {
      totalExpenses += expense.amount;
      expensesByCategory[expense.category] = 
          (expensesByCategory[expense.category] ?? 0.0) + expense.amount;
    }

    // 3. Calculate Staff Costs
    final workLogs = await getWorkLogs(start: start, end: end);
    double totalStaffCost = 0.0;
    for (var log in workLogs) {
      // If totalPay is set, use it. Else calculate from duration * rate
      if (log.totalPay != null) {
        totalStaffCost += log.totalPay!;
      } else if (log.endTime != null) {
        final durationHours = log.endTime!.difference(log.startTime).inMinutes / 60.0;
        totalStaffCost += durationHours * log.hourlyRateSnapshot;
      }
    }
    
    // Add staff costs to total expenses logic or keep separate?
    // Let's add it to total expenses for Net Profit calc, but keep it distinct in summary
    totalExpenses += totalStaffCost;
    expensesByCategory[ExpenseCategory.staff] = 
         (expensesByCategory[ExpenseCategory.staff] ?? 0.0) + totalStaffCost;

    // 4. Compliance Check
    // Proactively scan for issues to generate "John's Alerts"
    int complianceAlertCount = 0;
    List<String> urgentActions = [];

    for (var expense in expenses) {
      if (expense.amount > 100 && expense.receiptUrls.isEmpty) {
        complianceAlertCount++;
        urgentActions.add('Review \$${expense.amount.toStringAsFixed(0)} ${expense.category.name} (No Receipt)');
      }
      if (!expense.isVerified && expense.amount > 500) {
        complianceAlertCount++;
        urgentActions.add('Verify large transaction: ${expense.description}');
      }
    }

    // Limit actions to top 3
    final topActions = urgentActions.take(3).toList();


    return FinancialSummary(
      startDate: start,
      endDate: end,
      totalRevenue: totalRevenue,
      totalExpenses: totalExpenses,
      netProfit: totalRevenue - totalExpenses,
      totalTaxCollected: totalTax,
      totalTipsCollected: totalTips,
      totalStaffCost: totalStaffCost,
      expensesByCategory: expensesByCategory,
      complianceAlertCount: complianceAlertCount,
      urgentActionItems: topActions,
    );
  }
}

class FinancialSummary {
  final DateTime startDate;
  final DateTime endDate;
  final double totalRevenue;
  final double totalExpenses;
  final double netProfit;
  final double totalTaxCollected;
  final double totalTipsCollected;
  final double totalStaffCost;
  final Map<ExpenseCategory, double> expensesByCategory;
  
  // John's Insights
  final int complianceAlertCount;
  final List<String> urgentActionItems;

  FinancialSummary({
    required this.startDate,
    required this.endDate,
    required this.totalRevenue,
    required this.totalExpenses,
    required this.netProfit,
    required this.totalTaxCollected,
    required this.totalTipsCollected,
    required this.totalStaffCost,
    required this.expensesByCategory,
    this.complianceAlertCount = 0,
    this.urgentActionItems = const [],
  });
}
