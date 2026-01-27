import 'package:cloud_firestore/cloud_firestore.dart';
<<<<<<< HEAD
=======
import 'package:flutter/foundation.dart';
>>>>>>> 2364cb6 (feat: On-the-fly Product Translation, Ticker Improvements, Search B… (#87))
import 'translation_service.dart';

class DataStandardizationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TranslationService _translator = TranslationService();

  Future<Map<String, int>> standardizeCurrencies({
    required double rateToNio, // e.g. 36.6
  }) async {
    int updatedProducts = 0;
    int updatedEvents = 0;

    // 1. Products
    final productSnaps = await _firestore.collection('products').get();
    for (final doc in productSnaps.docs) {
      final data = doc.data();
      bool changed = false;
      final Map<String, dynamic> updates = {};

      // Logic: Ensure price (USD) and priceNio exist and match rate
      // Assume 'price' is the master USD price.
      double? usd = (data['price'] as num?)?.toDouble();
      double? nio = (data['priceNio'] as num?)?.toDouble();

      if (usd != null) {
        // Recalculate NIO
        final calcNio = double.parse((usd * rateToNio).toStringAsFixed(2));
        if (nio == null || (nio - calcNio).abs() > 0.05) {
          updates['priceNio'] = calcNio;
          changed = true;
        }
      } else if (nio != null) {
        // If only NIO exists, calculate USD
        final calcUsd = double.parse((nio / rateToNio).toStringAsFixed(2));
        updates['price'] = calcUsd;
        changed = true;
      }

      if (changed) {
        await doc.reference.update(updates);
        updatedProducts++;
      }
    }

    // 2. Events (Assuming 'price' field exists)
    final eventSnaps = await _firestore.collection('events').get();
    for (final doc in eventSnaps.docs) {
      final data = doc.data();
      bool changed = false;
      final Map<String, dynamic> updates = {};

      double? usd = (data['price'] as num?)?.toDouble();
      double? nio = (data['priceNio'] as num?)?.toDouble();

      if (usd != null) {
        final calcNio = double.parse((usd * rateToNio).toStringAsFixed(2));
        if (nio == null || (nio - calcNio).abs() > 0.05) {
          updates['priceNio'] = calcNio;
          changed = true;
        }
      } else if (nio != null) {
        final calcUsd = double.parse((nio / rateToNio).toStringAsFixed(2));
        updates['price'] = calcUsd;
        changed = true;
      }

      if (changed) {
        await doc.reference.update(updates);
        updatedEvents++;
      }
    }

    return {'products': updatedProducts, 'events': updatedEvents};
  }

  /// Iterates all products/events.
  /// If [targetLang] is 'es', looks for 'name', translates to 'name_es' if missing.
  /// If [targetLang] is 'en', looks for 'name', translates to 'name_en' if missing? 
  /// Actually, typically 'name' is the base.
  /// Strategy:
  /// - Ensure `name_es` and `description_es` exist (from `name`/`description`).
  /// - Ensure `name_en` and `description_en` exist (from `name`/`description`).
  Future<Map<String, int>> standardizeLanguages({
    required String targetLang, // 'es' or 'en'
  }) async {
    int updatedProducts = 0;
    int updatedEvents = 0;
    
    // We assume the base fields 'name' and 'description' contain English or mix.
    // But for standardization, we can try to detect or just assume base is readable.
    
    final collections = ['products', 'events'];
    
    for (final col in collections) {
      final snaps = await _firestore.collection(col).get();
      for (final doc in snaps.docs) {
        final data = doc.data();
        bool changed = false;
        final Map<String, dynamic> updates = {};

        // Fields to translate
        final fields = ['name', 'description'];

        for (final field in fields) {
          final baseVal = data[field] as String?;
          if (baseVal == null || baseVal.isEmpty) continue;

          // Target Key: name_es or name_en
          final targetKey = '${field}_$targetLang';
          final existingTarget = data[targetKey] as String?;

          if (existingTarget == null || existingTarget.isEmpty) {
            // Translate
            String translated = await _translator.translate(baseVal, targetLang);
            
            // Branding Rule: 'Naturally' -> 'Naturalmente'
            if (targetLang == 'es') {
               translated = translated.replaceAll(RegExp(r'Naturally', caseSensitive: false), 'Naturalmente');
            }
            
            updates[targetKey] = translated;
            changed = true;
          }
        }

        if (changed) {
          await doc.reference.update(updates);
<<<<<<< HEAD
          if (col == 'products') {
            updatedProducts++;
          } else {
            updatedEvents++;
          }
=======
          if (col == 'products') updatedProducts++;
          else updatedEvents++;
>>>>>>> 2364cb6 (feat: On-the-fly Product Translation, Ticker Improvements, Search B… (#87))
        }
        
        // Rate limit slightly to avoid API flooding?
        // await Future.delayed(const Duration(milliseconds: 50)); 
      }
    }

    return {'products': updatedProducts, 'events': updatedEvents};
  }
}
