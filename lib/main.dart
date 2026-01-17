// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
// WebView (universal, with per-platform creation params)
// WebView (standard imports)

import 'firebase_options.dart';

import 'services/config_service.dart';
import 'services/user_prefs_service.dart';
import 'screens/settings_pages.dart';
import 'screens/registration_screen.dart';
import 'screens/login_screen.dart';
import 'screens/intro_settings_screen.dart';


import 'screens/home_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/splash_to_login.dart';
import 'screens/document_webview.dart';
import 'screens/owner_dashboard_screen.dart';
import 'screens/catalog_admin_screen.dart';
import 'screens/contact_nina_verde_page.dart';
import 'screens/event_promo_admin_screen.dart';
import 'screens/app_settings_admin_screen.dart';
import 'screens/carousel_settings_screen.dart';
import 'screens/angelina_profile_settings_screen.dart';
import 'providers/cart_provider.dart';
import 'state/app_state.dart';
import 'theme/brand_colors.dart' as brand;
import 'widgets/nv_widgets.dart';
import 'widgets/admin/admin_route_wrapper.dart';
import 'screens/kids_zone_screen.dart';
import 'screens/kids/coloring_sandbox_screen.dart';
import 'screens/kids/slider_puzzle_screen.dart';
import 'screens/kids/maze_runner_screen.dart';
import 'screens/kids/memory_match_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Enforce logout ONLY for Guests on fresh app start
  // Registered users stay logged in (persistent session)
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.isAnonymous) {
      await FirebaseAuth.instance.signOut();
    }
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


class NinaVerdeApp extends StatefulWidget {
  const NinaVerdeApp({super.key});
  @override
  State<NinaVerdeApp> createState() => _NinaVerdeAppState();
}

