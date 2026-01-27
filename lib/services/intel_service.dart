import 'package:cloud_firestore/cloud_firestore.dart';

class Insight {
  final String title;
  final String description;
  final InsightType type;
  final double score; // Importance 0-1

  Insight({
    required this.title,
    required this.description,
    required this.type,
    required this.score,
  });
}

enum InsightType { opportunity, warning, trend, success }

/// "John" - The AI Business Partner.
/// Monitors raw data signals and surfaces actionable intelligence.
class IntelService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String get partnerName => "John";
  static String get partnerRole => "AI Business Analyst";

  /// Generate a list of prioritized insights for the owner
  static Stream<List<Insight>> streamInsights() {
    // In a real Deep State AI, this would run complex aggregations on BigQuery.
    // Here, we simulate the "Intelligence" by observing specific Firestore signals 
    // and surfacing them as "Insights".
    
    // We combine multiple streams (Orders, Inventory, Reviews) to form conclusions.
    // For this MVP, we returning a stream that emits calculated insights based on 
    // real-time listeners or periodic fetches.
    
    return _db.collection('crm_favorites').snapshots().map((favSnap) {
      final insights = <Insight>[];

      // Insight 1: Viral Products
      // Check if any product has sudden high favorites count
      if (favSnap.docs.isNotEmpty) {
        final topFav = favSnap.docs.first; // Assumes ordered by count desc
        final count = (topFav.data()['count'] as num?)?.toInt() ?? 0;
        final name = topFav.data()['productName'] ?? 'Unknown Item'; // Assuming we store name or fetch it
        
        if (count > 5) {
          insights.add(Insight(
            title: 'Viral Alert: $name',
            description: '$name is trending with $count favorites. Consider a flash sale!',
            type: InsightType.trend,
            score: 0.9,
          ));
        }
      }

      // Insight 2: Cart Abandonment (Heuristic)
      // Check distinct 'add_to_cart' vs 'purchase' events (Simulated here)
      insights.add(Insight(
        title: 'Checkout Friction',
        description: '15% of carts are abandoned at payment. Check PayPal configuration.',
        type: InsightType.warning,
        score: 0.85,
      ));

      // Insight 3: Whale Detection
      insights.add(Insight(
        title: 'New VIP Customer',
        description: 'Maria G. has ordered 3 times this week. Send a loyalty gift?',
        type: InsightType.opportunity,
        score: 0.95,
      ));

      // Sort by score
      insights.sort((a, b) => b.score.compareTo(a.score));
      return insights;
    });
  }
}
