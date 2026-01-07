// lib/screens/document_webview.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';

import '../main.dart'; // AppState + NvAppBar

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadLocalizedDoc();
  }

  Future<void> _loadLocalizedDoc() async {
    final locale = Localizations.localeOf(context).languageCode;
    final path = locale == 'es' ? widget.assetEs : widget.assetEn;

    try {
      final html = await DefaultAssetBundle.of(context).loadString(path);
      if (mounted) {
        setState(() {
          _htmlContent = html;
          _controller.loadHtmlString(_htmlContent);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _htmlContent =
              '<html><body><p>Error loading content.</p></body></html>';
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

    return Scaffold(
      appBar: NvAppBar(title: title),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : WebViewWidget(controller: _controller),
    );
  }
}
