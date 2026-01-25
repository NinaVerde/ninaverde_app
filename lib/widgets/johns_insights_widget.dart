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
          decoration: BoxDecoration(
            color: const Color(0xFF001e36), // Deep Blueprint Blue
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CustomPaint(
              painter: _BlueprintGridPainter(),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.cyanAccent.withOpacity(0.5)),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.smart_toy, color: Colors.cyanAccent, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'JOHN AI // SYSTEM MONITOR', 
                              style: TextStyle(
                                color: Colors.cyanAccent, 
                                fontWeight: FontWeight.bold, 
                                fontSize: 14,
                                fontFamily: 'monospace',
                                letterSpacing: 1.2
                              ),
                            ),
                            Text(
                              isEs ? 'ANALISIS TACTICO :: ACTIVO' : 'TACTICAL ANALYSIS :: ACTIVE',
                              style: TextStyle(
                                color: Colors.cyanAccent.withOpacity(0.6), 
                                fontSize: 10,
                                fontFamily: 'monospace'
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(color: Colors.cyanAccent, height: 24, thickness: 0.5),
                    ...insights.map((insight) => _InsightBlueprintRow(insight: insight)),
                  ],
                ),
              ),
            ),
          ),
        ).animate().fadeIn().slideY(begin: 0.05, end: 0);
      },
    );
  }
}

class _BlueprintGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1;

    const step = 20.0;
    
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _InsightBlueprintRow extends StatelessWidget {
  final Insight insight;
  const _InsightBlueprintRow({required this.insight});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    
    switch (insight.type) {
      case InsightType.opportunity:
        icon = Icons.lightbulb_outline;
        color = Colors.amberAccent;
        break;
      case InsightType.warning:
        icon = Icons.warning_amber_rounded;
        color = Colors.orangeAccent;
        break;
      case InsightType.trend:
        icon = Icons.trending_up;
        color = Colors.greenAccent;
        break;
      case InsightType.success:
        icon = Icons.check_circle_outline;
        color = Colors.lightBlueAccent;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title.toUpperCase(),
                  style: TextStyle(
                    color: color, 
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    fontFamily: 'monospace'
                  ),
                ),
                Text(
                  insight.description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                    height: 1.3,
                    fontFamily: 'monospace'
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
