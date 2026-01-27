// lib/screens/accounting_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../models/accounting_model.dart';
import '../services/accounting_service.dart';
import '../widgets/nv_widgets.dart';
import '../widgets/accounting/john_cfo_widget.dart';
import 'financial_report_screen.dart';

class AccountingDashboardScreen extends StatefulWidget {
  const AccountingDashboardScreen({super.key});

  @override
  State<AccountingDashboardScreen> createState() => _AccountingDashboardScreenState();
}

class _AccountingDashboardScreenState extends State<AccountingDashboardScreen> {
  final AccountingService _service = AccountingService();
  bool _isLoading = true;
  FinancialSummary? _summary;
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final summary = await _service.getFinancialSummary(
        start: _dateRange.start,
        end: _dateRange.end,
      );
      if (mounted) setState(() => _summary = summary);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _pickDateRange() async {
    final newRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    if (newRange != null) {
      setState(() => _dateRange = newRange);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: NvAppBar(
        title: 'Accounting Elite',
        showBack: true,
        extraActions: [
           IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () {
              if (_summary != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => FinancialReportScreen(summary: _summary!)),
                );
              }
            },
            tooltip: 'Investor Room',
          ),
           IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _pickDateRange,
            tooltip: 'Select Range',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showAddExpenseDialog(context);
        },
        backgroundColor: const Color(0xFFD4AF37), // Gold
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('ADD EXPENSE'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark 
              ? [const Color(0xFF1a1a1a), const Color(0xFF000000)]
              : [const Color(0xFFf5f5f5), const Color(0xFFe0e0e0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        ),
        child: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
            : RefreshIndicator(
                onRefresh: _loadData,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 120, 16, 100),
                  children: [
                    _buildDateHeader(),
                    const SizedBox(height: 20),
                    if (_summary != null) ...[
                      _buildHeroCards(_summary!),
                      const SizedBox(height: 24),
                      _buildProfitChart(_summary!),
                      const SizedBox(height: 24),
                      _buildExpenseBreakdown(_summary!),
                      const SizedBox(height: 24),
                      _buildRecentTransactions(),
                    ]
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildDateHeader() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withOpacity(0.8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
        ),
        child: Text(
          '${DateFormat.yMMMd().format(_dateRange.start)} - ${DateFormat.yMMMd().format(_dateRange.end)}',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCards(FinancialSummary summary) {
    return Column(
      children: [
        JohnCFOWidget(
          alertCount: summary.complianceAlertCount,
          actions: summary.urgentActionItems,
          onResolve: () {
            // TODO: Navigate to full compliance center
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opening Compliance Center...')));
          },
        ),
        const SizedBox(height: 16),
        _EliteCard(
          title: 'NET PROFIT',
          amount: summary.netProfit,
          isHero: true,
          delay: 0,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _EliteCard(
                title: 'REVENUE',
                amount: summary.totalRevenue,
                color: Colors.greenAccent[400],
                icon: Icons.attach_money,
                delay: 100,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _EliteCard(
                title: 'EXPENSES',
                amount: summary.totalExpenses,
                color: Colors.redAccent[400],
                icon: Icons.money_off,
                delay: 200,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProfitChart(FinancialSummary summary) {
     // A simple visual representation of Profit Margin
     final total = summary.totalRevenue > 0 ? summary.totalRevenue : 1.0;
     final profitPct = (summary.netProfit / total).clamp(0.0, 1.0);
     final expensePct = (summary.totalExpenses / total).clamp(0.0, 1.0);

     return Container(
       padding: const EdgeInsets.all(20),
       decoration: _eliteDecoration(context),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Text(
             'PROFIT MARGIN ANALYSIS',
             style: Theme.of(context).textTheme.labelSmall?.copyWith(
               color: Colors.grey,
               letterSpacing: 1.5,
             ),
           ),
           const SizedBox(height: 20),
           SizedBox(
             height: 30,
             child: Row(
               children: [
                  Expanded(
                    flex: (profitPct * 100).toInt(),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFF4CAF50),
                        borderRadius: BorderRadius.horizontal(left: Radius.circular(8)),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: (expensePct * 100).toInt(),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF5350),
                        borderRadius: BorderRadius.horizontal(right: Radius.circular(8)),
                      ),
                    ),
                  ),
               ],
             ),
           ).animate().scaleX(duration: 800.ms, curve: Curves.easeOutQuart, alignment: Alignment.centerLeft),
           const SizedBox(height: 12),
           Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
               Text('${(profitPct * 100).toStringAsFixed(1)}% Profit', style: const TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold)),
               Text('${(expensePct * 100).toStringAsFixed(1)}% Costs', style: const TextStyle(color: Color(0xFFEF5350), fontWeight: FontWeight.bold)),
             ],
           )
         ],
       ),
     );
  }

  Widget _buildExpenseBreakdown(FinancialSummary summary) {
    final categories = summary.expensesByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _eliteDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text(
             'EXPENSE BREAKDOWN',
             style: Theme.of(context).textTheme.labelSmall?.copyWith(
               color: Colors.grey,
               letterSpacing: 1.5,
             ),
           ),
           const SizedBox(height: 16),
           if (categories.isEmpty)
             const Padding(
               padding: EdgeInsets.all(16.0),
               child: Text('No expenses recorded for this period.'),
             ),
           ...categories.map((e) {
             final pct = (summary.totalExpenses > 0) ? (e.value / summary.totalExpenses) : 0.0;
             return Padding(
               padding: const EdgeInsets.only(bottom: 12.0),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       Text(e.key.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w600)),
                       Text('\$${e.value.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                     ],
                   ),
                   const SizedBox(height: 4),
                   ClipRRect(
                     borderRadius: BorderRadius.circular(4),
                     child: LinearProgressIndicator(
                       value: pct,
                       backgroundColor: Colors.grey.withOpacity(0.1),
                       color: _getColorForCategory(e.key),
                       minHeight: 6,
                     ),
                   ),
                 ],
               ),
             );
<<<<<<< HEAD
           }),
