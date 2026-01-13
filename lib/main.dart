// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

// WebView (universal, with per-platform creation params)
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'firebase_options.dart';

// Screens (disambiguate imports with `show`)
import 'screens/login_screen.dart' show LoginScreen;
import 'screens/home_screen.dart' show HomeScreen;
import 'screens/cart_screen.dart' show CartScreen;
import 'screens/splash_to_login.dart' show SplashToLoginScreen; // boot splash
import 'screens/document_webview.dart'
    show DocumentWebView; // standalone WebView screen
import 'screens/contact_nina_verde_page.dart'
    show ContactNinaVerdePage; // <-- NEW: AI Contact page
import 'screens/angelina_admin_screen.dart'
    show AngelinaAdminScreen;
import 'screens/owner_dashboard_screen.dart'
    show OwnerDashboardScreen;
import 'screens/app_settings_admin_screen.dart'
    show AppSettingsAdminScreen;
import 'screens/reviews_admin_screen.dart'
    show ReviewsAdminScreen;
import 'screens/favorites_admin_screen.dart'
    show FavoritesAdminScreen;
import 'screens/catalog_admin_screen.dart'
    show CatalogAdminScreen;
import 'screens/event_promo_admin_screen.dart'
    show EventPromoAdminScreen;
import 'screens/rewards_admin_screen.dart'
    show RewardsAdminScreen;
import 'screens/notification_preferences_screen.dart'
    show NotificationPreferencesScreen;
import 'screens/leads_admin_screen.dart'
    show LeadsAdminScreen;
import 'screens/comms_campaigns_screen.dart'
    show CommsCampaignsScreen;
import 'screens/comms_settings_admin_screen.dart'
    show CommsSettingsAdminScreen;
import 'screens/kids_zone_screen.dart' show KidsZoneScreen;
import 'screens/kids/coloring_sandbox_screen.dart'
    show ColoringSandboxScreen;
import 'screens/kids/slider_puzzle_screen.dart' show SliderPuzzleScreen;
import 'screens/kids/maze_runner_screen.dart' show MazeRunnerScreen;
import 'screens/kids/memory_match_screen.dart' show MemoryMatchScreen;
import 'screens/intro_settings_screen.dart' show IntroSettingsScreen;
import 'providers/cart_provider.dart';
import 'theme/brand_colors.dart' as brand;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Enforce logout on every fresh app start
  try {
    await FirebaseAuth.instance.signOut();
  } catch (_) {
    // Ignore sign-out errors on startup
  }

  // Keep local cache so values survive flaky network / quick restarts
  FirebaseFirestore.instance.settings =
      const Settings(persistenceEnabled: true);

  runApp(
    ChangeNotifierProvider(
      create: (_) => CartProvider(),
      child: const NinaVerdeApp(),
    ),
  );
}

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

class NinaVerdeApp extends StatefulWidget {
  const NinaVerdeApp({super.key});
  @override
  State<NinaVerdeApp> createState() => _NinaVerdeAppState();
}

class _NinaVerdeAppState extends State<NinaVerdeApp> {
  final themeMode = ValueNotifier<ThemeMode>(ThemeMode.light);
  final languageCode = ValueNotifier<String>('es');
  final languageOptions = ValueNotifier<List<String>>(['es', 'en']);
  final languageLabels = ValueNotifier<Map<String, String>>({
    'es': 'Espanol',
    'en': 'English',
  });
  final currencyCode = ValueNotifier<String>('USD');
  final currencyOptions = ValueNotifier<List<String>>(['USD', 'NIO']);
  final currencyConfigs = ValueNotifier<Map<String, CurrencyConfig>>({
    'USD': const CurrencyConfig(
      code: 'USD',
      symbol: '\$',
      rateFromUsd: 1.0,
    ),
    'NIO': const CurrencyConfig(
      code: 'NIO',
      symbol: 'C\$',
      rateFromUsd: 36.5,
    ),
  });
  final showTicker = ValueNotifier<bool>(true);

  // ----- Default messages (EN) -----
  static List<String> _defaultsEn() => const [
        "Naturally, welcome to Nicaragua Niña Verde!",
        "Log in to collect NV Coins.",
        "Get exclusive offers.",
        "Earn NV Coins.",
        "Enjoy free services.",
        "Tune into the best entertainment.",
        "Engage the community.",
        "Catch the _VYBZ!_",
        "Come for the food, stay for the _VYBZ!_",
      ];

  static List<String> _defaultsEsFromEn(List<String> en) {
    String tr(String s) {
      return s
          .replaceAll("Naturally, welcome to Nicaragua Niña Verde!",
              "Naturalmente, ¡Bienvenido a Nicaragua Niña Verde!")
          .replaceAll(
              "Log in to collect NV Coins.", "Inicia sesion para ganar Monedas NV.")
          .replaceAll("Get exclusive offers.", "Obtén ofertas exclusivas.")
          .replaceAll("Earn NV Coins.", "Gana Monedas NV.")
          .replaceAll("Enjoy free services.", "Disfruta servicios gratis.")
          .replaceAll("Tune into the best entertainment.",
              "Sintoniza el mejor entretenimiento.")
          .replaceAll("Engage the community.", "Participa en la comunidad.")
          .replaceAll("Catch the _VYBZ!_", "¡Atrapa el _VYBZ!_")
          .replaceAll("Come for the food, stay for the _VYBZ!_",
              "Ven por la comida, quédate por el _VYBZ!_");
    }

    return en.map(tr).toList();
  }

  // Language-aware messages
  late final ValueNotifier<List<String>> tickerEn =
      ValueNotifier<List<String>>(_defaultsEn());
  late final ValueNotifier<List<String>> tickerEs =
      ValueNotifier<List<String>>(_defaultsEsFromEn(tickerEn.value));

  // Speed (px/s).
  final tickerSpeedPx = ValueNotifier<double>(77.1);

  // Brand colors (edit in settings).
  final laneLight = ValueNotifier<Color>(const Color(0xFFF3A70B)); // orange
  final laneDark = ValueNotifier<Color>(const Color(0xFFF3A70B));
  final railLight = ValueNotifier<Color>(const Color(0xFFA24011)); // brown-red
  final railDark = ValueNotifier<Color>(const Color(0xFFA24011));
  final textLight = ValueNotifier<Color>(Colors.white);
  final textDark = ValueNotifier<Color>(Colors.white);

