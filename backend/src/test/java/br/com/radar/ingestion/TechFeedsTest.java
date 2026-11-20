package br.com.radar.ingestion;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class TechFeedsTest {
  @Test
  void recognizesPortugueseAndEnglishTechInTitleOrDescription() {
    assertThat(TechFeeds.category("Inteligência artificial no Brasil", "", "tech-br"))
        .isEqualTo("ia");
    assertThat(TechFeeds.category("Security update", "Fixes two vulnerabilities", null))
        .isEqualTo("seguranca");
    assertThat(TechFeeds.category("Novos semicondutores anunciados", "", null))
        .isEqualTo("chips");
  }

  @Test
  void skipsUnrelatedStoriesFromMixedFeedsAndPromotionsFromAllFeeds() {
    assertThat(TechFeeds.category("Campeonato de futebol começa domingo", "", null))
        .isNull();
    assertThat(TechFeeds.category("Black Friday: descontos no iPhone", "", "gadgets"))
        .isNull();
    assertThat(TechFeeds.category("Nova reportagem da editoria", "", "tech-br"))
        .isEqualTo("tech-br");
  }

  @Test
  void requiresOptInForLicensedPublishers() {
    assertThat(TechFeeds.catalog(false)).hasSize(8)
        .noneMatch(TechFeeds.Feed::licensedOnly);
    assertThat(TechFeeds.catalog(true)).hasSize(11);
  }
}
