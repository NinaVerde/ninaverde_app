// lib/main.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// WebView (universal, with per-platform creation params)
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'firebase_options.dart';

// Screens (disambiguate imports with `show`)
import 'screens/login_screen.dart' show LoginScreen;
import 'screens/home_screen.dart' show HomeScreen;
import 'screens/splash_to_login.dart' show SplashToLoginScreen; // boot splash
import 'screens/document_webview.dart' show DocumentWebView; // standalone WebView screen
import 'screens/contact_nina_verde_page.dart' show ContactNinaVerdePage; // <-- NEW: AI Contact page

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Keep local cache so values survive flaky network / quick restarts
  FirebaseFirestore.instance.settings =
      const Settings(persistenceEnabled: true);

  runApp(const NinaVerdeApp());
}

/// ---------- Global app state ----------
class AppState extends InheritedWidget {
  final ValueNotifier<ThemeMode> themeMode;

  /// Language: true=ES (default), false=EN
  final ValueNotifier<bool> isSpanish;

  /// Currency toggle: "USD" (default) <-> "NIO"
  final ValueNotifier<String> currencyCode;

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
    required this.isSpanish,
    required this.currencyCode,
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
    required Widget child,
  }) : super(child: child);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppState>()!;

  @override
  bool updateShouldNotify(covariant AppState old) =>
      themeMode != old.themeMode ||
      isSpanish != old.isSpanish ||
      currencyCode != old.currencyCode ||
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

class NinaVerdeApp extends StatefulWidget {
  const NinaVerdeApp({super.key});
  @override
  State<NinaVerdeApp> createState() => _NinaVerdeAppState();
}

class _NinaVerdeAppState extends State<NinaVerdeApp> {
  final themeMode = ValueNotifier<ThemeMode>(ThemeMode.light);
  final isSpanish = ValueNotifier<bool>(true); // ES default
  final currencyCode = ValueNotifier<String>('USD');
  final showTicker = ValueNotifier<bool>(true);

  // ----- Default messages (EN) -----
  static List<String> _defaultsEn() => const [
        "Naturally, Welcome to Nicaragua Niña Verde!",
        "Login to collect points.",
        "Get exclusive offers.",
        "Earn rewards.",
        "Enjoy free services.",
        "Tune into the best entertainment.",
        "Engage the community.",
        "Catch the _VYBZ!_",
        "Come for the food, Stay for the _VYBZ!_",
      ];

