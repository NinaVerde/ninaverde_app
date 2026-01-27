import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single option within a customization group
class CustomizationOption {
  final String id;
  final String nameEn;
  final String nameEs;
  final double price; // 0 = no extra cost

  CustomizationOption({
    required this.id,
    required this.nameEn,
    required this.nameEs,
    required this.price,
  });

  factory CustomizationOption.fromMap(Map<String, dynamic> data) {
    return CustomizationOption(
      id: data['id'] as String? ?? '',
      nameEn: data['nameEn'] as String? ?? data['name'] as String? ?? '',
      nameEs: data['nameEs'] as String? ?? data['name'] as String? ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'nameEn': nameEn,
    'nameEs': nameEs,
    'price': price,
  };
}

/// Represents a customization group (e.g., Size, Toppings, Flavors)
class CustomizationGroup {
  final String id;
  final String nameEn;
  final String nameEs;
  final bool enabled;
  final bool multiSelect; // true = checkboxes (Toppings), false = radio (Size)
  final List<CustomizationOption> options;

  CustomizationGroup({
    required this.id,
    required this.nameEn,
    required this.nameEs,
    required this.enabled,
    required this.multiSelect,
    required this.options,
  });

  factory CustomizationGroup.fromMap(Map<String, dynamic> data) {
    return CustomizationGroup(
      id: data['id'] as String? ?? '',
      nameEn: data['nameEn'] as String? ?? data['name'] as String? ?? '',
      nameEs: data['nameEs'] as String? ?? data['name'] as String? ?? '',
      enabled: data['enabled'] as bool? ?? true,
      multiSelect: data['multiSelect'] as bool? ?? false,
      options: (data['options'] as List<dynamic>? ?? [])
          .map((opt) => CustomizationOption.fromMap(opt as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'nameEn': nameEn,
    'nameEs': nameEs,
    'enabled': enabled,
    'multiSelect': multiSelect,
    'options': options.map((o) => o.toMap()).toList(),
  };
}


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
  
  // Localized fields
  final String nameEn;
  final String nameEs;
  final String descriptionEn;
  final String descriptionEs;
  final String categoryEn;
  final String categoryEs;
  
  // Customization options (Size, Toppings, Flavors, etc.)
  final List<CustomizationGroup> customizations;

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
    // Optional params for backward compat, defaulting to empty if not provided manually (factory handles defaults logic)
    this.nameEn = '',
    this.nameEs = '',
    this.descriptionEn = '',
    this.descriptionEs = '',
    this.categoryEn = '',
    this.categoryEs = '',
    this.customizations = const [],
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
      
      // Localized fields
      // Check both snake_case (standard) and camelCase (legacy/alternative)
      nameEn: data['name_en'] ?? data['nameEn'] ?? data['name'] ?? '',
      nameEs: data['name_es'] ?? data['nameEs'] ?? '',
      descriptionEn: data['description_en'] ?? data['descriptionEn'] ?? data['description'] ?? '',
      descriptionEs: data['description_es'] ?? data['descriptionEs'] ?? '',
      categoryEn: data['category_en'] ?? data['categoryEn'] ?? data['category'] ?? '',
      categoryEs: data['category_es'] ?? data['categoryEs'] ?? '',
      
      // Parse customizations from various possible formats
      customizations: _parseCustomizations(data),
    );
  }
  
  /// Parse customizations from Firebase data
  /// Handles both structured format and legacy formats (size, toppings, flavors as separate fields)
  static List<CustomizationGroup> _parseCustomizations(Map<String, dynamic> data) {
    final List<CustomizationGroup> groups = [];
    
    // First, check for structured 'customizations' array
    if (data['customizations'] is List) {
      for (final item in data['customizations'] as List) {
        if (item is Map<String, dynamic>) {
          groups.add(CustomizationGroup.fromMap(item));
        }
      }
      return groups;
    }
    
    // Legacy format: check for individual fields (size, toppings, flavors, etc.)
    // SIZE
    if (data['size'] != null || data['sizes'] != null) {
      final sizeData = data['size'] ?? data['sizes'];
      groups.add(_parseLegacyGroup(
        id: 'size',
        nameEn: 'Size',
        nameEs: 'Tamaño',
        data: sizeData,
        multiSelect: false,
      ));
    }
    
    // TOPPINGS
    if (data['toppings'] != null || data['topping'] != null) {
      final toppingData = data['toppings'] ?? data['topping'];
      groups.add(_parseLegacyGroup(
        id: 'toppings',
        nameEn: 'Toppings',
        nameEs: 'Extras',
        data: toppingData,
        multiSelect: true,
      ));
    }
    
    // FLAVORS
    if (data['flavors'] != null || data['flavor'] != null) {
      final flavorData = data['flavors'] ?? data['flavor'];
      groups.add(_parseLegacyGroup(
        id: 'flavors',
        nameEn: 'Flavors',
        nameEs: 'Sabores',
        data: flavorData,
        multiSelect: false,
      ));
    }
    
    // EXTRAS (generic)
    if (data['extras'] != null) {
      groups.add(_parseLegacyGroup(
        id: 'extras',
        nameEn: 'Extras',
        nameEs: 'Extras',
        data: data['extras'],
        multiSelect: true,
      ));
    }
    
    return groups;
  }
  
  /// Parse legacy format into CustomizationGroup
  static CustomizationGroup _parseLegacyGroup({
    required String id,
    required String nameEn,
    required String nameEs,
    required dynamic data,
    required bool multiSelect,
  }) {
    final List<CustomizationOption> options = [];
    
    if (data is List) {
      for (final item in data) {
        if (item is String) {
          // Simple string list: ["Small", "Medium", "Large"]
          options.add(CustomizationOption(
            id: item.toLowerCase().replaceAll(' ', '_'),
            nameEn: item,
            nameEs: item, // Would need translation service
            price: 0.0,
          ));
        } else if (item is Map) {
          // Map format: {"name": "Large", "price": 2.0}
          final name = item['name'] as String? ?? item['nameEn'] as String? ?? '';
          options.add(CustomizationOption(
            id: item['id'] as String? ?? name.toLowerCase().replaceAll(' ', '_'),
            nameEn: item['nameEn'] as String? ?? name,
            nameEs: item['nameEs'] as String? ?? name,
            price: (item['price'] as num?)?.toDouble() ?? 0.0,
          ));
        }
      }
    } else if (data is Map) {
      // Map of options: {"small": 0, "medium": 1.5, "large": 3.0}
      data.forEach((key, value) {
        final price = (value is num) ? value.toDouble() : 0.0;
        options.add(CustomizationOption(
          id: key.toString().toLowerCase(),
          nameEn: _capitalize(key.toString()),
          nameEs: _capitalize(key.toString()),
          price: price,
        ));
      });
    }
    
    return CustomizationGroup(
      id: id,
      nameEn: nameEn,
      nameEs: nameEs,
      enabled: true,
      multiSelect: multiSelect,
      options: options,
    );
  }
  
  static String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}
