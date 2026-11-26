package br.com.radar.content;

import static org.assertj.core.api.Assertions.assertThat;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;

class ArticleSummarizerTest {
  @Test
  void skipsWithoutGeminiKey() {
    var summarizer =
        new ArticleSummarizer(new GeminiClient(new ObjectMapper(), "", "gemini-3.5-flash-lite"));
    assertThat(summarizer.enabled()).isFalse();
    assertThat(summarizer.summarize("Título", "Corpo da matéria com fatos.")).isEmpty();
  }

  @Test
  void rejectsTooShortOutput() {
    assertThat(ArticleSummarizer.clean("")).isEmpty();
    assertThat(ArticleSummarizer.clean("Resumo curto.")).isEmpty();
  }

  @Test
  void normalizesWhitespaceAndCapsLength() {
    String text =
        "O Banco Central anunciou nesta quarta-feira   (26) a nova fase do Pix.\n"
            + "A mudança começa em março e afeta 150 milhões de usuários. ";
    assertThat(ArticleSummarizer.clean(text))
        .contains(
            "O Banco Central anunciou nesta quarta-feira (26) a nova fase do Pix. A mudança"
                + " começa em março e afeta 150 milhões de usuários.");

    String longText = "palavra ".repeat(200);
    var capped = ArticleSummarizer.clean(longText).orElseThrow();
    assertThat(capped.codePointCount(0, capped.length()))
        .isLessThanOrEqualTo(ArticleSummarizer.MAX_LENGTH);
    assertThat(capped).endsWith("…");
  }
}
