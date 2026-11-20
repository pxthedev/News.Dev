package br.com.radar;

import static org.assertj.core.api.Assertions.*;

import br.com.radar.ingestion.*;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import org.junit.jupiter.api.Test;

class RssFetcherTest {
  @Test
  void parsesRssWithoutLoadingExternalContent() throws Exception {
    var entries =
        RssFetcher.parse(
            "<rss version='2.0'><channel><title>Teste</title><link>https://example.com</link><description>Feed</description><item><title>Notícia</title><link>https://example.com/a</link><description>Resumo</description></item></channel></rss>"
                .getBytes(StandardCharsets.UTF_8));
    assertThat(entries).hasSize(1);
    assertThat(entries.getFirst().getTitle()).isEqualTo("Notícia");
  }

  @Test
  void blocksDoctypeAndExternalEntities() {
    assertThatThrownBy(
            () ->
                RssFetcher.parse(
                    "<!DOCTYPE rss [<!ENTITY xxe SYSTEM 'file:///not-accessed'>]><rss>&xxe;</rss>"
                        .getBytes(StandardCharsets.UTF_8)))
        .isInstanceOf(Exception.class);
  }

  @Test
  void canonicalizationRemovesTrackersButKeepsArticleIdentity() {
    assertThat(
            IngestionService.canonical(
                URI.create("https://EXAMPLE.com/a?id=42&utm_source=x#fragment")))
        .isEqualTo("https://example.com/a?id=42");
    assertThat(RssFetcher.text("<script>bad()</script><b>Bom</b> &amp; seguro"))
        .isEqualTo("Bom & seguro");
  }
}
