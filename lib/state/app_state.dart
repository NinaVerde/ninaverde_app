// lib/state/app_state.dart
import 'package:flutter/material.dart';
import '../theme/brand_colors.dart' as brand;

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

  /// Ticker brand colors (lane/orange, rails/brown, text)
  final ValueNotifier<Color> laneLight;
  final ValueNotifier<Color> laneDark;
  final ValueNotifier<Color> railLight;
  final ValueNotifier<Color> railDark;
  final ValueNotifier<Color> textLight;
  final ValueNotifier<Color> textDark;

  /// Gate for ticker settings (long-press)
  final ValueNotifier<bool> isManager;

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
    required this.laneLight,
    required this.laneDark,
    required this.railLight,
    required this.railDark,
    required this.textLight,
    required this.textDark,
    required this.isManager,
    required this.openPip,
    required super.child,
  });

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppState>()!;

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
      laneLight != old.laneLight ||
      laneDark != old.laneDark ||
      railLight != old.railLight ||
      railDark != old.railDark ||
      textLight != old.textLight ||
      textDark != old.textDark ||
      isManager != old.isManager ||
      openPip != old.openPip;
}

class CurrencyConfig {
  final String code;
  final String symbol;
  final double rateFromUsd;
  final int fractionDigits;

  const CurrencyConfig({
    required this.code,
    required this.symbol,
    required this.rateFromUsd,
    this.fractionDigits = 2,
  });
}

String formatCurrency(BuildContext context, double usdAmount) {
  final app = AppState.of(context);
  final code = app.currencyCode.value;
  final cfg = app.currencyConfigs.value[code] ??
      app.currencyConfigs.value['USD'] ??
      const CurrencyConfig(code: 'USD', symbol: '\$', rateFromUsd: 1.0);
  final value = usdAmount * cfg.rateFromUsd;
  return '${cfg.symbol}${value.toStringAsFixed(cfg.fractionDigits)}';
}

String tr(BuildContext context, {required String en, required String es}) {
  final isEs = AppState.of(context).languageCode.value == 'es';
  return isEs ? es : en;
}
