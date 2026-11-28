package br.com.radar.ingestion;

import br.com.radar.common.PostgresStore;
import br.com.radar.content.ContentRepository;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Remove as matérias que o Google News importou antes do filtro de tema atual: título sem nenhum
 * termo de tecnologia (ex.: "Expectativa de vida dos brasileiros" como games), patrocinados e
 * resumos de vídeo. Usa as mesmas regras do coletor.
 *
 * <p>Só olha matérias com registro de importação gnews-*. O registro fica, para a matéria não ser
 * importada de novo. Roda uma vez, um minuto após o boot; é idempotente.
 */
@Component
@ConditionalOnProperty(name = "radar.ingestion.google-news.enabled", havingValue = "true")
public class GoogleNewsCleanup {
  private static final Logger LOG = LoggerFactory.getLogger(GoogleNewsCleanup.class);

  private final PostgresStore store;
  private final ContentRepository articles;

  public GoogleNewsCleanup(PostgresStore store, ContentRepository articles) {
    this.store = store;
    this.articles = articles;
  }

  @Scheduled(initialDelay = 60_000, fixedDelay = Long.MAX_VALUE)
  public void run() {
    try {
      int removed = clean();
      LOG.info("Google News: limpeza concluída, {} matérias fora do tema removidas", removed);
    } catch (Exception e) {
      LOG.warn("Google News: limpeza falhou: {}", e.toString());
    }
  }

  public int clean() {
    int removed = 0;
    for (String topic : GoogleNewsTopics.QUERIES.keySet()) {
      var imports =
          store.query(store.collection("imports").whereEqualTo("sourceId", "gnews-" + topic));
      for (var imported : imports) {
        String id = imported.getString("articleId");
        if (id == null || id.isBlank()) continue; // marcador de "já visto", sem matéria
        var found = articles.byIds(List.of(id));
        if (found.isEmpty()) continue;
        var article = found.getFirst();
        String url = article.sources().isEmpty() ? "" : article.sources().getFirst().url();
        if (!GoogleNewsCollector.offTopicPage(url, article.title())
            && TechFeeds.strictCategory(article.title(), topic) != null) continue;
        articles.delete(id);
        removed++;
        LOG.info("Google News: removida fora do tema [{}] {}", topic, article.title());
      }
    }
    return removed;
  }
}
