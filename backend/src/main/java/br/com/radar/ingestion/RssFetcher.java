package br.com.radar.ingestion;

import br.com.radar.common.ApiException;
import com.rometools.rome.feed.synd.*;
import com.rometools.rome.io.SyndFeedInput;
import java.io.*;
import java.net.*;
import java.net.http.*;
import java.time.Duration;
import java.util.*;
import java.util.zip.GZIPInputStream;
import org.jdom2.input.SAXBuilder;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.util.HtmlUtils;

@Component
public class RssFetcher {
  private final Set<String> allowed;
  private final HttpClient http =
      HttpClient.newBuilder()
          .connectTimeout(Duration.ofSeconds(5))
          .followRedirects(HttpClient.Redirect.NEVER)
          .build();

  public RssFetcher(@Value("${radar.ingestion.allowed-hosts}") String hosts) {
    allowed = new HashSet<>();
    for (String host : hosts.split(","))
      if (!host.isBlank()) allowed.add(host.trim().toLowerCase(Locale.ROOT));
  }

  public void validate(String value) {
    validate(value, null);
  }

  private void validate(String value, String catalogHost) {
    try {
      URI uri = URI.create(value);
      if (!"https".equals(uri.getScheme())
          || uri.getHost() == null
          || uri.getUserInfo() != null
          || (uri.getPort() != -1 && uri.getPort() != 443)
          || !(uri.getHost().equalsIgnoreCase(catalogHost)
              || allowed.contains(uri.getHost().toLowerCase(Locale.ROOT))))
        throw new IllegalArgumentException();
      for (InetAddress address : InetAddress.getAllByName(uri.getHost()))
        if (address.isAnyLocalAddress()
            || address.isLoopbackAddress()
            || address.isLinkLocalAddress()
            || address.isSiteLocalAddress()
            || address.isMulticastAddress()) throw new IllegalArgumentException();
    } catch (Exception e) {
      throw ApiException.invalid(
          "A fonte deve usar HTTPS e um domínio público autorizado em RSS_ALLOWED_HOSTS.");
    }
  }

  public List<SyndEntry> fetch(String url) throws Exception {
    return fetch(url, null);
  }

  List<SyndEntry> fetch(String url, String catalogHost) throws Exception {
    validate(url, catalogHost);
    var response =
        download(
            HttpRequest.newBuilder(URI.create(url))
                .timeout(Duration.ofSeconds(10))
                .header("User-Agent", "news.dev-feed-reader/1.0")
                .header("Accept-Encoding", "gzip")
                .GET()
                .build(),
            2_000_000);
    if (response.status() != 200)
      throw new IOException("Fonte retornou status " + response.status());
    if (response.bytes() == null) throw new IOException("Feed maior que 2MB");
    return parse(response.bytes());
  }

  private record Downloaded(int status, HttpHeaders headers, byte[] bytes) {}

  /** Tempo máximo de uma requisição inteira, corpo incluído. */
  static final Duration TOTAL_TIMEOUT = Duration.ofSeconds(25);

  private static final java.util.concurrent.ExecutorService READERS =
      java.util.concurrent.Executors.newVirtualThreadPerTaskExecutor();

  /**
   * Baixa até {@code max} bytes (descompactando gzip) com prazo total. O timeout do HttpRequest só
   * cobre a chegada dos cabeçalhos: um servidor que trava no meio do corpo prenderia a thread de
   * agendamento para sempre. Estourado o prazo, o stream é fechado e a leitura é abortada. Corpo
   * maior que {@code max} volta com {@code bytes} nulo.
   */
  private Downloaded download(HttpRequest request, int max) throws Exception {
    var stream = new java.util.concurrent.atomic.AtomicReference<InputStream>();
    var future =
        http.sendAsync(request, HttpResponse.BodyHandlers.ofInputStream())
            .thenApplyAsync(
                response -> {
                  try (var input = response.body()) {
                    stream.set(input);
                    if (response.statusCode() != 200)
                      return new Downloaded(response.statusCode(), response.headers(), new byte[0]);
                    boolean gzip =
                        response
                            .headers()
                            .firstValue("Content-Encoding")
                            .filter("gzip"::equalsIgnoreCase)
                            .isPresent();
                    byte[] bytes = (gzip ? new GZIPInputStream(input) : input).readNBytes(max + 1);
                    return new Downloaded(
                        200, response.headers(), bytes.length > max ? null : bytes);
                  } catch (IOException e) {
                    throw new java.io.UncheckedIOException(e);
                  }
                },
                READERS);
    try {
      return future.get(TOTAL_TIMEOUT.toMillis(), java.util.concurrent.TimeUnit.MILLISECONDS);
    } catch (java.util.concurrent.TimeoutException e) {
      future.cancel(true);
      var input = stream.get();
      if (input != null) {
        try {
          input.close();
        } catch (IOException ignored) {
          // Só queremos destravar a leitura.
        }
      }
      throw new IOException("Tempo esgotado ao baixar " + request.uri().getHost());
    } catch (java.util.concurrent.ExecutionException e) {
      if (e.getCause() instanceof Exception cause) throw cause;
      throw e;
    }
  }

