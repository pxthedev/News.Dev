package br.com.radar;

import static br.com.radar.common.PostgresStore.await;
import static org.assertj.core.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

import br.com.radar.common.PostgresStore;
import com.fasterxml.jackson.databind.*;
import java.time.*;
import java.util.*;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.*;

@SpringBootTest(
    properties = {
      "radar.security.secret=integration-test-secret-at-least-32-bytes-long",
      "radar.bootstrap.admin-email=editor@radar.test",
      "radar.bootstrap.admin-password=Admin-test-password-2026",
      "radar.security.auth-requests-per-minute=1000",
      "spring.datasource.url=${TEST_DATABASE_URL:jdbc:postgresql://127.0.0.1:15432/fionova_test}",
      "spring.datasource.username=${TEST_DATABASE_USER:postgres}",
      "spring.datasource.password=${TEST_DATABASE_PASSWORD:}",
      "springdoc.api-docs.enabled=true"
    })
@AutoConfigureMockMvc
@org.springframework.test.context.ContextConfiguration(
    initializers = ApiIntegrationTest.LocalDatabaseGuard.class)
class ApiIntegrationTest {
  public static class LocalDatabaseGuard
      implements org.springframework.context.ApplicationContextInitializer<
          org.springframework.context.ConfigurableApplicationContext> {
    public void initialize(org.springframework.context.ConfigurableApplicationContext context) {
      String url = context.getEnvironment().getProperty("spring.datasource.url", "");
      if (!url.matches(
          "jdbc:postgresql://(?:127\\.0\\.0\\.1|localhost):[0-9]+/fionova_test(?:\\?.*)?"))
        throw new IllegalStateException(
            "Os testes só podem usar PostgreSQL local no banco fionova_test.");
    }
  }

  @org.springframework.test.context.bean.override.mockito.MockitoBean
  br.com.radar.auth.SupabaseIdentityVerifier verifier;

  @org.springframework.test.context.bean.override.mockito.MockitoBean
  br.com.radar.ingestion.RssFetcher rssFetcher;

  @Autowired br.com.radar.delivery.DeliveryQueue deliveryQueue;
  @Autowired br.com.radar.delivery.PushSender pushSender;
  @Autowired javax.sql.DataSource dataSource;
  @Autowired br.com.radar.common.JsonStore jsonStore;
  @Autowired MockMvc mvc;
  @Autowired ObjectMapper json;
  @Autowired PostgresStore db;
  String admin, user, other;

  @BeforeEach
  void setup() throws Exception {
    try (var connection = dataSource.getConnection()) {
      String url = connection.getMetaData().getURL();
      if (!(url.contains("//127.0.0.1:") || url.contains("//localhost:"))
          || !url.matches(".*/fionova_test(?:\\?.*)?$"))
        throw new IllegalStateException("Integração exige PostgreSQL local em banco fionova_test.");
    }
    for (String collection :
        List.of("articles", "liveEvents", "readerEvents", "imports", "sources", "outbox"))
      for (var doc : db.query(db.collection(collection))) await(doc.getReference().delete());
    // O teste de limite é isolado dos demais fluxos.
    admin =
        postJson(
                "/v1/auth/login",
                Map.of("email", "editor@radar.test", "password", "Admin-test-password-2026"),
                200)
            .get("token")
            .asText();
    user = anonymous().get("token").asText();
    other = anonymous().get("token").asText();
  }

  @Test
  void articleCommentsAreVisibleToReadersAndOnlyTheAuthorCanDelete() throws Exception {
    String articleId = "comments-" + UUID.randomUUID();
    publish(article(articleId, true, "normal", 60));
    String path = "/v1/articles/" + articleId + "/comments";
    String account =
        postJson(
                "/v1/auth/register",
                Map.of(
                    "name",
                    "Leitora",
                    "email",
                    UUID.randomUUID() + "@radar.test",
                    "password",
                    "Comments-test-password"),
                201)
            .get("token")
            .asText();
    var body = json.writeValueAsBytes(Map.of("body", " Boa análise! "));
    mvc.perform(
            post(path)
                .header("Authorization", "Bearer " + user)
                .contentType(MediaType.APPLICATION_JSON)
                .content(body))
        .andExpect(status().isForbidden());
    var result =
        mvc.perform(
                post(path)
                    .header("Authorization", "Bearer " + account)
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(body))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.body").value("Boa análise!"))
            .andExpect(jsonPath("$.mine").value(true))
            .andReturn()
            .getResponse();
    String commentId = json.readTree(result.getContentAsString()).get("id").asText();
    mvc.perform(get(path).header("Authorization", "Bearer " + other))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.items[0].author").value("Leitora"))
        .andExpect(jsonPath("$.items[0].mine").value(false))
        .andExpect(jsonPath("$.items[0].authorId").doesNotExist());
    mvc.perform(delete(path + "/" + commentId).header("Authorization", "Bearer " + other))
        .andExpect(status().isNotFound());
    mvc.perform(delete(path + "/" + commentId).header("Authorization", "Bearer " + account))
        .andExpect(status().isNoContent());
    mvc.perform(get(path).header("Authorization", "Bearer " + other))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.items").isEmpty());
  }

