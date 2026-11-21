package br.com.radar.content;

import br.com.radar.common.ApiException;
import java.net.URI;
import java.time.Instant;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.util.HtmlUtils;

@RestController
public class SharedArticleController {
  public static final String HOST = "https://appnewsai.discloud.app";
  private final ContentRepository articles;
  private final List<String> fingerprints;

  public SharedArticleController(ContentRepository articles,
      @Value("${radar.share.android-fingerprints}") String fingerprints) {
    this.articles = articles;
    this.fingerprints = Arrays.stream(fingerprints.split(","))
        .map(String::trim).filter(value -> value.matches("(?i)(?:[0-9a-f]{2}:){31}[0-9a-f]{2}"))
        .toList();
  }

  @GetMapping(value = "/.well-known/assetlinks.json", produces = MediaType.APPLICATION_JSON_VALUE)
  List<Map<String, Object>> androidLinks() {
    if (fingerprints.isEmpty()) return List.of();
    return List.of(Map.of(
        "relation", List.of("delegate_permission/common.handle_all_urls"),
        "target", Map.of("namespace", "android_app", "package_name", "app.radar.radar",
            "sha256_cert_fingerprints", fingerprints)));
  }

  @GetMapping(value = "/m/{id}", produces = "text/html;charset=UTF-8")
  ResponseEntity<String> shared(@PathVariable String id) {
    if (!id.matches("[a-z0-9-]{1,100}")) return missing();
    ContentModels.Article article;
    try {
      article = articles.find(id);
    } catch (ApiException error) {
      if (error.status == HttpStatus.NOT_FOUND) return missing();
      throw error;
    }
    if (!article.confirmed() || article.publishedAt().isAfter(Instant.now())) return missing();

    String title = escape(article.title());
    String synopsis = ArticleTranslation.shortSynopsis(article.summary().stream()
        .filter(text -> !text.isBlank()).findFirst().orElse(""));
    String canonical = HOST + "/m/" + id;
    String paragraphs = Arrays.stream(article.body().split("\\R\\s*\\R"))
        .filter(text -> !text.isBlank()).map(text -> "<p>" + escape(text) + "</p>")
        .collect(Collectors.joining());
    if (paragraphs.isEmpty()) paragraphs = "<p>A fonte disponibilizou apenas um trecho.</p>";
    String sources = article.sources().stream().map(SharedArticleController::sourceLink)
        .collect(Collectors.joining());
    String meta = """
        <link rel="canonical" href="%1$s">
        <meta property="og:url" content="%1$s">
        <meta property="og:title" content="%2$s">
        <meta property="og:description" content="%3$s">
        <meta property="og:type" content="article">
        <meta property="og:site_name" content="news.dev">
        """.formatted(canonical, title, escape(synopsis));
    String content = "<h1>" + title + "</h1>"
        + (synopsis.isEmpty() ? "" : "<section class=\"synopsis\"><h2>Sinopse</h2><p>"
            + escape(synopsis) + "</p></section>")
        + "<p><a class=\"open\" href=\"radar://materia/" + id
        + "?source=share\">Abrir no app</a></p>" + paragraphs
        + (sources.isEmpty() ? "" : "<h2>Fontes</h2><ul>" + sources + "</ul>");
    return page(HttpStatus.OK, title, meta, content);
  }

  private static String sourceLink(ContentModels.Source source) {
    String name = escape(source.name());
    try {
      URI url = URI.create(source.url());
      if (("https".equalsIgnoreCase(url.getScheme()) || "http".equalsIgnoreCase(url.getScheme()))
          && url.getHost() != null && url.getUserInfo() == null) {
        return "<li><a href=\"" + escape(url.toASCIIString()) + "\" rel=\"noopener noreferrer\">"
            + name + "</a></li>";
      }
    } catch (IllegalArgumentException ignored) {
      // O veículo ainda aparece como atribuição se não houver URL válida.
    }
    return "<li>" + name + "</li>";
  }

  private static ResponseEntity<String> missing() {
    return page(HttpStatus.NOT_FOUND, "Matéria indisponível", "",
        "<h1>Matéria indisponível</h1><p>Este link não leva a uma matéria publicada.</p>");
  }

  private static String escape(String text) {
    return HtmlUtils.htmlEscape(text, "UTF-8");
  }

  private static ResponseEntity<String> page(HttpStatus status, String title, String meta, String content) {
    return ResponseEntity.status(status)
        .header("Content-Security-Policy",
            "default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; frame-ancestors 'none'")
        .header("Referrer-Policy", "no-referrer")
        .body("""
            <!doctype html>
            <html lang="pt-BR"><head><meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>%s · news.dev</title>%s
            <style>
            :root{color-scheme:dark;font:16px/1.65 system-ui,sans-serif;background:#101014;color:#f5f5f8}
            main{max-width:44rem;margin:auto;padding:2.5rem 1.25rem 4rem;overflow-wrap:anywhere}
            h1,h2{line-height:1.2}h1{font-size:clamp(2rem,6vw,3.2rem);letter-spacing:-.04em}
            h2{font-size:1.15rem}.brand,a{color:#d4ff3a}.brand{font-weight:750}
            .synopsis{padding:.4rem 1.1rem;background:#1c1c1e;border-radius:14px}
            .open{display:inline-block;border-radius:2rem;background:#d4ff3a;color:#0d1400;
            padding:.6rem 1.1rem;font-weight:700;text-decoration:none}li{margin:.35rem 0}
            </style></head><body><main><div class="brand">news.dev</div>%s</main></body></html>
            """.formatted(title, meta, content));
  }
}
