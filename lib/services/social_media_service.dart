// lib/services/social_media_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:http/http.dart' as http; // Unused
// import 'dart:convert'; // Unused
import '../models/social_media_post_model.dart';

/// Service for managing social media posts across platforms
class SocialMediaService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  static const String postsCollection = 'social_media_posts';
  static const String accountsCollection = 'social_platform_accounts';
  static const String analyticsCollection = 'social_analytics';

  /// Create or update a post
  Future<String> savePost(SocialMediaPost post) async {
    if (post.id.isEmpty) {
      final docRef = await _firestore.collection(postsCollection).add(post.toMap());
      return docRef.id;
    } else {
      await _firestore.collection(postsCollection).doc(post.id).set(
        post.copyWith(updatedAt: DateTime.now()).toMap(),
        SetOptions(merge: true),
      );
      return post.id;
    }
  }

  /// Get all posts stream
  Stream<List<SocialMediaPost>> getPostsStream({PostStatus? status}) {
    var query = _firestore.collection(postsCollection).orderBy('createdAt', descending: true);
    
    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }
    
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => SocialMediaPost.fromFirestore(doc)).toList();
    });
  }

  /// Get scheduled posts
  Stream<List<SocialMediaPost>> getScheduledPostsStream() {
    return _firestore
        .collection(postsCollection)
        .where('status', isEqualTo: PostStatus.scheduled.name)
        .orderBy('scheduledTime')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => SocialMediaPost.fromFirestore(doc)).toList();
    });
  }

  /// Publish post to all platforms
  Future<void> publishPost(String postId) async {
    final doc = await _firestore.collection(postsCollection).doc(postId).get();
    final post = SocialMediaPost.fromFirestore(doc);

    // Update status to publishing
    await _firestore.collection(postsCollection).doc(postId).update({
      'status': PostStatus.publishing.name,
    });

    final platformPostIds = <String, String>{};
    bool hasError = false;
    String? errorMessage;

    // Publish to each platform
    for (final platform in post.targetPlatforms) {
      try {
        final platformPostId = await _publishToPlatform(post, platform);
        platformPostIds[platform.name] = platformPostId;
      } catch (e) {
        hasError = true;
        errorMessage = 'Failed to publish to ${platform.name}: $e';
        break;
      }
    }

    // Update post with results
    await _firestore.collection(postsCollection).doc(postId).update({
      'status': hasError ? PostStatus.failed.name : PostStatus.published.name,
      'publishedAt': hasError ? null : FieldValue.serverTimestamp(),
      'platformPostIds': platformPostIds,
      'errorMessage': errorMessage,
    });
  }

  /// Publish to specific platform (placeholder - needs actual API integration)
  Future<String> _publishToPlatform(SocialMediaPost post, SocialPlatform platform) async {
    // Get platform account
    final accountsSnapshot = await _firestore
        .collection(accountsCollection)
        .where('platform', isEqualTo: platform.name)
        .where('isConnected', isEqualTo: true)
        .limit(1)
        .get();

    if (accountsSnapshot.docs.isEmpty) {
      throw Exception('No connected account for ${platform.name}');
    }

    final account = SocialPlatformAccount.fromFirestore(accountsSnapshot.docs.first);
    
    // Get platform-specific content or use default
    final content = post.platformSpecificContent?[platform.name] ?? post.content;

    // Platform-specific publishing logic
    switch (platform) {
      case SocialPlatform.facebook:
        return await _publishToFacebook(account, content, post.mediaUrls, post.linkUrl);
      case SocialPlatform.instagram:
        return await _publishToInstagram(account, content, post.mediaUrls, post.hashtags);
      case SocialPlatform.twitter:
        return await _publishToTwitter(account, content, post.mediaUrls, post.hashtags);
      case SocialPlatform.tikTok:
        return await _publishToTikTok(account, content, post.mediaUrls);
      case SocialPlatform.linkedin:
        return await _publishToLinkedIn(account, content, post.mediaUrls, post.linkUrl);
      case SocialPlatform.pinterest:
        return await _publishToPinterest(account, content, post.mediaUrls, post.linkUrl);
      case SocialPlatform.youtube:
        return await _publishToYouTube(account, content);
    }
  }

  // Platform-specific publish methods (placeholders for actual API integration)
  
  Future<String> _publishToFacebook(SocialPlatformAccount account, String content, List<String> mediaUrls, String? linkUrl) async {
    // TODO: Implement Facebook Graph API integration
    // For now, return a mock ID
    return 'fb_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<String> _publishToInstagram(SocialPlatformAccount account, String content, List<String> mediaUrls, List<String> hashtags) async {
    // TODO: Implement Instagram Graph API integration
    // final fullContent = '$content\n\n${hashtags.map((h) => '#$h').join(' ')}'; // Unused
    return 'ig_${DateTime.now().millisecondsSinceEpoch}';  
  }

  Future<String> _publishToTwitter(SocialPlatformAccount account, String content, List<String> mediaUrls, List<String> hashtags) async {
    // TODO: Implement Twitter API v2 integration
    // final fullContent = '$content ${hashtags.map((h) => '#$h').join(' ')}'; // Unused
    return 'tw_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<String> _publishToTikTok(SocialPlatformAccount account, String content, List<String> mediaUrls) async {
    // TODO: Implement TikTok API integration
    return 'tt_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<String> _publishToLinkedIn(SocialPlatformAccount account, String content, List<String> mediaUrls, String? linkUrl) async {
    // TODO: Implement LinkedIn API integration
    return 'li_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<String> _publishToPinterest(SocialPlatformAccount account, String content, List<String> mediaUrls, String? linkUrl) async {
    // TODO: Implement Pinterest API integration
    return 'pin_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<String> _publishToYouTube(SocialPlatformAccount account, String content) async {
    // TODO: Implement YouTube Community Posts API integration
    return 'yt_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Delete post
  Future<void> deletePost(String postId) async {
    await _firestore.collection(postsCollection).doc(postId).delete();
  }

  /// Get suggested hashtags based on content
  Future<List<String>> suggestHashtags(String content) async {
    // TODO: Implement AI-based hashtag suggestion
    // For now, return some common ones
    return ['NiñaVerde', 'Nicaragua', 'GoodFood', 'LocalBusiness'];
  }

  /// Connect platform account
  Future<void> connectPlatformAccount(SocialPlatformAccount account) async {
    await _firestore
        .collection(accountsCollection)
        .doc(account.id)
        .set(account.toMap(), SetOptions(merge: true));
  }

  /// Get connected accounts
  Stream<List<SocialPlatformAccount>> getConnectedAccountsStream() {
    return _firestore
        .collection(accountsCollection)
        .where('isConnected', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => SocialPlatformAccount.fromFirestore(doc)).toList();
    });
  }

  /// Disconnect account
  Future<void> disconnectAccount(String accountId) async {
    await _firestore.collection(accountsCollection).doc(accountId).update({
      'isConnected': false,
    });
  }

  /// Get analytics for a post
  Future<Map<String, dynamic>> getPostAnalytics(String postId) async {
    final doc = await _firestore.collection(analyticsCollection).doc(postId).get();
    return doc.data() ?? {};
  }

  /// Sync analytics from platforms (placeholder)
  Future<void> syncAnalytics(String postId) async {
    // TODO: Fetch real analytics from each platform
    final mockAnalytics = {
      'facebook': {'likes': 42, 'shares': 12, 'comments': 8},
      'instagram': {'likes': 156, 'comments': 23, 'saves': 34},
      'twitter': {'likes': 89, 'retweets': 15, 'replies': 12},
    };

    await _firestore.collection(analyticsCollection).doc(postId).set(mockAnalytics);
  }

  /// Get overall social media stats
  Future<Map<String, int>> getSocialMediaStats() async {
    final postsSnapshot = await _firestore.collection(postsCollection).get();
    final posts = postsSnapshot.docs.map((doc) => SocialMediaPost.fromFirestore(doc)).toList();

    return {
      'total': posts.length,
      'drafts': posts.where((p) => p.status == PostStatus.draft).length,
      'scheduled': posts.where((p) => p.status == PostStatus.scheduled).length,
      'published': posts.where((p) => p.status == PostStatus.published).length,
      'failed': posts.where((p) => p.status == PostStatus.failed).length,
      'totalReach': posts.fold(0, (total, p) => total + p.totalReach),
      'totalEngagement': posts.fold(0, (total, p) => 
          total + (p.engagement?.values.fold<int>(0, (int s, int v) => s + v) ?? 0)),
    };
  }
}
