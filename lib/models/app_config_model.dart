// lib/models/app_config_model.dart
import 'package:flutter/material.dart';

/// ---------- Ticker Configuration ----------
class TickerConfig {
  final bool show;
  final List<String> messagesEn;
  final List<String> messagesEs;
  final double speedPx;
  final Color laneLight;
  final Color laneDark;
  final Color railLight;
  final Color railDark;
  final Color textLight;
  final Color textDark;

  const TickerConfig({
    this.show = true,
    this.messagesEn = const [],
    this.messagesEs = const [],
    this.speedPx = 77.1,
    this.laneLight = const Color(0xFFF3A70B),
    this.laneDark = const Color(0xFFF3A70B),
    this.railLight = const Color(0xFFA24011),
    this.railDark = const Color(0xFFA24011),
    this.textLight = Colors.white,
    this.textDark = Colors.white,
  });

  factory TickerConfig.fromMap(Map<String, dynamic> map) {
    return TickerConfig(
      show: map['show'] ?? true,
      messagesEn: (map['messages_en'] as List?)?.cast<String>() ?? [],
      messagesEs: (map['messages_es'] as List?)?.cast<String>() ?? [],
      speedPx: (map['speed_px'] as num?)?.toDouble() ?? 77.1,
      laneLight: _intToColor(map['lane_light'], const Color(0xFFF3A70B)),
      laneDark: _intToColor(map['lane_dark'], const Color(0xFFF3A70B)),
      railLight: _intToColor(map['rail_light'], const Color(0xFFA24011)),
      railDark: _intToColor(map['rail_dark'], const Color(0xFFA24011)),
      textLight: _intToColor(map['text_light'], Colors.white),
      textDark: _intToColor(map['text_dark'], Colors.white),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'show': show,
      'messages_en': messagesEn,
      'messages_es': messagesEs,
      'speed_px': speedPx,
      'lane_light': laneLight.toARGB32(),
      'lane_dark': laneDark.toARGB32(),
      'rail_light': railLight.toARGB32(),
      'rail_dark': railDark.toARGB32(),
      'text_light': textLight.toARGB32(),
      'text_dark': textDark.toARGB32(),
    };
  }

  static Color _intToColor(dynamic v, Color fallback) {
    if (v is int) return Color(v);
    return fallback;
  }
}

/// ---------- Video & Logo Configuration ----------
class VideoLogoConfig {
  final String videoSource; // 'asset', 'url', 'youtube'
  final String? videoUrl;
  final String? videoAsset;
  final String logoSource; // 'asset', 'network'
  final String? logoUrl;
  final String? logoAsset;

  const VideoLogoConfig({
    this.videoSource = 'asset',
    this.videoUrl,
    this.videoAsset = 'assets/videos/Niña Verde Delicia Halada (Baila Conmingo).mp4',
    this.logoSource = 'asset',
    this.logoUrl,
    this.logoAsset = 'assets/images/app_icon_foreground.png',
  });

  factory VideoLogoConfig.fromMap(Map<String, dynamic> map) {
    return VideoLogoConfig(
      videoSource: map['videoSource'] ?? (map['url'] != null ? 'youtube' : 'asset'),
      videoUrl: (map['videoUrl'] ?? map['url'])?.toString(),
      videoAsset: map['videoAsset']?.toString(),
      logoSource: map['logoSource'] ?? (map['logo'] != null ? 'network' : 'asset'),
      logoUrl: (map['logoUrl'] ?? map['logo'])?.toString(),
      logoAsset: map['logoAsset']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'videoSource': videoSource,
      'videoUrl': videoUrl,
      'videoAsset': videoAsset,
      'logoSource': logoSource,
      'logoUrl': logoUrl,
      'logoAsset': logoAsset,
    };
  }
}

/// ---------- Localization Configuration ----------
class AppLocalizationConfig {
  final List<String> languages;
  final Map<String, String> languageLabels;
  final String defaultLanguage;
  final String defaultCurrency;
  final List<String> currencies;
  final Map<String, dynamic> currencyConfigs;

  const AppLocalizationConfig({
    this.languages = const ['es', 'en'],
    this.languageLabels = const {'es': 'ES', 'en': 'EN'},
    this.defaultLanguage = 'es',
    this.defaultCurrency = 'USD',
    this.currencies = const ['USD', 'NIO'],
    this.currencyConfigs = const {},
  });

  factory AppLocalizationConfig.fromMap(Map<String, dynamic> map) {
    return AppLocalizationConfig(
      languages: (map['languages'] as List?)?.cast<String>() ?? ['es', 'en'],
      languageLabels: (map['languageLabels'] as Map?)?.cast<String, String>() ?? {'es': 'ES', 'en': 'EN'},
      defaultLanguage: map['defaultLanguage'] ?? 'es',
      defaultCurrency: map['defaultCurrency'] ?? 'USD',
      currencies: (map['currencies'] as List?)?.cast<String>() ?? ['USD', 'NIO'],
      currencyConfigs: (map['currencyConfigs'] as Map?)?.cast<String, dynamic>() ?? {},
    );
  }

  AppLocalizationConfig copyWith({
    List<String>? languages,
    Map<String, String>? languageLabels,
    String? defaultLanguage,
    String? defaultCurrency,
    List<String>? currencies,
    Map<String, dynamic>? currencyConfigs,
  }) {
    return AppLocalizationConfig(
      languages: languages ?? this.languages,
      languageLabels: languageLabels ?? this.languageLabels,
      defaultLanguage: defaultLanguage ?? this.defaultLanguage,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      currencies: currencies ?? this.currencies,
      currencyConfigs: currencyConfigs ?? this.currencyConfigs,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'languages': languages,
      'languageLabels': languageLabels,
      'defaultLanguage': defaultLanguage,
      'defaultCurrency': defaultCurrency,
      'currencies': currencies,
      'currencyConfigs': currencyConfigs,
    };
  }
}
