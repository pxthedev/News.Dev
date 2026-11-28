package br.com.radar.ingestion;

import static br.com.radar.common.PostgresStore.*;
import static br.com.radar.content.ContentModels.*;

import br.com.radar.common.PostgresStore;
import br.com.radar.content.BrazilianPublishers;
import br.com.radar.content.ContentRepository;
import com.rometools.rome.feed.synd.SyndEntry;
import java.net.URI;
import java.time.Duration;
import java.time.Instant;
import java.util.*;
import java.util.regex.Pattern;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Busca no Google News as matérias de cada tópico do app e importa as que o feed pode exibir.
 *
 * <p>O feed só mostra matérias de veículos brasileiros autorizados (ver ContentRepository.base).
 * A busca é restrita a esses sites, o link do Google é convertido no endereço real e a página da
 * matéria serve de base para a sinopse. O texto completo só é guardado nos hosts de texto aberto
 * (padrão: Agência Brasil); nos demais a matéria fica com sinopse e link para o veículo. Matérias
 * já coletadas pelo RSS são ignoradas pela mesma chave de URL canônica.
 */
@Component
@ConditionalOnProperty(name = "radar.ingestion.google-news.enabled", havingValue = "true")
public class GoogleNewsCollector {
  private static final Logger LOG = LoggerFactory.getLogger(GoogleNewsCollector.class);
  private static final Duration MAX_AGE = Duration.ofDays(7);

  /** Créditos de agências de notícias cujo texto a Agência Brasil não pode relicenciar. */
  static final Pattern WIRE_CREDIT =
      Pattern.compile(
          "(?i)\\b(?:reuters|associated press|ag[êe]ncia lusa|lusa|sputnik|xinhua|ag[êe]ncia efe"
              + "|ag[êe]ncia france-presse|afp|ansa|deutsche welle|rfi|bbc)\\b");

  private final PostgresStore store;
  private final RssFetcher fetcher;
  private final GoogleNewsLinks links;
  private final ContentRepository articles;
  private final ArticleSynopses synopses;
  private final Set<String> sites;
  private final Set<String> fullTextHosts;
  private final int perTopic;

  public GoogleNewsCollector(
      PostgresStore store,
      RssFetcher fetcher,
      GoogleNewsLinks links,
      ContentRepository articles,
      ArticleSynopses synopses,
      @Value("${radar.ingestion.google-news.sites:" + DEFAULT_SITES + "}") String sites,
      @Value("${radar.ingestion.google-news.full-text-hosts:agenciabrasil.ebc.com.br}")
          String fullTextHosts,
      @Value("${radar.ingestion.google-news.per-topic:8}") int perTopic) {
    this.store = store;
    this.fetcher = fetcher;
    this.links = links;
    this.articles = articles;
    this.synopses = synopses;
    this.sites = hosts(sites);
    this.fullTextHosts = hosts(fullTextHosts);
    this.perTopic = Math.max(1, Math.min(perTopic, 30));
  }

  /** Veículos de BrazilianPublishers; o filtro de URL descarta seções fora de tecnologia. */
  static final String DEFAULT_SITES =
      "g1.globo.com,agenciabrasil.ebc.com.br,cnnbrasil.com.br,r7.com,band.com.br,sbt.com.br,"
          + "tvcultura.com.br";

  private static Set<String> hosts(String list) {
    var hosts = new LinkedHashSet<String>();
    for (String host : list.split(","))
      if (!host.isBlank()) hosts.add(host.strip().toLowerCase(Locale.ROOT));
    return Collections.unmodifiableSet(hosts);
  }

  /** O host é o site ou um subdomínio dele. */
  static boolean onSite(String host, Set<String> sites) {
    String h = host.toLowerCase(Locale.ROOT);
    for (String site : sites) if (h.equals(site) || h.endsWith("." + site)) return true;
    return false;
  }

  @Scheduled(
      fixedDelayString = "${radar.ingestion.google-news.delay-ms:1800000}",
      initialDelayString = "${radar.ingestion.google-news.initial-delay-ms:120000}")
  public void run() {
    if (sites.isEmpty()) {
      LOG.warn("Google News ligado, mas GOOGLE_NEWS_SITES está vazio.");
      return;
    }
    long started = System.nanoTime();
    LOG.info("Google News: rodada iniciada ({} tópicos, sites {})", GoogleNewsTopics.QUERIES.size(), sites);
    int total = 0;
    for (String topic : GoogleNewsTopics.QUERIES.keySet()) {
      var stats = new Stats();
      try {
        collect(topic, stats);
      } catch (Exception e) {
        stats.error = e.getClass().getSimpleName();
      }
      total += stats.imported;
      LOG.info("Google News [{}]: {}", topic, stats);
    }
    LOG.info(
        "Google News: rodada concluída em {}s, {} matérias importadas",
        (System.nanoTime() - started) / 1_000_000_000,
        total);
  }

  /** Contadores de uma busca, para o log mostrar onde as matérias ficam pelo caminho. */
  static final class Stats {
    int found, alreadySeen, unresolved, otherSite, duplicate, offTopic, noSynopsis, imported;
    String error;

