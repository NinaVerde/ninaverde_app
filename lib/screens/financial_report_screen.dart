// lib/screens/financial_report_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../services/accounting_service.dart';
import '../widgets/nv_widgets.dart';

class FinancialReportScreen extends StatefulWidget {
  final FinancialSummary summary;

  const FinancialReportScreen({super.key, required this.summary});

  @override
  State<FinancialReportScreen> createState() => _FinancialReportScreenState();
}

class _FinancialReportScreenState extends State<FinancialReportScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7), // Paper-like off-white
      appBar: NvAppBar(
        title: 'Investor Report',
        showBack: true,
        extraActions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareReport,
            tooltip: 'Share CSV',
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () {
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Print dialog would open here.')));
            },
            tooltip: 'Print',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _pill(0, 'Profit & Loss'),
                const SizedBox(width: 12),
                _pill(1, 'Balance Sheet'),
                const SizedBox(width: 12),
                _pill(2, 'Compliance'),
              ],
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _currentPage = i),
              children: [
                _buildPnLPage(),
                _buildPlaceholderPage('Balance Sheet\n(Coming Soon)'),
                _buildPlaceholderPage('Compliance Audit\n(Coming Soon)'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(int index, String label) {
    final selected = _currentPage == index;
    return GestureDetector(
      onTap: () => _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.black : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black54,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildPnLPage() {
    final s = widget.summary;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
             BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                   const Icon(Icons.eco, color: Colors.green, size: 40),
                   const SizedBox(height: 12),
                   Text('NIÑA VERDE', style: Theme.of(context).textTheme.headlineSmall?.copyWith(letterSpacing: 2, fontWeight: FontWeight.bold, color: Colors.black)),
                   const SizedBox(height: 4),
                   const Text('PROFIT AND LOSS STATEMENT', style: TextStyle(color: Colors.grey, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 8),
                   Text('${DateFormat.yMMMd().format(s.startDate)} - ${DateFormat.yMMMd().format(s.endDate)}', style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ),
            const Divider(height: 40, thickness: 2),
            _row('REVENUE', isHeader: true),
            _row('Sales Revenue', amount: s.totalRevenue),
            _row('Service Charges (Tips)', amount: s.totalTipsCollected),
            _row('TOTAL REVENUE', amount: s.totalRevenue + s.totalTipsCollected, isTotal: true),
            const SizedBox(height: 24),
            _row('EXPENSES', isHeader: true),
            ...s.expensesByCategory.entries.map((e) => _row(e.key.name.toUpperCase(), amount: e.value)),
            _row('TOTAL EXPENSES', amount: s.totalExpenses, isTotal: true),
            const Divider(height: 40, thickness: 2),
            _row('NET INCOME', amount: s.netProfit, isTotal: true, isGrandTotal: true),
            const SizedBox(height: 40),
            Center(child: Text('Generated by John CFO AI', style: TextStyle(color: Colors.grey[300], fontSize: 10))),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPlaceholderPage(String text) {
    return Center(child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)));
  }

  Widget _row(String label, {double? amount, bool isHeader = false, bool isTotal = false, bool isGrandTotal = false}) {
    TextStyle style = const TextStyle(color: Colors.black87, fontSize: 14);
    if (isHeader) style = const TextStyle(color: Colors.black54, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1);
    if (isTotal) style = const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14);
    if (isGrandTotal) style = const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: isHeader ? 8 : 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          if (amount != null)
            Text(
              NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(amount),
              style: style,
            ),
        ],
      ),
    );
  }

  void _shareReport() {
    // Generate CSV string
    final s = widget.summary;
    final csv = StringBuffer();
    csv.writeln('Profit & Loss Statement');
    csv.writeln('Period,${s.startDate},${s.endDate}');
    csv.writeln('');
    csv.writeln('Revenue,${s.totalRevenue}');
    csv.writeln('Expenses,${s.totalExpenses}');
    csv.writeln('Net Profit,${s.netProfit}');
    
    Share.share(csv.toString(), subject: 'Nina Verde Financial Report');
  }
}
