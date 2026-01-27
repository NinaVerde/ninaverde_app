import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/theme_config_model.dart';
import '../theme/brand_colors.dart';

class ThemeService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _cfgCol = 'app_config';
  static const String _themesDoc = 'themes';

  /// Default Light Theme (Niña Verde Standard)
  static const CustomTheme defaultLight = CustomTheme(
    id: 'default_light',
    name: 'Niña Verde Light',
    isDark: false,
    primaryColor: nvGreen,
    secondaryColor: nvAccentOrange,
    surfaceColor: Colors.white,
    backgroundColor: Color(0xFFF9FBF9),
    errorColor: Color(0xFFD32F2F),
    onPrimary: Colors.white,
    onSurface: Color(0xFF1E1E1E),
  );

  /// Default Dark Theme (Niña Verde Midnight)
  static const CustomTheme defaultDark = CustomTheme(
    id: 'default_dark',
    name: 'Niña Verde Dark',
    isDark: true,
    primaryColor: nvGreen,
    secondaryColor: nvAccentOrange,
    surfaceColor: nvDarkSurface,
    backgroundColor: Color(0xFF020B08),
    errorColor: Color(0xFFCF6679),
    onPrimary: Colors.white,
    onSurface: Color(0xFFE0E0E0),
  );

  /// Fetch Global Theme Configuration
  static Future<AppThemeConfig> getThemeConfig() async {
    try {
      final doc = await _db.collection(_cfgCol).doc(_themesDoc).get();
      if (!doc.exists || doc.data() == null) {
        return const AppThemeConfig(customThemes: []);
      }
      return AppThemeConfig.fromMap(doc.data()!);
    } catch (e) {
      debugPrint('Error fetching theme config: $e');
      return const AppThemeConfig();
    }
  }

  /// Save Theme Configuration
  static Future<void> saveThemeConfig(AppThemeConfig config) async {
    await _db.collection(_cfgCol).doc(_themesDoc).set(
          config.toMap()..addAll({'updated_at': FieldValue.serverTimestamp()}),
          SetOptions(merge: true),
        );
  }

  /// Helper: Get all available themes (Defaults + Custom)
  static List<CustomTheme> getAllThemes(AppThemeConfig config) {
    return [
      defaultLight,
      defaultDark,
      ...config.customThemes,
    ];
  }
}
