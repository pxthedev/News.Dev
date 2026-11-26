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
import org.springframework.transaction.annotation.Transactional;
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

  public record Input(@NotBlank @Size(max = 1000) String body, @Positive Long parentId) {}

  public record Comment(
      String id,
      String author,
      String body,
      Instant createdAt,
      boolean mine,
      int likeCount,
      boolean liked,
      int replyCount) {}

  public record Reaction(int likeCount, boolean liked) {}

  @GetMapping
  Page<Comment> list(
      @PathVariable String articleId,
      @RequestParam(required = false) @Positive Long before,
      @RequestParam(required = false) @Positive Long parentId,
      @AuthenticationPrincipal Jwt jwt) {
    requirePublished(articleId);
    var rows =
        jdbc.query(
            """
        select c.id, c.body, c.created_at, c.author_id, u.data->>'name' as author,
          (select count(*) from fionova.article_comment_likes l where l.comment_id = c.id) as likes,
          exists(select 1 from fionova.article_comment_likes l
            where l.comment_id = c.id and l.user_id = ?) as liked,
          (select count(*) from fionova.article_comments r where r.parent_id = c.id) as replies
        from fionova.article_comments c
        join fionova.users u on u.owner_id = '' and u.id = c.author_id
        where c.article_id = ? and c.id < ?
          and c.parent_id is not distinct from cast(? as bigint)
        order by c.id desc limit ?
        """,
            (rs, index) ->
                new Comment(
                    rs.getString("id"),
                    rs.getString("author"),
                    rs.getString("body"),
                    rs.getTimestamp("created_at").toInstant(),
                    rs.getString("author_id").equals(jwt.getSubject()),
                    rs.getInt("likes"),
                    rs.getBoolean("liked"),
                    rs.getInt("replies")),
            jwt.getSubject(),
            articleId,
            before == null ? Long.MAX_VALUE : before,
            parentId,
            PAGE_SIZE + 1);
    List<Comment> page = rows.subList(0, Math.min(rows.size(), PAGE_SIZE));
    return new Page<>(page, rows.size() > PAGE_SIZE ? page.getLast().id() : null);
  }

  @PostMapping
  @ResponseStatus(HttpStatus.CREATED)
  @Transactional
  Comment post(
      @PathVariable String articleId,
      @Valid @RequestBody Input input,
      @AuthenticationPrincipal Jwt jwt) {
    requirePublished(articleId);
    String author = requireAccount(jwt);
    if (input.parentId() != null
        && jdbc.queryForList(
                "select id from fionova.article_comments where id = ? and article_id = ? and parent_id is null for key share",
                Long.class,
                input.parentId(),
                articleId)
            .isEmpty()) throw ApiException.missing();
    String body = input.body().strip();
    if (body.isBlank()
        || body.codePoints()
            .anyMatch(c -> Character.isISOControl(c) && c != '\n' && c != '\r' && c != '\t')) {
      throw ApiException.invalid("Escreva um comentário válido.");
    }
    return jdbc.queryForObject(
        """
        insert into fionova.article_comments (article_id, author_id, body, parent_id)
        values (?, ?, ?, ?) returning id, created_at
        """,
        (rs, index) ->
            new Comment(
                rs.getString("id"),
                author,
                body,
                rs.getTimestamp("created_at").toInstant(),
                true,
                0,
                false,
                0),
        articleId,
        jwt.getSubject(),
        body,
        input.parentId());
  }

  @PutMapping("/{commentId}/like")
  @Transactional
  Reaction like(
      @PathVariable String articleId,
      @PathVariable @Positive long commentId,
      @AuthenticationPrincipal Jwt jwt) {
    return react(articleId, commentId, jwt, true);
  }

  @DeleteMapping("/{commentId}/like")
  @Transactional
  Reaction unlike(
      @PathVariable String articleId,
      @PathVariable @Positive long commentId,
      @AuthenticationPrincipal Jwt jwt) {
    return react(articleId, commentId, jwt, false);
  }

  private Reaction react(String articleId, long commentId, Jwt jwt, boolean liked) {
    requirePublished(articleId);
    requireAccount(jwt);
    if (jdbc.queryForList(
            "select id from fionova.article_comments where id = ? and article_id = ? for update",
            Long.class,
            commentId,
            articleId)
        .isEmpty()) throw ApiException.missing();
    if (liked) {
      jdbc.update(
          "insert into fionova.article_comment_likes values (?, ?) on conflict do nothing",
          commentId,
          jwt.getSubject());
    } else {
      jdbc.update(
          "delete from fionova.article_comment_likes where comment_id = ? and user_id = ?",
          commentId,
          jwt.getSubject());
    }
    return new Reaction(
        jdbc.queryForObject(
            "select count(*) from fionova.article_comment_likes where comment_id = ?",
            Integer.class,
            commentId),
        liked);
  }

  private String requireAccount(Jwt jwt) {
    var user = identities.user(jwt.getSubject());
    if (user.getString("email") == null)
      throw new ApiException(
          HttpStatus.FORBIDDEN,
          "account_required",
          "Entre com uma conta para interagir com comentários.");
    return user.getString("name");
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
