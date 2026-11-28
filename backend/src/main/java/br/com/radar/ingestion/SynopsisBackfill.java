package br.com.radar.ingestion;

import br.com.radar.content.ContentModels.Article;
import br.com.radar.content.ContentRepository;
import java.time.Duration;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Gera a sinopse das matérias que entraram antes do resumo automático ou cujo resumo falhou na
 * coleta. Processa poucas por rodada para não estourar o limite de requisições do Gemini.
 */
@Component
@ConditionalOnProperty(name = "radar.ingestion.enabled", havingValue = "true")
public class SynopsisBackfill {
  private static final Logger LOG = LoggerFactory.getLogger(SynopsisBackfill.class);
  private static final int BATCH = 12;
  private static final Duration MAX_AGE = Duration.ofDays(7);
  private static final Duration RETRY_AFTER = Duration.ofHours(6);

  private final ContentRepository articles;
  private final ArticleSynopses synopses;

  public SynopsisBackfill(ContentRepository articles, ArticleSynopses synopses) {
    this.articles = articles;
    this.synopses = synopses;
  }

  @Scheduled(
      fixedDelayString = "${radar.ingestion.synopsis-backfill-ms:300000}",
      initialDelayString = "${radar.ingestion.synopsis-backfill-initial-ms:90000}")
  public void run() {
    if (!synopses.enabled()) return;
    int done = 0;
    int failed = 0;
    for (Article article : articles.synopsisBacklog(BATCH, MAX_AGE, RETRY_AFTER)) {
      try {
        var synopsis =
            synopses.write(article.title(), article.body(), "", url(article), excerpt(article));
        if (synopsis.isPresent()) {
          articles.replaceSynopsis(article.id(), synopsis.get());
          done++;
        } else {
          articles.markSynopsisTried(article.id());
          failed++;
        }
      } catch (Exception e) {
        articles.markSynopsisTried(article.id());
        failed++;
      }
    }
    if (done + failed > 0) LOG.info("Sinopses geradas: {} (sem resumo: {})", done, failed);
  }

  private static String url(Article article) {
    return article.sources().isEmpty() ? "" : article.sources().getFirst().url();
  }

  private static String excerpt(Article article) {
    return article.summary().stream().filter(text -> !text.isBlank()).findFirst().orElse("");
  }
}
