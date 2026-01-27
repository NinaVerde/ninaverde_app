// lib/config/product_animations_map.dart

/// Configuration for the "Elite" Hero Carousel.
/// Maps category names to their respective asset folders for 3D sequences.
class HeroCategoryConfig {
  static const List<String> order = [
    'VYBZ Eventos',
    'Cafés Especialidad y Bebidas',
    'Smoothies y Mezclas Congeladas',
    'Todo El Dia, Todo La Noche, Desayuno WTF',
    'La Cocina',
    'La Parrillada',
    'Los Postres',
    'Los Helados',
    'Microgreens',
    'Minoristas',
    'Equipo y Merchandising',
  ];

  static const String specialCategory = 'VYBZ Eventos';

  /// Maps Category Name -> Asset Folder Name
  /// Ensure these folders exist in `assets/images/sequences/`
  static const Map<String, String> animationFolders = {
    'VYBZ Eventos': 'vybz_eventos',
    'La Cocina': 'la_cocina',
    'La Parrillada': 'la_parrillada',
    'Todo El Dia, Todo La Noche, Desayuno WTF': 'desayuno_wtf',
    'Los Postres': 'los_postres',
    'Los Helados': 'los_helados',
    'Smoothies y Mezclas Congeladas': 'smoothies',
    'Cafés Especialidad y Bebidas': 'cafes',
    'Microgreens': 'microgreens',
    'Equipo y Merchandising': 'equipo',
    'Minoristas': 'minoristas',
  };

  /// Translations for Category Names (Key is always the Spanish DB string)
  static const Map<String, String> translations = {
    'VYBZ Eventos': 'VYBZ Events',
    'Todo El Dia, Todo La Noche, Desayuno WTF': 'All Day, All Night, Breakfast WTF?',
    'Cafés Especialidad y Bebidas': 'Specialty Coffees & Drinks',
    'La Parrillada': 'The Grill',
    'La Cocina': 'The Kitchen',
    'Smoothies y Mezclas Congeladas': 'Smoothies & Frozen Blends',
    'Los Postres': 'Desserts',
    'Los Helados': 'Ice Cream',
    'Microgreens': 'Microgreens',
    'Equipo y Merchandising': 'Gear & Merch',
    'Minoristas': 'Retailers',
  };

  /// Frame Counts for Sequences (Default is 1)
  static const Map<String, int> frameCounts = {
    'Todo El Dia, Todo La Noche, Desayuno WTF': 11,
    'La Parrillada': 12, // Assuming 12 based on directory count
    'Microgreens': 12,
  };
}
