import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../config.dart';
import 'login_screen.dart';

class WebsiteStorefrontScreen extends StatefulWidget {
  const WebsiteStorefrontScreen({super.key});

  @override
  State<WebsiteStorefrontScreen> createState() => _WebsiteStorefrontScreenState();
}

class _WebsiteStorefrontScreenState extends State<WebsiteStorefrontScreen> {
  late final WebViewController _controller;
  var _loadingProgress = 0;

  String get _storefrontUrl {
    final origin = baseUrl
        .replaceAll('/digitalcard/api', '')
        .replaceAll('/api', '');
    return origin.endsWith('/') ? origin : '$origin/';
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) setState(() => _loadingProgress = progress);
          },
          onNavigationRequest: _handleNavigation,
        ),
      )
      ..loadRequest(Uri.parse(_storefrontUrl));
  }

  NavigationDecision _handleNavigation(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;

    if (uri.path.endsWith('/Account/Login')) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return NavigationDecision.prevent;
    }

    if (uri.scheme == 'tel' ||
        uri.scheme == 'mailto' ||
        uri.host == 'wa.me' ||
        uri.host.endsWith('whatsapp.com')) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
      return NavigationDecision.prevent;
    }

    return NavigationDecision.navigate;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_loadingProgress < 100)
              LinearProgressIndicator(value: _loadingProgress / 100),
          ],
        ),
      ),
    );
  }
}