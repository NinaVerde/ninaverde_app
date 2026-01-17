// lib/models/live_game_models.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class LiveGameConfig {
  final String id;
  final String name;
  final String icon;
  final double pricePerQuarterHour;
  final int maxPlayers;
  final String rules;
  final double deposit;

  LiveGameConfig({
    required this.id,
    required this.name,
    required this.icon,
    required this.pricePerQuarterHour,
    required this.maxPlayers,
    required this.rules,
    required this.deposit,
  });

  factory LiveGameConfig.fromMap(String id, Map<String, dynamic> map) {
    return LiveGameConfig(
      id: id,
      name: map['name'] ?? '',
      icon: map['icon'] ?? '🎮',
      pricePerQuarterHour: (map['pricePerQuarterHour'] ?? 0.0).toDouble(),
      maxPlayers: map['maxPlayers'] ?? 1,
      rules: map['rules'] ?? '',
      deposit: (map['deposit'] ?? 0.0).toDouble(),
    );
  }

  LiveGameConfig copyWith({
    String? name,
    String? icon,
    double? pricePerQuarterHour,
    int? maxPlayers,
    String? rules,
    double? deposit,
  }) {
    return LiveGameConfig(
      id: this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      pricePerQuarterHour: pricePerQuarterHour ?? this.pricePerQuarterHour,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      rules: rules ?? this.rules,
      deposit: deposit ?? this.deposit,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'icon': icon,
      'pricePerQuarterHour': pricePerQuarterHour,
      'maxPlayers': maxPlayers,
      'rules': rules,
      'deposit': deposit,
    };
  }
}

class LiveGameSession {
  final String id;
  final String gameId;
  final String userId;
  final String userName;
  final DateTime startTime;
  final DateTime? endTime;
  final bool isApproved;
  final int playerCount;
  final double totalCharge;

  LiveGameSession({
    required this.id,
    required this.gameId,
    required this.userId,
    required this.userName,
    required this.startTime,
    this.endTime,
    required this.isApproved,
    required this.playerCount,
    required this.totalCharge,
  });

  factory LiveGameSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LiveGameSession(
      id: doc.id,
      gameId: data['gameId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: data['endTime'] != null ? (data['endTime'] as Timestamp).toDate() : null,
      isApproved: data['isApproved'] ?? false,
      playerCount: data['playerCount'] ?? 1,
      totalCharge: (data['totalCharge'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'gameId': gameId,
      'userId': userId,
      'userName': userName,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'isApproved': isApproved,
      'playerCount': playerCount,
      'totalCharge': totalCharge,
    };
  }
}
