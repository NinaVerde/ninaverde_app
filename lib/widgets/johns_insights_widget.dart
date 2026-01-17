import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/intel_service.dart';
import '../state/app_state.dart';

class JohnsInsightsWidget extends StatelessWidget {
  const JohnsInsightsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppState.of(context);
    final isEs = app.languageCode.value == 'es';
    
    return StreamBuilder<List<Insight>>(
      stream: IntelService.streamInsights(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        
        final insights = snapshot.data!;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.indigo.shade900, Colors.indigo.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.indigo.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 20,
                    child: Icon(Icons.face, color: Colors.indigo), // John's Face
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'John', 
                        style: const TextStyle(
                          color: Colors.white, 
                          fontWeight: FontWeight.bold, 
                          fontSize: 16
                        ),
                      ),
                      Text(
                        isEs ? 'Hermano de Angelina & Socio IA' : 'Angelina\'s Brother & AI Partner',
                        style: const TextStyle(
                          color: Colors.white70, 
                          fontSize: 12
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(color: Colors.white24, height: 24),
              ...insights.map((insight) => _InsightRow(insight: insight)),
            ],
          ),
        ).animate().fadeIn().slideY(begin: 0.1, end: 0);
      },
    );
  }
}

class _InsightRow extends StatelessWidget {
  final Insight insight;
  const _InsightRow({required this.insight});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    
    switch (insight.type) {
      case InsightType.opportunity:
        icon = Icons.lightbulb;
        color = Colors.amberAccent;
        break;
      case InsightType.warning:
        icon = Icons.warning_amber;
        color = Colors.orangeAccent;
        break;
      case InsightType.trend:
        icon = Icons.trending_up;
        color = Colors.greenAccent;
        break;
      case InsightType.success:
        icon = Icons.check_circle;
        color = Colors.lightBlueAccent;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: TextStyle(
                    color: color, 
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  insight.description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
