import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final String category;
  final bool featured;
  final double ratingAvg;
  final int ratingCount;
  final int favoritesCount;
  final String videoUrl;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.category,
    required this.featured,
    required this.ratingAvg,
    required this.ratingCount,
    required this.favoritesCount,
    required this.videoUrl,
  });

  factory Product.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    String extractImageUrl(Map<String, dynamic> data) {
      // 1. Try common string keys
      final keys = [
        'imageUrl',
        'image_url',
        'image',
        'imageURL',
        'image_link',
        'link',
        'url',
      ];
      for (final key in keys) {
        final val = data[key];
        if (val is String && val.trim().isNotEmpty) {
          return val.trim();
        }
        if (val is List && val.isNotEmpty) {
          final first = val.first;
          if (first is String && first.trim().isNotEmpty) {
            return first.trim();
          }
          if (first is Map) {
            final url = first['url'] ?? first['link'] ?? first['imageUrl'];
            if (url is String && url.trim().isNotEmpty) {
              return url.trim();
            }
          }
        }
      }

      // 2. Try 'media' list structure
      final media = data['media'];
      if (media is List) {
        for (final item in media) {
          if (item is Map &&
              (item['type'] == 'image' || !item.containsKey('type'))) {
            final url = item['url'] ?? item['link'] ?? item['imageUrl'];
            if (url is String && url.trim().isNotEmpty) {
              return url.trim();
            }
          }
          if (item is String && item.trim().isNotEmpty) {
            return item.trim();
          }
        }
      }

      // 3. Try to find any string that looks like a URL
      for (final val in data.values) {
        if (val is String &&
            val.trim().isNotEmpty &&
            (val.startsWith('http://') || val.startsWith('https://'))) {
          // Check if it's likely an image (optional but safer)
          final lower = val.toLowerCase();
          if (lower.contains('.jpg') ||
              lower.contains('.png') ||
              lower.contains('.jpeg') ||
              lower.contains('.webp') ||
              lower.contains('firebasestorage')) {
            return val.trim();
          }
        }
      }

      return '';
    }

    String extractVideoUrl(Map<String, dynamic> data) {
      final keys = [
        'videoUrl',
        'video_url',
        'video',
        'videoURL',
        'video_link',
      ];
      for (final key in keys) {
        final val = data[key];
        if (val is String && val.trim().isNotEmpty) {
          return val.trim();
        }
      }

      final media = data['media'];
      if (media is List) {
        for (final item in media) {
          if (item is Map && item['type'] == 'video') {
            final url = item['url'] ?? item['link'] ?? item['videoUrl'];
            if (url is String && url.trim().isNotEmpty) {
              return url.trim();
            }
          }
        }
      }
      return '';
    }

    return Product(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      imageUrl: extractImageUrl(data),
      category: data['category'] ?? 'uncategorized',
      featured: data['featured'] ?? false,
      ratingAvg: (data['ratingAvg'] as num?)?.toDouble() ?? 0.0,
      ratingCount: (data['ratingCount'] as num?)?.toInt() ?? 0,
      favoritesCount: (data['favoritesCount'] as num?)?.toInt() ?? 0,
      videoUrl: extractVideoUrl(data),
    );
  }
}
