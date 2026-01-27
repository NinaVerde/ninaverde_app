import 'package:flutter/material.dart';

/// Represents a single custom theme definition.
class CustomTheme {
  final String id;
  final String name;
  final bool isDark;
  final Color primaryColor;
  final Color secondaryColor;
  final Color surfaceColor;
  final Color backgroundColor;
  final Color errorColor;
  final Color onPrimary;
  final Color onSurface;

  const CustomTheme({
    required this.id,
    required this.name,
    required this.isDark,
    required this.primaryColor,
    required this.secondaryColor,
    required this.surfaceColor,
    required this.backgroundColor,
    required this.errorColor,
    required this.onPrimary,
    required this.onSurface,
  });

  factory CustomTheme.fromMap(Map<String, dynamic> map) {
    return CustomTheme(
      id: map['id'] ?? 'unknown',
      name: map['name'] ?? 'Unnamed Theme',
      isDark: map['isDark'] ?? false,
      primaryColor: Color(map['primaryColor'] ?? 0xFF4CAF50),
      secondaryColor: Color(map['secondaryColor'] ?? 0xFFF3A70B),
      surfaceColor: Color(map['surfaceColor'] ?? 0xFFFFFFFF),
      backgroundColor: Color(map['backgroundColor'] ?? 0xFFF9FBF9),
      errorColor: Color(map['errorColor'] ?? 0xFFD32F2F),
      onPrimary: Color(map['onPrimary'] ?? 0xFFFFFFFF),
      onSurface: Color(map['onSurface'] ?? 0xFF000000),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'isDark': isDark,
      'primaryColor': primaryColor.value,
      'secondaryColor': secondaryColor.value,
      'surfaceColor': surfaceColor.value,
      'backgroundColor': backgroundColor.value,
      'errorColor': errorColor.value,
      'onPrimary': onPrimary.value,
      'onSurface': onSurface.value,
    };
  }

  ThemeData toThemeData() {
    final colorScheme = isDark
        ? ColorScheme.dark(
            primary: primaryColor,
            secondary: secondaryColor,
            surface: surfaceColor,
            error: errorColor,
            onPrimary: onPrimary,
            onSurface: onSurface,
            brightness: Brightness.dark,
          )
        : ColorScheme.light(
            primary: primaryColor,
            secondary: secondaryColor,
            surface: surfaceColor,
            error: errorColor,
            onPrimary: onPrimary,
            onSurface: onSurface,
            brightness: Brightness.light,
          );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: onSurface),
        titleTextStyle: TextStyle(
          color: onSurface,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Collection of all available themes (defaults + custom).
class AppThemeConfig {
  final List<CustomTheme> customThemes;
  final String defaultLightId;
  final String defaultDarkId;

  const AppThemeConfig({
    this.customThemes = const [],
    this.defaultLightId = 'default_light',
    this.defaultDarkId = 'default_dark',
  });

  factory AppThemeConfig.fromMap(Map<String, dynamic> map) {
    return AppThemeConfig(
      customThemes: (map['customThemes'] as List?)
              ?.map((e) => CustomTheme.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      defaultLightId: map['defaultLightId'] ?? 'default_light',
      defaultDarkId: map['defaultDarkId'] ?? 'default_dark',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customThemes': customThemes.map((e) => e.toMap()).toList(),
      'defaultLightId': defaultLightId,
      'defaultDarkId': defaultDarkId,
    };
  }
}
