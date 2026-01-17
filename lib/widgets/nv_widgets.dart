// lib/widgets/nv_widgets.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../state/app_state.dart';

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
      if (normalized.startsWith('nina verde -')) {
        visibleTitle = visibleTitle.replaceFirst(RegExp(r'nina verde -', caseSensitive: false), 'Niña Verde -');
      } else {
        visibleTitle = visibleTitle.replaceFirst(RegExp(r'nina verde-', caseSensitive: false), 'Niña Verde-');
      }
    } else if (!hasCorrectPrefix) {
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
              builder: (_, spx, __) => TickerBand(
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

class TickerBand extends StatefulWidget {
  final List<String> messages;
  final double speedPxPerSec;
  final double height;
  final Color laneColor;
  final Color railColor;
  final Color textColor;
  final VoidCallback? onLongPress;

  const TickerBand({
    super.key,
    required this.messages,
    required this.speedPxPerSec,
    required this.height,
    required this.laneColor,
    required this.railColor,
    required this.textColor,
    this.onLongPress,
  });

  @override
  State<TickerBand> createState() => _TickerBandState();
}

class _TickerBandState extends State<TickerBand>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  Duration _period = const Duration(seconds: 20);
  double _contentWidth = 400;
  late String _joined;
  static const _sep = '     •     ';

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
  void didUpdateWidget(covariant TickerBand oldWidget) {
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
      if (!mounted) return;
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
