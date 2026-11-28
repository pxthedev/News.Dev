package br.com.radar.content;

import static br.com.radar.content.ContentModels.*;

import br.com.radar.auth.IdentityRepository;
import br.com.radar.common.ApiException;
import br.com.radar.user.UserRepository;
import jakarta.validation.constraints.*;
import java.time.Instant;
import java.util.*;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/v1")
public class ContentController {
  private final ContentRepository repo;
  private final ContentService service;
  private final UserRepository users;
  private final ArticleTranslation translations;
  private final IdentityRepository identities;

  public ContentController(
      ContentRepository repo,
      ContentService service,
      UserRepository users,
      ArticleTranslation translations,
      IdentityRepository identities) {
    this.repo = repo;
    this.service = service;
    this.users = users;
    this.translations = translations;
    this.identities = identities;
  }

  @GetMapping("/home")
  Map<String, Object> home(
      @AuthenticationPrincipal Jwt jwt,
      @RequestParam(defaultValue = "false") boolean rumors,
      @RequestParam(required = false) String topics) {
    return service.home(rumors, topics(jwt, topics));
  }

  @GetMapping("/feed")
  Page<Article> feed(
      @AuthenticationPrincipal Jwt jwt,
      @RequestParam(defaultValue = "for-you") String filter,
      @RequestParam(defaultValue = "false") boolean rumors,
      @RequestParam(required = false) String cursor,
      @RequestParam(defaultValue = "20") @Min(1) @Max(100) int limit,
      @RequestParam(required = false) String topics) {
    return repo.feed(
        jwt.getSubject(), filter, rumors, null, null, cursor, limit, topics(jwt, topics));
  }

  @GetMapping("/feed/new-count")
  Map<String, Integer> count(
      @AuthenticationPrincipal Jwt jwt,
      @RequestParam Instant since,
      @RequestParam(defaultValue = "for-you") String filter,
      @RequestParam(defaultValue = "false") boolean rumors,
      @RequestParam(required = false) String topics) {
    return Map.of(
        "count", repo.newCount(jwt.getSubject(), filter, rumors, since, topics(jwt, topics)));
  }

  /**
   * Tópicos seguidos: os enviados pelo app (que guarda a escolha também para quem não tem conta)
   * ou, sem o parâmetro, os das preferências salvas. Lista vazia = todos os tópicos.
   */
  private List<String> topics(Jwt jwt, String requested) {
    if (requested != null)
      return Arrays.stream(requested.split(","))
          .map(String::strip)
          .filter(topic -> topic.matches(ContentModels.CATEGORY))
          .distinct()
          .toList();
    return jwt == null ? List.of() : users.topics(jwt.getSubject());
  }

  @GetMapping("/articles/{id}")
  Article article(@PathVariable String id) {
    return repo.find(id);
  }

  @GetMapping("/articles/{id}/translation")
  ArticleTranslation.Translated translation(
      @AuthenticationPrincipal Jwt jwt, @PathVariable String id, @RequestParam String language) {
    if (identities.user(jwt.getSubject()).getString("email") == null)
      throw new ApiException(
          org.springframework.http.HttpStatus.FORBIDDEN,
          "account_required",
          "Entre com uma conta para traduzir matérias.");
    return translations.translate(repo.find(id), language);
  }

  @GetMapping("/articles/headline-translations")
  Map<String, String> headlineTranslations(
      @AuthenticationPrincipal Jwt jwt,
      @RequestParam @Size(max = 1600) String ids,
      @RequestParam String language) {
    if (identities.user(jwt.getSubject()).getString("email") == null)
      throw new ApiException(
          org.springframework.http.HttpStatus.FORBIDDEN,
          "account_required",
          "Entre com uma conta para traduzir matérias.");
    var articleIds = new LinkedHashSet<>(Arrays.asList(ids.split(",")));
    if (articleIds.size() > 15
        || articleIds.stream().anyMatch(id -> !id.matches("[a-z0-9-]{1,100}"))) {
      throw ApiException.invalid("Informe até 15 identificadores válidos.");
    }
    return translations.headlines(repo.byIds(List.copyOf(articleIds)), language);
  }

  @GetMapping("/articles")
  Map<String, Object> articles(@RequestParam @Size(max = 10100) String ids) {
    return Map.of("items", repo.byIds(ids.isBlank() ? List.of() : Arrays.asList(ids.split(","))));
  }

  @GetMapping("/topics/{slug}")
  Map<String, Object> topic(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable String slug,
      @RequestParam(required = false) @Size(max = 100) String company,
      @RequestParam(required = false) String cursor,
      @RequestParam(defaultValue = "false") boolean rumors) {
    return service.topic(jwt.getSubject(), slug, company, cursor, rumors);
  }

  @GetMapping("/explore")
  Map<String, Object> explore() {
    var result = new LinkedHashMap<>(service.explore());
    result.put("trending", users.trending());
    return result;
  }

  @GetMapping("/search")
  Map<String, Object> search(
      @RequestParam @Size(max = 200) String q,
      @RequestParam(defaultValue = "false") boolean rumors) {
    return service.search(q, rumors);
  }

  @GetMapping("/live/{id}")
  LiveEvent live(@PathVariable String id) {
    return repo.live(id);
  }
}
