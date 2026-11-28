import 'package:flutter_test/flutter_test.dart';
import 'package:radar/services/article_text.dart';

String _p(String text) =>
    '<p>$text Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod.</p>';

void main() {
  test('extrai os parágrafos do maior <article> e ignora o resto', () {
    final html = '''
<html><body>
<nav><p>${'Menu do site com muitos links e seções diferentes para navegar'}</p></nav>
<article class="leia-tambem">${_p('Chamada curta de outra matéria')}</article>
<article class="materia">
  <header><p>Cabeçalho com data e autor que não faz parte do texto da matéria</p></header>
  ${_p('Primeiro parágrafo da matéria sobre tecnologia.')}
  <figure><figcaption><p>Legenda da foto que não deve entrar no texto da matéria</p></figcaption></figure>
  ${_p('Segundo parágrafo com mais detalhes.')}
  <p>Leia também: outra notícia relacionada que aparece no meio do texto</p>
  ${_p('Terceiro parágrafo com a conclusão.')}
  ${_p('Quarto parágrafo com contexto adicional.')}
  ${_p('Quinto parágrafo com a fala de um especialista.')}
  ${_p('Sexto parágrafo, que fecha a matéria.')}
  <p>✅Fique por dentro das principais notícias do dia no canal do WhatsApp</p>
  <p>Curto</p>
</article>
<footer><p>Todos os direitos reservados ao veículo que publicou esta matéria</p></footer>
</body></html>''';
    final paragraphs = ArticleText.extract(html);
    expect(paragraphs, hasLength(6));
    expect(paragraphs.first, startsWith('Primeiro parágrafo'));
    expect(paragraphs.last, startsWith('Sexto parágrafo'));
    expect(paragraphs.join(' '), isNot(contains('Legenda')));
    expect(paragraphs.join(' '), isNot(contains('Leia também')));
    expect(paragraphs.join(' '), isNot(contains('Fique por dentro')));
  });

  test('página sem texto de matéria volta vazia (o app abre a página)', () {
    expect(
        ArticleText.extract(
            '<html><body>${_p('Só uma chamada')}</body></html>'),
        isEmpty);
  });

  test('o script da WebView usa a mesma limpeza', () {
    final script = ArticleText.extractScript();
    expect(script, contains('fique por dentro'));
    expect(script, contains(r'replace(/\s+/g'));
  });
}
