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
        http.send(
            HttpRequest.newBuilder(URI.create(url))
                .timeout(Duration.ofSeconds(10))
                .header("User-Agent", "news.dev-feed-reader/1.0")
                .header("Accept-Encoding", "gzip")
                .GET()
                .build(),
            HttpResponse.BodyHandlers.ofInputStream());
    try (var input = response.body()) {
      if (response.statusCode() != 200)
        throw new IOException("Fonte retornou status " + response.statusCode());
      boolean gzip = response.headers().firstValue("Content-Encoding")
          .filter("gzip"::equalsIgnoreCase).isPresent();
      byte[] bytes = (gzip ? new GZIPInputStream(input) : input).readNBytes(2_000_001);
      if (bytes.length > 2_000_000) throw new IOException("Feed maior que 2MB");
      return parse(bytes);
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

  static String articleText(String html) {
    if (html == null) return "";
    return java.util.Arrays.stream(html.replaceAll("(?is)<(script|style)[^>]*>.*?</\\1>", "")
            .split("(?i)</(?:p|li|h[1-6]|blockquote)>|<br\\s*/?>|\\R\\s*\\R"))
        .map(RssFetcher::text)
        .filter(part -> !part.isBlank())
        .collect(java.util.stream.Collectors.joining("\n\n"));
  }

  public static String text(String html) {
    return html == null
        ? ""
        : html.replaceAll("(?is)<(script|style)[^>]*>.*?</\\1>", "")
            .replaceAll("(?s)<[^>]+>", " ")
            .replace("&amp;", "&")
            .replace("&lt;", "<")
            .replace("&gt;", ">")
            .replace("&quot;", "\"")
            .replace("&#39;", "'")
            .replace("&nbsp;", " ")
            .replaceAll("\\s+", " ")
            .trim();
  }
}
