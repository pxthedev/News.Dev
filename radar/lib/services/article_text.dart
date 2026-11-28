import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

/// Modo leitura: baixa a página da matéria no próprio aparelho e extrai só os
/// parágrafos do texto, como o leitor do Safari. Nada é guardado no servidor do
/// app; o texto vem do veículo no momento da leitura.
class ArticleText {
  ArticleText({http.Client? client}) : _client = client ?? http.Client();

  static final instance = ArticleText();

  final http.Client _client;
  final _cache = <String, List<String>>{};

  /// Parágrafos da matéria em [url]; lista vazia quando a página não tem um
  /// texto reconhecível (aí o app abre a página do veículo).
  Future<List<String>> fetch(Uri url) async {
    final key = url.toString();
    final cached = _cache[key];
    if (cached != null) return cached;
    final response = await _client.get(url, headers: const {
      'Accept': 'text/html',
      'User-Agent':
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148',
    }).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) return const [];
    final paragraphs = extract(_decode(response));
    if (paragraphs.isNotEmpty) _cache[key] = paragraphs;
    return paragraphs;
  }

  static String _decode(http.Response response) {
    final type = response.headers['content-type'] ?? '';
    final charset =
        RegExp(r'charset=([\w-]+)', caseSensitive: false).firstMatch(type);
    final encoding =
        charset == null ? null : Encoding.getByName(charset.group(1));
    if (encoding != null && encoding != utf8) {
      return encoding.decode(response.bodyBytes);
    }
    return utf8.decode(response.bodyBytes, allowMalformed: true);
  }

  /// Mesma limpeza de [extract], para rodar dentro da WebView (páginas que
  /// bloqueiam pedidos fora de um navegador). Devolve um JSON com os parágrafos.
  static String extractScript() => '''
(function () {
  var noise = 'script,style,noscript,svg,figure,figcaption,aside,nav,header,footer,form,button,iframe';
  var doc = document.cloneNode(true);
  doc.querySelectorAll(noise).forEach(function (n) { n.remove(); });
  function size(el) {
    var t = 0; el.querySelectorAll('p').forEach(function (p) { t += p.textContent.trim().length; });
    return t;
  }
  var root = null, best = 0;
  doc.querySelectorAll('article').forEach(function (a) { var n = size(a); if (n > best) { best = n; root = a; } });
  if (best < 600) root = doc.body;
  var re = new RegExp(${jsonEncode(_boilerplate.pattern)}, 'i');
  var out = [], seen = {}, total = 0;
  if (root) root.querySelectorAll('p').forEach(function (p) {
    var t = p.textContent.replace(/\\s+/g, ' ').trim();
    if (t.length < 60 || re.test(t) || seen[t] || total > 60000) return;
    seen[t] = true; out.push(t); total += t.length;
  });
  return JSON.stringify(out.length >= 3 && total >= 600 ? out : []);
})();
''';

  static final _boilerplate = RegExp(
    r'^(\W*\s*)?(leia (também|mais)|veja (também|mais)|siga o|siga a|siga as|'
    r'assine|inscreva-se|receba as|clique aqui|compartilhe|publicidade|'
    r'newsletter|participe do canal|fique por dentro|para saber tudo|'
    r'análises, entrevistas e as notícias)|todos os direitos reservados|'
    r'utilizamos cookies|'
    r'usamos cookies|[—–-]\s*(foto|imagem|reprodução)\s*:',
    caseSensitive: false,
  );

  static const _noise =
      'script, style, noscript, svg, figure, figcaption, aside, nav, header, '
      'footer, form, button, iframe';

  /// Parágrafos do texto principal: os `<p>` dentro de `<article>` (ou da
  /// página toda), sem legendas, menus e chamadas de "leia também".
  static List<String> extract(String source) {
    final document = html.parse(source);
    for (final node in document.querySelectorAll(_noise)) {
      node.remove();
    }
    final dom.Element? root = _bestArticle(document) ?? document.body;
    if (root == null) return const [];
    final paragraphs = <String>[];
    final seen = <String>{};
    var length = 0;
    for (final p in root.querySelectorAll('p')) {
      // O \s do Dart também cobre o espaço não separável (&nbsp;).
      final text = p.text.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (text.length < 60 || _boilerplate.hasMatch(text)) continue;
      if (!seen.add(text)) continue;
      paragraphs.add(text);
      length += text.length;
      if (length > 60000) break;
    }
    // Menos que isso costuma ser só a chamada da matéria, não o texto.
    return paragraphs.length >= 3 && length >= 600 ? paragraphs : const [];
  }

  /// O `<article>` com mais texto em parágrafos (páginas trazem vários, como
  /// os cards de "leia também").
  static dom.Element? _bestArticle(dom.Document document) {
    dom.Element? best;
    var bestLength = 0;
    for (final article in document.querySelectorAll('article')) {
      final length = article
          .querySelectorAll('p')
          .fold<int>(0, (sum, p) => sum + p.text.trim().length);
      if (length > bestLength) {
        best = article;
        bestLength = length;
      }
    }
    return bestLength >= 600 ? best : null;
  }
}
