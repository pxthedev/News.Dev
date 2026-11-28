package br.com.radar.ingestion;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Base64;
import java.util.List;
import java.util.Optional;
import java.util.regex.Pattern;
import org.springframework.stereotype.Component;

/**
 * Converte o link do Google News (news.google.com/rss/articles/…) no endereço real da matéria.
 *
 * <p>Links antigos trazem a URL codificada em base64. Os atuais exigem a assinatura que a página do
 * artigo publica e uma chamada ao endpoint batchexecute, o mesmo que o site usa para redirecionar.
 * É um formato não documentado: qualquer falha devolve vazio e a matéria é simplesmente ignorada.
 */
@Component
public class GoogleNewsLinks {
  private static final Pattern SIGNATURE = Pattern.compile("data-n-a-sg=\"([^\"]+)\"");
  private static final Pattern TIMESTAMP = Pattern.compile("data-n-a-ts=\"(\\d+)\"");
  private static final Pattern ARTICLE_ID =
      Pattern.compile("^/(?:rss/)?articles/([A-Za-z0-9_-]+)$");
  private static final URI BATCH =
      URI.create("https://news.google.com/_/DotsSplashUi/data/batchexecute");

  private final ObjectMapper json;
  private final HttpClient http =
      HttpClient.newBuilder()
          .connectTimeout(Duration.ofSeconds(5))
          .followRedirects(HttpClient.Redirect.NEVER)
          .build();

  public GoogleNewsLinks(ObjectMapper json) {
    this.json = json;
  }

  /** Identificador do artigo num link do Google News, ou vazio se não for um. */
  static Optional<String> articleId(String link) {
    try {
      URI uri = URI.create(link);
      if (!"https".equals(uri.getScheme()) || !GoogleNewsTopics.HOST.equals(uri.getHost()))
        return Optional.empty();
      var matcher = ARTICLE_ID.matcher(uri.getPath());
      return matcher.matches() ? Optional.of(matcher.group(1)) : Optional.empty();
    } catch (Exception e) {
      return Optional.empty();
    }
  }

  public Optional<String> resolve(String link) {
    var id = articleId(link);
    if (id.isEmpty()) return Optional.empty();
    var legacy = legacy(id.get());
    if (legacy.isPresent()) return legacy;
    try {
      var page =
          send(
              HttpRequest.newBuilder(
                      URI.create(
                          "https://news.google.com/rss/articles/"
                              + id.get()
                              + "?hl=pt-BR&gl=BR&ceid=BR:pt-419"))
                  .timeout(Duration.ofSeconds(10))
                  .header("User-Agent", "Mozilla/5.0 (compatible; news.dev-reader/1.0)")
                  .GET()
                  .build(),
              HttpResponse.BodyHandlers.ofString());
      if (page.statusCode() != 200) return Optional.empty();
      var sg = SIGNATURE.matcher(page.body());
      var ts = TIMESTAMP.matcher(page.body());
      if (!sg.find() || !ts.find()) return Optional.empty();
      var response =
          send(
              HttpRequest.newBuilder(BATCH)
                  .timeout(Duration.ofSeconds(10))
                  .header("Content-Type", "application/x-www-form-urlencoded;charset=UTF-8")
                  .header("User-Agent", "Mozilla/5.0 (compatible; news.dev-reader/1.0)")
                  .POST(
                      HttpRequest.BodyPublishers.ofString(
                          "f.req="
                              + URLEncoder.encode(
                                  request(id.get(), Long.parseLong(ts.group(1)), sg.group(1)),
                                  StandardCharsets.UTF_8)))
                  .build(),
              HttpResponse.BodyHandlers.ofString());
      if (response.statusCode() != 200) return Optional.empty();
      return decodedUrl(response.body());
    } catch (InterruptedException e) {
      Thread.currentThread().interrupt();
      return Optional.empty();
    } catch (Exception e) {
      return Optional.empty();
    }
  }

  /** Prazo total por requisição (o timeout do HttpRequest não cobre a leitura do corpo). */
  private <T> HttpResponse<T> send(HttpRequest request, HttpResponse.BodyHandler<T> handler)
      throws Exception {
    var future = http.sendAsync(request, handler);
    try {
      return future.get(
          RssFetcher.TOTAL_TIMEOUT.toMillis(), java.util.concurrent.TimeUnit.MILLISECONDS);
    } catch (java.util.concurrent.TimeoutException e) {
      future.cancel(true);
      throw e;
    }
  }

  /** Formato antigo: protobuf em base64 com a URL logo após o cabeçalho 08 13 22. */
  static Optional<String> legacy(String id) {
    try {
      byte[] bytes = Base64.getUrlDecoder().decode(pad(id));
      if (bytes.length < 5 || bytes[0] != 0x08 || bytes[1] != 0x13 || bytes[2] != 0x22)
        return Optional.empty();
      int length = 0;
      int shift = 0;
      int pos = 3;
      while (pos < bytes.length) {
        int b = bytes[pos++] & 0xff;
        length |= (b & 0x7f) << shift;
        if ((b & 0x80) == 0) break;
        shift += 7;
        if (shift > 21) return Optional.empty();
      }
      if (length <= 0 || pos + length > bytes.length) return Optional.empty();
      String url = new String(bytes, pos, length, StandardCharsets.UTF_8);
      return url.startsWith("https://") || url.startsWith("http://")
          ? Optional.of(url)
          : Optional.empty();
    } catch (IllegalArgumentException e) {
      return Optional.empty();
    }
  }

  private static String pad(String id) {
    int rest = id.length() % 4;
    return rest == 0 ? id : id + "=".repeat(4 - rest);
  }

  String request(String id, long timestamp, String signature) throws Exception {
    var inner =
        List.of(
            "garturlreq",
            json.readTree(
                "[[\"X\",\"X\",[\"X\",\"X\"],null,null,1,1,\"US:en\",null,1,null,null,null,null,"
                    + "null,0,1],\"X\",\"X\",1,[1,1,1],1,1,null,0,0,null,0]"),
            id,
            timestamp,
            signature);
    return json.writeValueAsString(
        List.of(
            List.of(
                java.util.Arrays.asList(
                    "Fbv4je", json.writeValueAsString(inner), null, "generic"))));
  }

  /** Lê a resposta do batchexecute ({@code )]}'} + linhas JSON) e devolve a URL decodificada. */
  Optional<String> decodedUrl(String body) {
    for (String line : body.split("\n")) {
      line = line.strip();
      if (!line.startsWith("[[")) continue;
      try {
        for (JsonNode item : json.readTree(line)) {
          if (!"wrb.fr".equals(item.path(0).asText()) || !item.path(2).isTextual()) continue;
          JsonNode payload = json.readTree(item.path(2).asText());
          if ("garturlres".equals(payload.path(0).asText()) && payload.path(1).isTextual()) {
            String url = payload.path(1).asText();
            if (url.startsWith("https://") || url.startsWith("http://")) return Optional.of(url);
          }
        }
      } catch (Exception ignored) {
        // Linha que não é JSON válido: segue para a próxima.
      }
    }
    return Optional.empty();
  }
}