=======
           }).toList(),
>>>>>>> 2364cb6 (feat: On-the-fly Product Translation, Ticker Improvements, Search B… (#87))
        ],
      )
    );
  }
  
  Widget _buildRecentTransactions() {
    // Placeholder for actual list
    return Container(
       padding: const EdgeInsets.all(20),
       decoration: _eliteDecoration(context),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'RECENT TRANSACTIONS',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.grey,
                    letterSpacing: 1.5,
                  ),
                ),
                TextButton(onPressed: (){}, child: const Text('VIEW ALL'))
              ],
            ),
            const SizedBox(height: 8),
            // We would fetch the actual list here using FutureBuilder or similar
            const Center(child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Recent transactions will appear here.'),
            )),
         ],
       ),
    );
  }

  Color _getColorForCategory(ExpenseCategory cat) {
    switch (cat) {
      case ExpenseCategory.staff: return Colors.blue;
      case ExpenseCategory.inventory: return Colors.orange;
      case ExpenseCategory.overhead: return Colors.purple;
      case ExpenseCategory.marketing: return Colors.pink;
      case ExpenseCategory.maintenance: return Colors.grey;
      case ExpenseCategory.supplies: return Colors.teal;
      default: return Colors.brown;
    }
  }

  void _showAddExpenseDialog(BuildContext context) {
    showDialog(
      context: context, 
      builder: (ctx) => const _AddExpenseDialog()
    ).then((val) {
      if (val == true) _loadData();
    });
  }

  BoxDecoration _eliteDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 20,
          offset: const Offset(0, 10),
        )
      ],
      border: isDark ? Border.all(color: Colors.white10) : null,
    );
  }
}

class _EliteCard extends StatelessWidget {
  final String title;
  final double amount;
  final bool isHero;
  final Color? color;
  final IconData? icon;
  final int delay;

  const _EliteCard({
    required this.title,
    required this.amount,
    this.isHero = false,
    this.color,
    this.icon,
    this.delay = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isHero ? const Color(0xFFD4AF37) : (color ?? (isDark ? Colors.white : Colors.black87));

    return Container(
      height: isHero ? 140 : 100,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(isHero ? 24 : 20),
        boxShadow: [
          BoxShadow(
            color: (color ?? Colors.black).withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
        border: isHero 
            ? Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3), width: 1)
            : (isDark ? Border.all(color: Colors.white10) : null),
        gradient: isHero && isDark ? LinearGradient(
          colors: [
             const Color(0xFF1E1E1E),
             const Color(0xFF2A2A2A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: textColor.withOpacity(0.7)),
                const SizedBox(width: 8),
              ],
              Text(
                title,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: textColor.withOpacity(0.6),
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            // Simple formatter
            '\$${NumberFormat("#,##0.00", "en_US").format(amount)}',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w900,
              fontSize: isHero ? 36 : 24,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: delay)).slideY(begin: 0.2, end: 0);
  }
}

class _AddExpenseDialog extends StatefulWidget {
  const _AddExpenseDialog();

  @override
  State<_AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<_AddExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _amountController = TextEditingController();
  ExpenseCategory _category = ExpenseCategory.supplies;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Dialog( // Using general dialog for better control than AlertDialog
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NEW EXPENSE',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 20),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _descController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'e.g. Weekly Vegetable Restock',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _amountController,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => double.tryParse(v ?? '') == null ? 'Invalid amount' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<ExpenseCategory>(
<<<<<<< HEAD
                    initialValue: _category,
=======
                    value: _category,
>>>>>>> 2364cb6 (feat: On-the-fly Product Translation, Ticker Improvements, Search B… (#87))
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: ExpenseCategory.values.map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(c.name.toUpperCase()),
                    )).toList(),
                    onChanged: (v) => setState(() => _category = v!),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCEL'),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: Colors.black,
                  ),
                  child: _saving 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('SAVE EXPENSE'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    
    try {
      final amount = double.parse(_amountController.text);
      final expense = ExpenseModel(
        id: '', // Will be generated by Firestore
        category: _category,
        description: _descController.text,
        amount: amount,
        currencyCode: 'USD', // Defaulting for now
        date: DateTime.now(),
      );
      
      await AccountingService().addExpense(expense);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _saving = false);
      }
    }
  }
}
