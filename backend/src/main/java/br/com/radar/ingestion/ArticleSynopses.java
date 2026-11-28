package br.com.radar.ingestion;

import br.com.radar.content.ArticleSummarizer;
import com.rometools.rome.feed.synd.SyndEntry;
import java.util.Comparator;
import java.util.Optional;
import org.springframework.stereotype.Component;

/**
 * Escolhe o melhor texto disponível para resumir uma matéria e pede a sinopse ao Gemini.
 *
 * <p>A maioria dos feeds (g1, CNN Brasil) só traz uma description curta, às vezes cortada no meio
 * da frase. Resumir isso gera uma sinopse tão incompleta quanto o trecho. Por isso a ordem é: texto
 * completo guardado, content:encoded do feed, texto da página da matéria e, por último, o trecho. O
 * texto da página serve só de base para o resumo e não é guardado.
 */
@Component
public class ArticleSynopses {
  /** Abaixo disso não há fatos suficientes para um resumo que valha mais que o próprio trecho. */
  static final int MIN_SOURCE = 200;

  private static final int RICH_SOURCE = 400;

  private final ArticleSummarizer summarizer;
  private final RssFetcher fetcher;

  public ArticleSynopses(ArticleSummarizer summarizer, RssFetcher fetcher) {
    this.summarizer = summarizer;
    this.fetcher = fetcher;
  }

  public boolean enabled() {
    return summarizer.enabled();
  }

  public Optional<String> write(
      String title, String body, String encoded, String url, String excerpt) {
    if (!enabled()) return Optional.empty();
    String text = sourceText(body, encoded, url, excerpt);
    if (text.strip().length() < MIN_SOURCE) return Optional.empty();
    return summarizer.summarize(title, text);
  }

  String sourceText(String body, String encoded, String url, String excerpt) {
    if (body != null && !body.isBlank()) return body;
    if (encoded != null && encoded.length() >= RICH_SOURCE) return encoded;
    String page = url == null || url.isBlank() ? "" : fetcher.pageText(url);
    if (page.length() >= RICH_SOURCE) return page;
    String best = excerpt == null ? "" : excerpt;
    if (encoded != null && encoded.length() > best.length()) best = encoded;
    return best;
  }

  /** Maior bloco de content:encoded do item, em texto corrido. */
  static String encoded(SyndEntry entry) {
    return entry.getContents().stream()
        .map(content -> RssFetcher.articleText(content.getValue()))
        .filter(value -> value.length() <= 100_000)
        .max(Comparator.comparingInt(String::length))
        .orElse("");
  }
}
