import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../services/payroll_service.dart';
import '../widgets/nv_widgets.dart';

class PayrollDashboardScreen extends StatefulWidget {
  const PayrollDashboardScreen({super.key});

  @override
  State<PayrollDashboardScreen> createState() => _PayrollDashboardScreenState();
}

class _PayrollDashboardScreenState extends State<PayrollDashboardScreen> {
  bool _isLoading = true;
  PayrollReport? _report;
  DateTime _rangeStart = DateTime.now().subtract(const Duration(days: 7));
  DateTime _rangeEnd = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
      setState(() => _isLoading = true);
      // Simulate "AI Processing" delay for elite feel
      await Future.delayed(const Duration(milliseconds: 1500)); 
      
      final report = await PayrollService.generateReport(_rangeStart, _rangeEnd);
      
      if (mounted) {
          setState(() {
              _report = report;
              _isLoading = false;
          });
      }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: const NvAppBar(title: 'Elite Payroll Command', showBack: true),
      body: _isLoading 
          ? Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                      const CircularProgressIndicator(color: Color(0xFFD4AF37)), // Gold
                      const SizedBox(height: 16),
                      Text("JOHN AI IS CALCULATING...", style: TextStyle(color: Colors.grey[600], letterSpacing: 2)),
                  ]
              )
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      // 1. Hero Total Card
                      _buildHeroTotal(_report!),
                      const SizedBox(height: 24),
                      
                      // 2. Chart Section (Mock Visual for MVP)
                      _buildChartSection(),
                      const SizedBox(height: 24),
                      
                      // 3. Employee Stubs
                      const Text("PAYROLL BREAKDOWN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      const SizedBox(height: 12),
                      ..._report!.stubs.map((stub) => _buildPayStubCard(stub)),
                  ],
              ),
            ),
    );
  }
  
  Widget _buildHeroTotal(PayrollReport report) {
      return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFD4AF37), Color(0xFFF7F1D3)], // Gold Gradient
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                  BoxShadow(color: const Color(0xFFD4AF37).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8)),
              ]
          ),
          child: Column(
              children: [
                  const Text("TOTAL LABOR COST", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  const SizedBox(height: 8),
                  Text(
                      "\$${report.totalLaborCost.toStringAsFixed(2)}", 
                      style: const TextStyle(color: Colors.black, fontSize: 48, fontWeight: FontWeight.bold)
                  ).animate().scale(delay: 200.ms, duration: 600.ms, curve: Curves.elasticOut),
                  const SizedBox(height: 8),
                  Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(20)),
                      child: Text(
                          "${DateFormat('MMM d').format(report.startDate)} - ${DateFormat('MMM d').format(report.endDate)}",
                          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                      ),
                  ),
              ],
          ),
      ).animate().slideY(begin: 0.2, duration: 600.ms);
  }
  
  Widget _buildChartSection() {
      // Mock Chart Visual using Containers for simplicity/flare
      return Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
          ),
          child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(7, (index) {
                  final height = [40.0, 60.0, 120.0, 80.0, 150.0, 180.0, 90.0][index];
                  return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                          Container(
                              width: 20,
                              height: height,
                              decoration: BoxDecoration(
                                  color: const Color(0xFFD4AF37).withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: [BoxShadow(color: const Color(0xFFD4AF37).withOpacity(0.4), blurRadius: 8)]
                              ),
                          ).animate().scaleY(begin: 0, duration: (600 + (index * 100)).ms, curve: Curves.easeOut),
                          const SizedBox(height: 8),
                          Text(
                              ['M', 'T', 'W', 'T', 'F', 'S', 'S'][index],
                              style: TextStyle(color: Colors.grey[600], fontSize: 10),
                          )
                      ],
                  );
              }),
          ),
      );
  }
  
  Widget _buildPayStubCard(StaffPayStub stub) {
      return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
          ),
          child: Row(
              children: [
                  CircleAvatar(
                      backgroundColor: Colors.grey[800],
                      child: Text(stub.staff.displayName.substring(0, 1), style: const TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                              Text(stub.staff.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(
                                  "${stub.regularHours.toStringAsFixed(1)} Regular • ${stub.overtimeHours.toStringAsFixed(1)} OT",
                                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                              ),
                          ],
                      ),
                  ),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                          Text("\$${stub.totalPay.toStringAsFixed(2)}", style: const TextStyle(color: Color(0xFF00FF94), fontWeight: FontWeight.bold, fontSize: 18)),
                          if (stub.overtimePay > 0)
                            Text("+${stub.overtimePay.toStringAsFixed(0)} OT", style: const TextStyle(color: Colors.orangeAccent, fontSize: 10)),
                      ],
                  ),
              ],
          ),
      ).animate().fadeIn().slideX(begin: 0.1);
  }
}