    @Override
    public String toString() {
      return "encontradas="
          + found
          + " já vistas="
          + alreadySeen
          + " link não convertido="
          + unresolved
          + " outro site="
          + otherSite
          + " já no feed="
          + duplicate
          + " fora do tema="
          + offTopic
          + " sem sinopse="
          + noSynopsis
          + " importadas="
          + imported
          + (error == null ? "" : " ERRO=" + error);
    }
  }

  int collect(String topic, Stats stats) throws Exception {
    String url = GoogleNewsTopics.searchUrl(topic, sites, 2);
    var entries = fetcher.fetch(url, GoogleNewsTopics.HOST);
    stats.found = entries.size();
    Instant now = Instant.now();
    int inserted = 0;
    int resolved = 0;
    for (SyndEntry entry : entries) {
      if (inserted >= perTopic || resolved >= perTopic * 2) break;
      var googleId = GoogleNewsLinks.articleId(Objects.requireNonNullElse(entry.getLink(), ""));
      if (googleId.isEmpty() || entry.getTitle() == null) continue;
      var seen = store.doc("imports", hash("gnews:" + googleId.get()));
      if (store.get(seen).exists()) {
        stats.alreadySeen++;
        continue;
      }

      var date = entry.getPublishedDate() == null ? entry.getUpdatedDate() : entry.getPublishedDate();
      if (date == null) continue;
      Instant published = date.toInstant();
      if (published.isAfter(now.plusSeconds(300)) || published.isBefore(now.minus(MAX_AGE)))
        continue;

      String[] parts = GoogleNewsTopics.splitTitle(RssFetcher.text(entry.getTitle()));
      String title = parts[0];
      if (title.isBlank()) continue;
      title = title.substring(0, Math.min(title.length(), 240));

      resolved++;
      var real = links.resolve(entry.getLink());
      if (real.isEmpty()) { // falha transitória: tenta de novo na próxima rodada
        stats.unresolved++;
        continue;
      }
      URI link;
      try {
        link = URI.create(real.get());
      } catch (Exception e) {
        markSeen(seen, topic, null);
        continue;
      }
      if (!"https".equals(link.getScheme())
          || link.getHost() == null
          || !onSite(link.getHost(), sites)
          || !BrazilianPublishers.contains(link.toString())) {
        stats.otherSite++;
        markSeen(seen, topic, null);
        continue;
      }
      String canonical = IngestionService.canonical(link);
      String key = hash(canonical);
      var imported = store.doc("imports", key);
      if (store.get(imported).exists()) {
        stats.duplicate++;
        markSeen(seen, topic, canonical);
        continue;
      }

      // O Google acha o termo em qualquer parte da página (menus, "leia também"). Só entra se o
      // título ou a sinopse falarem de tecnologia.
      String category = TechFeeds.strictCategory(title, topic);
      // A página serve de base para a sinopse; só vira corpo da matéria em host de texto aberto.
      String page = fetcher.pageText(canonical);
      String body =
          fullTextHosts.contains(link.getHost().toLowerCase(Locale.ROOT)) && openBody(page)
              ? page
              : "";
      String synopsis = synopses.write(title, body, page, canonical, "").orElse(null);
      if (synopsis == null) { // Gemini ou página fora do ar: tenta de novo na próxima rodada
        stats.noSynopsis++;
        continue;
      }
      if (category == null) category = TechFeeds.strictCategory(synopsis, topic);
      if (category == null) {
        stats.offTopic++;
        markSeen(seen, topic, canonical);
        continue;
      }
      String outlet = parts[1].isBlank() ? link.getHost() : parts[1];
      String id = "rss-" + key.substring(0, 32);
      int readingMinutes = body.isEmpty() ? 1 : Math.max(1, Math.min(120, (body.split("\\s+").length + 199) / 200));
      var article =
          new Article(
              id,
              title,
              List.of(synopsis),
              body,
              category,
              outlet,
              null,
              now,
              published,
              List.of(new Source(outlet, canonical, null, null)),
              1,
              false,
              null,
              "normal",
              true,
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
                        "gnews-" + topic,
                        "url",
                        canonical,
                        "importedAt",
                        time(Instant.now())));
                return true;
              });
      markSeen(seen, topic, canonical);
      if (saved) {
        inserted++;
        stats.imported++;
        articles.markSynopsisGenerated(id);
      }
    }
    return inserted;
  }

  /**
   * Texto da página serve de corpo só quando parece uma matéria completa e própria do veículo (sem
   * crédito de agência internacional no início ou no fim).
   */
  static boolean openBody(String body) {
    if (body == null || body.length() < 350 || body.length() > 100_000) return false;
    String[] paragraphs = body.split("\n\n");
    if (paragraphs.length < 3) return false;
    return !WIRE_CREDIT.matcher(paragraphs[0]).find()
        && !WIRE_CREDIT.matcher(paragraphs[paragraphs.length - 1]).find();
  }

  private void markSeen(PostgresStore.DocumentReference seen, String topic, String url) {
    await(
        seen.set(
            map(
                "sourceId",
                "gnews-" + topic,
                "url",
                url == null ? "" : url,
                "importedAt",
                time(Instant.now()))));
  }
}