  static List<String> _defaultsEsFromEn(List<String> en) {
    String tr(String s) {
      return s
          .replaceAll("Naturally, Welcome to Nicaragua Niña Verde!",
              "Naturalmente, ¡Bienvenido a Nicaragua Niña Verde!")
          .replaceAll("Login to collect points.",
              "Inicia sesión para acumular puntos.")
          .replaceAll("Get exclusive offers.", "Obtén ofertas exclusivas.")
          .replaceAll("Earn rewards.", "Gana recompensas.")
          .replaceAll("Enjoy free services.", "Disfruta servicios gratis.")
          .replaceAll("Tune into the best entertainment.",
              "Sintoniza el mejor entretenimiento.")
          .replaceAll("Engage the community.", "Participa en la comunidad.")
          .replaceAll("Catch the _VYBZ!_", "¡Atrapa el _VYBZ!_")
          .replaceAll("Come for the food, Stay for the _VYBZ!_",
              "Ven por la comida, quédate por el _VYBZ!");
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

  final isManager = ValueNotifier<bool>(true);

  // Brand colors for themes
  static const Color nvGreenDark = Color(0xFF022F18);
  static const Color nvDarkSurface = Color(0xFF0B2C1E);

  // --------- Firestore persistence ----------
  static const _cfgCol = 'app_config';
  static const _tickerDoc = 'ticker';

  static DocumentReference<Map<String, dynamic>> _tickerRef() =>
      FirebaseFirestore.instance.collection(_cfgCol).doc(_tickerDoc);

  @override
  void initState() {
    super.initState();
    _loadTickerSettings();
  }

  static int _colorToInt(Color c) => c.value;
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
          final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
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
      isSpanish: isSpanish,
      currencyCode: currencyCode,
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
      child: ValueListenableBuilder<bool>(
        valueListenable: isSpanish,
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
                    seedColor: nvGreenDark,
                    surface: const Color(0xFFE9F6E9),
                  ),
                  appBarTheme: const AppBarTheme(centerTitle: true),
                ),
                darkTheme: ThemeData(
                  useMaterial3: true,
                  brightness: Brightness.dark,
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: nvGreenDark,
                    brightness: Brightness.dark,
                    surface: nvDarkSurface,
                  ),
                  scaffoldBackgroundColor: nvGreenDark,
                  appBarTheme: const AppBarTheme(
                    backgroundColor: nvGreenDark,
                    centerTitle: true,
                  ),
                ),
                routes: {
                  '/': (_) => const SplashToLoginScreen(),
                  '/splash': (_) => const SplashToLoginScreen(),
                  '/login': (_) => LoginScreen(), // non-const for dynamic logo/video
                  '/home': (_) => const HomeScreen(),
                  '/forgot': (_) =>
                      const PlaceholderPage(title: 'Forgot Password'),
                  '/register': (_) =>
                      const PlaceholderPage(title: 'Register'),
                  '/contact': (_) => const ContactNinaVerdePage(), // <-- AI contact page
                  '/privacy': (_) => const DocumentWebView(
                        titleEs: 'Política de Privacidad',
                        titleEn: 'Privacy Policy',
                        assetEs: 'assets/legal/privacy-policy.es.html',
                        assetEn: 'assets/legal/privacy-policy.en.html',
                      ),
                  '/data-deletion': (_) => const DocumentWebView(
                        titleEs: 'Eliminación de Datos',
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
  const NvAppBar({super.key, required this.title});

  static const double tickerHeight = 54;

  @override
  Size get preferredSize =>
      const Size.fromHeight(kToolbarHeight + tickerHeight);

  String _t(BuildContext context, String key) {
    final es = AppState.of(context).isSpanish.value;
    const esMap = {
      'dark': 'Oscuro',
      'light': 'Claro',
      'lang_tip_es': 'Cambiar a Inglés (mantener para ajustes)',
      'lang_tip_en': 'Switch to Español (mantener para ajustes)',
      'cur_tip': 'Mantener para ajustes de moneda',
    };
    const enMap = {
      'dark': 'Dark',
      'light': 'Light',
      'lang_tip_es': 'Switch to English (long-press for settings)',
      'lang_tip_en': 'Cambiar a Español (mantener para ajustes)',
      'cur_tip': 'Long-press for currency settings',
    };
    return (es ? esMap : enMap)[key]!;
  }

  List<String> _messages(AppState app) {
    final es = app.isSpanish.value;
    return List<String>.from(es ? app.tickerEs.value : app.tickerEn.value);
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

    // Ensure "Niña Verde — " prefix exactly once
    String visibleTitle = title.replaceFirst('Nicaragua ', '');
    final normalized = visibleTitle.toLowerCase();
    final hasPrefix = normalized.startsWith('niña verde —') ||
        normalized.startsWith('nina verde —') || // ascii fallback
        normalized.startsWith('niña verde-') ||
        normalized.startsWith('nina verde-');
    if (!hasPrefix) {
      visibleTitle = 'Niña Verde — $visibleTitle';
    }

    return AppBar(
      title: Text(
        visibleTitle,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      centerTitle: true,
      automaticallyImplyLeading: false,
      actions: [
        // Language toggle; long-press -> settings
        ValueListenableBuilder<bool>(
          valueListenable: app.isSpanish,
          builder: (_, es, __) => IconButton(
            tooltip:
                es ? _t(context, 'lang_tip_es') : _t(context, 'lang_tip_en'),
            onPressed: () => app.isSpanish.value = !es,
            onLongPress: () =>
                Navigator.pushNamed(context, '/language-settings'),
            icon: Text(es ? 'ES' : 'EN',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        // Currency toggle; long-press -> settings
        ValueListenableBuilder<String>(
          valueListenable: app.currencyCode,
          builder: (_, code, __) => IconButton(
            tooltip: _t(context, 'cur_tip'),
            onPressed: () =>
                app.currencyCode.value = (code == 'USD') ? 'NIO' : 'USD',
            onLongPress: () =>
                Navigator.pushNamed(context, '/currency-settings'),
            icon:
                Text(code, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        // Theme toggle
        ValueListenableBuilder<ThemeMode>(
          valueListenable: app.themeMode,
          builder: (_, mode, __) {
            final isDark = mode == ThemeMode.dark;
            return IconButton(
              tooltip: isDark ? _t(context, 'light') : _t(context, 'dark'),
              onPressed: () => app.themeMode.value =
                  isDark ? ThemeMode.light : ThemeMode.dark,
              icon: Icon(isDark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined),
            );
          },
        ),
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
                    Navigator.pushNamed(context, '/ticker-settings');
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Insufficient permissions')),
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
                    Navigator.pushNamed(context, '/ticker-settings');
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Insufficient permissions')),
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
            Container(height: topH, width: double.infinity, color: widget.railColor),
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

                      Widget copy(double x) => Transform.translate(
                            offset: Offset(x, 0),
                            child: SizedBox(
                              width: _contentWidth,
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 1.0),
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
            Container(height: botH, width: double.infinity, color: widget.railColor),
          ],
        ),
      ),
    );
  }
}

/// ---------- Placeholder ----------
class PlaceholderPage extends StatelessWidget {
  final String title;
  const PlaceholderPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: NvAppBar(title: title),
      body: Center(
        child: Text(
          '$title — placeholder screen',
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
    return Scaffold(
      appBar: const NvAppBar(title: 'Language Settings'),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Default to Español (ES)'),
            subtitle: const Text('Show Spanish first throughout the app'),
            value: app.isSpanish.value,
            onChanged: (v) => app.isSpanish.value = v,
          ),
        ],
      ),
    );
  }
}

/// ---------- Currency Settings ----------
class CurrencySettingsPage extends StatelessWidget {
  const CurrencySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppState.of(context);
    return Scaffold(
      appBar: const NvAppBar(title: 'Currency Settings'),
      body: ListView(
        children: [
          RadioListTile<String>(
            value: 'USD',
            groupValue: app.currencyCode.value,
            onChanged: (v) => app.currencyCode.value = v!,
            title: const Text('USD — US Dollar'),
          ),
          RadioListTile<String>(
            value: 'NIO',
            groupValue: app.currencyCode.value,
            onChanged: (v) => app.currencyCode.value = v!,
            title: const Text('NIO — Córdoba (Nicaragua)'),
          ),
        ],
      ),
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
    'earn rewards.': 'gana recompensas.',
    'get exclusive offers.': 'obtén ofertas exclusivas.',
    'login to collect points.': 'inicia sesión para acumular puntos.',
    'enjoy free services.': 'disfruta servicios gratis.',
    'tune into the best entertainment.': 'sintoniza el mejor entretenimiento.',
    'engage the community.': 'participa en la comunidad.',
    'catch the _vybz!_': '¡atrapa el _vybz!_',
    'come for the food, stay for the _vybz!_':
        'ven por la comida, quédate por el _vybz!_',
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
    if (RegExp(r'[áéíóúñ¡¿]').hasMatch(t)) return true;
    const hits = [
      ' el ', ' la ', ' los ', ' las ', ' de ', ' para ',
      ' sesión', ' ofertas', ' recompensas', ' gratis',
      ' sintoniza', ' participa', ' bienvenido', ' naturalmente'
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

    _editingSpanish = app.isSpanish.value;

    // Build paired list from current app lists (always align by index)
    final es = List<String>.from(app.tickerEs.value);
    final en = List<String>.from(app.tickerEn.value);
    final n = (es.length > en.length) ? es.length : en.length;
    while (es.length < n) es.add('');
    while (en.length < n) en.add('');
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
          const SnackBar(content: Text('Ticker settings saved')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('Save failed: $e'),
        ),
      );
    }
  }

  // ----- Helpers for colors/hex -----
  static String _toHex(Color c, {bool leadingHash = true}) {
    return '${leadingHash ? '#' : ''}'
        '${c.alpha.toRadixString(16).padLeft(2, '0')}'
        '${c.red.toRadixString(16).padLeft(2, '0')}'
        '${c.green.toRadixString(16).padLeft(2, '0')}'
        '${c.blue.toRadixString(16).padLeft(2, '0')}'
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
        title: const Text('Remove message?'),
        content: const Text('This will delete the message in both languages.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
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
          decoration:
              BoxDecoration(color: value, borderRadius: BorderRadius.circular(6)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: ctl,
            decoration: InputDecoration(
              labelText: label,
              helperText: 'Hex ARGB (#AARRGGBB or #RRGGBB)',
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
    final chipEs = isEsUI ? 'Español (ES)' : 'Spanish (ES)';
    final chipEn = isEsUI ? 'Inglés (EN)' : 'English (EN)';
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
                  decoration: const InputDecoration(
                    hintText: 'Message text… Use _VYBZ!_ to style VYBZ!',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => _editMsg(
                    spanish: isEs,
                    index: i,
                    value: v,
                  ),
                ),
                trailing: IconButton(
                  tooltip: 'Remove',
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

    return ValueListenableBuilder<bool>(
      valueListenable: app.isSpanish,
      builder: (context, isEsUI, _) {
        final title = isEsUI ? 'Ajustes del Ticker' : 'Ticker Settings';
        final tabMsg = isEsUI ? 'Mensajes' : 'Messages';
        final tabApp = isEsUI ? 'Apariencia' : 'Appearance';
        final showTickerLbl = isEsUI ? 'Mostrar ticker' : 'Show ticker';
        final showHint = isEsUI
            ? 'Cambia la vista previa aquí; solo se aplica al guardar.'
            : 'Changes preview while here; only applies on “Save”.';
        final speedLbl = isEsUI ? 'Velocidad' : 'Speed';
        final pxs = isEsUI ? 'px/s' : 'px/s';
        final colorsLight =
            isEsUI ? 'Colores — Modo Claro' : 'Colors — Light Mode';
        final colorsDark =
            isEsUI ? 'Colores — Modo Oscuro' : 'Colors — Dark Mode';
        final laneLbl = isEsUI ? 'Pista (naranja)' : 'Lane (orange)';
        final railLbl = isEsUI ? 'Rieles (marrón)' : 'Rails (brown)';
        final textLbl = isEsUI ? 'Color de texto' : 'Text color';
        final cancel = isEsUI ? 'Cancelar' : 'Cancel';
        final save = isEsUI ? 'Guardar' : 'Save';

        return Scaffold(
          appBar: NvAppBar(title: title),
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
                              style: const TextStyle(fontWeight: FontWeight.bold)),
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
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          _colorRow(
                            label: laneLbl,
                            value: _laneLightLocal,
                            onChanged: (c) => setState(() => _laneLightLocal = c),
                          ),
                          const SizedBox(height: 10),
                          _colorRow(
                            label: railLbl,
                            value: _railLightLocal,
                            onChanged: (c) => setState(() => _railLightLocal = c),
                          ),
                          const SizedBox(height: 10),
                          _colorRow(
                            label: textLbl,
                            value: _textLightLocal,
                            onChanged: (c) => setState(() => _textLightLocal = c),
                          ),
                          const SizedBox(height: 20),
                          Text(colorsDark,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          _colorRow(
                            label: laneLbl,
                            value: _laneDarkLocal,
                            onChanged: (c) => setState(() => _laneDarkLocal = c),
                          ),
                          const SizedBox(height: 10),
                          _colorRow(
                            label: railLbl,
                            value: _railDarkLocal,
                            onChanged: (c) => setState(() => _railDarkLocal = c),
                          ),
                          const SizedBox(height: 10),
                          _colorRow(
                            label: textLbl,
                            value: _textDarkLocal,
                            onChanged: (c) => setState(() => _textDarkLocal = c),
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

/// Centralized brand colors (fallback defaults)
class _NinaVerdeColors {
  static const nvGreenDark = Color(0xFF022F18);
  static const nvOrange = Color(0xFFE8792F);

  // Ticker-specific (from logo)
  static const nvTickerOrange = Color(0xFFF3A70B); // #f3a70b
  static const nvTickerBrown = Color(0xFFA24011); // #a24011
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
    try { await _cookieManager.clearCookies(); } catch (_) {}
    try { final tmp = WebViewController(); await tmp.clearCache(); } catch (_) {}

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

    final controller = WebViewController.fromPlatformCreationParams(creationParams)
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
    try { await _controller.loadRequest(Uri.parse('about:blank')); } catch (_) {}
    try { await _controller.clearCache(); } catch (_) {}
    try { await _cookieManager.clearCookies(); } catch (_) {}
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
