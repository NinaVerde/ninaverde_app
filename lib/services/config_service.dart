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
      return TickerConfig.fromMap(doc.data()!);
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
}

// Helper for debugging without importing material everywhere
void debugPrint(String message) {
  // Use print in production-ready services if logging is set up, 
  // but for now, simple print is okay for internal debugging.
  // print('[ConfigService] $message');
}
