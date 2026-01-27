// lib/services/live_game_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/live_game_models.dart';

class LiveGameService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _configCol = 'live_game_configs';
  static const String _sessionCol = 'live_game_sessions';

  // --- Configurations ---
  static Future<List<LiveGameConfig>> getConfigs() async {
    final snap = await _db.collection(_configCol).get();
    
    // Check if critical new games exist (e.g. ps5). If not, re-seed.
    final existingIds = snap.docs.map((d) => d.id).toSet();
    if (!existingIds.contains('ps5')) {
        await seedInitialConfigs();
        final snap2 = await _db.collection(_configCol).get();
        return snap2.docs.map((d) => LiveGameConfig.fromMap(d.id, d.data())).toList();
    }
    
    return snap.docs.map((d) => LiveGameConfig.fromMap(d.id, d.data())).toList();
  }

  static Future<void> upsertConfig(LiveGameConfig config) async {
    await _db.collection(_configCol).doc(config.id).set(config.toMap());
  }

  // --- Sessions ---
  static Future<String> startSession({
    required String gameId,
    required int playerCount,
    String collateralDescription = '',
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Auth required');

    // Check payment method (simulated)
    final userSnap = await _db.collection('users').doc(user.uid).get();
    final hasPayment = userSnap.data()?['hasPaymentMethod'] == true;
    if (!hasPayment) {
      throw Exception('Payment method required to start live games');
    }

    final session = LiveGameSession(
      id: '', // Firestore will generate
      gameId: gameId,
      userId: user.uid,
      userName: user.displayName ?? user.email ?? 'Guest',
      startTime: DateTime.now(),
      isApproved: false,
      playerCount: playerCount,
      totalCharge: 0,
      collateralDescription: collateralDescription,
    );

    final doc = await _db.collection(_sessionCol).add(session.toMap());
    return doc.id;
  }

  static Future<void> requestEndSession(String sessionId) async {
    await _db.collection(_sessionCol).doc(sessionId).update({
      'endTime': Timestamp.now(),
    });
  }

  static Future<void> approveEndSession(String sessionId, double finalCharge) async {
    await _db.collection(_sessionCol).doc(sessionId).update({
      'isApproved': true,
      'totalCharge': finalCharge,
    });
  }

  static Stream<List<LiveGameSession>> getActiveSessions() {
    return _db
        .collection(_sessionCol)
        .where('isApproved', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) => LiveGameSession.fromFirestore(d)).toList());
  }

  static Stream<LiveGameSession?> getUserActiveSession() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);
    
    return _db
        .collection(_sessionCol)
        .where('userId', isEqualTo: user.uid)
        .where('isApproved', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.isNotEmpty 
            ? LiveGameSession.fromFirestore(snap.docs.first) 
            : null);
  }

  // Calculate charge based on 15-minute periods
  static double calculateCharge(DateTime start, DateTime end, double pricePerQuarter) {
    final duration = end.difference(start);
    final quarters = (duration.inMinutes / 15).ceil();
    return quarters * pricePerQuarter;
  }

  // --- Seed Data ---
  static Future<void> seedInitialConfigs() async {
    final configs = [
      LiveGameConfig(
        id: 'ps5',
        name: 'PS5 Console',
        icon: '🎮',
        pricePerQuarterHour: 2.50,
        maxPlayers: 4,
        rules: 'Return controllers to staff. No food/drink near console.',
        deposit: 20.0,
        requireDeposit: true,
        collateralType: 'ID', // Require ID
      ),
      LiveGameConfig(
        id: 'chess',
        name: 'Chess Board',
        icon: '♟️',
        pricePerQuarterHour: 1.00,
        maxPlayers: 2,
        rules: 'Return all pieces. Report any damage.',
        deposit: 5.0,
        requireDeposit: false,
        collateralType: 'None',
      ),
      LiveGameConfig(
        id: 'checkers',
        name: 'Checkers Board',
        icon: '🔴',
        pricePerQuarterHour: 1.00,
        maxPlayers: 2,
        rules: 'Return all pieces.',
        deposit: 5.0,
        requireDeposit: false,
        collateralType: 'None',
      ),
      LiveGameConfig(
        id: 'cards',
        name: 'Playing Cards',
        icon: '🃏',
        pricePerQuarterHour: 0.50,
        maxPlayers: 6,
        rules: 'Complete deck must be returned.',
        deposit: 2.0,
        requireDeposit: false,
        collateralType: 'Cash', // Cash deposit preferred for small items
      ),
      LiveGameConfig(
        id: 'darts',
        name: 'Darts',
        icon: '🎯',
        pricePerQuarterHour: 1.50,
        maxPlayers: 4,
        rules: 'Adult supervision required. Play in designated area.',
        deposit: 10.0,
        requireDeposit: true,
        collateralType: 'ID',
      ),
      LiveGameConfig(
        id: 'jenga',
        name: 'Giant Jenga',
        icon: '🧱',
        pricePerQuarterHour: 2.00,
        maxPlayers: 6,
        rules: 'Stack safely. Watch your toes!',
        deposit: 15.0,
        requireDeposit: false,
        collateralType: 'None',
      ),
    ];

    for (final c in configs) {
      await upsertConfig(c);
    }
  }
}
