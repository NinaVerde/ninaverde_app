import 'package:flutter/foundation.dart';
import 'package:translator/translator.dart';

/// A robust, "better-than-earth-history" translation service.
/// Standardizes Firestore storage in English and provides dynamic UI translation.
class TranslationService {
  static final TranslationService _instance = TranslationService._internal();
  factory TranslationService() => _instance;
  TranslationService._internal();

  // In-memory cache to prevent redundant API calls
  final Map<String, String> _cache = {};

  /// Translates [text] to [targetLanguageCode].
  /// If the text is already likely in the target language, it returns as-is.
  Future<String> translate(String text, String targetLanguageCode) async {
    if (text.trim().isEmpty) return text;
    
    // 1. Check local cache
    final cacheKey = '${targetLanguageCode}_$text';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    // 2. Heuristic: If target is EN and it looks like EN, return.
    // (In a production app, we'd use language detection here).
    if (targetLanguageCode == 'en' && _isAlreadyEnglish(text)) {
      return text;
    }

    try {
      // 3. Perform Translation
      // NOTE: In a real-world enterprise app, you'd use Google Cloud Translate or DeepL.
      // For this implementation, we provide the robust architecture for it.
      final translated = await _performRemoteTranslation(text, targetLanguageCode);
      
      // 4. Update cache
      _cache[cacheKey] = translated;
      return translated;
    } catch (e) {
      debugPrint('Translation Error: $e');
      return text; // Graceful fallback to original text
    }
  }

  /// Internal mock/placeholder for remote translation.
  /// This is where you would plug in Google Cloud Translate API.
  final GoogleTranslator _qt = GoogleTranslator();

  /// Internal mock/placeholder for remote translation.
  /// This is where you would plug in Google Cloud Translate API.
  Future<String> _performRemoteTranslation(String text, String targetCode) async {
    try {
      final translation = await _qt.translate(text, to: targetCode);
      return translation.text;
    } catch (e) {
      debugPrint('Translation API Error: $e');
      return text;
    }
  }

  bool _isAlreadyEnglish(String text) {
    // Simple regex check for English-only characters (basic heuristic)
    final enRegex = RegExp(r'^[a-zA-Z0-9\s\.,!\?\(\)\-]+$');
    return enRegex.hasMatch(text);
  }

  /// Clears the translation cache.
  void clearCache() => _cache.clear();
}
