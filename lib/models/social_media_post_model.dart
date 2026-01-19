// lib/models/social_media_post_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Supported social media platforms
enum SocialPlatform {
  facebook,
  instagram,
  twitter,  // X
  tikTok,
  linkedin,
  pinterest,
  youtube,  // Community posts
}

/// Post status
enum PostStatus {
  draft,
  scheduled,
  publishing,
  published,
  failed,
}

/// Social media post model - unified across all platforms
class SocialMediaPost {
  final String id;
  final String userId;  // Who created this post
  final String userDisplayName;
  
  // Content
  final String content;  // Main text content
  final Map<String, String>? platformSpecificContent;  // Different text per platform
  final List<String> mediaUrls;  // Images/videos
  final List<String> hashtags;
  final String? linkUrl;
  
  // Platforms
  final List<SocialPlatform> targetPlatforms;
  final Map<String, String>? platformPostIds;  // Track post IDs on each platform
  
  // Scheduling
  final PostStatus status;
  final DateTime? scheduledTime;
  final DateTime? publishedAt;
  
  // Analytics
  final Map<String, int>? engagement;  // likes, shares, comments per platform
  final int totalReach;
  final int totalClicks;
  
  // Metadata
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? errorMessage;
  
  // Template
  final bool isTemplate;
  final String? templateName;

  SocialMediaPost({
    required this.id,
    required this.userId,
    required this.userDisplayName,
    required this.content,
    this.platformSpecificContent,
    this.mediaUrls = const [],
    this.hashtags = const [],
    this.linkUrl,
    required this.targetPlatforms,
    this.platformPostIds,
    required this.status,
    this.scheduledTime,
    this.publishedAt,
    this.engagement,
    this.totalReach = 0,
    this.totalClicks = 0,
    required this.createdAt,
    this.updatedAt,
    this.errorMessage,
    this.isTemplate = false,
    this.templateName,
  });

  /// Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userDisplayName': userDisplayName,
      'content': content,
      'platformSpecificContent': platformSpecificContent,
      'mediaUrls': mediaUrls,
      'hashtags': hashtags,
      'linkUrl': linkUrl,
      'targetPlatforms': targetPlatforms.map((p) => p.name).toList(),
      'platformPostIds': platformPostIds,
      'status': status.name,
      'scheduledTime': scheduledTime != null ? Timestamp.fromDate(scheduledTime!) : null,
      'publishedAt': publishedAt != null ? Timestamp.fromDate(publishedAt!) : null,
      'engagement': engagement,
      'totalReach': totalReach,
      'totalClicks': totalClicks,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'errorMessage': errorMessage,
      'isTemplate': isTemplate,
      'templateName': templateName,
    };
  }

  /// Create from Firestore document
  factory SocialMediaPost.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    DateTime? parseTimestamp(dynamic ts) {
      if (ts is Timestamp) return ts.toDate();
      return null;
    }

    return SocialMediaPost(
      id: doc.id,
      userId: data['userId'] ?? '',
      userDisplayName: data['userDisplayName'] ?? 'Unknown',
      content: data['content'] ?? '',
      platformSpecificContent: (data['platformSpecificContent'] as Map?)?.cast<String, String>(),
      mediaUrls: (data['mediaUrls'] as List?)?.cast<String>() ?? [],
      hashtags: (data['hashtags'] as List?)?.cast<String>() ?? [],
      linkUrl: data['linkUrl'],
      targetPlatforms: (data['targetPlatforms'] as List? ?? [])
          .map((name) => SocialPlatform.values.firstWhere(
                (e) => e.name == name,
                orElse: () => SocialPlatform.facebook,
              ))
          .toList(),
      platformPostIds: (data['platformPostIds'] as Map?)?.cast<String, String>(),
      status: PostStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => PostStatus.draft,
      ),
      scheduledTime: parseTimestamp(data['scheduledTime']),
      publishedAt: parseTimestamp(data['publishedAt']),
      engagement: (data['engagement'] as Map?)?.cast<String, int>(),
      totalReach: data['totalReach'] ?? 0,
      totalClicks: data['totalClicks'] ?? 0,
      createdAt: parseTimestamp(data['createdAt']) ?? DateTime.now(),
      updatedAt: parseTimestamp(data['updatedAt']),
      errorMessage: data['errorMessage'],
      isTemplate: data['isTemplate'] ?? false,
      templateName: data['templateName'],
    );
  }

  /// Create a copy with modifications
  SocialMediaPost copyWith({
    String? id,
    String? userId,
    String? userDisplayName,
    String? content,
    Map<String, String>? platformSpecificContent,
    List<String>? mediaUrls,
    List<String>? hashtags,
    String? linkUrl,
    List<SocialPlatform>? targetPlatforms,
    Map<String, String>? platformPostIds,
    PostStatus? status,
    DateTime? scheduledTime,
    DateTime? publishedAt,
    Map<String, int>? engagement,
    int? totalReach,
    int? totalClicks,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? errorMessage,
    bool? isTemplate,
    String? templateName,
  }) {
    return SocialMediaPost(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userDisplayName: userDisplayName ?? this.userDisplayName,
      content: content ?? this.content,
      platformSpecificContent: platformSpecificContent ?? this.platformSpecificContent,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      hashtags: hashtags ?? this.hashtags,
      linkUrl: linkUrl ?? this.linkUrl,
      targetPlatforms: targetPlatforms ?? this.targetPlatforms,
      platformPostIds: platformPostIds ?? this.platformPostIds,
      status: status ?? this.status,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      publishedAt: publishedAt ?? this.publishedAt,
      engagement: engagement ?? this.engagement,
      totalReach: totalReach ?? this.totalReach,
      totalClicks: totalClicks ?? this.totalClicks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      errorMessage: errorMessage ?? this.errorMessage,
      isTemplate: isTemplate ?? this.isTemplate,
      templateName: templateName ?? this.templateName,
    );
  }
}

