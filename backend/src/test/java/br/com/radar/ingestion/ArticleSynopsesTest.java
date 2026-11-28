package br.com.radar.ingestion;

import static org.assertj.core.api.Assertions.assertThat;

import br.com.radar.content.ArticleSummarizer;
import br.com.radar.content.ArticleTranslation;
import br.com.radar.content.GeminiClient;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;

class ArticleSynopsesTest {
  private static final String LONG_PARAGRAPH =
      "O Banco Central anunciou nesta quarta-feira uma nova fase do Pix, que passa a permitir"
          + " pagamentos parcelados a partir de março para 150 milhões de usuários.";

  @Test
  void extractsArticleParagraphsAndSkipsBoilerplate() {
    String html =
        "<html><head><script>var x = '<p>script</p>';</script></head><body>"
            + "<nav><p>Menu de navegação com links para todas as editorias do portal g1</p></nav>"
            + "<article><h1>Título</h1>"
            + "<p class='content-text'>"
            + LONG_PARAGRAPH
            + "</p>"
            + "<p>Curto.</p>"
            + "<p>Leia também: outra matéria sobre pagamentos instantâneos no Brasil e no mundo</p>"
            + "<figure><p>Legenda da foto do presidente do Banco Central em Brasília hoje</p></figure>"
            + "<p>Segundo o BC, o WhatsApp Pay também poderá usar o recurso, que terá limite de"
            + " R$ 5 mil por transação.</p>"
            + "</article><footer><p>Todos os direitos reservados ao grupo de comunicação.</p></footer>"
            + "</body></html>";

    String text = RssFetcher.readableText(html);

    assertThat(text)
        .isEqualTo(
            LONG_PARAGRAPH
                + "\n\nSegundo o BC, o WhatsApp Pay também poderá usar o recurso, que terá limite"
                + " de R$ 5 mil por transação.");
  }

  @Test
  void prefersStoredBodyThenEncodedContentThenExcerpt() {
    var synopses =
        new ArticleSynopses(
            new ArticleSummarizer(
                new GeminiClient(new ObjectMapper(), "", "gemini-3.5-flash-lite")),
            new RssFetcher("example.com"));
    String encoded = LONG_PARAGRAPH.repeat(4);

    assertThat(synopses.sourceText("Corpo guardado", encoded, "", "trecho"))
        .isEqualTo("Corpo guardado");
    assertThat(synopses.sourceText("", encoded, "", "trecho")).isEqualTo(encoded);
    // Página fora dos hosts confiáveis não é baixada: fica o maior texto disponível.
    assertThat(synopses.sourceText("", "", "https://evil.test/a", "trecho do feed"))
        .isEqualTo("trecho do feed");
    assertThat(synopses.write("Título", "", encoded, "", "trecho")).isEmpty();
  }

  @Test
  void shortSynopsisEndsOnAWholeSentence() {
    String text =
        "Primeira frase completa com o fato principal da notícia de hoje. "
            + "Segunda frase com números, valores e nomes importantes para o leitor. "
            + "Terceira frase que é longa demais e não cabe no limite definido pelo app";

    assertThat(ArticleTranslation.shortSynopsis(text, 140))
        .isEqualTo(
            "Primeira frase completa com o fato principal da notícia de hoje. "
                + "Segunda frase com números, valores e nomes importantes para o leitor.");
    assertThat(ArticleTranslation.shortSynopsis("palavra ".repeat(40), 60)).endsWith("…");
  }
}
