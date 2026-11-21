package br.com.radar.content;

import static br.com.radar.content.ContentModels.*;

import br.com.radar.common.ApiException;
import java.time.*;
import java.util.*;
import org.springframework.stereotype.Service;

@Service
public class ContentService {
  public static final ZoneId ZONE = ZoneId.of("America/Sao_Paulo");
  private final ContentRepository repo;
  private final ContentAnalyticsRepository analytics;

  public ContentService(ContentRepository repo, ContentAnalyticsRepository analytics) {
    this.repo = repo;
    this.analytics = analytics;
  }

  public static Instant startToday() {
    return LocalDate.now(ZONE).atStartOfDay(ZONE).toInstant();
  }

  public Map<String, Object> home(boolean rumors) {
    String hero = analytics.heroId(rumors);
    var result = new LinkedHashMap<>(analytics.home(rumors));
    result.put("hero", hero == null ? null : repo.find(hero));
    return result;
  }

  public Map<String, Object> topic(
      String user, String category, String company, String cursor, boolean rumors) {
    if (!category.matches(ContentModels.CATEGORY)) throw ApiException.missing();
    var result = new LinkedHashMap<>(analytics.topic(category, rumors));
    result.put(
        "feed", repo.feed(user, "for-you", rumors, category, company, cursor, 20, List.of()));
    return result;
  }

  public Map<String, Object> explore() {
    return Map.of("topics", analytics.topics(), "people", analytics.people());
  }

  public Map<String, Object> search(String q, boolean rumors) {
    if (q.isBlank()) return Map.of("articles", List.of(), "people", List.of());
    var articles = repo.search(q.trim(), rumors);
    var result = new LinkedHashMap<String, Object>();
    result.put("articles", articles);
    result.put(
        "people",
        articles.stream()
            .flatMap(a -> a.entities().stream())
            .filter(e -> e.type().equals("person"))
            .distinct()
            .map(e -> Map.of("id", e.id(), "name", e.name()))
            .toList());
    articles.stream()
        .flatMap(a -> a.entities().stream())
        .filter(e -> e.name().toLowerCase(Locale.ROOT).contains(q.trim().toLowerCase(Locale.ROOT)))
        .findFirst()
        .ifPresent(
            e -> {
              var entity =
                  new LinkedHashMap<String, Object>(analytics.entityCounts(e.id(), rumors));
              entity.put("id", e.id());
              entity.put("name", e.name());
              entity.put("type", e.type());
              result.put("entity", entity);
            });
    return result;
  }
}
