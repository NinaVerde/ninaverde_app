// lib/services/config_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_config_model.dart';
import '../models/payment_config_model.dart';

/// Service to manage global application configurations from Firestore.
class ConfigService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String _cfgCol = 'app_config';
  static const String _tickerDoc = 'ticker';
  static const String _localeDoc = 'localization';
  static const String _videoDoc = 'video';
  static const String _paymentDoc = 'payment';

  /// Fetch Ticker Configuration
  static Future<TickerConfig> getTickerConfig() async {
    try {
      final doc = await _db.collection(_cfgCol).doc(_tickerDoc).get();
      if (!doc.exists || doc.data() == null) return const TickerConfig();
      
      var config = TickerConfig.fromMap(doc.data()!);

      // --- SELF-HEALING SANITIZATION ---
      // Detect placeholder remnants but don't wipe user soul
      bool needsHealing = false;
      final badPatterns = [
        'Login to collect', 'Inicie sesión'
      ];
      
      bool isMessy(String s) => badPatterns.any((p) => s.contains(p));

      // Clean English
      final cleanEn = config.messagesEn.where((m) => !isMessy(m)).toList();
      
      // Clean Spanish 
      final cleanEs = config.messagesEs.where((m) => !isMessy(m)).toList();

      // Only HEAL if the results are TRULY empty (no user content found even after fallback)
      if (cleanEn.isEmpty || cleanEs.isEmpty) {
        needsHealing = true;
        
        if (cleanEn.isEmpty) {
          cleanEn.addAll([
            'Welcome to Niña Verde 🌿',
            'Authentically Nicaraguan 🇳🇮',
            'Farm to Table Freshness 🥬',
            'Try our famous Smoothies 🥤',
            'Breakfast served All Day 🍳',
            'Relax and enjoy the vibes ✨'
          ]);
        }
        if (cleanEs.isEmpty) {
          cleanEs.addAll([
            'Bienvenido a Niña Verde 🌿',
            'Auténticamente Nicaragüense 🇳🇮',
            'Frescura de la Granja a la Mesa 🥬',
            'Prueba nuestros famosos Batidos 🥤',
            'Desayuno servido Todo el Día 🍳',
            'Relájate y disfruta del ambiente ✨'
          ]);
        }

        // Reconstruct config with healed messages
        config = TickerConfig(
          show: config.show,
          messagesEn: cleanEn,
          messagesEs: cleanEs,
          speedPx: config.speedPx,
          direction: config.direction,
          laneLight: config.laneLight,
          laneDark: config.laneDark,
          railLight: config.railLight,
          railDark: config.railDark,
          textLight: config.textLight,
          textDark: config.textDark,
        );

        // HEAL FIRESTORE ONLY if we actually added defaults
        debugPrint('Sanitized ticker config. Healing Firestore...');
        await saveTickerConfig(config);
      }
      
      return config;
    } catch (e) {
      debugPrint('Error fetching ticker config: $e');
      return const TickerConfig();
    }
  }

  /// Save Ticker Configuration
  static Future<void> saveTickerConfig(TickerConfig config) async {
    await _db.collection(_cfgCol).doc(_tickerDoc).set(
          config.toMap()..addAll({'updated_at': FieldValue.serverTimestamp()}),
          SetOptions(merge: true),
        );
  }

  /// Fetch Video & Logo Configuration
  static Future<VideoLogoConfig> getVideoLogoConfig() async {
    try {
      final doc = await _db.collection(_cfgCol).doc(_videoDoc).get();
      if (!doc.exists || doc.data() == null) return const VideoLogoConfig();
      return VideoLogoConfig.fromMap(doc.data()!);
    } catch (e) {
      debugPrint('Error fetching video/logo config: $e');
      return const VideoLogoConfig();
    }
  }

  /// Save Video & Logo Configuration
  static Future<void> saveVideoLogoConfig(VideoLogoConfig config) async {
    await _db.collection(_cfgCol).doc(_videoDoc).set(
          config.toMap()..addAll({'updated_at': FieldValue.serverTimestamp()}),
          SetOptions(merge: true),
        );
  }

  /// Fetch Localization Configuration
  static Future<AppLocalizationConfig> getLocalizationConfig() async {
    try {
      final doc = await _db.collection(_cfgCol).doc(_localeDoc).get();
      if (!doc.exists || doc.data() == null) return const AppLocalizationConfig();
      return AppLocalizationConfig.fromMap(doc.data()!);
    } catch (e) {
      debugPrint('Error fetching localization config: $e');
      return const AppLocalizationConfig();
    }
  }

  /// Save Localization Configuration
  static Future<void> saveLocalizationConfig(AppLocalizationConfig config) async {
    await _db.collection(_cfgCol).doc(_localeDoc).set(
          config.toMap()..addAll({'updated_at': FieldValue.serverTimestamp()}),
          SetOptions(merge: true),
        );
  }

  /// Fetch Payment Configuration
  static Future<PaymentConfig> getPaymentConfig() async {
    try {
      final doc = await _db.collection(_cfgCol).doc(_paymentDoc).get();
      if (!doc.exists || doc.data() == null) return const PaymentConfig();
      return PaymentConfig.fromMap(doc.data()!);
    } catch (e) {
      debugPrint('Error fetching payment config: $e');
      return const PaymentConfig();
    }
  }

  /// Save Payment Configuration
  static Future<void> savePaymentConfig(PaymentConfig config) async {
    await _db.collection(_cfgCol).doc(_paymentDoc).set(
          config.toMap()..addAll({'updated_at': FieldValue.serverTimestamp()}),
          SetOptions(merge: true),
        );
  }

  // --- LOCALIZATION HELPERS ---

  static Future<void> addLanguage(String code, String label) async {
    final cfg = await getLocalizationConfig();
    final languages = List<String>.from(cfg.languages);
    if (!languages.contains(code)) languages.add(code);
    final labels = Map<String, String>.from(cfg.languageLabels);
    labels[code] = label;
    await saveLocalizationConfig(cfg.copyWith(languages: languages, languageLabels: labels));
  }

  static Future<void> removeLanguage(String code) async {
    final cfg = await getLocalizationConfig();
    final languages = List<String>.from(cfg.languages)..remove(code);
    final labels = Map<String, String>.from(cfg.languageLabels)..remove(code);
    await saveLocalizationConfig(cfg.copyWith(languages: languages, languageLabels: labels));
  }

  static Future<void> addCurrency(String code, String symbol, double rate) async {
    final cfg = await getLocalizationConfig();
    final currencies = List<String>.from(cfg.currencies);
    if (!currencies.contains(code)) currencies.add(code);
    final configs = Map<String, dynamic>.from(cfg.currencyConfigs);
    configs[code] = {
      'code': code,
      'symbol': symbol,
      'rateFromUsd': rate,
      'fractionDigits': 2,
    };
    await saveLocalizationConfig(cfg.copyWith(currencies: currencies, currencyConfigs: configs));
  }

  static Future<void> removeCurrency(String code) async {
    final cfg = await getLocalizationConfig();
    final currencies = List<String>.from(cfg.currencies)..remove(code);
    final configs = Map<String, dynamic>.from(cfg.currencyConfigs)..remove(code);
    await saveLocalizationConfig(cfg.copyWith(currencies: currencies, currencyConfigs: configs));
  }
}

// Helper for debugging without importing material everywhere
void debugPrint(String message) {
  // Use print in production-ready services if logging is set up, 
  // but for now, simple print is okay for internal debugging.
  // print('[ConfigService] $message');
}
