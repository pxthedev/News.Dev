package br.com.radar.content;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

class SharedArticleControllerTest {
  private final ContentRepository repository = mock(ContentRepository.class);
  private final SharedArticleController controller = new SharedArticleController(repository, "");

  @Test
  void rendersThePublishedArticleWithADeepLinkAndEscapesFeedText() {
    when(repository.find("example")).thenReturn(article(true, Instant.now().minusSeconds(5)));
    var response = controller.shared("example");
    assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
    assertThat(response.getBody())
        .contains(
            "radar://materia/example?source=share",
            "/m/example",
            "&lt;unsafe&gt;",
            "Fontes",
            "Veículo");
    assertThat(response.getBody()).doesNotContain("<unsafe>", "javascript:");
  }

  @Test
  void hidesUnconfirmedOrScheduledArticlesFromPublicLinks() {
    when(repository.find("example")).thenReturn(article(false, Instant.now().minusSeconds(5)));
    assertThat(controller.shared("example").getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
    when(repository.find("example")).thenReturn(article(true, Instant.now().plusSeconds(60)));
    assertThat(controller.shared("example").getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
  }

  private static ContentModels.Article article(boolean confirmed, Instant published) {
    return new ContentModels.Article(
        "example",
        "Título <unsafe>",
        List.of("Sinopse"),
        "Conteúdo <unsafe>",
        "ia",
        null,
        null,
        published,
        published,
        List.of(new ContentModels.Source("Veículo", "javascript:alert(1)", null, null)),
        1,
        false,
        null,
        "normal",
        confirmed,
        1,
        null,
        null,
        List.of(),
        null);
  }
}
