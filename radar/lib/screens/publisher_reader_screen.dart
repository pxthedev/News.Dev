import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../l10n/app_copy.dart';
import '../services/platform_services.dart';
import '../theme/tokens.dart';

/// Leitura da matéria na página do próprio veículo, dentro do app.
///
/// Veículos sem licença de texto aberto (g1, CNN Brasil, R7…) não têm o texto
/// guardado no app; aqui o leitor vê a página original, com a autoria e os
/// anúncios de quem publicou, sem sair do aplicativo.
class PublisherReaderScreen extends StatefulWidget {
  const PublisherReaderScreen(
      {super.key, required this.url, required this.publisher});

  final Uri url;
  final String publisher;

  /// Abre o leitor; na web (sem WebView) abre a página numa nova aba.
  static Future<void> open(BuildContext context, Uri url, String publisher) {
    if (kIsWeb) return PlatformServices.instance.openUrl(url.toString());
    return Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PublisherReaderScreen(url: url, publisher: publisher),
    ));
  }

  @override
  State<PublisherReaderScreen> createState() => _PublisherReaderScreenState();
}

class _PublisherReaderScreenState extends State<PublisherReaderScreen> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (value) {
          if (mounted) setState(() => _progress = value);
        },
        onWebResourceError: (error) {
          if (error.isForMainFrame ?? true) {
            if (mounted) setState(() => _failed = true);
          }
        },
        // Só páginas web; esquemas como intent:// e market:// ficam de fora.
        onNavigationRequest: (request) {
          final uri = Uri.tryParse(request.url);
          final web = uri != null &&
              (uri.scheme == 'https' || uri.scheme == 'http');
          return web ? NavigationDecision.navigate : NavigationDecision.prevent;
        },
      ))
      ..loadRequest(widget.url);
  }

  void _openOutside() =>
      PlatformServices.instance.openUrl(widget.url.toString());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.publisher, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: context.tr('Abrir no navegador'),
            icon: const Icon(Icons.open_in_new),
            onPressed: _openOutside,
          ),
        ],
        bottom: _progress < 100 && !_failed
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                    value: _progress == 0 ? null : _progress / 100,
                    minHeight: 2),
              )
            : null,
      ),
      body: _failed
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(RSpace.screen),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(context.tr('Não foi possível abrir a página.'),
                        style: RText.body, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _failed = false;
                          _progress = 0;
                        });
                        _controller.loadRequest(widget.url);
                      },
                      child: Text(context.tr('Tentar de novo')),
                    ),
                    TextButton(
                      onPressed: _openOutside,
                      child: Text(context.tr('Abrir no navegador')),
                    ),
                  ],
                ),
              ),
            )
          : WebViewWidget(controller: _controller),
    );
  }
}
