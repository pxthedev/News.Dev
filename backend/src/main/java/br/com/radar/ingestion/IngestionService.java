package br.com.radar.ingestion;

import static br.com.radar.common.PostgresStore.*;
import static br.com.radar.content.ContentModels.*;

import br.com.radar.common.*;
import br.com.radar.common.PostgresStore.*;
import br.com.radar.content.*;
import com.rometools.rome.feed.synd.SyndEntry;
import java.net.URI;
import java.time.*;
import java.util.*;
import org.springframework.stereotype.Service;

@Service
public class IngestionService {
  private final PostgresStore store;
  private final RssFetcher fetcher;
  private final ContentRepository articles;

  public IngestionService(PostgresStore store, RssFetcher fetcher, ContentRepository articles) {
    this.store = store;
    this.fetcher = fetcher;
    this.articles = articles;
  }

  public record SourceConfig(
      String id, String name, String url, String category, boolean allowFullText) {}

  public void save(SourceConfig source) {
    if (source.id() == null
        || !source.id().matches("[a-z0-9-]{1,80}")
        || source.name() == null
        || source.name().isBlank()
        || source.name().length() > 100
        || source.category() == null
        || !source.category().matches(ContentModels.CATEGORY))
      throw ApiException.invalid("Confira o identificador, nome e categoria da fonte.");
    fetcher.validate(source.url());
    await(
        store
            .doc("sources", source.id())
            .set(
                map(
                    "name",
                    source.name(),
                    "url",
                    source.url(),
                    "category",
                    source.category(),
                    "enabled",
                    true,
                    "allowFullText",
                    source.allowFullText())));
  }

  public Map<String, Integer> run(String sourceId) {
    return run(sourceId, null);
  }

  Map<String, Integer> run(TechFeeds.Feed feed) {
    var ref = store.doc("sources", feed.id());
    store.transaction(
        tx -> {
          if (!await(tx.get(ref)).exists()) {
            tx.set(
                ref,
                map(
                    "name",
                    feed.name(),
                    "url",
                    feed.url(),
                    "category",
                    Objects.requireNonNullElse(feed.fallback(), "bigtech"),
                    "enabled",
                    true));
          }
          return null;
        });
    return run(feed.id(), feed);
  }

  private Map<String, Integer> run(String sourceId, TechFeeds.Feed feed) {
    var ref = store.doc("sources", sourceId);
    var source = store.get(ref);
    require(source);
    if (feed != null && !Boolean.TRUE.equals(source.getBoolean("enabled")))
      return Map.of("imported", 0);
    int inserted = 0;
    // Lease evita duas instâncias coletarem a mesma fonte ao mesmo tempo.
    boolean claim =
        store.transaction(
            tx -> {
              var current = await(tx.get(ref));
              var until = current.getInstant("leaseUntil");
              if (until != null && instant(until).isAfter(Instant.now())) return false;
              tx.update(ref, "leaseUntil", time(Instant.now().plusSeconds(120)));
              return true;
            });
    if (!claim) return Map.of("imported", 0);
    try {
      String sourceUrl = source.getString("url");
      var entries =
          feed != null && feed.url().equals(sourceUrl)
              ? fetcher.fetch(sourceUrl, feed.host())
              : fetcher.fetch(sourceUrl);
      Instant now = Instant.now();
      for (SyndEntry entry : entries.stream().limit(100).toList()) {
        if (feed != null && inserted >= 25) break;
        if (entry.getLink() == null || entry.getTitle() == null) continue;
        URI link;
        try {
          link = URI.create(entry.getLink());
          if (!List.of("http", "https").contains(link.getScheme()) || link.getHost() == null)
            continue;
        } catch (Exception e) {
          continue;
        }
        String title = RssFetcher.text(entry.getTitle());
        if (feed != null && !BrazilianPublishers.contains(link.toString())) continue;
        if (title.isBlank()) continue;
        title = title.substring(0, Math.min(title.length(), 240));
        String excerpt =
            RssFetcher.text(
                entry.getDescription() == null ? "" : entry.getDescription().getValue());
        if (excerpt.length() > 3000) excerpt = excerpt.substring(0, 3000);
        var date = entry.getPublishedDate();
        if (date == null) date = entry.getUpdatedDate();
        if (feed != null && date == null) continue;
        Instant published = date == null ? now : date.toInstant();
        if (published.isAfter(now.plusSeconds(300))
            || (feed != null && published.isBefore(now.minus(Duration.ofDays(7))))) continue;
        String category =
            feed == null
                ? source.getString("category")
                : TechFeeds.category(title, excerpt, feed.fallback());
        if (category == null) continue;
        String canonical = canonical(link);
        String key = hash(canonical);
        String id = "rss-" + key.substring(0, 32);
        var imported = store.doc("imports", key);
        boolean openFullText =
            feed != null
                && feed.openFullText()
                && feed.url().equals(sourceUrl)
                && feed.host().equalsIgnoreCase(link.getHost());
        String fullText =
            openFullText || Boolean.TRUE.equals(source.getBoolean("allowFullText"))
                ? fullText(entry, excerpt)
                : "";
        if (fullText.isBlank()
            && feed != null
            && feed.id().equals("rss-ebc-geral")
            && feed.url().equals(sourceUrl)
            && feed.host().equalsIgnoreCase(link.getHost())) {
          fullText = agencyBrasilBody(entry);
        }
        int readingMinutes =
            fullText.isBlank()
                ? 1
                : Math.max(1, Math.min(120, (fullText.split("\\s+").length + 199) / 200));
        var previous = store.get(imported);
        if (previous.exists()) {
          if (!fullText.isBlank() && sourceId.equals(previous.getString("sourceId"))) {
            articles.fillImportedBody(id, fullText, readingMinutes);
          }
          continue;
        }

        String summary =
            excerpt.isBlank()
                ? "A fonte publicou uma nova atualização. Acesse o conteúdo original."
                : excerpt.substring(0, Math.min(excerpt.length(), 1000));
        var article =
            new Article(
                id,
                title,
                feed == null
                    ? List.of(
                        summary,
                        "Conteúdo importado por RSS, aguardando revisão editorial.",
                        "Leia os detalhes e a atribuição na fonte original.")
                    : (excerpt.isBlank()
                        ? List.of()
                        : List.of(br.com.radar.content.ArticleTranslation.shortSynopsis(excerpt))),
                fullText,
                category,
                feed == null ? "Aguardando revisão" : source.getString("name"),
                null,
                now,
                published,
                List.of(
                    new Source(
                        openFullText && !fullText.isBlank()
                            ? openTextCredit(entry, source.getString("name"))
                            : source.getString("name"),
                        canonical,
                        null,
                        null)),
                1,
                false,
                null,
                "normal",
                feed != null,
                readingMinutes,
                null,
                null,
                List.of(),
                null);
        boolean saved =
            store.transaction(
                tx -> {
                  if (await(tx.get(imported)).exists()) return false;
                  articles.save(article);
                  tx.set(
                      imported,
                      map(
                          "articleId",
                          id,
                          "sourceId",
                          sourceId,
                          "url",
                          canonical,
                          "importedAt",
                          time(Instant.now())));
                  return true;
                });
        if (saved) inserted++;
      }
      await(
          ref.update(map("lastSuccessAt", time(Instant.now()), "lastError", FieldValue.delete())));
    } catch (Exception e) {
      await(ref.update("lastError", e.getClass().getSimpleName()));
      throw new ApiException(
          org.springframework.http.HttpStatus.BAD_GATEWAY,
          "source_unavailable",
          "Não foi possível coletar essa fonte agora.");
    } finally {
      await(ref.update("leaseUntil", time(Instant.EPOCH)));
    }
    return Map.of("imported", inserted);
  }

