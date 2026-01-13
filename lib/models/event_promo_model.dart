import 'package:cloud_firestore/cloud_firestore.dart';

class EventPromo {
  final String id;
  final String title;
  final String description;
  final String type;
  final String imageUrl;
  final String videoUrl;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool active;

  EventPromo({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.imageUrl,
    required this.videoUrl,
    required this.startDate,
    required this.endDate,
    required this.active,
  });

  factory EventPromo.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    DateTime? readDate(String key) {
      final ts = data[key];
      if (ts is Timestamp) return ts.toDate();
      return null;
    }

    String extractMediaUrl(String type) {
      final keys = type == 'image'
          ? ['imageUrl', 'image_url', 'image', 'imageURL', 'link', 'url']
          : ['videoUrl', 'video_url', 'video', 'videoURL'];

      for (final key in keys) {
        final val = data[key];
        if (val is String && val.trim().isNotEmpty) return val.trim();
        if (val is List && val.isNotEmpty) {
          final first = val.first;
          if (first is String && first.trim().isNotEmpty) return first.trim();
          if (first is Map) {
            final u = first['url'] ?? first['link'] ?? first['imageUrl'];
            if (u is String && u.trim().isNotEmpty) return u.trim();
          }
        }
      }

      final media = data['media'];
      if (media is List) {
        for (final item in media) {
          if (item is Map && (item['type'] == type || type == 'image')) {
            final u = item['url'] ?? item['link'] ?? item['imageUrl'];
            if (u is String && u.trim().isNotEmpty) return u.trim();
          }
        }
      }
      return '';
    }

    return EventPromo(
      id: doc.id,
      title: (data['title'] as String?) ?? '',
      description: (data['description'] as String?) ?? '',
      type: (data['type'] as String?) ?? 'promo',
      imageUrl: extractMediaUrl('image'),
      videoUrl: extractMediaUrl('video'),
      startDate: readDate('startDate'),
      endDate: readDate('endDate'),
      active: (data['active'] as bool?) ?? true,
    );
  }
}