  public static List<SyndEntry> parse(byte[] xml) throws Exception {
    var builder = new SAXBuilder();
    builder.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
    builder.setFeature("http://xml.org/sax/features/external-general-entities", false);
    builder.setFeature("http://xml.org/sax/features/external-parameter-entities", false);
    builder.setExpandEntities(false);
    return new SyndFeedInput().build(builder.build(new ByteArrayInputStream(xml))).getEntries();
  }

  /**
   * Baixa a página da matéria e extrai os parágrafos do texto, só para servir de base ao resumo (o
   * texto não é guardado nem exibido). Aceita veículos brasileiros do catálogo ou hosts em
   * RSS_ALLOWED_HOSTS; retorna vazio em qualquer falha.
   */
  public String pageText(String url) {
    try {
      URI uri = URI.create(url);
      String host = uri.getHost();
      if (host == null) return "";
      boolean trusted =
          br.com.radar.content.BrazilianPublishers.contains(url)
              || allowed.contains(host.toLowerCase(Locale.ROOT));
      if (!trusted) return "";
      validate(url, host);
      var response =
          download(
              HttpRequest.newBuilder(uri)
                  .timeout(Duration.ofSeconds(10))
                  .header("User-Agent", "Mozilla/5.0 (compatible; news.dev-reader/1.0)")
                  .header("Accept", "text/html")
                  .header("Accept-Encoding", "gzip")
                  .GET()
                  .build(),
              3_000_000);
      if (response.status() != 200 || response.bytes() == null) return "";
      String charset =
          response
              .headers()
              .firstValue("Content-Type")
              .map(type -> type.replaceAll("(?i).*charset=([\\w-]+).*", "$1"))
              .filter(name -> !name.contains("/") && java.nio.charset.Charset.isSupported(name))
              .orElse("UTF-8");
      return readableText(new String(response.bytes(), charset));
    } catch (InterruptedException e) {
      Thread.currentThread().interrupt();
      return "";
    } catch (Exception e) {
      return "";
    }
  }

  private static final java.util.regex.Pattern ARTICLE =
      java.util.regex.Pattern.compile("(?is)<article\\b[^>]*>(.*)</article>");
  private static final java.util.regex.Pattern PARAGRAPH =
      java.util.regex.Pattern.compile("(?is)<p\\b[^>]*>(.*?)</p>");
  private static final java.util.regex.Pattern BOILERPLATE =
      java.util.regex.Pattern.compile(
          "(?i)^(leia (também|mais)|veja (também|mais)|siga o|assine|inscreva-se|receba as|"
              + "clique aqui|compartilhe|publicidade|newsletter|participe do canal)|"
              + "todos os direitos reservados|utilizamos cookies|usamos cookies|"
              + "[—–-]\\s*(foto|imagem|reprodução)\\s*:");

  /** Extrai o texto corrido de uma página de notícia (parágrafos dentro de article, se houver). */
  static String readableText(String html) {
    if (html == null) return "";
    String clean =
        html.replaceAll(
            "(?is)<(script|style|noscript|svg|figure|figcaption|aside|nav|header|footer|form|button)\\b[^>]*>.*?</\\1>",
            " ");
    var article = ARTICLE.matcher(clean);
    if (article.find()) clean = article.group(1);
    var text = new StringBuilder();
    var paragraphs = PARAGRAPH.matcher(clean);
    while (paragraphs.find() && text.length() < 12_000) {
      String paragraph = text(paragraphs.group(1));
      if (paragraph.length() < 60 || BOILERPLATE.matcher(paragraph).find()) continue;
      if (!text.isEmpty()) text.append("\n\n");
      text.append(paragraph);
    }
    return text.toString();
  }

  static String articleText(String html) {
    if (html == null) return "";
    return java.util.Arrays.stream(
            html.replaceAll("(?is)<(script|style)[^>]*>.*?</\\1>", "")
                .split("(?i)</(?:p|li|h[1-6]|blockquote)>|<br\\s*/?>|\\R\\s*\\R"))
        .map(RssFetcher::text)
        .filter(part -> !part.isBlank())
        .collect(java.util.stream.Collectors.joining("\n\n"));
  }

  public static String text(String html) {
    return html == null
        ? ""
        : HtmlUtils.htmlUnescape(
                html.replaceAll("(?is)<(script|style)[^>]*>.*?</\\1>", "")
                    .replaceAll("(?s)<[^>]+>", " "))
            .replace('\u00a0', ' ')
            .replaceAll("\\s+", " ")
            .trim();
  }
}
