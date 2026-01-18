// lib/screens/document_webview.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:webview_flutter/webview_flutter.dart';
// import '../main.dart'; // Unused
import '../state/app_state.dart';
import '../theme/brand_colors.dart'; // AppState + NvAppBar
import '../widgets/nv_widgets.dart';

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
  bool? _activeIsEs;
  String? _pendingAsset;

  String _t(BuildContext context, String key) {
    final es = AppState.of(context).languageCode.value == 'es';
    const esMap = {
      'back': 'Regresar a inicio',
      'caption': 'Documentacion legal de Niña Verde',
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
    final isEs = appState.languageCode.value == 'es';
    final path = isEs ? widget.assetEs : widget.assetEn;

    if ((path == _activeAsset && _activeIsEs == isEs) ||
        path == _pendingAsset) {
      return;
    }

    _pendingAsset = path;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadLocalizedDoc(path, isEs);
    });
  }

  String _applyDocLanguage(String html, bool isEs, String title) {
    final lang = isEs ? 'es' : 'en';
    final css = '''
<style>
.lang-toggle{display:none !important;}
</style>
''';
    final script = '''
<script>
(function(){
  try {
    document.documentElement.setAttribute('lang', '$lang');
    var es = document.getElementById('sec-es');
    var en = document.getElementById('sec-en');
    if (es) es.classList.remove('active');
    if (en) en.classList.remove('active');
    var target = document.getElementById('${isEs ? 'sec-es' : 'sec-en'}');
    if (target) target.classList.add('active');
    var h1 = document.querySelector('.title-wrap');
    if (h1) h1.textContent = ${jsonEncode(title)};
    var helpP = document.querySelector('.footer p:first-child');
    if (helpP) {
      helpP.innerHTML = ( $isEs ? '¿Necesita ayuda? ' : 'Need help? ') + '<a href="mailto:info@nicaraguaninaverde.com">info@nicaraguaninaverde.com</a>';
    }
    var copyrightP = document.querySelector('.footer p:nth-child(2)');
    if (copyrightP) {
      copyrightP.textContent = '© 2025 Nicaragua Niña Verde. ' + ( $isEs ? 'Todos los derechos reservados.' : 'All rights reserved.');
    }
  } catch (e) {}
})();
</script>
''';

    var out = html;
    if (out.contains('</head>')) {
      out = out.replaceFirst('</head>', '$css</head>');
    } else {
      out = '$css$out';
    }
    if (out.contains('</body>')) {
      out = out.replaceFirst('</body>', '$script</body>');
    } else {
      out = '$out$script';
    }
    return out;
  }

  Future<void> _loadLocalizedDoc(String path, bool isEs) async {
    if (path == _activeAsset && _activeIsEs == isEs) {
      _pendingAsset = null;
      return;
    }

    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final raw = await DefaultAssetBundle.of(context).loadString(path);

      // Verify if this is still the asset we need
      if (mounted) {
        final currentIsEs = AppState.of(context).languageCode.value == 'es';
        final currentPath = currentIsEs ? widget.assetEs : widget.assetEn;
        if (path != currentPath) return;
      }

      final title = isEs ? widget.titleEs : widget.titleEn;
      final html = _applyDocLanguage(raw, isEs, title);
      if (mounted) {
        setState(() {
          _htmlContent = html;
          _activeAsset = path;
          _activeIsEs = isEs;
          _pendingAsset = null;
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
          _activeIsEs = isEs;
          _pendingAsset = null;
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
    final appState = AppState.of(context);
    return ValueListenableBuilder<String>(
      valueListenable: appState.languageCode,
      builder: (context, code, _) {
        final isEs = code == 'es';
        final title = isEs ? widget.titleEs : widget.titleEn;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final backLabel = _t(context, 'back');
        final caption = _t(context, 'caption');
        final targetAsset = isEs ? widget.assetEs : widget.assetEn;
        if (targetAsset != _activeAsset || _activeIsEs != isEs) {
          _scheduleLocalizedLoad();
        }

        return Scaffold(
          appBar: NvAppBar(title: title, showBack: true),
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
                              color:
                                  Colors.black.withValues(alpha: isDark ? 0.3 : 0.12),
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
                                              .withValues(alpha: 0.7),
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
                        child: Material(
                          color: Theme.of(context).colorScheme.surface,
                          elevation: isDark ? 14 : 8,
                          borderRadius: BorderRadius.circular(20),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            children: [
                              WebViewWidget(controller: _controller),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: _isLoading
                                    ? Container(
                                        key: const ValueKey('loading_overlay'),
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surface,
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const CircularProgressIndicator(),
                                              const SizedBox(height: 12),
                                              Text(_t(context, 'loading')),
                                            ],
                                          ),
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
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