  final isManager = ValueNotifier<bool>(false);
  StreamSubscription? _authSub;
  StreamSubscription? _userSub;

  // --------- Firestore persistence ----------
  static const _cfgCol = 'app_config';
  static const _tickerDoc = 'ticker';
  static const _localeDoc = 'localization';

  static DocumentReference<Map<String, dynamic>> _tickerRef() =>
      FirebaseFirestore.instance.collection(_cfgCol).doc(_tickerDoc);
  static DocumentReference<Map<String, dynamic>> _localeRef() =>
      FirebaseFirestore.instance.collection(_cfgCol).doc(_localeDoc);

  @override
  void initState() {
    super.initState();
    _loadTickerSettings();
    _loadLocalizationSettings();
    _listenToAuth();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _userSub?.cancel();
    super.dispose();
  }

  void _listenToAuth() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      _userSub?.cancel();
      if (user == null) {
        isManager.value = false;
      } else {
        _userSub = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots()
            .listen((snap) {
          final data = snap.data();
          if (data != null) {
            final admin = data['isAdmin'] == true ||
                (data['role'] as String?)?.toLowerCase() == 'admin';
            isManager.value = admin;
          } else {
            isManager.value = false;
          }
        });
      }
    });
  }

  static int _colorToInt(Color c) => c.toARGB32();
  static Color _intToColor(int v) => Color(v);

  Future<void> _loadTickerSettings() async {
    try {
      final doc = await _tickerRef().get();
      if (!doc.exists) return;

      final d = doc.data()!;
      showTicker.value = (d['show'] as bool?) ?? showTicker.value;
      tickerSpeedPx.value =
          (d['speed_px'] as num?)?.toDouble() ?? tickerSpeedPx.value;

      final es = (d['messages_es'] as List?)?.cast<String>();
      final en = (d['messages_en'] as List?)?.cast<String>();
      if (en != null && en.isNotEmpty) {
        tickerEn.value = List<String>.from(en);
      }
      if (es != null && es.isNotEmpty) {
        tickerEs.value = List<String>.from(es);
      } else if (en != null && en.isNotEmpty) {
        tickerEs.value = _defaultsEsFromEn(List<String>.from(en));
      }

      final ll = d['lane_light'] as int?;
      final ld = d['lane_dark'] as int?;
      final rl = d['rail_light'] as int?;
      final rd = d['rail_dark'] as int?;
      final tl = d['text_light'] as int?;
      final td = d['text_dark'] as int?;
      if (ll != null) laneLight.value = _intToColor(ll);
      if (ld != null) laneDark.value = _intToColor(ld);
      if (rl != null) railLight.value = _intToColor(rl);
      if (rd != null) railDark.value = _intToColor(rd);
      if (tl != null) textLight.value = _intToColor(tl);
      if (td != null) textDark.value = _intToColor(td);
    } catch (_) {
      // Silent fallback to defaults
    }
  }

  Future<void> _loadLocalizationSettings() async {
    try {
      final doc = await _localeRef().get();
      if (!doc.exists) return;
      final data = doc.data()!;

      final langs = (data['languages'] as List?)?.cast<String>();
      final labels = (data['languageLabels'] as Map?)?.cast<String, String>();
      if (langs != null && langs.isNotEmpty) {
        languageOptions.value = List<String>.from(langs);
      }
      if (labels != null && labels.isNotEmpty) {
        languageLabels.value = Map<String, String>.from(labels);
      }
      if (data['defaultLanguage'] is String) {
        languageCode.value = data['defaultLanguage'] as String;
      }
      if (!languageOptions.value.contains(languageCode.value) &&
          languageOptions.value.isNotEmpty) {
        languageCode.value = languageOptions.value.first;
      }

      final currencies = (data['currencies'] as List?)?.cast<String>();
      final cfgs = data['currencyConfigs'] as Map?;
      if (currencies != null && currencies.isNotEmpty) {
        currencyOptions.value = List<String>.from(currencies);
      }
      if (cfgs != null) {
        final out = <String, CurrencyConfig>{};
        cfgs.forEach((key, value) {
          if (key is! String || value is! Map) return;
          final map = value.cast<String, dynamic>();
          out[key] = CurrencyConfig(
            code: key,
            symbol: (map['symbol'] as String?) ?? key,
            rateFromUsd: (map['rateFromUsd'] as num?)?.toDouble() ?? 1.0,
            fractionDigits: (map['fractionDigits'] as num?)?.toInt() ?? 2,
          );
        });
        if (out.isNotEmpty) {
          currencyConfigs.value = out;
        }
      }
      if (data['defaultCurrency'] is String) {
        currencyCode.value = data['defaultCurrency'] as String;
      }
      if (!currencyOptions.value.contains(currencyCode.value) &&
          currencyOptions.value.isNotEmpty) {
        currencyCode.value = currencyOptions.value.first;
      }
    } catch (_) {
      // Silent fallback to defaults
    }
  }

  static Future<void> saveTickerSettings({
    required bool show,
    required List<String> es,
    required List<String> en,
    required double speedPx,
    required Color laneLight,
    required Color laneDark,
    required Color railLight,
    required Color railDark,
    required Color textLight,
    required Color textDark,
  }) async {
    await _tickerRef().set({
      'show': show,
      'messages_es': es,
      'messages_en': en,
      'speed_px': speedPx,
      'lane_light': _colorToInt(laneLight),
      'lane_dark': _colorToInt(laneDark),
      'rail_light': _colorToInt(railLight),
      'rail_dark': _colorToInt(railDark),
      'text_light': _colorToInt(textLight),
      'text_dark': _colorToInt(textDark),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ===== Route-based pop-up (fresh WebView session every time) =====
  void _openPip(BuildContext ctx) {
    final nowKey = UniqueKey(); // ensures the entire popup subtree is fresh
    Navigator.of(ctx).push(
      PageRouteBuilder(
        opaque: false,
        maintainState: false, // ensure full teardown on pop
        barrierDismissible: true,
        barrierColor: Colors.black54,
        settings: RouteSettings(
          name: 'yt_${DateTime.now().microsecondsSinceEpoch}',
          arguments: nowKey,
        ),
        pageBuilder: (context, _, __) => _YouTubePopupWebView(
          key: nowKey,
          videoId: 'ZczKlWNp5qY',
        ),
        transitionsBuilder: (context, anim, _, child) {
          final curved =
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }
  // =====================

  @override
  Widget build(BuildContext context) {
    return AppState(
      themeMode: themeMode,
      languageCode: languageCode,
      languageOptions: languageOptions,
      languageLabels: languageLabels,
      currencyCode: currencyCode,
      currencyOptions: currencyOptions,
      currencyConfigs: currencyConfigs,
      showTicker: showTicker,
      tickerEs: tickerEs,
      tickerEn: tickerEn,
      tickerSpeedPx: tickerSpeedPx,
      laneLight: laneLight,
      laneDark: laneDark,
      railLight: railLight,
      railDark: railDark,
      textLight: textLight,
      textDark: textDark,
      isManager: isManager,
      openPip: _openPip,
      child: ValueListenableBuilder<String>(
        valueListenable: languageCode,
        builder: (_, __, ___) => ValueListenableBuilder<String>(
          valueListenable: currencyCode,
          builder: (_, __, ___) => ValueListenableBuilder<ThemeMode>(
            valueListenable: themeMode,
            builder: (context, mode, _) {
              return MaterialApp(
                title: 'Niña Verde',
                debugShowCheckedModeBanner: false,
                themeMode: mode,
                theme: ThemeData(
                  useMaterial3: true,
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: brand.nvGreenDark,
                    surface: const Color(0xFFE9F6E9),
                  ),
                  appBarTheme: const AppBarTheme(centerTitle: true),
                ),
                darkTheme: ThemeData(
                  useMaterial3: true,
                  brightness: Brightness.dark,
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: brand.nvGreenDark,
                    brightness: Brightness.dark,
                    surface: brand.nvDarkSurface,
                  ),
                  scaffoldBackgroundColor: brand.nvGreenDark,
                  appBarTheme: const AppBarTheme(
                    backgroundColor: brand.nvGreenDark,
                    centerTitle: true,
                  ),
                ),
                routes: {
                  '/': (_) => const SplashToLoginScreen(),
                  '/splash': (_) => const SplashToLoginScreen(),
                  '/login': (_) =>
                      LoginScreen(), // non-const for dynamic logo/video
                  '/home': (_) => const HomeScreen(),
                  '/cart': (_) => const CartScreen(),
                  '/kids': (_) => const KidsZoneScreen(),
                  '/kids/coloring': (_) => const ColoringSandboxScreen(),
                  '/kids/puzzle': (_) => const SliderPuzzleScreen(),
                  '/kids/maze': (_) => const MazeRunnerScreen(),
                  '/kids/memory': (_) => const MemoryMatchScreen(),
                  '/forgot': (_) => const PlaceholderPage(
                        titleEn: 'Forgot Password',
                        titleEs: 'Olvide mi contrasena',
                      ),
                  '/register': (_) => const PlaceholderPage(
                        titleEn: 'Register',
                        titleEs: 'Registro',
                      ),
                  '/contact': (_) =>
                      const ContactNinaVerdePage(), // <-- AI contact page
                  '/angelina-admin': (_) => const AngelinaAdminScreen(),
                  '/app-settings': (_) => const OwnerDashboardScreen(),
                  '/app-settings/localization': (_) =>
                      const AppSettingsAdminScreen(),
                  '/app-settings/reviews': (_) => const ReviewsAdminScreen(),
                  '/app-settings/favorites': (_) => const FavoritesAdminScreen(),
                  '/app-settings/catalog': (_) => const CatalogAdminScreen(),
                  '/app-settings/events': (_) => const EventPromoAdminScreen(),
                  '/app-settings/rewards': (_) => const RewardsAdminScreen(),
                  '/preferences/notifications': (_) =>
                      const NotificationPreferencesScreen(),
                  '/app-settings/leads': (_) => const LeadsAdminScreen(),
                  '/app-settings/campaigns': (_) => const CommsCampaignsScreen(),
                  '/app-settings/comms-settings': (_) =>
                      const CommsSettingsAdminScreen(),
                  '/app-settings/intro': (_) => const IntroSettingsScreen(),
                  '/privacy': (_) => const DocumentWebView(
                        titleEs: 'Politica de Privacidad',
                        titleEn: 'Privacy Policy',
                        assetEs: 'assets/legal/privacy-policy.es.html',
                        assetEn: 'assets/legal/privacy-policy.en.html',
                      ),
                  '/data-deletion': (_) => const DocumentWebView(
                        titleEs: 'Eliminacion de Datos',
                        titleEn: 'Data Deletion',
                        assetEs: 'assets/legal/data-deletion.es.html',
                        assetEn: 'assets/legal/data-deletion.en.html',
                      ),
                  '/language-settings': (_) => const LanguageSettingsPage(),
                  '/currency-settings': (_) => const CurrencySettingsPage(),
                  '/ticker-settings': (_) => const TickerSettingsPage(),
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

/// ---------- AppBar with ticker in bottom ----------
class NvAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool centerTitle;
  final bool showBack;
  final List<Widget> extraActions;
  const NvAppBar({
    super.key,
    required this.title,
    this.centerTitle = true,
    this.showBack = false,
    this.extraActions = const [],
  });

  static const double tickerHeight = 54;

  @override
  Size get preferredSize =>
      const Size.fromHeight(kToolbarHeight + tickerHeight);

  List<String> _messages(AppState app) {
    final isEs = app.languageCode.value == 'es';
    return List<String>.from(isEs ? app.tickerEs.value : app.tickerEn.value);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.of(context);

    final laneColor = (Theme.of(context).brightness == Brightness.dark)
        ? app.laneDark.value
        : app.laneLight.value;
    final railColor = (Theme.of(context).brightness == Brightness.dark)
        ? app.railDark.value
        : app.railLight.value;
    final textColor = (Theme.of(context).brightness == Brightness.dark)
        ? app.textDark.value
        : app.textLight.value;

    // Ensure "Niña Verde - " prefix exactly once
    String visibleTitle = title.replaceFirst('Nicaragua ', '');
    final normalized = visibleTitle.toLowerCase();
    
    // Check for existing prefixes (case-insensitive)
    final bool hasCorrectPrefix = normalized.startsWith('niña verde -') || 
                                  normalized.startsWith('niña verde-');
    final bool hasIncorrectPrefix = normalized.startsWith('nina verde -') || 
                                    normalized.startsWith('nina verde-');

    if (hasIncorrectPrefix) {
      // Replace the incorrect "Nina Verde" with "Niña Verde"
      if (normalized.startsWith('nina verde -')) {
        visibleTitle = visibleTitle.replaceFirst(RegExp(r'nina verde -', caseSensitive: false), 'Niña Verde -');
      } else {
        visibleTitle = visibleTitle.replaceFirst(RegExp(r'nina verde-', caseSensitive: false), 'Niña Verde-');
      }
    } else if (!hasCorrectPrefix) {
      // Prepend "Niña Verde - " if no prefix exists
      visibleTitle = 'Niña Verde - $visibleTitle';
    }

    return AppBar(
      title: Text(
        visibleTitle,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      centerTitle: centerTitle,
      automaticallyImplyLeading: showBack,
      actions: [
        ...extraActions,
        const NvLanguageToggle(),
        const NvCurrencyToggle(),
        const NvThemeToggle(),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(tickerHeight),
        child: ValueListenableBuilder<bool>(
          valueListenable: app.showTicker,
          builder: (_, show, __) {
            final msgs = _messages(app);
            if (!show || msgs.isEmpty) {
              return GestureDetector(
                onLongPress: () {
                  if (app.isManager.value) {
                    Navigator.pushNamed(context, '/app-settings');
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          tr(
                            context,
                            en: 'Insufficient permissions',
                            es: 'Permisos insuficientes',
                          ),
                        ),
                      ),
                    );
                  }
                },
                child: const SizedBox(height: tickerHeight),
              );
            }
            return ValueListenableBuilder<double>(
              valueListenable: app.tickerSpeedPx,
              builder: (_, spx, __) => _TickerBand(
                height: tickerHeight,
                laneColor: laneColor,
                railColor: railColor,
                textColor: textColor,
                messages: msgs,
                speedPxPerSec: spx,
                onLongPress: () {
                  if (app.isManager.value) {
                    Navigator.pushNamed(context, '/app-settings');
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          tr(
                            context,
                            en: 'Insufficient permissions',
                            es: 'Permisos insuficientes',
                          ),
                        ),
                      ),
                    );
                  }
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class NvLanguageToggle extends StatelessWidget {
  const NvLanguageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppState.of(context);
    return ValueListenableBuilder<List<String>>(
      valueListenable: app.languageOptions,
      builder: (_, options, __) => ValueListenableBuilder<Map<String, String>>(
        valueListenable: app.languageLabels,
        builder: (_, labels, __) => ValueListenableBuilder<String>(
          valueListenable: app.languageCode,
          builder: (_, code, __) {
            final label = labels[code] ??
                (code.isNotEmpty ? code.toUpperCase() : 'LANG');
            final next = options.isEmpty
                ? code
                : options[(options.indexOf(code) + 1) % options.length];
            return IconButton(
              tooltip: tr(context, en: 'Language', es: 'Idioma'),
              onPressed: () => app.languageCode.value = next,
              onLongPress: () =>
                  Navigator.pushNamed(context, '/language-settings'),
              icon: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            );
          },
        ),
      ),
    );
  }
}

class NvCurrencyToggle extends StatelessWidget {
  const NvCurrencyToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppState.of(context);
    return ValueListenableBuilder<List<String>>(
      valueListenable: app.currencyOptions,
      builder: (_, options, __) => ValueListenableBuilder<String>(
        valueListenable: app.currencyCode,
        builder: (_, code, __) {
          final next = options.isEmpty
              ? code
              : options[(options.indexOf(code) + 1) % options.length];
          return IconButton(
            tooltip: tr(context, en: 'Currency', es: 'Moneda'),
            onPressed: () => app.currencyCode.value = next,
            onLongPress: () =>
                Navigator.pushNamed(context, '/currency-settings'),
            icon:
                Text(code, style: const TextStyle(fontWeight: FontWeight.bold)),
          );
        },
      ),
    );
  }
}

class NvThemeToggle extends StatelessWidget {
  const NvThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppState.of(context);
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: app.themeMode,
      builder: (_, mode, __) {
        final isDark = mode == ThemeMode.dark;
        return IconButton(
          tooltip: tr(
            context,
            en: isDark ? 'Light' : 'Dark',
            es: isDark ? 'Claro' : 'Oscuro',
          ),
          onPressed: () => app.themeMode.value =
              isDark ? ThemeMode.light : ThemeMode.dark,
          icon: Icon(
            isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          ),
        );
      },
    );
  }
}

class NvInlineToggles extends StatelessWidget {
  const NvInlineToggles({super.key, this.spacing = 4});

  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const NvLanguageToggle(),
        SizedBox(width: spacing),
        const NvCurrencyToggle(),
        SizedBox(width: spacing),
        const NvThemeToggle(),
      ],
    );
  }
}

/// ---------- Ultra-simple ticker with perfect loop spacing ----------
class _TickerBand extends StatefulWidget {
  final List<String> messages;
  final double speedPxPerSec; // pixels per second
  final double height;
  final Color laneColor;
  final Color railColor;
  final Color textColor;
  final VoidCallback? onLongPress;

  const _TickerBand({
    required this.messages,
    required this.speedPxPerSec,
    required this.height,
    required this.laneColor,
    required this.railColor,
    required this.textColor,
    this.onLongPress,
  });

  @override
  State<_TickerBand> createState() => _TickerBandState();
}

class _TickerBandState extends State<_TickerBand>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl; // bounded; drives 0..1
  Duration _period = const Duration(seconds: 20);
  double _contentWidth = 400; // safe default > 0
  late String _joined; // duplicated sequence with symmetrical separators
  static const _sep = '     •     ';

  // Rails + lane proportions
  static const double _brownTopFrac = 0.09;
  static const double _brownBottomFrac = 0.09;
  static const double _orangePadV = 9.0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this);
    _recalcAndStart();
  }

  @override
  void didUpdateWidget(covariant _TickerBand oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messages != widget.messages ||
        oldWidget.speedPxPerSec != widget.speedPxPerSec ||
        oldWidget.height != widget.height ||
        oldWidget.textColor != widget.textColor) {
      _recalcAndStart();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  InlineSpan _richSpan(String txt) {
    final base = TextStyle(
      fontWeight: FontWeight.w700,
      color: widget.textColor,
      letterSpacing: 0.2,
      fontSize: 16,
      height: 1.25,
    );

    final parts = txt.split('_VYBZ!_');
    return TextSpan(children: [
      for (int i = 0; i < parts.length; i++) ...[
        if (parts[i].isNotEmpty) TextSpan(text: parts[i], style: base),
        if (i < parts.length - 1)
          TextSpan(
            text: 'VYBZ!',
            style: base.copyWith(
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w800,
              shadows: const [Shadow(color: Colors.white70, blurRadius: 6)],
            ),
          ),
      ],
    ]);
  }

  void _recalcAndStart() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final msgs = widget.messages.where((m) => m.trim().isNotEmpty).toList();
      final base = (msgs.isEmpty ? [''] : msgs).join(_sep);

      _joined = '$_sep$base$_sep';

      final tp = TextPainter(
        text: TextSpan(children: [_richSpan(_joined)]),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 1,
        textWidthBasis: TextWidthBasis.longestLine,
      )..layout();
      final w = tp.width;
      _contentWidth = (w.isFinite && w > 1) ? w : 400;

      final seconds =
          (_contentWidth / widget.speedPxPerSec).clamp(8, 1200).toDouble();
      _period = Duration(milliseconds: (seconds * 1000).round());

      _ctrl
        ..stop()
        ..reset()
        ..repeat(period: _period);

      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final tickerOn = TickerMode.of(context);
    if (!tickerOn && _ctrl.isAnimating) _ctrl.stop();
    if (tickerOn && !_ctrl.isAnimating) {
      _ctrl.repeat(period: _period);
    }

    final topH = widget.height * _brownTopFrac;
    final botH = widget.height * _brownBottomFrac;

    return GestureDetector(
      onLongPress: widget.onLongPress,
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Column(
          children: [
            Container(
                height: topH, width: double.infinity, color: widget.railColor),
            Expanded(
              child: Container(
                width: double.infinity,
                color: widget.laneColor,
                padding: const EdgeInsets.symmetric(vertical: _orangePadV),
                child: ClipRect(
                  child: AnimatedBuilder(
                    animation: _ctrl,
                    builder: (_, __) {
                      final dx =
                          -((_ctrl.value * _contentWidth) % _contentWidth);

                      final rich = RichText(
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.visible,
                        textWidthBasis: TextWidthBasis.longestLine,
                        textAlign: TextAlign.center,
                        strutStyle: const StrutStyle(
                          fontSize: 16,
                          height: 1.25,
                          forceStrutHeight: true,
                        ),
                        text: _richSpan(_joined),
                      );

                      Widget copy(double x) => Transform(
                            transform: Matrix4.translationValues(x, 0, 0),
                            child: SizedBox(
                              width: _contentWidth,
                              child: Center(
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 1.0),
                                  child: rich,
                                ),
                              ),
                            ),
                          );

                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Stack(
                          children: [
                            copy(dx),
                            copy(dx + _contentWidth),
                            copy(dx + _contentWidth * 2),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            Container(
                height: botH, width: double.infinity, color: widget.railColor),
          ],
        ),
      ),
    );
  }
}

/// ---------- Placeholder ----------
class PlaceholderPage extends StatelessWidget {
  final String titleEn;
  final String titleEs;
  const PlaceholderPage({
    super.key,
    required this.titleEn,
    required this.titleEs,
  });

  @override
  Widget build(BuildContext context) {
    final title = tr(context, en: titleEn, es: titleEs);
    return Scaffold(
      appBar: NvAppBar(title: title, showBack: true),
      body: Center(
        child: Text(
          tr(
            context,
            en: '$title - placeholder screen',
            es: '$title - pantalla en construccion',
          ),
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }
}

/// ---------- Language Settings ----------
class LanguageSettingsPage extends StatelessWidget {
  const LanguageSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppState.of(context);
    return ValueListenableBuilder<String>(
      valueListenable: app.languageCode,
      builder: (_, __, ___) {
        final title = tr(
          context,
          en: 'Language Settings',
          es: 'Configuracion de idiomas',
        );
        return Scaffold(
          appBar: NvAppBar(title: title, showBack: true),
          body: ValueListenableBuilder<List<String>>(
            valueListenable: app.languageOptions,
            builder: (context, options, _) {
              return ValueListenableBuilder<Map<String, String>>(
                valueListenable: app.languageLabels,
                builder: (context, labels, _) {
                  return ValueListenableBuilder<String>(
                    valueListenable: app.languageCode,
                    builder: (context, code, _) {
                      return RadioGroup<String>(
                        groupValue: code,
                        onChanged: (value) {
                          if (value != null) {
                            app.languageCode.value = value;
                          }
                        },
                        child: ListView(
                          children: options.map((lang) {
                            final label = labels[lang] ?? lang.toUpperCase();
                            return RadioListTile<String>(
                              value: lang,
                              title: Text(label),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

/// ---------- Currency Settings ----------
class CurrencySettingsPage extends StatelessWidget {
  const CurrencySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppState.of(context);
    return ValueListenableBuilder<String>(
      valueListenable: app.languageCode,
      builder: (_, __, ___) {
        final title = tr(
          context,
          en: 'Currency Settings',
          es: 'Configuracion de monedas',
        );
        return Scaffold(
          appBar: NvAppBar(title: title, showBack: true),
          body: ValueListenableBuilder<List<String>>(
            valueListenable: app.currencyOptions,
            builder: (context, options, _) {
              return ValueListenableBuilder<Map<String, CurrencyConfig>>(
                valueListenable: app.currencyConfigs,
                builder: (context, configs, _) {
                  return ValueListenableBuilder<String>(
                    valueListenable: app.currencyCode,
                    builder: (context, currency, _) {
                      final rateLabel = tr(context, en: 'rate', es: 'tasa');
                      return RadioGroup<String>(
                        groupValue: currency,
                        onChanged: (value) {
                          if (value != null) {
                            app.currencyCode.value = value;
                          }
                        },
                        child: ListView(
                          children: options.map((code) {
                            final cfg = configs[code];
                            final label = cfg == null
                                ? code
                                : '${cfg.code} - ${cfg.symbol} ($rateLabel ${cfg.rateFromUsd.toStringAsFixed(2)})';
                            return RadioListTile<String>(
                              value: code,
                              title: Text(label),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

/// ---------- Ticker Settings (paired EN/ES with auto-translate & auto-fix) ----------
class TickerSettingsPage extends StatefulWidget {
  const TickerSettingsPage({super.key});

  @override
  State<TickerSettingsPage> createState() => _TickerSettingsPageState();
}

class MessagePair {
  String en;
  String es;
  MessagePair({this.en = '', this.es = ''});
}

class _TickerSettingsPageState extends State<TickerSettingsPage>
    with TickerProviderStateMixin {
  // Local working copies so Cancel can discard changes
  late bool _showLocal;
  late double _speedLocal;

  late Color _laneLightLocal, _laneDarkLocal, _railLightLocal, _railDarkLocal;
  late Color _textLightLocal, _textDarkLocal;

  // Editor language selector (decoupled from global language)
  late bool _editingSpanish;

  /// List of paired messages (kept aligned 1:1)
  late List<MessagePair> _pairs;

  /// Stable keys for reorderable list
  late List<int> _ids;
  int _nextId = 0;

  // --- Tiny bilingual dictionary (extend freely) ---
  static const Map<String, String> _enToEs = {
    'hi': 'hola',
    'hello': 'hola',
    'cat': 'gato',
    'dog': 'perro',
    'earn nv coins.': 'gana monedas nv.',
    'get exclusive offers.': 'obten ofertas exclusivas.',
    'login to collect nv coins.': 'inicia sesion para ganar monedas nv.',
    'enjoy free services.': 'disfruta servicios gratis.',
    'tune into the best entertainment.': 'sintoniza el mejor entretenimiento.',
    'engage the community.': 'participa en la comunidad.',
    'catch the _vybz!_': 'atrapa el _vybz!_',
    'come for the food, stay for the _vybz!_':
        'ven por la comida, quedate por el _vybz!_',
  };

  String _translateEnToEs(String input) {
    final k = input.trim().toLowerCase();
    return _enToEs[k] ?? input;
  }

  String _translateEsToEn(String input) {
    final k = input.trim().toLowerCase();
    final found = _enToEs.entries.firstWhere(
      (e) => e.value == k,
      orElse: () => const MapEntry('', ''),
    );
    if (found.key.isNotEmpty) return found.key;
    return input;
  }

  bool _looksSpanish(String s) {
    final t = s.trim().toLowerCase();
    if (t.isEmpty) return false;
    if (RegExp(r'[¡¿]').hasMatch(t)) return true;
    const hits = [
      ' el ',
      ' la ',
      ' los ',
      ' las ',
      ' de ',
      ' para ',
      ' sesion',
      ' ofertas',
      ' recompensas',
      ' gratis',
      ' sintoniza',
      ' participa',
      ' bienvenido',
      ' naturalmente',
      ' quedate',
    ];
    return hits.any((w) => t.contains(w));
  }

  bool _looksEnglish(String s) {
    final t = s.trim().toLowerCase();
    if (t.isEmpty) return false;
    if (_looksSpanish(t)) return false;
    return RegExp(r'[a-z]').hasMatch(t);
  }

  void _autoFixMix() {
    setState(() {
      for (final p in _pairs) {
        if (_looksEnglish(p.es) && _looksSpanish(p.en)) {
          final tmp = p.es;
          p.es = p.en;
          p.en = tmp;
        }
      }
    });
  }

  void _fillMissingTranslations() {
    setState(() {
      for (final p in _pairs) {
        if (p.es.trim().isEmpty && p.en.trim().isNotEmpty) {
          p.es = _translateEnToEs(p.en);
        }
        if (p.en.trim().isEmpty && p.es.trim().isNotEmpty) {
          p.en = _translateEsToEn(p.es);
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppState.of(context);
    _showLocal = app.showTicker.value;
    _speedLocal = app.tickerSpeedPx.value;

    _laneLightLocal = app.laneLight.value;
    _laneDarkLocal = app.laneDark.value;
    _railLightLocal = app.railLight.value;
    _railDarkLocal = app.railDark.value;
    _textLightLocal = app.textLight.value;
    _textDarkLocal = app.textDark.value;

    _editingSpanish = app.languageCode.value == 'es';

    // Build paired list from current app lists (always align by index)
    final es = List<String>.from(app.tickerEs.value);
    final en = List<String>.from(app.tickerEn.value);
    final n = (es.length > en.length) ? es.length : en.length;
    while (es.length < n) {
      es.add('');
    }
    while (en.length < n) {
      en.add('');
    }
    _pairs = List.generate(n, (i) => MessagePair(en: en[i], es: es[i]));

    // Initial automatic clean-up so the Spanish tab actually shows Spanish.
    _autoFixMix();
    _fillMissingTranslations();

    _ids = List<int>.generate(_pairs.length, (i) => i);
    _nextId = _pairs.length;
  }

  List<String> _toEnList() => _pairs.map((p) => p.en).toList();
  List<String> _toEsList() => _pairs.map((p) => p.es).toList();

  Future<void> _saveAndExit() async {
    final app = AppState.of(context);

    app.showTicker.value = _showLocal;
    app.tickerEs.value = _toEsList();
    app.tickerEn.value = _toEnList();
    app.tickerSpeedPx.value = _speedLocal;

    app.laneLight.value = _laneLightLocal;
    app.laneDark.value = _laneDarkLocal;
    app.railLight.value = _railLightLocal;
    app.railDark.value = _railDarkLocal;
    app.textLight.value = _textLightLocal;
    app.textDark.value = _textDarkLocal;

    try {
      await _NinaVerdeAppState.saveTickerSettings(
        show: _showLocal,
        es: _toEsList(),
        en: _toEnList(),
        speedPx: _speedLocal,
        laneLight: _laneLightLocal,
        laneDark: _laneDarkLocal,
        railLight: _railLightLocal,
        railDark: _railDarkLocal,
        textLight: _textLightLocal,
        textDark: _textDarkLocal,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                context,
                en: 'Ticker settings saved',
                es: 'Ajustes del ticker guardados',
              ),
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(
            tr(
              context,
              en: 'Save failed: $e',
              es: 'Error al guardar: $e',
            ),
          ),
        ),
      );
    }
  }

  // ----- Helpers for colors/hex -----
  static String _toHex(Color c, {bool leadingHash = true}) {
    final argb = c.toARGB32();
    final a = (argb >> 24) & 0xFF;
    final r = (argb >> 16) & 0xFF;
    final g = (argb >> 8) & 0xFF;
    final b = argb & 0xFF;

    return '${leadingHash ? '#' : ''}'
            '${a.toRadixString(16).padLeft(2, '0')}'
            '${r.toRadixString(16).padLeft(2, '0')}'
            '${g.toRadixString(16).padLeft(2, '0')}'
            '${b.toRadixString(16).padLeft(2, '0')}'
        .toUpperCase();
  }

  static Color _parseHex(String input, Color fallback) {
    final s = input.trim();
    final hex = s.startsWith('#') ? s.substring(1) : s;
    if (hex.length == 6) {
      final v = int.tryParse('FF$hex', radix: 16);
      if (v != null) return Color(v);
    } else if (hex.length == 8) {
      final v = int.tryParse(hex, radix: 16);
      if (v != null) return Color(v);
    }
    return fallback;
  }

  Future<void> _confirmRemove(int index) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          tr(
            context,
            en: 'Remove message?',
            es: 'Eliminar mensaje?',
          ),
        ),
        content: Text(
          tr(
            context,
            en: 'This will delete the message in both languages.',
            es: 'Esto eliminara el mensaje en ambos idiomas.',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr(context, en: 'No', es: 'No'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr(context, en: 'Yes', es: 'Si'))),
        ],
      ),
    );
    if (ok == true) {
      setState(() {
        if (index >= 0 && index < _pairs.length) _pairs.removeAt(index);
        if (index >= 0 && index < _ids.length) _ids.removeAt(index);
      });
    }
  }

  void _editMsg({
    required bool spanish,
    required int index,
    required String value,
  }) {
    setState(() {
      if (spanish) {
        _pairs[index].es = value;
        if (value.trim().isNotEmpty) {
          _pairs[index].en = _translateEsToEn(value);
        }
      } else {
        _pairs[index].en = value;
        if (value.trim().isNotEmpty) {
          _pairs[index].es = _translateEnToEs(value);
        }
      }
    });
  }

  void _addMsg(bool spanish) {
    setState(() {
      final p = MessagePair();
      _pairs.add(p);
      _ids.add(_nextId++);
    });
  }

  void _reorderBoth(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    void move<T>(List<T> list, int from, int to) {
      final item = list.removeAt(from);
      list.insert(to, item);
    }

    setState(() {
      move(_ids, oldIndex, newIndex);
      move(_pairs, oldIndex, newIndex);
    });
  }

  Widget _colorRow({
    required String label,
    required Color value,
    required ValueChanged<Color> onChanged,
  }) {
    final ctl = TextEditingController(text: _toHex(value));
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
              color: value, borderRadius: BorderRadius.circular(6)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: ctl,
            decoration: InputDecoration(
              labelText: label,
              helperText: tr(
                context,
                en: 'Hex ARGB (#AARRGGBB or #RRGGBB)',
                es: 'Hex ARGB (#AARRGGBB o #RRGGBB)',
              ),
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            onChanged: (s) => onChanged(_parseHex(s, value)),
          ),
        ),
      ],
    );
  }

  Widget _messagesReorderEditor({required bool isEsUI}) {
    final isEs = _editingSpanish;

    final labelEs = isEsUI ? 'Mensajes' : 'Messages';
    final chipEs = isEsUI ? 'Espanol (ES)' : 'Spanish (ES)';
    final chipEn = isEsUI ? 'Ingles (EN)' : 'English (EN)';
    final addMsg = isEsUI ? 'Agregar mensaje' : 'Add message';
    final fixMix = isEsUI ? 'Auto-corregir mezcla' : 'Auto-fix mix';
    final fillMissing =
        isEsUI ? 'Completar traducciones' : 'Fill missing translations';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(labelEs, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: Text(chipEs),
              selected: isEs,
              onSelected: (s) => setState(() => _editingSpanish = true),
            ),
            ChoiceChip(
              label: Text(chipEn),
              selected: !isEs,
              onSelected: (s) => setState(() => _editingSpanish = false),
            ),
            ActionChip(
              label: Text(fixMix),
              onPressed: _autoFixMix,
              avatar: const Icon(Icons.swap_horiz, size: 18),
            ),
            ActionChip(
              label: Text(fillMissing),
              onPressed: _fillMissingTranslations,
              avatar: const Icon(Icons.translate, size: 18),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ReorderableListView.builder(
          buildDefaultDragHandles: false,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: _ids.length,
          onReorder: _reorderBoth,
          itemBuilder: (context, i) {
            final visibleText = isEs ? _pairs[i].es : _pairs[i].en;
            return Card(
              key: ValueKey(_ids[i]),
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                leading: ReorderableDragStartListener(
                  index: i,
                  child: const Icon(Icons.drag_handle_rounded),
                ),
                title: TextFormField(
                  initialValue: visibleText,
                  maxLines: 6,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: tr(
                      context,
                      en: 'Message text. Use _VYBZ!_ to style VYBZ!',
                      es: 'Texto del mensaje. Usa _VYBZ!_ para estilo.',
                    ),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => _editMsg(
                    spanish: isEs,
                    index: i,
                    value: v,
                  ),
                ),
                trailing: IconButton(
                  tooltip: tr(context, en: 'Remove', es: 'Eliminar'),
                  onPressed: () => _confirmRemove(i),
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: () => _addMsg(isEs),
            icon: const Icon(Icons.add),
            label: Text(addMsg),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.of(context);

    return ValueListenableBuilder<String>(
      valueListenable: app.languageCode,
      builder: (context, code, _) {
        final isEsUI = code == 'es';
        final title = isEsUI ? 'Ajustes del Ticker' : 'Ticker Settings';
        final tabMsg = isEsUI ? 'Mensajes' : 'Messages';
        final tabApp = isEsUI ? 'Apariencia' : 'Appearance';
        final showTickerLbl = isEsUI ? 'Mostrar ticker' : 'Show ticker';
        final showHint = isEsUI
            ? 'Cambia la vista previa aqui; solo se aplica al guardar.'
            : 'Changes preview while here; only applies on "Save".';
        final speedLbl = isEsUI ? 'Velocidad' : 'Speed';
        final pxs = isEsUI ? 'px/s' : 'px/s';
        final colorsLight =
            isEsUI ? 'Colores — Modo Claro' : 'Colors — Light Mode';
        final colorsDark =
            isEsUI ? 'Colores — Modo Oscuro' : 'Colors — Dark Mode';
        final laneLbl = isEsUI ? 'Pista (naranja)' : 'Lane (orange)';
        final railLbl = isEsUI ? 'Rieles (marron)' : 'Rails (brown)';
        final textLbl = isEsUI ? 'Color de texto' : 'Text color';
        final cancel = isEsUI ? 'Cancelar' : 'Cancel';
        final save = isEsUI ? 'Guardar' : 'Save';

        return Scaffold(
          appBar: NvAppBar(title: title, showBack: true),
          body: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                TabBar(
                  tabs: [
                    Tab(text: tabMsg),
                    Tab(text: tabApp),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // --------- Messages tab ----------
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          SwitchListTile(
                            title: Text(showTickerLbl),
                            subtitle: Text(showHint),
                            value: _showLocal,
                            onChanged: (v) => setState(() => _showLocal = v),
                          ),
                          const SizedBox(height: 8),
                          Text(speedLbl,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          Slider(
                            value: _speedLocal,
                            min: 40,
                            max: 160,
                            divisions: 24,
                            label: '${_speedLocal.toStringAsFixed(0)} $pxs',
                            onChanged: (v) => setState(() => _speedLocal = v),
                          ),
                          const SizedBox(height: 12),
                          _messagesReorderEditor(isEsUI: isEsUI),
                          const SizedBox(height: 80),
                        ],
                      ),

                      // --------- Appearance tab ----------
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Text(colorsLight,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          _colorRow(
                            label: laneLbl,
                            value: _laneLightLocal,
                            onChanged: (c) =>
                                setState(() => _laneLightLocal = c),
                          ),
                          const SizedBox(height: 10),
                          _colorRow(
                            label: railLbl,
                            value: _railLightLocal,
                            onChanged: (c) =>
                                setState(() => _railLightLocal = c),
                          ),
                          const SizedBox(height: 10),
                          _colorRow(
                            label: textLbl,
                            value: _textLightLocal,
                            onChanged: (c) =>
                                setState(() => _textLightLocal = c),
                          ),
                          const SizedBox(height: 20),
                          Text(colorsDark,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          _colorRow(
                            label: laneLbl,
                            value: _laneDarkLocal,
                            onChanged: (c) =>
                                setState(() => _laneDarkLocal = c),
                          ),
                          const SizedBox(height: 10),
                          _colorRow(
                            label: railLbl,
                            value: _railDarkLocal,
                            onChanged: (c) =>
                                setState(() => _railDarkLocal = c),
                          ),
                          const SizedBox(height: 10),
                          _colorRow(
                            label: textLbl,
                            value: _textDarkLocal,
                            onChanged: (c) =>
                                setState(() => _textDarkLocal = c),
                          ),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(cancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saveAndExit,
                      child: Text(save),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// ===== Pop-up widget using WebView (fresh session each open) =====
class _YouTubePopupWebView extends StatefulWidget {
  final String videoId;
  const _YouTubePopupWebView({super.key, required this.videoId});

  @override
  State<_YouTubePopupWebView> createState() => _YouTubePopupWebViewState();
}

class _YouTubePopupWebViewState extends State<_YouTubePopupWebView> {
  late final WebViewController _controller;
  final _cookieManager = WebViewCookieManager();
  bool _ready = false;
  late final int _bust;

  String _html(String videoId, int bust) => '''
<!doctype html>
<html>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
      html,body{margin:0;padding:0;background:#000;height:100%;overflow:hidden}
      #player{position:absolute;inset:0}
    </style>
  </head>
  <body>
    <div id="player"></div>
    <script>
      var tag=document.createElement('script');
      tag.src="https://www.youtube.com/iframe_api?ts=$bust";
      document.head.appendChild(tag);
      var player;
      function onYouTubeIframeAPIReady(){
        player=new YT.Player('player',{
          width:'100%',height:'100%',
          videoId:'$videoId',
          playerVars:{autoplay:1,controls:1,modestbranding:1,rel:0,playsinline:1,mute:1},
          events:{onReady:function(e){try{e.target.playVideo();}catch(e){}}}
        });
      }
      window.addEventListener('unload', function(){
        try{ if(player){ player.stopVideo(); player.destroy(); } }catch(e){}
      });
    </script>
  </body>
</html>
''';

  Future<void> _init() async {
    // Clear cookies/cache to avoid sticky state across opens.
    try {
      await _cookieManager.clearCookies();
    } catch (_) {}
    try {
      final tmp = WebViewController();
      await tmp.clearCache();
    } catch (_) {}

    // Per-platform creation params (inline playback on iOS)
    PlatformWebViewControllerCreationParams creationParams;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      creationParams = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      creationParams = const PlatformWebViewControllerCreationParams();
    }

    final controller =
        WebViewController.fromPlatformCreationParams(creationParams)
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(Colors.black)
          ..setNavigationDelegate(
            NavigationDelegate(
              onNavigationRequest: (req) => NavigationDecision.navigate,
            ),
          );

    // Android: allow autoplay
    if (controller.platform is AndroidWebViewController) {
      final android = controller.platform as AndroidWebViewController;
      AndroidWebViewController.enableDebugging(false);
      await android.setMediaPlaybackRequiresUserGesture(false);
    }

    await controller.loadHtmlString(_html(widget.videoId, _bust));
    _controller = controller;
    if (mounted) setState(() => _ready = true);
  }

  @override
  void initState() {
    super.initState();
    _bust = DateTime.now().microsecondsSinceEpoch;
    _init();
  }

  Future<void> _cleanup() async {
    try {
      await _controller.loadRequest(Uri.parse('about:blank'));
    } catch (_) {}
    try {
      await _controller.clearCache();
    } catch (_) {}
    try {
      await _cookieManager.clearCookies();
    } catch (_) {}
  }

  @override
  void dispose() {
    _cleanup(); // best-effort
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    final width = size.width * 0.9;
    final height = width * 9 / 16;

    return SafeArea(
      child: Stack(
        children: [
          // Tap outside to dismiss
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
          // Centered player card
          Center(
            child: Material(
              elevation: 24,
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: Container(
                width: width,
                height: height,
                color: Colors.black,
                child: Stack(
                  children: [
                    if (_ready)
                      WebViewWidget(
                        key: ValueKey(_bust), // brand-new widget each open
                        controller: _controller,
                      )
                    else
                      const Center(child: CircularProgressIndicator()),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(36, 36),
                          padding: EdgeInsets.zero,
                        ),
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}












