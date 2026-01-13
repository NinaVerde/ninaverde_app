import 'package:cloud_firestore/cloud_firestore.dart';

class RewardsSettings {
  final bool enabled;
  final double usdPerCoin;
  final int signupBonus;
  final int referralBonus;
  final double minOrderUsd;
  final int maxCoinsPerOrder;

  const RewardsSettings({
    required this.enabled,
    required this.usdPerCoin,
    required this.signupBonus,
    required this.referralBonus,
    required this.minOrderUsd,
    required this.maxCoinsPerOrder,
  });
}

class RewardsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _cfgCol = 'app_config';
  static const String _docId = 'rewards';

  DocumentReference<Map<String, dynamic>> get _ref =>
      _db.collection(_cfgCol).doc(_docId);

  Stream<RewardsSettings> settingsStream() {
    return _ref.snapshots().map((doc) {
      final data = doc.data() ?? {};
      return RewardsSettings(
        enabled: (data['enabled'] as bool?) ?? true,
        usdPerCoin: (data['usdPerCoin'] as num?)?.toDouble() ?? 10.0,
        signupBonus: (data['signupBonus'] as num?)?.toInt() ?? 0,
        referralBonus: (data['referralBonus'] as num?)?.toInt() ?? 0,
        minOrderUsd: (data['minOrderUsd'] as num?)?.toDouble() ?? 0.0,
        maxCoinsPerOrder: (data['maxCoinsPerOrder'] as num?)?.toInt() ?? 0,
      );
    });
  }

  Future<void> saveSettings(RewardsSettings settings) async {
    await _ref.set({
      'enabled': settings.enabled,
      'usdPerCoin': settings.usdPerCoin,
      'signupBonus': settings.signupBonus,
      'referralBonus': settings.referralBonus,
      'minOrderUsd': settings.minOrderUsd,
      'maxCoinsPerOrder': settings.maxCoinsPerOrder,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  int computeCoins({
    required double orderTotalUsd,
    required RewardsSettings settings,
  }) {
    if (!settings.enabled) return 0;
    if (orderTotalUsd < settings.minOrderUsd) return 0;
    if (settings.usdPerCoin <= 0) return 0;
    var coins = (orderTotalUsd / settings.usdPerCoin).floor();
    if (settings.maxCoinsPerOrder > 0) {
      coins = coins.clamp(0, settings.maxCoinsPerOrder);
    }
    return coins;
  }
}
