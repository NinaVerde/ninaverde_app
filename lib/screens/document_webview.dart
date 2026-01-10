// lib/screens/document_webview.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../theme/brand_colors.dart'; // AppState + NvAppBar

class DocumentWebView extends StatefulWidget {
  final String titleEn;
  final String titleEs;
  final String assetEn;
  final String assetEs;

  const DocumentWebView({
    super.key,
    required this.titleEn,
    required this.titleEs,
    required this.assetEn,
    required this.assetEs,
  });

  @override
  State<DocumentWebView> createState() => _DocumentWebViewState();
}

class _DocumentWebViewState extends State<DocumentWebView> {
  late final WebViewController _controller;
  String _htmlContent = '';
  bool _isLoading = true;
  String? _activeAsset;

  String _t(BuildContext context, String key) {
    final es = AppState.of(context).isSpanish.value;
    const esMap = {
      'back': 'Regresar a inicio',
      'caption': 'Documentación legal de Niña Verde',
      'loading': 'Cargando documento...',
    };
    const enMap = {
      'back': 'Back to login',
      'caption': 'Niña Verde legal documentation',
      'loading': 'Loading document...',
    };
    return (es ? esMap : enMap)[key]!;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleLocalizedLoad();
  }

  void _scheduleLocalizedLoad() {
    final appState = AppState.of(context);
    final path = appState.isSpanish.value ? widget.assetEs : widget.assetEn;
    if (path == _activeAsset) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadLocalizedDoc(path);
    });
  }

  Future<void> _loadLocalizedDoc(String path) async {
    if (path == _activeAsset) return;
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final html = await DefaultAssetBundle.of(context).loadString(path);
      if (mounted) {
        setState(() {
          _htmlContent = html;
          _activeAsset = path;
          _controller.loadHtmlString(_htmlContent);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _htmlContent =
              '<html><body><p>Error loading content.</p></body></html>';
          _activeAsset = path;
          _controller.loadHtmlString(_htmlContent);
          _isLoading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final title = appState.isSpanish.value ? widget.titleEs : widget.titleEn;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backLabel = _t(context, 'back');
    final caption = _t(context, 'caption');
    final scheme = Theme.of(context).colorScheme;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final targetAsset =
        appState.isSpanish.value ? widget.assetEs : widget.assetEn;
    if (targetAsset != _activeAsset) {
      _scheduleLocalizedLoad();
    }

    return Scaffold(
      appBar: NvAppBar(title: title),
      body: SafeArea(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      nvGreenDark,
                      nvDarkSurface,
                      Colors.black,
                    ]
                  : [
                      const Color(0xFFF6FFF6),
                      Theme.of(context).colorScheme.surface,
                      const Color(0xFFE0F2E3),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  switchInCurve: Curves.easeOutCubic,
                  transitionBuilder: (child, animation) {
                    final slide = Tween<Offset>(
                      begin: const Offset(0, -0.06),
                      end: Offset.zero,
                    ).animate(animation);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(position: slide, child: child),
                    );
                  },
                  child: Container(
                    key: ValueKey(title),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.3 : 0.12),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: () {
                            final nav = Navigator.of(context);
                            if (nav.canPop()) {
                              nav.pop();
                            } else {
                              nav.pushReplacementNamed('/login');
                            }
                          },
                          icon: const Icon(Icons.arrow_back_ios_new_rounded),
                          label: Text(backLabel),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                caption,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.7),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    switchInCurve: Curves.easeOutCubic,
                    transitionBuilder: (child, animation) {
                      final slide = Tween<Offset>(
                        begin: const Offset(0, 0.05),
                        end: Offset.zero,
                      ).animate(animation);
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(position: slide, child: child),
                      );
                    },
                    child: _isLoading
                        ? Center(
                            key: const ValueKey('loading'),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const CircularProgressIndicator(),
                                const SizedBox(height: 12),
                                Text(_t(context, 'loading')),
                              ],
                            ),
                          )
                        : Material(
                            key: ValueKey(_activeAsset ?? _htmlContent),
                            color: Theme.of(context).colorScheme.surface,
                            elevation: isDark ? 14 : 8,
                            borderRadius: BorderRadius.circular(20),
                            clipBehavior: Clip.antiAlias,
                            child: WebViewWidget(controller: _controller),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