/// Platform connection/account model
class SocialPlatformAccount {
  final String id;
  final SocialPlatform platform;
  final String accountId;  // Platform's user ID
  final String accountName;
  final String? profilePictureUrl;
  final bool isConnected;
  final DateTime connectedAt;
  final DateTime? lastSyncAt;
  final String? accessToken;  // Encrypted
  final DateTime? tokenExpiresAt;

  SocialPlatformAccount({
    required this.id,
    required this.platform,
    required this.accountId,
    required this.accountName,
    this.profilePictureUrl,
    this.isConnected = true,
    required this.connectedAt,
    this.lastSyncAt,
    this.accessToken,
    this.tokenExpiresAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'platform': platform.name,
      'accountId': accountId,
      'accountName': accountName,
      'profilePictureUrl': profilePictureUrl,
      'isConnected': isConnected,
      'connectedAt': Timestamp.fromDate(connectedAt),
      'lastSyncAt': lastSyncAt != null ? Timestamp.fromDate(lastSyncAt!) : null,
      'accessToken': accessToken,
      'tokenExpiresAt': tokenExpiresAt != null ? Timestamp.fromDate(tokenExpiresAt!) : null,
    };
  }

  factory SocialPlatformAccount.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    DateTime? parseTimestamp(dynamic ts) {
      if (ts is Timestamp) return ts.toDate();
      return null;
    }

    return SocialPlatformAccount(
      id: doc.id,
      platform: SocialPlatform.values.firstWhere(
        (e) => e.name == data['platform'],
        orElse: () => SocialPlatform.facebook,
      ),
      accountId: data['accountId'] ?? '',
      accountName: data['accountName'] ?? '',
      profilePictureUrl: data['profilePictureUrl'],
      isConnected: data['isConnected'] ?? true,
      connectedAt: parseTimestamp(data['connectedAt']) ?? DateTime.now(),
      lastSyncAt: parseTimestamp(data['lastSyncAt']),
      accessToken: data['accessToken'],
      tokenExpiresAt: parseTimestamp(data['tokenExpiresAt']),
    );
  }
}
