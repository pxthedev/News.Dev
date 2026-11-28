package br.com.radar.ingestion;

import static org.assertj.core.api.Assertions.assertThat;

import br.com.radar.content.ContentModels;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.ByteArrayOutputStream;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.List;
import org.junit.jupiter.api.Test;

class GoogleNewsTest {
  private final GoogleNewsLinks links = new GoogleNewsLinks(new ObjectMapper());

  @Test
  void hasAQueryForEveryTopicOfTheApp() {
    assertThat(GoogleNewsTopics.QUERIES.keySet())
        .containsExactlyInAnyOrder(ContentModels.CATEGORY.split("\\|"));
  }

  @Test
  void buildsAPortugueseSearchRestrictedToTheOpenHosts() {
    String url =
        GoogleNewsTopics.searchUrl("chips", List.of("agenciabrasil.ebc.com.br", "x.gov.br"), 2);
    assertThat(url)
        .startsWith("https://news.google.com/rss/search?q=")
        .endsWith("&hl=pt-BR&gl=BR&ceid=BR:pt-419");
    String query = URLDecoder.decode(url.split("q=")[1].split("&")[0], StandardCharsets.UTF_8);
    assertThat(query)
        .contains("semicondutores OR chips")
        .contains("(site:agenciabrasil.ebc.com.br OR site:x.gov.br)")
        .endsWith(" when:2d");
  }

  @Test
  void splitsThePublisherSuffixFromTheTitle() {
    assertThat(GoogleNewsTopics.splitTitle("Governo lança plano de IA - Agência Brasil"))
        .containsExactly("Governo lança plano de IA", "Agência Brasil");
    assertThat(GoogleNewsTopics.splitTitle("Título sem veículo"))
        .containsExactly("Título sem veículo", "");
  }

  @Test
  void readsTheArticleIdOnlyFromGoogleNewsLinks() {
    assertThat(GoogleNewsLinks.articleId("https://news.google.com/rss/articles/CBMiABC_-1?oc=5"))
        .contains("CBMiABC_-1");
    assertThat(GoogleNewsLinks.articleId("https://evil.example/rss/articles/CBMi")).isEmpty();
    assertThat(GoogleNewsLinks.articleId("http://news.google.com/rss/articles/CBMi")).isEmpty();
  }

