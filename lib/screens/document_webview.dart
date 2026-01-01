// lib/screens/document_webview.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

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

  @override
  void initState() {
    super.initState();

    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = const PlatformWebViewControllerCreationParams();
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (req) => NavigationDecision.navigate,
      ));

    // ✅ Enable iOS-specific features
    if (controller.platform is WebKitWebViewController) {
      final iosController = controller.platform as WebKitWebViewController;
      iosController.setAllowsBackForwardNavigationGestures(true);
    }

    _controller = controller;
    _loadLocalizedDoc();
  }

  Future<void> _loadLocalizedDoc() async {
    final locale = Localizations.localeOf(context).languageCode;
    final path = locale == 'es' ? widget.assetEs : widget.assetEn;

    final html = await DefaultAssetBundle.of(context).loadString(path);
    await _controller.loadHtmlString(html, baseUrl: 'asset:///$path');
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final title = locale == 'es' ? widget.titleEs : widget.titleEn;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: WebViewWidget(controller: _controller),
    );
  }
}
