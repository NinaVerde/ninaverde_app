import 'package:cloud_firestore/cloud_firestore.dart';
import 'translation_service.dart';

class MigrationService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Scans all text-heavy collections and standardizes them to English.
  static Future<void> standardizeAllToEnglish() async {
    await _standardizeCollection('products', ['name', 'description', 'category']);
    await _standardizeCollection('events_promotions', ['title', 'description']);
    await _standardizeCollection('categories', ['name']);
    await _standardizeCollection('live_game_configs', ['name', 'rules']);
    // Categories are stored by ID as the name, so we need to be careful.
    // We'll handle 'categories' separately if needed, but usually they match.
  }

  static Future<void> _standardizeCollection(String collectionPath, List<String> fields) async {
    final snap = await _db.collection(collectionPath).get();
    for (final doc in snap.docs) {
      final data = doc.data();
      final updates = <String, dynamic>{};
      
      for (final field in fields) {
        final originalValue = data[field];
        if (originalValue is String && originalValue.isNotEmpty) {
          final enValue = await TranslationService().translate(originalValue, 'en');
          if (enValue != originalValue) {
            updates[field] = enValue;
          }
        }
      }

      if (updates.isNotEmpty) {
        await doc.reference.update(updates);
      }
    }
  }
}