  @Test
  void decodesLegacyBase64Links() {
    String target = "https://agenciabrasil.ebc.com.br/geral/noticia/2026-11/teste";
    var bytes = new ByteArrayOutputStream();
    bytes.write(0x08);
    bytes.write(0x13);
    bytes.write(0x22);
    bytes.write(target.length());
    bytes.writeBytes(target.getBytes(StandardCharsets.UTF_8));
    bytes.write(0xd2);
    String id = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes.toByteArray());
    assertThat(GoogleNewsLinks.legacy(id)).contains(target);
    assertThat(GoogleNewsLinks.legacy("AU_yqLNotLegacy")).isEmpty();
  }

  @Test
  void buildsTheBatchRequestAndReadsTheDecodedUrl() throws Exception {
    var mapper = new ObjectMapper();
    var request = mapper.readTree(links.request("CBMiXYZ", 1764000000L, "sig123"));
    var rpc = request.path(0).path(0);
    assertThat(rpc.path(0).asText()).isEqualTo("Fbv4je");
    var inner = mapper.readTree(rpc.path(1).asText());
    assertThat(inner.path(0).asText()).isEqualTo("garturlreq");
    assertThat(inner.path(2).asText()).isEqualTo("CBMiXYZ");
    assertThat(inner.path(3).asLong()).isEqualTo(1764000000L);
    assertThat(inner.path(4).asText()).isEqualTo("sig123");

    String body =
        ")]}'\n\n123\n[[\"wrb.fr\",\"Fbv4je\",\"[\\\"garturlres\\\",\\\"https://agenciabrasil.ebc.com.br/x\\\",1]\",null,null,null,\"generic\"]]\n58\n[[\"di\",10]]";
    assertThat(links.decodedUrl(body)).contains("https://agenciabrasil.ebc.com.br/x");
    assertThat(links.decodedUrl(")]}'\n[[\"er\",null]]")).isEmpty();
  }

  @Test
  void keepsOnlyFullOwnStoriesAsBody() {
    String paragraph = "Texto da reportagem sobre tecnologia no Brasil. ".repeat(3).trim();
    String story = String.join("\n\n", paragraph, paragraph, paragraph);
    assertThat(GoogleNewsCollector.openBody(story)).isTrue();
    assertThat(GoogleNewsCollector.openBody(paragraph)).isFalse();
    assertThat(GoogleNewsCollector.openBody(story + "\n\n*Com informações da Reuters")).isFalse();
  }

  @Test
  void parsesTheGoogleNewsRssShape() throws Exception {
    String xml =
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0"><channel><title>t</title><link>https://news.google.com</link>
        <description>d</description>
        <item><title>Brasil amplia 5G - Agência Brasil</title>
        <link>https://news.google.com/rss/articles/CBMiABC?oc=5</link>
        <pubDate>Thu, 26 Nov 2026 12:00:00 GMT</pubDate>
        <source url="https://agenciabrasil.ebc.com.br">Agência Brasil</source></item>
        </channel></rss>
        """;
    var entries = RssFetcher.parse(xml.strip().getBytes(StandardCharsets.UTF_8));
    assertThat(entries).hasSize(1);
    assertThat(GoogleNewsLinks.articleId(entries.getFirst().getLink())).contains("CBMiABC");
    assertThat(GoogleNewsTopics.splitTitle(entries.getFirst().getTitle())[1])
        .isEqualTo("Agência Brasil");
    assertThat(entries.getFirst().getPublishedDate()).isNotNull();
  }

  @org.junit.jupiter.api.Test
  void onlyConfiguredSitesAndSubdomains() {
    var sites = java.util.Set.of("g1.globo.com", "r7.com");
    org.junit.jupiter.api.Assertions.assertTrue(GoogleNewsCollector.onSite("g1.globo.com", sites));
    org.junit.jupiter.api.Assertions.assertTrue(
        GoogleNewsCollector.onSite("Noticias.R7.com", sites));
    org.junit.jupiter.api.Assertions.assertFalse(GoogleNewsCollector.onSite("globo.com", sites));
    org.junit.jupiter.api.Assertions.assertFalse(
        GoogleNewsCollector.onSite("g1.globo.com.evil.io", sites));
    org.junit.jupiter.api.Assertions.assertFalse(GoogleNewsCollector.onSite("notr7.com", sites));
  }

  @org.junit.jupiter.api.Test
  void offTopicHeadlinesHaveNoStrictCategory() {
    org.junit.jupiter.api.Assertions.assertNull(
        TechFeeds.strictCategory(
            "Expectativa de vida dos brasileiros chega a quase 77 anos", "games"));
    org.junit.jupiter.api.Assertions.assertEquals(
        "games", TechFeeds.strictCategory("Nintendo anuncia novo console", "games"));
    org.junit.jupiter.api.Assertions.assertEquals(
        "ia", TechFeeds.strictCategory("OpenAI lança modelo no Brasil", "games"));
    org.junit.jupiter.api.Assertions.assertEquals(
        "bigtech", TechFeeds.strictCategory("Google e OpenAI disputam mercado", "bigtech"));
  }

  @org.junit.jupiter.api.Test
  void techHeadlinesRemovedByTheFirstCleanupNowMatch() {
    var cases =
        java.util.Map.of(
            "PL das Big Techs: relator altera texto e espera votar nesta terça", "regulacao",
            "Europa planeja fundo de € 50 bilhões para impulsionar tecnologia quântica", "chips",
            "Abin apresenta estratégia para criptografia pós-quântica", "seguranca",
            "Estação espacial chinesa recebe o primeiro astronauta estrangeiro", "espaco",
            "IFS oferece 180 vagas em curso gratuito de desenvolvimento de games", "games",
            "Justiça dos EUA condena Huawei por esquema ligado ao Irã", "chips",
            "Anatel abre consulta pública sobre medidas de segurança em ligações", "tech-br",
            "Tecnologia permite que paciente tetraplégica controle cadeiras de rodas", "tech-br");
    cases.forEach(
        (title, category) ->
            org.junit.jupiter.api.Assertions.assertEquals(
                category, TechFeeds.strictCategory(title, "nenhum"), title));
    for (String title :
        java.util.List.of(
            "Mulher perde R$ 80 mil após cair no 'golpe do amor' aplicado por falso médico",
            "Trabuco aceita convite e será ministro da Fazenda de Lula",
            "Celular explode dentro do bolso de empresário no meio do trânsito",
            "Superlua: veja quando e como observar fenômeno em Goiás"))
      org.junit.jupiter.api.Assertions.assertNull(TechFeeds.strictCategory(title, "nenhum"), title);
  }

  @org.junit.jupiter.api.Test
  void titleOnlyRulesSkipAmbiguousPortugueseWords() {
    for (String title :
        java.util.List.of(
            "Cachorro aprende a reconhecer sinais de libras para se comunicar com tutora",
            "No 9º mês de gestação, Sabrina Sato desfila pela Vila Isabel",
            "Burning Fest tem shows de rock, churrasco e entrada gratuita em Cubatão; veja a programação",
            "Dia D de vacinação contra a raiva para cães e gatos ocorre neste sábado",
            "Dor nas costas é sinal de abdômen fraco? Estudo questiona explicação comum",
            "Ele ia para o trabalho quando foi assaltado",
            "Governo cumpre a meta fiscal do ano",
            "Momento fofo! Ana Hickmann decora casa para fim de ano com auxílio de pets",
            "Suspeito é investigado por furtar R$ 7 mil em produtos de casa em Boa Vista"))
      org.junit.jupiter.api.Assertions.assertNull(
          TechFeeds.strictCategory(title, "bigtech"), title);
    var kept =
        java.util.Map.of(
            "Google prepara novos recursos para aproximar o Modo IA do buscador ao Gemini", "ia",
            "Nas escolas, 1 em cada 8 meninos admite ter criado nudes com IA", "ia",
            "EUA autorizam SpaceX a lançar 1 milhão de satélites", "espaco",
            "Data centers gigantes invadem bairros residenciais no Japão", "tech-br",
            "Robôs do tamanho de um grão de arroz podem levar medicamentos ao coração", "tech-br",
            "Livro revisita a história da Nintendo", "games",
            "Giro Internacional: hackers invadem sistema da Força Aérea dos EUA", "seguranca");
    kept.forEach(
        (title, category) ->
            org.junit.jupiter.api.Assertions.assertEquals(
                category, TechFeeds.strictCategory(title, "nenhum"), title));
  }

  @org.junit.jupiter.api.Test
  void sponsoredAndVideoRoundupPagesAreSkipped() {
    org.junit.jupiter.api.Assertions.assertTrue(
        GoogleNewsCollector.offTopicPage(
            "https://g1.globo.com/especial-publicitario/totvs/noticia/2026/11/x.ghtml", "CORTEN"));
    org.junit.jupiter.api.Assertions.assertTrue(
        GoogleNewsCollector.offTopicPage(
            "https://g1.globo.com/ba/bahia/edicao/2026/11/27/videos.ghtml",
            "Vídeos do g1 e TV Bahia - sexta-feira"));
    org.junit.jupiter.api.Assertions.assertFalse(
        GoogleNewsCollector.offTopicPage(
            "https://g1.globo.com/tecnologia/noticia/2026/11/28/data-centers.ghtml",
            "Data centers gigantes invadem bairros"));
  }
}
