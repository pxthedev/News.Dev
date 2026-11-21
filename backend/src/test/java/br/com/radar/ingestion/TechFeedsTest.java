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
  void groupsDataCareersAnalyticsAndSpecialistFeeds() {
    assertThat(TechFeeds.category("O que faz um analista de dados?", "", null)).isEqualTo("dados");
    assertThat(TechFeeds.category("Python and SQL for reporting", "", null)).isEqualTo("dados");
    assertThat(TechFeeds.category("Google publica novidades", "", "dados")).isEqualTo("dados");
    assertThat(TechFeeds.category("Power BI sofre vazamento de dados", "", null)).isEqualTo("seguranca");
  }

  @Test
  void requiresOptInForLicensedPublishers() {
    assertThat(TechFeeds.catalog(false)).hasSize(10)
        .noneMatch(TechFeeds.Feed::licensedOnly);
    assertThat(TechFeeds.catalog(true)).hasSize(13);
  }
}
