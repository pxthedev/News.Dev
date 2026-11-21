import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../data/models.dart';
import '../l10n/app_copy.dart';
import '../theme/tokens.dart';
import '../widgets/primitives.dart';

/// Leitor para publicações em que o feed não traz o conteúdo integral.
class PublisherReaderScreen extends StatefulWidget {
  const PublisherReaderScreen({
    super.key,
    required this.article,
    required this.sourceUrl,
    this.targetLanguage,
  });

  final Article article;
  final Uri sourceUrl;
  final String? targetLanguage;

  @override
  State<PublisherReaderScreen> createState() => _PublisherReaderScreenState();
}

class _PublisherReaderScreenState extends State<PublisherReaderScreen> {
  late final WebViewController _controller;
  late bool _translated = widget.targetLanguage != null;
  bool _loading = true;
  bool _error = false;
  Uri? _currentUri;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setBackgroundColor(RColors.bgBase)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) {
          final url = Uri.tryParse(request.url);
          return url != null &&
                  url.scheme == 'https' &&
                  url.host.isNotEmpty &&
                  url.userInfo.isEmpty
              ? NavigationDecision.navigate
              : NavigationDecision.prevent;
        },
        onPageStarted: (url) {
          _currentUri = Uri.tryParse(url);
          if (mounted) {
            setState(() {
              _loading = true;
              _error = false;
            });
          }
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onWebResourceError: (error) {
          if (error.isForMainFrame == true) _fail();
        },
        onHttpError: (error) {
          if (error.request?.uri == _currentUri) _fail();
        },
      ));
    _load();
  }

  void _fail() {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = true;
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    final uri = _translated
        ? Uri.https('translate.google.com', '/translate', {
            'sl': 'auto',
            'tl': widget.targetLanguage!,
            'u': widget.sourceUrl.toString(),
          })
        : widget.sourceUrl;
    try {
      await _controller.loadRequest(uri);
    } on Exception {
      _fail();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Matéria completa'))),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_loading) const LinearProgressIndicator(),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  WebViewWidget(controller: _controller),
                  if (_error)
                    ColoredBox(
                      color: RColors.bgBase,
                      child: Center(
                        child: EmptyState(
                          icon: Icons.article_outlined,
                          title: 'Não foi possível carregar a publicação.',
                          message: _translated
                              ? 'Você pode tentar abrir o texto original.'
                              : null,
                          actionLabel:
                              _translated ? 'Ver original' : 'Tentar de novo',
                          onAction: () {
                            if (_translated) {
                              setState(() => _translated = false);
                            }
                            _load();
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: RColors.bgCard,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "${context.tr('Fontes')} · ${widget.article.sourcesLabel}",
                      style: RText.footnote,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.targetLanguage != null && !_error)
                    TextButton(
                      onPressed: () {
                        setState(() => _translated = !_translated);
                        _load();
                      },
                      child: Text(context.tr(
                          _translated ? 'Ver original' : 'Traduzir página')),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
