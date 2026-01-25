// lib/widgets/nv_widgets.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart' as intl;

import '../state/app_state.dart';
import '../services/user_prefs_service.dart';
import '../models/app_config_model.dart';
import 'package:flutter/foundation.dart'; // For listEquals

/// ---------- AppBar with ticker in bottom ----------
class NvAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? titleWidget;
  final bool centerTitle;
  final bool showBack;
  final bool tickerVisible; // New: Controls toolbar height
  final PreferredSizeWidget? bottom;
  final List<Widget> extraActions; // Left-side actions (gear, notifications, cart)
  final Widget? centerWidget; // Center widget (sandwich menu)
  const NvAppBar({
    super.key,
    required this.title,
    this.titleWidget,
    this.centerTitle = true,
    this.showBack = false,
    this.tickerVisible = true, // Default true for backward compatibility/during transition
    this.bottom,
    this.extraActions = const [],
    this.centerWidget,
  });

  static const double tickerHeight = 54;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (tickerVisible ? tickerHeight : 0) + (bottom?.preferredSize.height ?? 0));

  List<String> _messages(AppState app) {
    final es = app.tickerEs.value;
    final en = app.tickerEn.value;
    final isEs = app.languageCode.value == 'es';
    
    // Determine max length to ensure we cover all messages
    final count = es.length > en.length ? es.length : en.length;
    final List<String> result = [];

    for (int i = 0; i < count; i++) {
      final String sEs = (i < es.length) ? es[i] : '';
      final String sEn = (i < en.length) ? en[i] : '';
      
      if (isEs) {
        // Show Spanish, or fallback to English if Spanish is empty
        if (sEs.trim().isNotEmpty) {
          result.add(sEs);
        } else if (sEn.trim().isNotEmpty) {
          result.add(sEn);
        }
      } else {
        // Show English, or fallback to Spanish if English is empty (rare but possible)
        if (sEn.trim().isNotEmpty) {
          result.add(sEn);
        } else if (sEs.trim().isNotEmpty) {
          result.add(sEs);
        }
      }
    }
    return result;
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
      if (normalized.startsWith('nina verde -')) {
        visibleTitle = visibleTitle.replaceFirst(RegExp(r'nina verde -', caseSensitive: false), 'Niña Verde -');
      } else {
        visibleTitle = visibleTitle.replaceFirst(RegExp(r'nina verde-', caseSensitive: false), 'Niña Verde-');
      }
    } else if (!hasCorrectPrefix) {
      visibleTitle = 'Niña Verde - $visibleTitle';
    }

    // Build custom title with center widget if provided
    Widget? customTitle;
    if (centerWidget != null) {
      customTitle = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Left-side actions
          ...extraActions,
          // Spacer to push center widget to middle
          const Spacer(),
          // Center widget (sandwich menu)
          centerWidget!,
          // Spacer to balance layout
          const Spacer(),
        ],
      );
    }

    return AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Seamless match
      elevation: 0, // Remove shadow for flat continuity
      title: customTitle ?? (titleWidget ??
          TranslatedText(
            visibleTitle,
            style: const TextStyle(fontWeight: FontWeight.w700),
          )),
      centerTitle: customTitle != null ? false : centerTitle,
      automaticallyImplyLeading: showBack,
      actions: customTitle != null 
          ? [
              // Right-side toggles only when using custom layout
              const NvLanguageToggle(),
              const NvCurrencyToggle(),
              const NvThemeToggle(),
            ]
          : [
              // Original layout: extraActions + toggles
              ...extraActions,
              const NvLanguageToggle(),
              const NvCurrencyToggle(),
              const NvThemeToggle(),
            ],
      bottom: !tickerVisible 
          ? bottom 
          : PreferredSize(
              preferredSize: Size.fromHeight(tickerHeight + (bottom?.preferredSize.height ?? 0)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   if (bottom != null) bottom!,
                  SizedBox(
                      height: tickerHeight,
                      child: ValueListenableBuilder<bool>(
                        valueListenable: app.showTicker,
                        builder: (_, show, __) {
                          if (!show) return const SizedBox.shrink();

                          return ValueListenableBuilder<String>(
                            valueListenable: app.languageCode,
                            builder: (_, langCode, __) {
                              // FIX: Listen to message list changes!
                              return ValueListenableBuilder<List<String>>(
                                valueListenable: app.tickerEs,
                                builder: (_, esList, __) => ValueListenableBuilder<List<String>>(
                                  valueListenable: app.tickerEn,
                                  builder: (_, enList, __) {
                                      final msgs = _messages(app);
                                      if (msgs.isEmpty) {
                                         return GestureDetector(
                                            onLongPress: () {
                                              if (app.isManager.value) {
                                                Navigator.pushNamed(context, '/ticker-settings');
                                              }
                                            },
                                            child: const SizedBox(height: tickerHeight),
                                          );
                                      }
                                      return ValueListenableBuilder<double>(
                                        valueListenable: app.tickerSpeedPx,
                                        builder: (_, spx, __) => ValueListenableBuilder<TickerDirection>(
                                          valueListenable: app.tickerDirection,
                                          builder: (_, direction, __) => TickerBand(
                                            height: tickerHeight,
                                            laneColor: laneColor,
                                            railColor: railColor,
                                            textColor: textColor,
                                            messages: msgs,
                                            speedPxPerSec: spx,
                                            direction: direction,
                                            onLongPress: () {
                                              if (app.isManager.value) {
                                                Navigator.pushNamed(context, '/ticker-settings');
                                              }
                                            },
                                          ),
                                        ),
                                      );
                                  },
                                ),
                              );
                            },
                          );
                        },
                      ),
                   ),
                ],
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
              onPressed: () {
                app.languageCode.value = next;
                UserPrefsService.saveLanguage(next);
              },
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
            onPressed: () {
              app.currencyCode.value = next;
              UserPrefsService.saveCurrency(next);
            },
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
          onPressed: () {
            final next = isDark ? ThemeMode.light : ThemeMode.dark;
            app.themeMode.value = next;
            UserPrefsService.saveThemeMode(next);
          },
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

class TickerBand extends StatefulWidget {
  final List<String> messages;
  final double speedPxPerSec;
  final double height;
  final Color laneColor;
  final Color railColor;
  final Color textColor;
  final TickerDirection direction;
  final VoidCallback? onLongPress;

  const TickerBand({
    super.key,
    required this.messages,
    required this.speedPxPerSec,
    required this.height,
    required this.laneColor,
    required this.railColor,
    required this.textColor,
    this.direction = TickerDirection.rtl,
    this.onLongPress,
  });

  @override
  State<TickerBand> createState() => _TickerBandState();
}

class _TickerBandState extends State<TickerBand> with TickerProviderStateMixin {
  // Horizontal Scroll
  late final AnimationController _scrollCtrl;
  Duration _period = const Duration(seconds: 20);
  double _contentWidth = 400;
  String _joined = '';
  static const _sep = '     •     ';

  // Vertical/Fade Cycling
  late final AnimationController _cycleController; // Replaces _cycleTimer
  int _currentIndex = 0;

  static const double _brownTopFrac = 0.09;
  static const double _brownBottomFrac = 0.09;
  static const double _orangePadV = 9.0;

  @override
  void initState() {
    super.initState();
    _scrollCtrl = AnimationController(vsync: this);
    _cycleController = AnimationController(vsync: this); // No duration yet
    _initMode();
  }

  @override
  void didUpdateWidget(covariant TickerBand oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.messages, widget.messages) ||
        (oldWidget.speedPxPerSec - widget.speedPxPerSec).abs() > 0.1 || // Strict equality might fail floating point
        oldWidget.height != widget.height ||
        oldWidget.textColor != widget.textColor ||
        oldWidget.direction != widget.direction) {
      _initMode();
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _cycleController.dispose();
    super.dispose();
  }

  void _initMode() {
    _scrollCtrl.stop();
    _cycleController.stop(); 
    // No more timer to cancel

    if (widget.messages.isEmpty) return;

    switch (widget.direction) {
      case TickerDirection.ltr:
      case TickerDirection.rtl:
        _initHorizontal();
        break;
      case TickerDirection.ttb:
      case TickerDirection.btt:
      case TickerDirection.fade:
        _initCycling();
        break;
    }
  }

  // --- Horizontal Logic ---
  void _initHorizontal() {
    final rawMsgs = widget.messages.where((m) => m.trim().isNotEmpty).toList();
    final msgs = rawMsgs.isEmpty ? [''] : rawMsgs.map((m) => _replaceDynamicTokens(m)).toList();
    final base = msgs.join(_sep);
    _joined = '$_sep$base$_sep';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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
          (_contentWidth / widget.speedPxPerSec).clamp(1, 1200).toDouble();
      _period = Duration(milliseconds: (seconds * 1000).round());

      _scrollCtrl
        ..reset()
        ..repeat(period: _period);
      setState(() {});
    });
  }

  // --- Cycling Logic (Vertical/Fade) ---
  void _initCycling() {
    // Basic setup 
    if (_currentIndex >= widget.messages.length) {
      _currentIndex = 0;
    }
    
    // Calculate One-Time Duration based on current speed
    // 80 px/sec (FAST) -> ?? ms
    // 10 px/sec (SLOW) -> ?? ms
    // Formula: (Base Time * Scale) / Speed
    // e.g. Base 4000ms. 
    // Speed 80: 4000 * (77/80) ~= 3850 ms
    // Speed 10: 4000 * (77/10) ~= 30800 ms
    final durationMs = (4000 * (77.1 / widget.speedPxPerSec)).clamp(500, 20000).toInt();

    _cycleController.duration = Duration(milliseconds: durationMs);

    // If not already running, start the loop
    if (!_cycleController.isAnimating) {
        _cycleController.repeat(); // 0 -> 1 -> 0 -> 1...
        // But wait, repeat() just animates value. We need an ACTION at the end of the duration.
        // We can listen to status listener or use a periodic listener?
        // Actually, for TickerProviderStateMixin and simplicity:
        // Why not just use `repeat` and listen for value wraparounds? 
        // Or cleaner: `_cycleController.forward()` then completion listener resets and starts again.
        
        // Let's use `repeat` and invoke a callback on each cycle completion.
        // HOWEVER, standard AnimationController.repeat doesn't have an "onCycle" callback easily without a StatusListener that might fire oddly.
        // Safer approach: _playCycle() -> forward -> onComplete -> setState -> _playCycle()
        _playCycle();
    } else {
        // If already running, we just updated duration above! 
        // But changing duration mid-flight might jump the value 
        // e.g. if we were at 0.5 of 10s (5s), and change duration to 2s, we are now at >1.0? 
        // Flutter handles this gracefully usually by scaling.
        // To be safe for "instant" feel:
        _playCycle(); 
    }
  }

  void _playCycle() {
    _cycleController.stop(); 
    // Re-calc duration every cycle start ensures it picks up latest speed
    final durationMs = (4000 * (77.1 / widget.speedPxPerSec)).clamp(500, 20000).toInt();
    _cycleController.duration = Duration(milliseconds: durationMs);
    
    _cycleController.forward(from: 0).then((_) {
      if (!mounted) return;
      // Cycle complete, switch text
      setState(() {
        _currentIndex = (_currentIndex + 1) % widget.messages.length;
      });
      // recurse
      _playCycle();
    });
  }

  String _replaceDynamicTokens(String input) {
    if (input.isEmpty) return input;
    
    // User Info
    final user = FirebaseAuth.instance.currentUser;
    String name = user?.displayName ?? '';
    if (name.isEmpty) {
        name = user?.email?.split('@')[0] ?? 'User';
    }
    
    String fName = name;
    String lName = '';
    if (name.contains(' ')) {
      fName = name.split(' ')[0];
      lName = name.split(' ').sublist(1).join(' ');
    }

    final now = DateTime.now();
    
    // Get current language code
    String lang = 'en';
    try {
      final app = AppState.of(context, listen: false);
      lang = app.languageCode.value;
    } catch (_) {}

    // Use intl for localized date names
    // Note: Ensure initializeDateFormatting is called if supporting many locales, 
    // but standard set usually works or defaults to English if data missing.
    String dayName;
    String monthName;
    try {
      dayName = intl.DateFormat('EEEE', lang).format(now);
      monthName = intl.DateFormat('MMMM', lang).format(now);
      // Title case because some locales (like es) return lowercase
      if (dayName.isNotEmpty) dayName = dayName[0].toUpperCase() + dayName.substring(1);
      if (monthName.isNotEmpty) monthName = monthName[0].toUpperCase() + monthName.substring(1);
    } catch (_) {
      // Fallback
      dayName = intl.DateFormat('EEEE').format(now);
      monthName = intl.DateFormat('MMMM').format(now);
    }

    String res = input;
    res = res.replaceAll('USER_NAME', name);
    res = res.replaceAll('USER_F_NAME', fName);
    res = res.replaceAll('USER_L_NAME', lName);
    res = res.replaceAll('_YEAR_', now.year.toString());
    res = res.replaceAll('_DATE_', now.day.toString());
    res = res.replaceAll('_DAY_', dayName);
    res = res.replaceAll('_MONTH_', monthName);
    
    return res;
  }

  InlineSpan _richSpan(String txt) {
    final base = TextStyle(
      fontWeight: FontWeight.w400,
      color: widget.textColor,
      letterSpacing: 0.2,
      fontSize: 16,
      height: 1.25,
    );
    final boldStyle = base.copyWith(fontWeight: FontWeight.w700);

    final parts = txt.split('_');
    final children = <InlineSpan>[];

    for (int i = 0; i < parts.length; i++) {
      final part = parts[i];
      if (part.isEmpty) continue;
      if (i % 2 == 0) {
        children.add(TextSpan(text: part, style: base));
      } else {
        if (part == 'VYBZ!') {
          children.add(TextSpan(
            text: 'VYBZ!',
            style: base.copyWith(
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w800,
              shadows: const [Shadow(color: Colors.white70, blurRadius: 6)],
            ),
          ));
        } else {
          children.add(TextSpan(text: part, style: boldStyle));
        }
      }
    }
    return TextSpan(children: children);
  }

  @override
  Widget build(BuildContext context) {
    final topH = widget.height * _brownTopFrac;
    final botH = widget.height * _brownBottomFrac;
    final coreH = widget.height - topH - botH;

    Widget content;
    switch (widget.direction) {
      case TickerDirection.ltr:
      case TickerDirection.rtl:
        content = _buildHorizontal(coreH);
        break;
      case TickerDirection.ttb:
      case TickerDirection.btt:
        content = _buildVertical(coreH);
        break;
      case TickerDirection.fade:
        content = _buildFade(coreH);
        break;
    }

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
                child: ClipRect(child: content),
              ),
            ),
            Container(height: botH, width: double.infinity, color: widget.railColor),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontal(double h) {
    return AnimatedBuilder(
      animation: _scrollCtrl,
      builder: (_, __) {
        double dx;
        if (widget.direction == TickerDirection.ltr) {
           // Move right: starts at -width, goes to 0
           final prog = _scrollCtrl.value;
           dx = -_contentWidth + (prog * _contentWidth);
        } else {
           // RTL (Standard): starts at 0, goes to -width
           final prog = _scrollCtrl.value;
           dx = -(prog * _contentWidth);
        }

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
              copy(dx + _contentWidth), // Next copy
              if (widget.direction == TickerDirection.ltr) copy(dx - _contentWidth), // Prev copy for LTR loop
            ],
          ),
        );
      },
    );
  }

  Widget _buildVertical(double h) {
    if (widget.messages.isEmpty) return const SizedBox.shrink();
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      transitionBuilder: (child, animation) {
        final isEntering = child.key == ValueKey<int>(_currentIndex);
        final direction = widget.direction == TickerDirection.btt ? 1.0 : -1.0;

        // If Entering: Slide IN from Bottom (if btt) or Top (if ttb)
        // If Exiting: Slide OUT to Top (if btt) or Bottom (if ttb)
        
        // Offset(0, 1) = Below
        // Offset(0, -1) = Above
        
        late Offset begin, end;

        if (isEntering) {
             // Enter from:
             // BTT: Bottom (0, 1) -> Center (0, 0)
             // TTB: Top (0, -1) -> Center (0, 0)
             begin = Offset(0, direction);
             end = Offset.zero;
        } else {
             // Exit to:
             // BTT: Center (0, 0) -> Top (0, -1)
             // TTB: Center (0, 0) -> Bottom (0, 1)
             begin = Offset.zero;
             // Note: SlideTransition position maps 0->1 animation to offset.
             // But for exit, the animation goes 1->0? No, AnimatedSwitcher runs forward for new, reverse for old?
             // Actually standard AnimatedSwitcher runs correct animation for both if specified.
             // But simpler to just define the flow:
             // Everything flow UP (BTT) or DOWN (TTB).
             
             // Let's use a simpler SlideTransition for both.
             // If BTT: We want flow UP. 
             //   Incoming: starts at (0, 1), ends at (0, 0)
             //   Outgoing: starts at (0, 0), ends at (0, -1)
             
             // Warning: transitionBuilder applies to *both* with same animation controller (0->1).
             // If we want different paths, we might need conditional offset.
             end = Offset(0, -direction); 
        }

        return SlideTransition(
          position: Tween<Offset>(
             begin: isEntering ? Offset(0, direction) : Offset.zero,
             end: isEntering ? Offset.zero : Offset(0, -direction),
          ).animate(animation),
          child: child,
        );
      },
      child: Center(
        key: ValueKey<int>(_currentIndex),
        child: RichText(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          text: _richSpan(_replaceDynamicTokens(widget.messages[_currentIndex])),
        ),
      ),
    );
  }

  Widget _buildFade(double h) {
    if (widget.messages.isEmpty) return const SizedBox.shrink();
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 800),
      child: Center(
        key: ValueKey<int>(_currentIndex),
        child: RichText(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          text: _richSpan(_replaceDynamicTokens(widget.messages[_currentIndex])),
        ),
      ),
    );
  }
}

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

