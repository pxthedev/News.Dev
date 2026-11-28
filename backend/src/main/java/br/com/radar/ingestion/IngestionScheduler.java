package br.com.radar.ingestion;

import br.com.radar.common.PostgresStore;
import br.com.radar.content.BrazilianPublishers;
import java.util.Set;
import java.util.stream.Collectors;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
@ConditionalOnProperty(name = "radar.ingestion.enabled", havingValue = "true")
public class IngestionScheduler {
  private static final Logger LOG = LoggerFactory.getLogger(IngestionScheduler.class);
  private static final Set<String> CATALOG_IDS =
      TechFeeds.catalog(true).stream()
          .map(TechFeeds.Feed::id)
          .collect(Collectors.toUnmodifiableSet());

  private final PostgresStore store;
  private final IngestionService service;
  private final boolean catalogEnabled;
  private final boolean licensedFeeds;

  public IngestionScheduler(
      PostgresStore store,
      IngestionService service,
      @Value("${radar.ingestion.tech-feeds-enabled}") boolean catalogEnabled,
      @Value("${radar.ingestion.licensed-feeds-enabled}") boolean licensedFeeds) {
    this.store = store;
    this.service = service;
    this.catalogEnabled = catalogEnabled;
    this.licensedFeeds = licensedFeeds;
  }

  @Scheduled(fixedDelayString = "${radar.ingestion.delay-ms}")
  public void run() {
    long started = System.nanoTime();
    LOG.info("Coleta RSS: rodada iniciada");
    try {
      collectAll();
    } finally {
      LOG.info(
          "Coleta RSS: rodada concluída em {}s", (System.nanoTime() - started) / 1_000_000_000);
    }
  }

  private void collectAll() {
    if (catalogEnabled) {
      for (var feed : TechFeeds.catalog(licensedFeeds)) {
        if (BrazilianPublishers.contains(feed.url()) || feed.id().equals("rss-cnn-brasil"))
          collect(feed.id(), () -> service.run(feed));
      }
    }
    for (var source : store.query(store.collection("sources").whereEqualTo("enabled", true))) {
      if (!CATALOG_IDS.contains(source.getId())) {
        collect(source.getId(), () -> service.run(source.getId()));
      }
    }
  }

  private void collect(String id, Runnable collection) {
    try {
      collection.run();
    } catch (Exception e) {
      LOG.warn("Coleta da fonte {} falhou: {}", id, e.getClass().getSimpleName());
    }
  }
}