  @Test
  void accountCanUpdateItsOwnProfileAndRemoveItsPhoto() throws Exception {
    String account =
        postJson(
                "/v1/auth/register",
                Map.of(
                    "name",
                    "Antes",
                    "email",
                    UUID.randomUUID() + "@radar.test",
                    "password",
                    "Profile-test-password"),
                201)
            .get("token")
            .asText();
    var bytes = new java.io.ByteArrayOutputStream();
    javax.imageio.ImageIO.write(
        new java.awt.image.BufferedImage(2, 2, java.awt.image.BufferedImage.TYPE_INT_RGB),
        "png",
        bytes);
    String photo = Base64.getEncoder().encodeToString(bytes.toByteArray());
    mvc.perform(
            put("/v1/me")
                .header("Authorization", "Bearer " + account)
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    json.writeValueAsBytes(
                        Map.of("name", " Novo nome ", "bio", "Minha bio", "avatarBase64", photo))))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.name").value("Novo nome"))
        .andExpect(jsonPath("$.bio").value("Minha bio"))
        .andExpect(jsonPath("$.avatarBase64").value(photo));
    mvc.perform(get("/v1/me").header("Authorization", "Bearer " + other))
        .andExpect(jsonPath("$.avatarBase64").doesNotExist());
    mvc.perform(
            put("/v1/me")
                .header("Authorization", "Bearer " + account)
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    json.writeValueAsBytes(
                        Map.of("name", "Novo nome", "bio", "", "avatarBase64", "aW52YWxpZA=="))))
        .andExpect(status().isBadRequest());
    mvc.perform(
            put("/v1/me")
                .header("Authorization", "Bearer " + account)
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    json.writeValueAsBytes(
                        Map.of("name", "Novo nome", "bio", "", "removeAvatar", true))))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.avatarBase64").doesNotExist());
    mvc.perform(
            put("/v1/me")
                .header("Authorization", "Bearer " + other)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"name\":\"Teste\",\"bio\":\"\"}"))
        .andExpect(status().isUnauthorized());
  }

  JsonNode anonymous() throws Exception {
    return postJson("/v1/auth/anonymous", Map.of("platform", "android"), 200);
  }

  JsonNode postJson(String path, Object body, int status) throws Exception {
    return json.readTree(
        mvc.perform(
                post(path)
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(json.writeValueAsBytes(body)))
            .andExpect(status().is(status))
            .andReturn()
            .getResponse()
            .getContentAsString());
  }

  String id(String token) throws Exception {
    return json.readTree(
            mvc.perform(get("/v1/me").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString())
        .get("id")
        .asText();
  }

  Map<String, Object> article(String id, boolean confirmed, String urgency, int age) {
    return new LinkedHashMap<>(
        Map.ofEntries(
            Map.entry("id", id),
            Map.entry("title", "Matéria de teste sobre Nvidia " + id),
            Map.entry("summary", List.of("Primeiro ponto", "Segundo ponto", "Terceiro ponto")),
            Map.entry("body", "Texto da matéria de teste com fontes verificadas."),
            Map.entry("category", "chips"),
            Map.entry("detectedAt", Instant.now().minusSeconds(age + 60).toString()),
            Map.entry("publishedAt", Instant.now().minusSeconds(age).toString()),
            Map.entry(
                "sources", List.of(Map.of("name", "Fonte de teste", "url", "https://example.org"))),
            Map.entry("sourceCount", 1),
            Map.entry("firstInBrazil", true),
            Map.entry("leadMinutes", 30),
            Map.entry("urgency", urgency),
            Map.entry("confirmed", confirmed),
            Map.entry("readingMinutes", 2),
            Map.entry(
                "entities",
                List.of(
                    Map.of("type", "company", "id", "nvidia", "name", "Nvidia"),
                    Map.of("type", "person", "id", "jensen-huang", "name", "Jensen Huang"))),
            Map.entry("trendingTag", "nvidia")));
  }

  void publish(Map<String, Object> a) throws Exception {
    mvc.perform(
            put("/v1/admin/articles/" + a.get("id"))
                .header("Authorization", "Bearer " + admin)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsBytes(a)))
        .andExpect(status().isNoContent());
  }

  @Test
  void authenticationRegistrationRefreshAndRevocation() throws Exception {
    String email = UUID.randomUUID() + "@radar.test";
    var tokens =
        postJson(
            "/v1/auth/register",
            Map.of("email", email, "name", "Ana", "password", "Senha-bem-forte-2026"),
            201);
    String original = tokens.get("token").asText();
    mvc.perform(get("/v1/me").header("Authorization", "Bearer " + original))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.name").value("Ana"));
    postJson("/v1/auth/login", Map.of("email", email, "password", "senha-incorreta"), 401);
    postJson(
        "/v1/auth/register",
        Map.of("email", email, "name", "Ana", "password", "Senha-bem-forte-2026"),
        409);
    var refreshed =
        postJson(
            "/v1/auth/refresh", Map.of("refreshToken", tokens.get("refreshToken").asText()), 200);
    postJson("/v1/auth/refresh", Map.of("refreshToken", tokens.get("refreshToken").asText()), 401);
    mvc.perform(get("/v1/me").header("Authorization", "Bearer " + original))
        .andExpect(status().isUnauthorized());
    mvc.perform(
            post("/v1/auth/logout")
                .header("Authorization", "Bearer " + refreshed.get("token").asText()))
        .andExpect(status().isNoContent());
    mvc.perform(get("/v1/me").header("Authorization", "Bearer " + refreshed.get("token").asText()))
        .andExpect(status().isUnauthorized());
    postJson(
        "/v1/auth/refresh", Map.of("refreshToken", refreshed.get("refreshToken").asText()), 401);
  }

  @Test
  void securityAndValidation() throws Exception {
    mvc.perform(get("/v1/feed"))
        .andExpect(status().isUnauthorized())
        .andExpect(jsonPath("$.error.code").value("unauthorized"));
    mvc.perform(get("/v1/me").header("Authorization", "Bearer forged.token.value"))
        .andExpect(status().isUnauthorized());
    mvc.perform(
            put("/v1/admin/articles/nope")
                .header("Authorization", "Bearer " + user)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{}"))
        .andExpect(status().isForbidden());
    postJson("/v1/auth/anonymous", Map.of("platform", "invalid"), 400);
    postJson("/v1/auth/register", Map.of("email", "bad", "password", "short", "name", ""), 400);
    var a = article("invalid", true, "urgent", 10);
    a.put("summary", List.of("apenas um"));
    mvc.perform(
            put("/v1/admin/articles/invalid")
                .header("Authorization", "Bearer " + admin)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsBytes(a)))
        .andExpect(status().isBadRequest());
    var nullEntity = article("null-entity", true, "normal", 10);
    nullEntity.put("entities", java.util.Arrays.asList((Object) null));
    mvc.perform(
            put("/v1/admin/articles/null-entity")
                .header("Authorization", "Bearer " + admin)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsBytes(nullEntity)))
        .andExpect(status().isBadRequest());
    mvc.perform(post("/v1/me").header("Authorization", "Bearer " + user))
        .andExpect(status().isMethodNotAllowed());
    mvc.perform(
            put("/v1/me/prefs")
                .header("Authorization", "Bearer " + user)
                .contentType(MediaType.TEXT_PLAIN)
                .content("invalid"))
        .andExpect(status().isUnsupportedMediaType());
    mvc.perform(get("/v1/feed?limit=101").header("Authorization", "Bearer " + user))
        .andExpect(status().isBadRequest());
    mvc.perform(get("/v1/feed?cursor=invalid").header("Authorization", "Bearer " + user))
        .andExpect(status().isBadRequest());
    mvc.perform(get("/v1/feed?filter=invalid").header("Authorization", "Bearer " + user))
        .andExpect(status().isBadRequest());
    mvc.perform(get("/v1/articles/missing").header("Authorization", "Bearer " + user))
        .andExpect(status().isNotFound());
    mvc.perform(get("/v1/home").header("Authorization", "Bearer " + user))
        .andExpect(status().isOk());
    mvc.perform(get("/actuator/health")).andExpect(status().isOk());
    mvc.perform(get("/v3/api-docs")).andExpect(status().isOk());
  }

  @Test
  void contentPaginationFiltersAndDiscovery() throws Exception {
    publish(article("first", true, "urgent", 60));
    publish(article("second", true, "normal", 120));
    publish(article("rumor", false, "normal", 180));
    var page =
        json.readTree(
            mvc.perform(get("/v1/feed?limit=1").header("Authorization", "Bearer " + user))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].id").value("first"))
                .andReturn()
                .getResponse()
                .getContentAsString());
    mvc.perform(
            get("/v1/feed")
                .param("limit", "1")
                .param("cursor", page.get("nextCursor").asText())
                .header("Authorization", "Bearer " + user))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.items[0].id").value("second"))
        .andExpect(jsonPath("$.nextCursor").doesNotExist());
    mvc.perform(get("/v1/feed?rumors=true").header("Authorization", "Bearer " + user))
        .andExpect(jsonPath("$.items.length()").value(3));
    mvc.perform(get("/v1/feed?filter=urgent").header("Authorization", "Bearer " + user))
        .andExpect(jsonPath("$.items.length()").value(1));
    mvc.perform(get("/v1/feed?filter=following").header("Authorization", "Bearer " + user))
        .andExpect(jsonPath("$.items.length()").value(0));
    mvc.perform(put("/v1/me/following/nvidia").header("Authorization", "Bearer " + user))
        .andExpect(status().isNoContent());
    mvc.perform(get("/v1/feed?filter=following").header("Authorization", "Bearer " + user))
        .andExpect(jsonPath("$.items.length()").value(2));
    mvc.perform(
            get("/v1/feed/new-count")
                .param("since", Instant.now().minusSeconds(600).toString())
                .header("Authorization", "Bearer " + user))
        .andExpect(jsonPath("$.count").value(2));
    mvc.perform(get("/v1/home").header("Authorization", "Bearer " + user))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.hero.id").value("first"))
        .andExpect(jsonPath("$.trending.perDay.length()").value(7));
    mvc.perform(get("/v1/topics/chips?company=Nvidia").header("Authorization", "Bearer " + user))
        .andExpect(jsonPath("$.feed.items.length()").value(2));
    mvc.perform(get("/v1/search?q=Nvidia").header("Authorization", "Bearer " + user))
        .andExpect(jsonPath("$.articles.length()").value(2))
        .andExpect(jsonPath("$.entity.id").value("nvidia"));
    mvc.perform(get("/v1/search?q=%25").header("Authorization", "Bearer " + user))
        .andExpect(jsonPath("$.articles.length()").value(0));
    mvc.perform(
            get("/v1/articles?ids=first,missing,second").header("Authorization", "Bearer " + user))
        .andExpect(jsonPath("$.items.length()").value(2));
    mvc.perform(get("/v1/explore").header("Authorization", "Bearer " + user))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.topics.length()").value(13))
        .andExpect(jsonPath("$.people[0].id").value("jensen-huang"));
  }

  @Test
  void userIsolationPatchSemanticsStatsAndPreferences() throws Exception {
    publish(article("saved", true, "urgent", 10));
    mvc.perform(get("/v1/me/prefs").header("Authorization", "Bearer " + user))
        .andExpect(status().isNotFound());
    var prefs =
        new LinkedHashMap<String, Object>(
            Map.of(
                "topics",
                List.of("chips"),
                "alertLevel",
                "balanced",
                "digestTimes",
                List.of("08:00"),
                "showRumors",
                false,
                "urgentAlerts",
                true,
                "followedEntities",
                List.of("nvidia")));
    prefs.put("quietHours", Map.of("from", "23:00", "to", "07:00"));
    mvc.perform(
            put("/v1/me/prefs")
                .header("Authorization", "Bearer " + user)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsBytes(prefs)))
        .andExpect(status().isNoContent());
    mvc.perform(delete("/v1/me/following/nvidia").header("Authorization", "Bearer " + user))
        .andExpect(status().isNoContent());
    mvc.perform(get("/v1/me/prefs").header("Authorization", "Bearer " + user))
        .andExpect(jsonPath("$.followedEntities.length()").value(0));
    mvc.perform(get("/v1/feed?filter=following").header("Authorization", "Bearer " + user))
        .andExpect(jsonPath("$.items.length()").value(1));
    mvc.perform(
            put("/v1/me/saved/saved")
                .header("Authorization", "Bearer " + user)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsBytes(Map.of("progress", 0.7))))
        .andExpect(status().isNoContent());
    mvc.perform(
            put("/v1/me/saved/saved")
                .header("Authorization", "Bearer " + user)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsBytes(Map.of("archived", true))))
        .andExpect(status().isNoContent());
    mvc.perform(get("/v1/me/saved").header("Authorization", "Bearer " + user))
        .andExpect(jsonPath("$.items[0].progress").value(0.7))
        .andExpect(jsonPath("$.items[0].archived").value(true));
    mvc.perform(get("/v1/me/saved").header("Authorization", "Bearer " + other))
        .andExpect(jsonPath("$.items.length()").value(0));
    mvc.perform(delete("/v1/me/saved/saved").header("Authorization", "Bearer " + other))
        .andExpect(status().isNoContent());
    mvc.perform(get("/v1/me/stats/weekly").header("Authorization", "Bearer " + user))
        .andExpect(jsonPath("$.scoops").value(1))
        .andExpect(jsonPath("$.streakDays").value(1))
        .andExpect(jsonPath("$.avgLeadMinutes").value(30));
    mvc.perform(
            put("/v1/me/saved/saved")
                .header("Authorization", "Bearer " + user)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsBytes(Map.of("progress", 2))))
        .andExpect(status().isBadRequest());
    publish(article("saved", true, "important", 10));
    mvc.perform(get("/v1/me/saved").header("Authorization", "Bearer " + user))
        .andExpect(jsonPath("$.items.length()").value(1));
    mvc.perform(delete("/v1/admin/articles/saved").header("Authorization", "Bearer " + admin))
        .andExpect(status().isNoContent());
    mvc.perform(get("/v1/me/saved").header("Authorization", "Bearer " + user))
        .andExpect(jsonPath("$.items.length()").value(0));
  }

  @Test
  void alertsPushWaitlistAndLive() throws Exception {
    publish(article("alert", true, "urgent", 10));
    var alertBody =
        Map.of(
            "userId",
            id(user),
            "articleId",
            "alert",
            "type",
            "urgent",
            "category",
            "chips",
            "title",
            "Alerta de teste",
            "subtitle",
            "Novo conteúdo");
    String alert =
        json.readTree(
                mvc.perform(
                        post("/v1/admin/alerts")
                            .header("Authorization", "Bearer " + admin)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(json.writeValueAsBytes(alertBody)))
                    .andExpect(status().isCreated())
                    .andReturn()
                    .getResponse()
                    .getContentAsString())
            .get("id")
            .asText();
    mvc.perform(
            post("/v1/me/alerts/read")
                .header("Authorization", "Bearer " + other)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsBytes(Map.of("ids", List.of(alert)))))
        .andExpect(status().isNoContent());
    mvc.perform(get("/v1/me/alerts").header("Authorization", "Bearer " + user))
        .andExpect(jsonPath("$.items[0].read").value(false));
    mvc.perform(
            post("/v1/me/alerts/read")
                .header("Authorization", "Bearer " + user)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsBytes(Map.of("ids", List.of(alert)))))
        .andExpect(status().isNoContent());
    mvc.perform(get("/v1/me/alerts").header("Authorization", "Bearer " + user))
        .andExpect(jsonPath("$.items[0].read").value(true));
    mvc.perform(
            post("/v1/me/push-tokens")
                .header("Authorization", "Bearer " + user)
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    json.writeValueAsBytes(
                        Map.of("token", "device-test-token", "platform", "android"))))
        .andExpect(status().isNoContent());
    mvc.perform(post("/v1/waitlist/community").header("Authorization", "Bearer " + user))
        .andExpect(status().isNoContent());
    var event =
        Map.of(
            "id",
            "keynote",
            "title",
            "Keynote",
            "headline",
            "Novidades",
            "startsAt",
            Instant.now().minusSeconds(60).toString(),
            "endsAt",
            Instant.now().plusSeconds(3600).toString(),
            "updates",
            List.of(Map.of("at", Instant.now().toString(), "text", "Evento iniciado")));
    mvc.perform(
            put("/v1/admin/live/keynote")
                .header("Authorization", "Bearer " + admin)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsBytes(event)))
        .andExpect(status().isNoContent());
    mvc.perform(get("/v1/live/keynote").header("Authorization", "Bearer " + user))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.updates.length()").value(1));
    mvc.perform(delete("/v1/admin/live/keynote").header("Authorization", "Bearer " + admin))
        .andExpect(status().isNoContent());
    mvc.perform(get("/v1/live/keynote").header("Authorization", "Bearer " + user))
        .andExpect(status().isNotFound());
  }

  @Autowired br.com.radar.auth.AuthService authService;
  @Autowired org.springframework.security.oauth2.jwt.JwtEncoder jwtEncoder;
  @Autowired org.springframework.security.oauth2.jwt.JwtDecoder jwtDecoder;

  @Test
  void tiedPublicationTimesDoNotDuplicateOrSkipArticles() throws Exception {
    String instant = Instant.now().minusSeconds(60).toString();
    for (String id : List.of("tie-a", "tie-b", "tie-c")) {
      var a = article(id, true, "normal", 60);
      a.put("publishedAt", instant);
      publish(a);
    }
    var seen = new ArrayList<String>();
    String cursor = null;
    do {
      var request = get("/v1/feed").param("limit", "1").header("Authorization", "Bearer " + user);
      if (cursor != null) request.param("cursor", cursor);
      var page =
          json.readTree(
              mvc.perform(request)
                  .andExpect(status().isOk())
                  .andReturn()
                  .getResponse()
                  .getContentAsString());
      for (var item : page.get("items")) seen.add(item.get("id").asText());
      cursor = page.hasNonNull("nextCursor") ? page.get("nextCursor").asText() : null;
      assertThat(seen.size()).isLessThanOrEqualTo(3);
    } while (cursor != null);
    assertThat(seen).containsExactly("tie-c", "tie-b", "tie-a");
  }

  @Test
  void concurrentRefreshHasExactlyOneWinner() throws Exception {
    String refresh = anonymous().get("refreshToken").asText();
    var gate = new java.util.concurrent.CountDownLatch(1);
    try (var pool = java.util.concurrent.Executors.newFixedThreadPool(2)) {
      java.util.concurrent.Callable<Boolean> task =
          () -> {
            gate.await();
            try {
              authService.refresh(refresh);
              return true;
            } catch (br.com.radar.common.ApiException e) {
              assertThat(e.status.value()).isEqualTo(401);
              return false;
            }
          };
      var first = pool.submit(task);
      var second = pool.submit(task);
      gate.countDown();
      assertThat(
              List.of(
                  first.get(10, java.util.concurrent.TimeUnit.SECONDS),
                  second.get(10, java.util.concurrent.TimeUnit.SECONDS)))
          .containsExactlyInAnyOrder(true, false);
    }
  }

  @Test
  void rejectsExpiredAndWrongIssuerEvenWithValidSignature() throws Exception {
    var valid = jwtDecoder.decode(user);
    for (boolean expired : List.of(true, false)) {
      Instant now = Instant.now();
      var claims =
          org.springframework.security.oauth2.jwt.JwtClaimsSet.builder()
              .issuer(expired ? "radar-api" : "wrong-issuer")
              .subject(valid.getSubject())
              .issuedAt(now.minusSeconds(7200))
              .expiresAt(expired ? now.minusSeconds(120) : now.plusSeconds(3600))
              .claim("sid", valid.getClaimAsString("sid"))
              .claim("roles", List.of("USER"))
              .build();
      String token =
          jwtEncoder
              .encode(
                  org.springframework.security.oauth2.jwt.JwtEncoderParameters.from(
                      org.springframework.security.oauth2.jwt.JwsHeader.with(
                              org.springframework.security.oauth2.jose.jws.MacAlgorithm.HS256)
                          .build(),
                      claims))
              .getTokenValue();
      mvc.perform(get("/v1/me").header("Authorization", "Bearer " + token))
          .andExpect(status().isUnauthorized());
    }
  }

  @Test
  void upgradesAnonymousWithoutLosingSavedPreferences() throws Exception {
    publish(article("upgrade", true, "normal", 60));
    String original = id(user);
    mvc.perform(
            put("/v1/me/saved/upgrade")
                .header("Authorization", "Bearer " + user)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{}"))
        .andExpect(status().isNoContent());
    String email = UUID.randomUUID() + "@radar.test";
    var result =
        json.readTree(
            mvc.perform(
                    post("/v1/auth/upgrade")
                        .header("Authorization", "Bearer " + user)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(
                            json.writeValueAsBytes(
                                Map.of(
                                    "email",
                                    email,
                                    "name",
                                    "Leitora",
                                    "password",
                                    "Senha-forte-para-testes"))))
                .andExpect(status().isCreated())
                .andReturn()
                .getResponse()
                .getContentAsString());
    String token = result.get("token").asText();
    assertThat(id(token)).isEqualTo(original);
    mvc.perform(get("/v1/me/saved").header("Authorization", "Bearer " + token))
        .andExpect(jsonPath("$.items[0].articleId").value("upgrade"));
  }

  @Test
  void importsAnonymousSavedWhenLoggingInToExistingAccount() throws Exception {
    String email = UUID.randomUUID() + "@radar.test";
    var registered =
        postJson(
            "/v1/auth/register",
            Map.of(
                "email", email, "name", "Conta existente", "password", "Senha-forte-para-testes"),
            201);
    publish(article("anonymous-saved", true, "normal", 60));
    mvc.perform(
            put("/v1/me/saved/anonymous-saved")
                .header("Authorization", "Bearer " + user)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsBytes(Map.of("progress", 0.5))))
        .andExpect(status().isNoContent());
    var result =
        json.readTree(
            mvc.perform(
                    post("/v1/auth/login")
                        .header("Authorization", "Bearer " + user)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(
                            json.writeValueAsBytes(
                                Map.of("email", email, "password", "Senha-forte-para-testes"))))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString());
    assertThat(id(result.get("token").asText())).isEqualTo(id(registered.get("token").asText()));
    mvc.perform(
            get("/v1/me/saved").header("Authorization", "Bearer " + result.get("token").asText()))
        .andExpect(jsonPath("$.items[0].progress").value(0.5));
  }

  @Test
  void passwordRecoveryIsSingleUseAndRevokesSessions() throws Exception {
    String email = UUID.randomUUID() + "@radar.test";
    var registered =
        postJson(
            "/v1/auth/register",
            Map.of("email", email, "name", "Ana", "password", "Senha-forte-para-testes"),
            201);
    mvc.perform(
            post("/v1/auth/forgot-password")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsBytes(Map.of("email", email))))
        .andExpect(status().isAccepted())
        .andExpect(content().string(""));
    mvc.perform(
            post("/v1/auth/forgot-password")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsBytes(Map.of("email", "unknown-" + email))))
        .andExpect(status().isAccepted())
        .andExpect(content().string(""));
    var messages = db.query(db.collection("outbox").whereEqualTo("to", email));
    assertThat(messages).hasSize(1);
    var matcher =
        java.util.regex.Pattern.compile("token=([A-Za-z0-9_-]+)")
            .matcher(messages.getFirst().getString("body"));
    assertThat(matcher.find()).isTrue();
    String reset = matcher.group(1);
    mvc.perform(
            post("/v1/auth/reset-password")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    json.writeValueAsBytes(
                        Map.of("token", reset, "password", "Minha-nova-senha-forte"))))
        .andExpect(status().isNoContent());
    mvc.perform(
            post("/v1/auth/reset-password")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    json.writeValueAsBytes(
                        Map.of("token", reset, "password", "Outra-nova-senha-forte"))))
        .andExpect(status().isBadRequest());
    mvc.perform(get("/v1/me").header("Authorization", "Bearer " + registered.get("token").asText()))
        .andExpect(status().isUnauthorized());
    postJson(
        "/v1/auth/refresh", Map.of("refreshToken", registered.get("refreshToken").asText()), 401);
    postJson("/v1/auth/login", Map.of("email", email, "password", "Senha-forte-para-testes"), 401);
    postJson("/v1/auth/login", Map.of("email", email, "password", "Minha-nova-senha-forte"), 200);
  }

  @Test
  void verifiedGoogleIdentityUpgradesAnonymousAndEmailCollisionRequiresExplicitLink()
      throws Exception {
    String email = UUID.randomUUID() + "@radar.test", uid = UUID.randomUUID().toString();
    var token = new br.com.radar.auth.SupabaseIdentityVerifier.Identity(uid, email, "Google User");
    org.mockito.Mockito.when(verifier.verify("verified-google-token")).thenReturn(token);
    String original = id(user);
    var result =
        json.readTree(
            mvc.perform(
                    post("/v1/auth/supabase")
                        .header("Authorization", "Bearer " + user)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(
                            json.writeValueAsBytes(Map.of("accessToken", "verified-google-token"))))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString());
    assertThat(id(result.get("token").asText())).isEqualTo(original);
    org.mockito.Mockito.when(verifier.verify("verified-google-token"))
        .thenThrow(br.com.radar.common.ApiException.unauthorized());
    mvc.perform(
            post("/v1/auth/supabase")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsBytes(Map.of("accessToken", "verified-google-token"))))
        .andExpect(status().isUnauthorized());
  }

  @Test
  void pushOwnershipCannotBeDeletedByPreviousAccount() throws Exception {
    String installation = "fid-" + UUID.randomUUID();
    var body =
        json.writeValueAsBytes(Map.of("token", installation, "platform", "android", "kind", "fid"));
    mvc.perform(
            post("/v1/me/push-tokens")
                .header("Authorization", "Bearer " + user)
                .contentType(MediaType.APPLICATION_JSON)
                .content(body))
        .andExpect(status().isNoContent());
    mvc.perform(
            post("/v1/me/push-tokens")
                .header("Authorization", "Bearer " + other)
                .contentType(MediaType.APPLICATION_JSON)
                .content(body))
        .andExpect(status().isNoContent());
    mvc.perform(
            delete("/v1/me/push-tokens")
                .header("Authorization", "Bearer " + user)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsBytes(Map.of("token", installation))))
        .andExpect(status().isNoContent());
    assertThat(
            db.get(db.doc("pushTokens", br.com.radar.common.PostgresStore.hash(installation)))
                .getString("userId"))
        .isEqualTo(id(other));
  }

  @Test
  void rssImportsAreDeduplicatedAndRequireEditorialConfirmation() throws Exception {
    var entry = new com.rometools.rome.feed.synd.SyndEntryImpl();
    entry.setTitle("Novidade via RSS");
    entry.setLink("https://example.org/news?id=1&utm_source=feed");
    entry.setPublishedDate(new java.util.Date());
    var description = new com.rometools.rome.feed.synd.SyndContentImpl();
    description.setValue("Resumo da fonte");
    entry.setDescription(description);
    var content = new com.rometools.rome.feed.synd.SyndContentImpl();
    content.setValue("<p>Primeiro parágrafo &amp; detalhes.</p><p>Segundo parágrafo.</p>");
    entry.setContents(List.of(content));
    org.mockito.Mockito.when(rssFetcher.fetch("https://example.org/feed.xml"))
        .thenReturn(List.of(entry));
    mvc.perform(
            put("/v1/admin/sources/test-feed")
                .header("Authorization", "Bearer " + admin)
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    json.writeValueAsBytes(
                        Map.of(
                            "name",
                            "Fonte de teste",
                            "url",
                            "https://example.org/feed.xml",
                            "category",
                            "programacao"))))
        .andExpect(status().isNoContent());
    mvc.perform(
            post("/v1/admin/sources/test-feed/collect").header("Authorization", "Bearer " + admin))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.imported").value(1));
    mvc.perform(
            post("/v1/admin/sources/test-feed/collect").header("Authorization", "Bearer " + admin))
        .andExpect(jsonPath("$.imported").value(0));
    mvc.perform(get("/v1/feed").header("Authorization", "Bearer " + user))
        .andExpect(jsonPath("$.items.length()").value(0));
    mvc.perform(get("/v1/feed?rumors=true").header("Authorization", "Bearer " + user))
        .andExpect(jsonPath("$.items[0].confirmed").value(false))
        .andExpect(jsonPath("$.items[0].body").value(""))
        .andExpect(jsonPath("$.items[0].sources[0].url").value("https://example.org/news?id=1"));
    mvc.perform(
            put("/v1/admin/sources/test-feed")
                .header("Authorization", "Bearer " + admin)
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    json.writeValueAsBytes(
                        Map.of(
                            "name",
                            "Fonte de teste",
                            "url",
                            "https://example.org/feed.xml",
                            "category",
                            "programacao",
                            "allowFullText",
                            true))))
        .andExpect(status().isNoContent());
    mvc.perform(
            post("/v1/admin/sources/test-feed/collect").header("Authorization", "Bearer " + admin))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.imported").value(0));
    mvc.perform(get("/v1/feed?rumors=true").header("Authorization", "Bearer " + user))
        .andExpect(
            jsonPath("$.items[0].body")
                .value("Primeiro parágrafo & detalhes.\n\nSegundo parágrafo."));
  }

  @Test
  void smtpFailureRetriesAndSuccessfulAcceptanceClearsSecretBody() {
    // Evitar processar os emails de outros cenários; nenhum provedor real é chamado.
    for (var job : db.query(db.collection("outbox")))
      await(job.getReference().update("state", "failed"));
    var mail = org.mockito.Mockito.mock(org.springframework.mail.javamail.JavaMailSender.class);
    org.mockito.Mockito.doThrow(new org.springframework.mail.MailSendException("offline"))
        .when(mail)
        .send(org.mockito.ArgumentMatchers.any(org.springframework.mail.SimpleMailMessage.class));
    String id = "smtp-test-" + UUID.randomUUID();
    db.transaction(
        tx -> {
          deliveryQueue.email(tx, id, "recipient@example.org", "Teste", "secret-test-body");
          return null;
        });
    var worker =
        new br.com.radar.delivery.DeliveryWorker(
            db, deliveryQueue, mail, pushSender, jsonStore, "test@example.org");
    worker.run();
    var ref = db.doc("outbox", id);
    assertThat(db.get(ref).getString("state")).isEqualTo("pending");
    assertThat(db.get(ref).getLong("attempts")).isEqualTo(1L);
    org.mockito.Mockito.reset(mail);
    await(
        ref.update(
            "availableAt", br.com.radar.common.PostgresStore.time(Instant.now().minusSeconds(1))));
    worker.run();
    assertThat(db.get(ref).getString("state")).isEqualTo("sent");
    assertThat(db.get(ref).getString("body")).isNull();
    assertThat(db.get(ref).getLong("attempts")).isEqualTo(2L);
  }

  @Test
  void existingEmailNeedsExplicitVerifiedSocialLink() throws Exception {
    String email = UUID.randomUUID() + "@radar.test";
    var registered =
        postJson(
            "/v1/auth/register",
            Map.of("email", email, "name", "Ana", "password", "Senha-forte-para-testes"),
            201);
    String account = registered.get("token").asText();
    var identity =
        new br.com.radar.auth.SupabaseIdentityVerifier.Identity(
            UUID.randomUUID().toString(), email, "Ana");
    org.mockito.Mockito.when(verifier.verify("apple-verified")).thenReturn(identity);
    postJson("/v1/auth/supabase", Map.of("accessToken", "apple-verified"), 409);
    mvc.perform(
            post("/v1/auth/link/supabase")
                .header("Authorization", "Bearer " + account)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsBytes(Map.of("accessToken", "apple-verified"))))
        .andExpect(status().isNoContent());
    var result = postJson("/v1/auth/supabase", Map.of("accessToken", "apple-verified"), 200);
    assertThat(id(result.get("token").asText())).isEqualTo(id(account));
  }

  @Test
  void concurrentRefreshIsSingleUseOnPostgres() throws Exception {
    var account =
        postJson(
            "/v1/auth/register",
            Map.of(
                "email", UUID.randomUUID() + "@radar.test", "name", "Ana", "password", "Senha123"),
            201);
    String refresh = account.get("refreshToken").asText();
    try (var pool = java.util.concurrent.Executors.newFixedThreadPool(2)) {
      var start = new java.util.concurrent.CountDownLatch(1);
      java.util.concurrent.Callable<Integer> attempt =
          () -> {
            start.await();
            return mvc.perform(
                    post("/v1/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsBytes(Map.of("refreshToken", refresh))))
                .andReturn()
                .getResponse()
                .getStatus();
          };
      var first = pool.submit(attempt);
      var second = pool.submit(attempt);
      start.countDown();
      assertThat(java.util.List.of(first.get(), second.get())).containsExactlyInAnyOrder(200, 401);
    }
  }

  @Test
  void transactionsRollbackAndDataSchemaIsPrivate() throws Exception {
    String id = "rollback-" + UUID.randomUUID();
    assertThatThrownBy(
            () ->
                db.transaction(
                    tx -> {
                      tx.create(db.doc("system", id), Map.of("value", 1));
                      throw new IllegalStateException("rollback");
                    }))
        .isInstanceOf(IllegalStateException.class);
    assertThat(db.get(db.doc("system", id)).exists()).isFalse();
    try (var connection = dataSource.getConnection();
        var statement = connection.createStatement()) {
      try (var rows =
          statement.executeQuery(
              "select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='fionova' and c.relkind='r' and c.relname<>'flyway_schema_history' and not c.relrowsecurity")) {
        rows.next();
        assertThat(rows.getInt(1)).isZero();
      }
      try (var rows =
          statement.executeQuery(
              "select count(*) from pg_namespace n, lateral aclexplode(n.nspacl) a where n.nspname='fionova' and a.grantee=0 and a.privilege_type='USAGE'")) {
        rows.next();
        assertThat(rows.getInt(1)).isZero();
      }
    }
  }

  @Test
  void emptyDatabaseHasSuccessfulEmptyHomeAndFeed() throws Exception {
    mvc.perform(get("/v1/home").header("Authorization", "Bearer " + user))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.hero").doesNotExist());
    mvc.perform(get("/v1/feed").header("Authorization", "Bearer " + user))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.items").isEmpty());
  }

  @Test
  void migratedSocialOnlyAccountCanSetPasswordThroughVerifiedRecoveryEmail() throws Exception {
    String email = UUID.randomUUID() + "@radar.test";
    var identity =
        new br.com.radar.auth.SupabaseIdentityVerifier.Identity(
            "supabase:" + UUID.randomUUID(), email, "Ana");
    org.mockito.Mockito.when(verifier.verify("social-only-token")).thenReturn(identity);
    var account = postJson("/v1/auth/supabase", Map.of("accessToken", "social-only-token"), 200);
    String userId = id(account.get("token").asText());
    postJson("/v1/auth/login", Map.of("email", email, "password", "Senha123"), 401);
    mvc.perform(
            post("/v1/auth/forgot-password")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsBytes(Map.of("email", email))))
        .andExpect(status().isAccepted());
    var messages = db.query(db.collection("outbox").whereEqualTo("to", email));
    assertThat(messages).hasSize(1);
    var matcher =
        java.util.regex.Pattern.compile("token=([A-Za-z0-9_-]+)")
            .matcher(messages.getFirst().getString("body"));
    assertThat(matcher.find()).isTrue();
    mvc.perform(
            post("/v1/auth/reset-password")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    json.writeValueAsBytes(
                        Map.of("token", matcher.group(1), "password", "Senha123"))))
        .andExpect(status().isNoContent());
    var signedIn = postJson("/v1/auth/login", Map.of("email", email, "password", "Senha123"), 200);
    assertThat(id(signedIn.get("token").asText())).isEqualTo(userId);
  }
}
