// lib/widgets/accounting/john_cfo_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/accounting_model.dart'; // Ensure correct import for FinancialSummary if moved, or use accounting_service.dart

class JohnCFOWidget extends StatelessWidget {
  final int alertCount;
  final List<String> actions;
  final VoidCallback? onResolve;

  const JohnCFOWidget({
    super.key,
    required this.alertCount,
    required this.actions,
    this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    if (alertCount == 0 && actions.isEmpty) {
      return _buildCleanState(context);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.redAccent.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.redAccent.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'JOHN (CFO)',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$alertCount ISSUES',
                        style: const TextStyle(
                          color: Colors.white, 
                          fontSize: 10,
                          fontWeight: FontWeight.bold
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _getInsightMessage(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ...actions.map((action) => Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          action,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )),
                const SizedBox(height: 8),
                SizedBox(
                  height: 32,
                  child: OutlinedButton(
                    onPressed: onResolve,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text('RESOLVE NOW'),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _buildAvatar() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[200],
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: const Icon(Icons.person, color: Colors.grey, size: 30),
    );
  }
  
  Widget _buildCleanState(BuildContext context) {
    // "All Good" state
    return Container(
       padding: const EdgeInsets.all(16),
       decoration: BoxDecoration(
         color: Theme.of(context).colorScheme.surface,
         borderRadius: BorderRadius.circular(20),
         border: Border.all(color: Colors.green.withOpacity(0.3)),
       ),
       child: Row(
         children: [
           _buildAvatar(),
           const SizedBox(width: 16),
           Expanded(
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 const Text(
                   'JOHN (CFO)',
                   style: TextStyle(
                     fontWeight: FontWeight.bold,
                     fontSize: 10,
                     color: Colors.grey,
                   ),
                 ),
                 const SizedBox(height: 4),
                 Text(
                   'Books are clean. Ready for investor review.',
                   style: TextStyle(
                     color: Colors.green[700],
                     fontWeight: FontWeight.w600,
                   ),
                 ),
               ],
             ),
           )
         ],
       ),
    ).animate().fadeIn();
  }

  String _getInsightMessage() {
    if (alertCount > 5) return 'We have significant compliance gaps.';
    if (alertCount > 0) return 'Action required on recent expenses.';
    return 'Everything looks good.'; 
  }
}
