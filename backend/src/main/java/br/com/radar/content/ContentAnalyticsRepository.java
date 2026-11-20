package br.com.radar.content;

import static br.com.radar.common.PostgresStore.*;

import br.com.radar.common.*;
import br.com.radar.common.PostgresStore.*;
import java.time.*;
import java.util.*;
import org.springframework.stereotype.Repository;

@Repository
public class ContentAnalyticsRepository {
  private final PostgresStore store;
  private final ContentRepository content;

  public ContentAnalyticsRepository(PostgresStore store, ContentRepository content) {
    this.store = store;
    this.content = content;
  }

  private Instant week() {
    return LocalDate.now(ContentService.ZONE)
        .minusDays(6)
        .atStartOfDay(ContentService.ZONE)
        .toInstant();
  }

  private List<DocumentSnapshot> metadata(boolean rumors, String category, Instant since) {
    Query q = content.base(rumors).whereGreaterThanOrEqualTo("publishedAt", time(since));
    if (category != null) q = q.whereEqualTo("category", category);
    return store.query(
        q.select(
            "category", "firstInBrazil", "publishedAt", "trendingTag", "entities", "entityIds"));
  }

  public String heroId(boolean rumors) {
    for (String urgency : List.of("urgent", "important", "normal")) {
      var rows =
          store.query(
              content
                  .base(rumors)
                  .whereEqualTo("urgency", urgency)
                  .whereGreaterThanOrEqualTo("publishedAt", time(week()))
                  .orderBy("publishedAt", Query.Direction.DESCENDING)
                  .limit(1)
                  .select(new String[0]));
      if (!rows.isEmpty()) return rows.getFirst().getId();
    }
    var page = content.feed("", "for-you", rumors, null, null, null, 1, List.of());
    return page.items().isEmpty() ? null : page.items().getFirst().id();
  }

  public Map<String, Object> home(boolean rumors) {
    var rows = metadata(rumors, null, week());
    var tags = new TreeMap<String, Integer>();
    for (var row : rows) {
      String tag = row.getString("trendingTag");
      if (tag != null) tags.merge(tag, 1, Integer::sum);
    }
    String tag =
        tags.entrySet().stream()
            .sorted(
                Map.Entry.<String, Integer>comparingByValue()
                    .reversed()
                    .thenComparing(Map.Entry.comparingByKey()))
            .map(Map.Entry::getKey)
            .findFirst()
            .orElse("tecnologia");
    var perDay = new ArrayList<Long>();
    for (int i = 6; i >= 0; i--) {
      var day = LocalDate.now(ContentService.ZONE).minusDays(i);
      perDay.add(
          rows.stream()
              .filter(
                  r ->
                      tag.equals(r.getString("trendingTag"))
                          && instant(r.getInstant("publishedAt"))
                              .atZone(ContentService.ZONE)
                              .toLocalDate()
                              .equals(day))
              .count());
    }
    Instant lastNight =
        LocalDate.now(ContentService.ZONE)
            .minusDays(1)
            .atTime(18, 0)
            .atZone(ContentService.ZONE)
            .toInstant();
    return Map.of(
        "scoopsSinceLastNight",
        rows.stream()
            .filter(
                r ->
                    Boolean.TRUE.equals(r.getBoolean("firstInBrazil"))
                        && !instant(r.getInstant("publishedAt")).isBefore(lastNight))
            .count(),
        "trending",
        Map.of("tag", tag, "count", tags.getOrDefault(tag, 0), "perDay", perDay));
  }

  public Map<String, Object> topic(String category, boolean rumors) {
    var rows = metadata(rumors, category, week());
    var companies = new TreeSet<String>();
    for (var r : rows)
      for (var e : entities(r))
        if ("company".equals(e.get("type"))) companies.add((String) e.get("name"));
    return Map.of(
        "week",
        rows.size(),
        "today",
        rows.stream()
            .filter(
                r -> !instant(r.getInstant("publishedAt")).isBefore(ContentService.startToday()))
            .count(),
        "scoops",
        rows.stream().filter(r -> Boolean.TRUE.equals(r.getBoolean("firstInBrazil"))).count(),
        "companies",
        companies);
  }

  public List<Map<String, Object>> topics() {
    var rows = metadata(false, null, ContentService.startToday().minus(Duration.ofDays(1)));
    var result = new ArrayList<Map<String, Object>>();
    for (String c : ContentModels.CATEGORY.split("\\|")) {
      long
          today =
              rows.stream()
                  .filter(
                      r ->
                          c.equals(r.getString("category"))
                              && !instant(r.getInstant("publishedAt"))
                                  .isBefore(ContentService.startToday()))
                  .count(),
          yesterday =
              rows.stream()
                  .filter(
                      r ->
                          c.equals(r.getString("category"))
                              && instant(r.getInstant("publishedAt"))
                                  .isBefore(ContentService.startToday()))
                  .count();
      result.add(
          Map.of(
              "category",
              c,
              "today",
              today,
              "deltaPercent",
              yesterday == 0
                  ? (today > 0 ? 100 : 0)
                  : Math.round(100.0 * (today - yesterday) / yesterday)));
    }
    return result;
  }

  public List<Map<String, String>> people() {
    var people = new TreeMap<String, Map<String, String>>();
    for (var row : metadata(false, null, week()))
      for (var e : entities(row))
        if ("person".equals(e.get("type")))
          people.put(
              (String) e.get("id"),
              Map.of("id", (String) e.get("id"), "name", (String) e.get("name")));
    return people.values().stream().limit(20).toList();
  }

  public Map<String, Object> entityCounts(String id, boolean rumors) {
    Query q = content.base(rumors).whereArrayContains("entityIds", id);
    long total = await(q.count().get()).getCount(),
        scoops =
            await(
                    q.whereEqualTo("firstInBrazil", true)
                        .whereGreaterThanOrEqualTo("publishedAt", time(ContentService.startToday()))
                        .count()
                        .get())
                .getCount();
    return Map.of("articleCount", total, "scoopsToday", scoops);
  }

  @SuppressWarnings("unchecked")
  private List<Map<String, Object>> entities(DocumentSnapshot doc) {
    Object e = doc.get("entities");
    return e instanceof List<?> ? (List<Map<String, Object>>) e : List.of();
  }
}