class YouTubePopupWebView extends StatefulWidget {
  final String videoId;
  const YouTubePopupWebView({super.key, required this.videoId});

  @override
  State<YouTubePopupWebView> createState() => _YouTubePopupWebViewState();
}

class _YouTubePopupWebViewState extends State<YouTubePopupWebView> {
  late final WebViewController _videoController;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    _videoController = WebViewController.fromPlatformCreationParams(params);

    if (_videoController.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (_videoController.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    final String html = '''
      <!DOCTYPE html>
      <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
          <style>
            body { margin: 0; padding: 0; background-color: black; overflow: hidden; }
            .video-container { position: relative; width: 100vw; height: 100vh; }
            iframe { width: 100%; height: 100%; border: none; }
          </style>
        </head>
        <body>
          <div class="video-container">
            <iframe id="player" 
                    src="https://www.youtube.com/embed/${widget.videoId}?autoplay=1&mute=0&controls=1&showinfo=0&rel=0&loop=1&playlist=${widget.videoId}&playsinline=1" 
                    allow="autoplay; encrypted-media; picture-in-picture" 
                    allowfullscreen>
            </iframe>
          </div>
        </body>
      </html>
    ''';

    _videoController
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _ready = true);
          },
        ),
      )
      ..loadHtmlString(html);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width * 0.92;
    final h = w * 9 / 16;
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 20)],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              WebViewWidget(controller: _videoController),
              if (!_ready)
                const Center(
                    child: CircularProgressIndicator(color: Colors.white)),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
