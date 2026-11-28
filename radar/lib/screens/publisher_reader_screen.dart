import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../l10n/app_copy.dart';
import '../services/article_text.dart';
import '../services/platform_services.dart';
import '../theme/tokens.dart';
import 'full_article_screen.dart';

/// Modo leitura pela WebView, para veículos que bloqueiam pedidos fora de um
/// navegador (ex.: Band). A página carrega escondida, o texto da matéria é
/// extraído no aparelho e aberto no leitor do app. Se a página não tiver um
/// texto reconhecível, ela mesma é mostrada.
class PublisherReaderScreen extends StatefulWidget {
  const PublisherReaderScreen({
    super.key,
    required this.url,
    required this.publisher,
    required this.articleId,
    required this.title,
  });

  final Uri url;
  final String publisher;
  final String articleId;
  final String title;

  /// Abre o leitor; na web (sem WebView) abre a página numa nova aba.
  static Future<void> open(BuildContext context,
      {required Uri url,
      required String publisher,
      required String articleId,
      required String title}) {
    if (kIsWeb) return PlatformServices.instance.openUrl(url.toString());
    return Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PublisherReaderScreen(
          url: url, publisher: publisher, articleId: articleId, title: title),
    ));
  }

  @override
  State<PublisherReaderScreen> createState() => _PublisherReaderScreenState();
}

class _PublisherReaderScreenState extends State<PublisherReaderScreen> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _failed = false;
  // Enquanto true, a página fica escondida atrás do carregamento.
  bool _extracting = true;
  Timer? _giveUp;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (value) {
          if (mounted) setState(() => _progress = value);
        },
        onPageFinished: (_) => _extract(),
        onWebResourceError: (error) {
          if (error.isForMainFrame ?? true) {
            if (mounted) setState(() => _failed = true);
          }
        },
        // Só páginas web; esquemas como intent:// e market:// ficam de fora.
        onNavigationRequest: (request) {
          final uri = Uri.tryParse(request.url);
          final web =
              uri != null && (uri.scheme == 'https' || uri.scheme == 'http');
          return web ? NavigationDecision.navigate : NavigationDecision.prevent;
        },
      ))
      ..loadRequest(widget.url);
    // Página que nunca termina de carregar (anúncios): tenta com o que já veio.
    _giveUp = Timer(const Duration(seconds: 15), _extract);
  }

  @override
  void dispose() {
    _giveUp?.cancel();
    super.dispose();
  }

  Future<void> _extract() async {
    if (!_extracting || !mounted) return;
    var paragraphs = const <String>[];
    try {
      var result = await _controller
          .runJavaScriptReturningResult(ArticleText.extractScript());
      // Android devolve a string do JSON entre aspas; iOS, a string pura.
      if (result is String) result = jsonDecode(result);
      if (result is String) result = jsonDecode(result);
      if (result is List) paragraphs = result.whereType<String>().toList();
    } on Object {
      paragraphs = const [];
    }
    if (!mounted || !_extracting) return;
    if (paragraphs.isEmpty) {
      // Página ainda carregando: espera o fim; senão, mostra a página.
      if (_progress < 100 && (_giveUp?.isActive ?? false)) return;
      _giveUp?.cancel();
      setState(() => _extracting = false);
      return;
    }
    _giveUp?.cancel();
    _extracting = false;
    await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
      builder: (_) => FullArticleScreen(
        articleId: widget.articleId,
        title: widget.title,
        paragraphs: paragraphs,
        publisher: (name: widget.publisher, url: widget.url),
      ),
    ));
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
          : Stack(
              children: [
                // A WebView precisa estar na árvore para carregar a página.
                Opacity(
                  opacity: _extracting ? 0 : 1,
                  child: WebViewWidget(controller: _controller),
                ),
                if (_extracting)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 12),
                        Text(context.tr('Carregando o texto…'),
                            style: RText.footnote),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