class _NinaVerdeAppState extends State<NinaVerdeApp> {
  final themeMode = ValueNotifier<ThemeMode>(ThemeMode.dark);
  final languageCode = ValueNotifier<String>('es');
  final languageOptions = ValueNotifier<List<String>>(['es', 'en']);
  final languageLabels = ValueNotifier<Map<String, String>>({
    'es': 'Español',
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

  // Language-aware messages
  late final ValueNotifier<List<String>> tickerEn = ValueNotifier<List<String>>([]);
  late final ValueNotifier<List<String>> tickerEs = ValueNotifier<List<String>>([]);

  final tickerSpeedPx = ValueNotifier<double>(77.1);
  
  // Carousel State
  final carouselSpeed = ValueNotifier<double>(60.0); // seconds per rotation
  final carouselAutoPlay = ValueNotifier<bool>(true);
  final carouselGlobalMode = ValueNotifier<CarouselMode>(CarouselMode.animated);
  final categoryConfigs = ValueNotifier<Map<String, CategoryConfig>>({});

  // Angelina Profile Picture State
  final angelinaProfilePics = ValueNotifier<List<String>>([]); // Firebase Storage URLs
  final selectedProfilePic = ValueNotifier<String?>(null); // null = use default
  final profilePicRandomize = ValueNotifier<bool>(false);
  final profilePicInterval = ValueNotifier<int>(300); // 5 minutes in seconds

  final laneLight = ValueNotifier<Color>(const Color(0xFFF3A70B));
  final laneDark = ValueNotifier<Color>(const Color(0xFFF3A70B));
  final railLight = ValueNotifier<Color>(const Color(0xFFA24011));
  final railDark = ValueNotifier<Color>(const Color(0xFFA24011));
  final textLight = ValueNotifier<Color>(Colors.white);
  final textDark = ValueNotifier<Color>(Colors.white);

  final isManager = ValueNotifier<bool>(false);
  StreamSubscription? _authSub;
  StreamSubscription? _userSub;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // 0. Init Prefs
    await UserPrefsService.init();
    final userPrefs = UserPrefsService.loadLocalPrefs();

    // 1. Load initial configs via ConfigService
    final ticker = await ConfigService.getTickerConfig();
    showTicker.value = ticker.show;
    tickerEn.value = ticker.messagesEn;
    tickerEs.value = ticker.messagesEs;
    tickerSpeedPx.value = ticker.speedPx;
    laneLight.value = ticker.laneLight;
    laneDark.value = ticker.laneDark;
    railLight.value = ticker.railLight;
    railDark.value = ticker.railDark;
    textLight.value = ticker.textLight;
    textDark.value = ticker.textDark;

    final loc = await ConfigService.getLocalizationConfig();
    
    // Apply Cloud Global Default first, then User Pref overrides
    languageCode.value = userPrefs.languageCode; // Was loc.defaultLanguage
    themeMode.value = userPrefs.themeMode;
    currencyCode.value = userPrefs.currencyCode; // Was loc.defaultCurrency
    
    // Fallback if user hasn't set anything? (Actually loadLocalPrefs defaults nicely)
    // If we wanted to respect Admin Global Default for FIRST LAUNCH users, we would check if userPrefs.languageCode was explicity set or just default 'es'.
    // For now, loadLocalPrefs defaults to 'es', so we are safe.

    languageOptions.value = loc.languages;
    languageLabels.value = loc.languageLabels;
    currencyOptions.value = loc.currencies;
    
    final cfgs = <String, CurrencyConfig>{};
    if (loc.currencyConfigs.isEmpty) {
      // Fallback: If remote config has no currency definitions, use App Defaults
      cfgs['USD'] = const CurrencyConfig(code: 'USD', symbol: '\$', rateFromUsd: 1.0);
      cfgs['NIO'] = const CurrencyConfig(code: 'NIO', symbol: 'C\$', rateFromUsd: 36.5);
    } else {
      for (var entry in loc.currencyConfigs.entries) {
        cfgs[entry.key] = CurrencyConfig(
          code: entry.value['code'] ?? entry.key,
          symbol: entry.value['symbol'] ?? '\$',
          rateFromUsd: (entry.value['rateFromUsd'] as num?)?.toDouble() ?? 1.0,
          fractionDigits: (entry.value['fractionDigits'] as num?)?.toInt() ?? 2,
        );
      }
    }
    currencyConfigs.value = cfgs;

    // 1b. Load Carousel Config
    final carouselCfg = UserPrefsService.loadCarouselConfig();
    if (carouselCfg.isNotEmpty) {
      if (carouselCfg['speed'] != null) carouselSpeed.value = (carouselCfg['speed'] as num).toDouble();
      if (carouselCfg['autoPlay'] != null) carouselAutoPlay.value = carouselCfg['autoPlay'] as bool;
      if (carouselCfg['globalMode'] != null) {
        carouselGlobalMode.value = CarouselMode.values[carouselCfg['globalMode'] as int];
      }
      if (carouselCfg['categories'] != null) {
        final catMap = (carouselCfg['categories'] as Map).cast<String, dynamic>();
        final parsedCats = <String, CategoryConfig>{};
        catMap.forEach((k, v) {
          parsedCats[k] = CategoryConfig.fromJson(v as Map<String, dynamic>);
        });
        categoryConfigs.value = parsedCats;
      }
    }

    // 2. Listen to auth
    _listenToAuth();
  }

  void _listenToAuth() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      _userSub?.cancel();
      if (user == null) {
        isManager.value = false;
      } else {
        // Sync cloud prefs to device on login
        UserPrefsService.syncFromCloud().then((_) {
          // Reload to reflect cloud sync
          final synced = UserPrefsService.loadLocalPrefs();
          languageCode.value = synced.languageCode;
          currencyCode.value = synced.currencyCode;
          themeMode.value = synced.themeMode;
        });

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

  @override
  void dispose() {
    _authSub?.cancel();
    _userSub?.cancel();
    super.dispose();
  }

  void _openPip(BuildContext ctx) {
    // This will be replaced by NvVideoOverlay logic in Phase 3
    showDialog(
      context: ctx,
      builder: (context) => const YouTubePopupWebView(videoId: '8q-6y2i8S5M'),
    );
  }

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
      carouselSpeed: carouselSpeed,
      carouselAutoPlay: carouselAutoPlay,
      carouselGlobalMode: carouselGlobalMode,
      categoryConfigs: categoryConfigs,
      angelinaProfilePics: angelinaProfilePics,
      selectedProfilePic: selectedProfilePic,
      profilePicRandomize: profilePicRandomize,
      profilePicInterval: profilePicInterval,
      openPip: _openPip,
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeMode,
        builder: (context, mode, _) {
          return MaterialApp(
            title: 'Niña Verde',
            debugShowCheckedModeBanner: false,
            themeMode: mode,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(seedColor: brand.nvGreenDark),
              scaffoldBackgroundColor: const Color(0xFFF9FBF9),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.white,
                elevation: 0,
                centerTitle: true,
              ),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              colorScheme: ColorScheme.fromSeed(
                seedColor: brand.nvGreenDark,
                brightness: Brightness.dark,
              ),
              scaffoldBackgroundColor: brand.nvDarkSurface,
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF1E1E1E),
                elevation: 0,
                centerTitle: true,
              ),
            ),
            initialRoute: '/',
            routes: {
              '/': (context) => const SplashToLoginScreen(),
              '/login': (context) => const LoginScreen(),
              '/register': (context) => const RegistrationScreen(),
              '/home': (context) => const HomeScreen(),
              '/cart': (context) => const CartScreen(),
              '/contact': (context) => ContactNinaVerdePage(),
              '/owner': (context) => const OwnerDashboardScreen(),
              '/language-settings': (context) => const AdminRoute(child: LanguageSettingsPage()),
              '/currency-settings': (context) => const AdminRoute(child: CurrencySettingsPage()),
              '/ticker-settings': (context) => const AdminRoute(child: TickerSettingsPage()),
              '/app-settings': (context) => const AdminRoute(child: AppSettingsAdminScreen()),
              '/carousel-settings': (context) => const AdminRoute(child: CarouselSettingsScreen()),
              '/angelina-profile': (context) => const AdminRoute(child: AngelinaProfileSettingsScreen()),
              '/admin/catalog': (context) => AdminRoute(child: CatalogAdminScreen()),
              '/admin/events': (context) => const AdminRoute(child: EventPromoAdminScreen()),
              '/intro': (context) => const IntroSettingsScreen(),

              // Legal
              '/privacy': (context) => const DocumentWebView(
                    titleEn: 'Privacy Policy',
                    titleEs: 'Política de Privacidad',
                    assetEn: 'assets/legal/privacy-policy.en.html',
                    assetEs: 'assets/legal/privacy-policy.es.html',
                  ),
              '/data-deletion': (context) => const DocumentWebView(
                    titleEn: 'Data Deletion',
                    titleEs: 'Eliminación de Datos',
                    assetEn: 'assets/legal/data-deletion.en.html',
                    assetEs: 'assets/legal/data-deletion.es.html',
                  ),

              // Kidsz Gamez Zone
              '/kids': (context) => const KidszGamezZoneScreen(),
              '/kids/coloring': (context) => const ColoringSandboxScreen(),
              '/kids/puzzle': (context) => const SliderPuzzleScreen(),
              '/kids/maze': (context) => const MazeRunnerScreen(),
              '/kids/memory': (context) => const MemoryMatchScreen(),
            },
          );
        },
      ),
    );
  }
}












