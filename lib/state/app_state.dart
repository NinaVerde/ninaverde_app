// lib/state/app_state.dart
import 'package:flutter/material.dart';
import '../theme/brand_colors.dart' as brand;
import '../services/translation_service.dart';
import '../models/app_config_model.dart';
import '../models/theme_config_model.dart';

/// ---------- Global app state ----------
class AppState extends InheritedWidget {
  final ValueNotifier<ThemeMode> themeMode;

  /// Language code (default: es)
  final ValueNotifier<String> languageCode;

  /// Supported languages and labels
  final ValueNotifier<List<String>> languageOptions;
  final ValueNotifier<Map<String, String>> languageLabels;

  /// Currency toggle: "USD" (default) <-> "NIO"
  final ValueNotifier<String> currencyCode;
  final ValueNotifier<List<String>> currencyOptions;
  final ValueNotifier<Map<String, CurrencyConfig>> currencyConfigs;

  /// Ticker visibility
  final ValueNotifier<bool> showTicker;

  /// Language-aware ticker bulletins
  final ValueNotifier<List<String>> tickerEs;
  final ValueNotifier<List<String>> tickerEn;

  /// Ticker speed (px/s). Baseline ~77.1
  final ValueNotifier<double> tickerSpeedPx;
  
  /// Ticker scroll direction
  final ValueNotifier<TickerDirection> tickerDirection;

  /// Ticker brand colors (lane/orange, rails/brown, text)
  final ValueNotifier<Color> laneLight;
  final ValueNotifier<Color> laneDark;
  final ValueNotifier<Color> railLight;
  final ValueNotifier<Color> railDark;
  final ValueNotifier<Color> textLight;
  final ValueNotifier<Color> textDark;

  /// Gate for ticker settings (long-press)
  final ValueNotifier<bool> isManager;

  /// Carousel Settings
  final ValueNotifier<double> carouselSpeed; // Default ~25s
  final ValueNotifier<bool> carouselAutoPlay;
  final ValueNotifier<CarouselMode> carouselGlobalMode; // Still vs Animated
  final ValueNotifier<List<String>> categoryOrder; // Dynamic order
  final ValueNotifier<Map<String, CategoryConfig>> categoryConfigs;

  /// Angelina Profile Picture Settings
  final ValueNotifier<List<String>> angelinaProfilePics; // List of Firebase Storage URLs
  final ValueNotifier<String?> selectedProfilePic; // Current selected pic URL (null = default)
  final ValueNotifier<bool> profilePicRandomize; // Randomization enabled
  final ValueNotifier<int> profilePicInterval; // Interval in seconds (default 300 = 5 min)

  /// John AI Profile Picture Settings
  final ValueNotifier<List<String>> johnProfilePics;
  final ValueNotifier<String?> selectedJohnProfilePic;
  final ValueNotifier<bool> johnProfilePicRandomize;
  final ValueNotifier<int> johnProfilePicInterval;

  /// Theme Settings
  final ValueNotifier<List<CustomTheme>> availableThemes;
  final ValueNotifier<String> currentThemeId;

  /// Convenience: open the video pop-up
  final void Function(BuildContext ctx) openPip;

  const AppState({
    super.key,
    required this.themeMode,
    required this.languageCode,
    required this.languageOptions,
    required this.languageLabels,
    required this.currencyCode,
    required this.currencyOptions,
    required this.currencyConfigs,
    required this.showTicker,
    required this.tickerEs,
    required this.tickerEn,
    required this.tickerSpeedPx,
    required this.tickerDirection,
    required this.laneLight,
    required this.laneDark,
    required this.railLight,
    required this.railDark,
    required this.textLight,
    required this.textDark,
    required this.availableThemes,
    required this.currentThemeId,
    required this.isManager,
    required this.carouselSpeed,
    required this.carouselAutoPlay,
    required this.carouselGlobalMode,
    required this.categoryOrder,
    required this.categoryConfigs,
    required this.angelinaProfilePics,
    required this.selectedProfilePic,
    required this.profilePicRandomize,
    required this.profilePicInterval,
    required this.johnProfilePics,
    required this.selectedJohnProfilePic,
    required this.johnProfilePicRandomize,
    required this.johnProfilePicInterval,
    required this.openPip,
    required super.child,
  });

  /// Access the AppState. Default to listen: false to prevent assertion errors
  /// during rapid widget tree changes (like login/navigation).
  static AppState of(BuildContext context, {bool listen = false}) {
    if (listen) {
      return context.dependOnInheritedWidgetOfExactType<AppState>()!;
    } else {
      return context.getElementForInheritedWidgetOfExactType<AppState>()!.widget as AppState;
    }
  }

  /// Explicit non-listening read for clarity in initialization or one-off lookups.
  static AppState read(BuildContext context) => 
      context.getElementForInheritedWidgetOfExactType<AppState>()!.widget as AppState;

