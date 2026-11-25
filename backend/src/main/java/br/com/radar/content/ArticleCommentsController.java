package br.com.radar.content;

import br.com.radar.auth.IdentityRepository;
import br.com.radar.common.ApiException;
import br.com.radar.content.ContentModels.Page;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.time.Instant;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/v1/articles/{articleId}/comments")
public class ArticleCommentsController {
  private static final int PAGE_SIZE = 20;
  private final ContentRepository articles;
  private final IdentityRepository identities;
  private final JdbcTemplate jdbc;

  public ArticleCommentsController(
      ContentRepository articles, IdentityRepository identities, JdbcTemplate jdbc) {
    this.articles = articles;
    this.identities = identities;
    this.jdbc = jdbc;
  }

  public record Input(@NotBlank @Size(max = 1000) String body) {}

  public record Comment(String id, String author, String body, Instant createdAt, boolean mine) {}

  @GetMapping
  Page<Comment> list(
      @PathVariable String articleId,
      @RequestParam(required = false) @Positive Long before,
      @AuthenticationPrincipal Jwt jwt) {
    requirePublished(articleId);
    var rows =
        jdbc.query(
            """
        select c.id, c.body, c.created_at, c.author_id, u.data->>'name' as author
        from fionova.article_comments c
        join fionova.users u on u.owner_id = '' and u.id = c.author_id
        where c.article_id = ? and c.id < ?
        order by c.id desc limit ?
        """,
            (rs, index) ->
                new Comment(
                    rs.getString("id"),
                    rs.getString("author"),
                    rs.getString("body"),
                    rs.getTimestamp("created_at").toInstant(),
                    rs.getString("author_id").equals(jwt.getSubject())),
            articleId,
            before == null ? Long.MAX_VALUE : before,
            PAGE_SIZE + 1);
    List<Comment> page = rows.subList(0, Math.min(rows.size(), PAGE_SIZE));
    return new Page<>(page, rows.size() > PAGE_SIZE ? page.getLast().id() : null);
  }

  @PostMapping
  @ResponseStatus(HttpStatus.CREATED)
  Comment post(
      @PathVariable String articleId,
      @Valid @RequestBody Input input,
      @AuthenticationPrincipal Jwt jwt) {
    requirePublished(articleId);
    var user = identities.user(jwt.getSubject());
    if (user.getString("email") == null)
      throw new ApiException(
          HttpStatus.FORBIDDEN, "account_required", "Entre com uma conta para comentar.");
    String body = input.body().strip();
    if (body.isBlank()
        || body.codePoints()
            .anyMatch(c -> Character.isISOControl(c) && c != '\n' && c != '\r' && c != '\t')) {
      throw ApiException.invalid("Escreva um comentário válido.");
    }
    return jdbc.queryForObject(
        """
        insert into fionova.article_comments (article_id, author_id, body)
        values (?, ?, ?) returning id, created_at
        """,
        (rs, index) ->
            new Comment(
                rs.getString("id"),
                user.getString("name"),
                body,
                rs.getTimestamp("created_at").toInstant(),
                true),
        articleId,
        jwt.getSubject(),
        body);
  }

  @DeleteMapping("/{commentId}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  void delete(
      @PathVariable String articleId,
      @PathVariable @Positive long commentId,
      @AuthenticationPrincipal Jwt jwt) {
    if (jdbc.update(
            "delete from fionova.article_comments where article_id = ? and id = ? and author_id = ?",
            articleId,
            commentId,
            jwt.getSubject())
        == 0) throw ApiException.missing();
  }

  private void requirePublished(String id) {
    if (articles.find(id).publishedAt().isAfter(Instant.now())) throw ApiException.missing();
  }
}