  private static String fullText(SyndEntry entry, String excerpt) {
    return entry.getContents().stream()
        .map(content -> RssFetcher.articleText(content.getValue()))
        .filter(value -> !value.isBlank() && value.length() <= 100_000)
        .filter(value -> !RssFetcher.text(value).equals(excerpt))
        .findFirst()
        .orElse("");
  }

  static String agencyBrasilBody(SyndEntry entry) {
    if (entry.getDescription() == null) return "";
    var body = RssFetcher.articleText(entry.getDescription().getValue());
    // O feed Geral da EBC publica o corpo em description. Trechos curtos ficam como sinopse.
    if (body.length() < 350 || body.length() > 100_000 || body.split("\n\n").length < 3) return "";
    String author = RssFetcher.text(entry.getAuthor()).toLowerCase(Locale.ROOT);
    if (author.matches(
        ".*(?:reuters|associated press|lusa|sputnik|xinhua|agência efe|agência france-presse|\\bafp\\b).*"))
      return "";
    return body;
  }

  private static String openTextCredit(SyndEntry entry, String outlet) {
    String authors =
        entry.getAuthors().stream()
            .map(author -> RssFetcher.text(author.getName()))
            .filter(name -> !name.isBlank())
            .distinct()
            .collect(java.util.stream.Collectors.joining(", "));
    if (authors.isBlank()) authors = RssFetcher.text(entry.getAuthor());
    return authors.isBlank() ? outlet : outlet + " · " + authors;
  }

  public static String canonical(URI uri) {
    try {
      return new URI(
              uri.getScheme().toLowerCase(Locale.ROOT),
              null,
              uri.getHost().toLowerCase(Locale.ROOT),
              uri.getPort(),
              uri.getPath(),
              uri.getQuery() == null
                  ? null
                  : Arrays.stream(uri.getQuery().split("&"))
                      .filter(
                          q ->
                              !q.toLowerCase(Locale.ROOT).startsWith("utm_")
                                  && !q.startsWith("fbclid=")
                                  && !q.startsWith("ocid=")
                                  && !q.startsWith("at_medium=")
                                  && !q.startsWith("at_campaign="))
                      .sorted()
                      .reduce((a, b) -> a + "&" + b)
                      .orElse(null),
              null)
          .toString();
    } catch (Exception e) {
      throw ApiException.invalid("O link da fonte é inválido.");
    }
  }
}