  Color get nvGreenDark => brand.nvGreenDark;
  Color get nvDarkSurface => brand.nvDarkSurface;

  @override
  bool updateShouldNotify(covariant AppState old) =>
      themeMode != old.themeMode ||
      languageCode != old.languageCode ||
      languageOptions != old.languageOptions ||
      languageLabels != old.languageLabels ||
      currencyCode != old.currencyCode ||
      currencyOptions != old.currencyOptions ||
      currencyConfigs != old.currencyConfigs ||
      showTicker != old.showTicker ||
      tickerEs != old.tickerEs ||
      tickerEn != old.tickerEn ||
      tickerSpeedPx != old.tickerSpeedPx ||
      tickerDirection != old.tickerDirection ||
      laneLight != old.laneLight ||
      laneDark != old.laneDark ||
      railLight != old.railLight ||
      railDark != old.railDark ||
      textLight != old.textLight ||
      textDark != old.textDark ||
      availableThemes != old.availableThemes ||
      currentThemeId != old.currentThemeId ||
      isManager != old.isManager ||
      carouselSpeed != old.carouselSpeed ||
      carouselAutoPlay != old.carouselAutoPlay ||
      carouselGlobalMode != old.carouselGlobalMode ||
      categoryOrder != old.categoryOrder ||
      categoryConfigs != old.categoryConfigs ||
      angelinaProfilePics != old.angelinaProfilePics ||
      selectedProfilePic != old.selectedProfilePic ||
      profilePicRandomize != old.profilePicRandomize ||
      profilePicInterval != old.profilePicInterval ||
      johnProfilePics != old.johnProfilePics ||
      selectedJohnProfilePic != old.selectedJohnProfilePic ||
      johnProfilePicRandomize != old.johnProfilePicRandomize ||
      johnProfilePicInterval != old.johnProfilePicInterval ||
      openPip != old.openPip;
}


enum CarouselMode {
  still,
  animated,
  // 'default' implies falling back to Global setting
}

enum CarouselEffect {
  still,
  scrollSequence,
  stopMotion,
  video,
}

class CategoryConfig {
  final CarouselEffect effect;
  final String? assetPath; // Local asset override
  final String? videoUrl; // For video mode
  final String? folderOverride; // For sequences

  const CategoryConfig({
    this.effect = CarouselEffect.still, 
    this.assetPath,
    this.videoUrl,
    this.folderOverride,
  });

  Map<String, dynamic> toJson() => {
    'effect': effect.index,
    'assetPath': assetPath,
    'videoUrl': videoUrl,
    'folderOverride': folderOverride,
  };

  factory CategoryConfig.fromJson(Map<String, dynamic> json) {
    return CategoryConfig(
      effect: CarouselEffect.values[json['effect'] ?? 0],
      assetPath: json['assetPath'],
      videoUrl: json['videoUrl'],
      folderOverride: json['folderOverride'],
    );
  }
}

String formatCurrency(BuildContext context, double usdAmount) {
  final app = AppState.of(context, listen: false);
  final code = app.currencyCode.value;
  final cfg = app.currencyConfigs.value[code] ??
      app.currencyConfigs.value['USD'] ??
      const CurrencyConfig(code: 'USD', symbol: '\$', rateFromUsd: 1.0);
  final value = usdAmount * cfg.rateFromUsd;
  return '${cfg.symbol}${value.toStringAsFixed(cfg.fractionDigits)}';
}

String tr(BuildContext context, {required String en, required String es}) {
  final isEs = AppState.of(context, listen: false).languageCode.value == 'es';
  // Final safety catch for branding normalize
  final out = isEs ? es : en;
  return out.replaceAll(RegExp(r'Nina Verde', caseSensitive: false), 'Niña Verde');
}

/// A widget that translates its children dynamically based on the current app language.
/// This is used for Firestore data (Products, Events) which is stored in English by standard.
class TranslatedText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const TranslatedText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    // Listen strictly to languageCode changes to trigger rebuilds
    return ValueListenableBuilder<String>(
      valueListenable: AppState.of(context).languageCode,
      builder: (context, language, child) {
        // If it's English, we don't need to translate as per our new storage standard.
        if (language == 'en') {
          return Text(
            text,
            style: style,
            textAlign: textAlign,
            maxLines: maxLines,
            overflow: overflow,
          );
        }

        return FutureBuilder<String>(
          // Create a unified key for the future to prevent unnecessary re-firing if parameters are same
          key: ValueKey('${language}_$text'), 
          future: TranslationService().translate(text, language),
          initialData: text,
          builder: (context, snapshot) {
            final display = snapshot.data ?? text;
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                display,
                key: ValueKey(display),
                style: style,
                textAlign: textAlign,
                maxLines: maxLines,
                overflow: overflow,
              ),
            );
          },
        );
      },
    );
  }
}
