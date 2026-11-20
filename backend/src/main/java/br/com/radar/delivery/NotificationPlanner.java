package br.com.radar.delivery;

import static br.com.radar.common.PostgresStore.*;

import br.com.radar.common.*;
import br.com.radar.common.PostgresStore.*;
import br.com.radar.content.*;
import br.com.radar.user.UserModels.Prefs;
import java.time.*;
import java.util.*;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
@ConditionalOnProperty(name = "radar.delivery.enabled", havingValue = "true")
public class NotificationPlanner {
  private final PostgresStore store;
  private final JsonStore json;
  private final ContentRepository content;

  public NotificationPlanner(PostgresStore store, JsonStore json, ContentRepository content) {
    this.store = store;
    this.json = json;
    this.content = content;
  }

  @Scheduled(fixedDelayString = "${radar.delivery.planner-delay-ms:60000}")
  public void run() {
    Instant now = Instant.now();
    var recent =
        store.query(
            content
                .base(true)
                .whereGreaterThanOrEqualTo("publishedAt", time(now.minus(Duration.ofDays(1))))
                .orderBy("publishedAt", Query.Direction.DESCENDING));
    DocumentSnapshot cursor = null;
    do {
      Query query = store.collection("users").orderBy(FieldPath.documentId()).limit(100);
      if (cursor != null) query = query.startAfter(cursor);
      var page = store.query(query);
      if (page.isEmpty()) break;
      for (var user : page) {
        String raw = user.getString("prefs");
        if (raw == null) continue;
        Prefs p = json.read(raw, Prefs.class);
        // Entidades são mantidas no mesmo documento e podem mudar depois de salvar prefs.
        Object followed = user.get("following");
        if (followed instanceof List<?> f)
          p =
              new Prefs(
                  p.topics(),
                  p.alertLevel(),
                  p.digestTimes(),
                  p.quietHours(),
                  p.showRumors(),
                  p.urgentAlerts(),
                  f.stream().map(Object::toString).toList());
        for (var doc : recent) {
          var article = content.decode(doc);
          if (!NotificationPolicy.matches(p, article)) continue;
          String id =
              "article-" + hash(user.getId() + "|" + article.id() + "|" + article.publishedAt());
          plan(
              id,
              user.getId(),
              article.title(),
              article.summary().getFirst(),
              "radar://materia/" + article.id() + "?source=push",
              NotificationPolicy.nextAllowed(p, article.urgency().equals("urgent"), now),
              article.id(),
              article.category(),
              article.urgency().equals("urgent") ? "urgent" : "article");
        }
        var local = now.atZone(ContentService.ZONE);
        for (String at : p.digestTimes()) {
          var scheduled =
              local.toLocalDate().atTime(LocalTime.parse(at)).atZone(ContentService.ZONE);
          if (scheduled.toInstant().isAfter(now)
              || scheduled.toInstant().isBefore(now.minus(Duration.ofHours(1)))) continue;
          final Prefs snapshotPrefs = p;
          var digest =
              recent.stream()
                  .map(content::decode)
                  .filter(
                      a ->
                          (a.confirmed() || snapshotPrefs.showRumors())
                              && (snapshotPrefs.topics().isEmpty()
                                  || snapshotPrefs.topics().contains(a.category())))
                  .limit(3)
                  .toList();
          if (digest.isEmpty()) continue;
          String id = "digest-" + hash(user.getId() + "|" + scheduled.toLocalDate() + "|" + at);
          plan(
              id,
              user.getId(),
              "Seu resumo do news.dev",
              digest.stream().map(a -> a.title()).reduce((a, b) -> a + " • " + b).orElse(""),
              "radar://alertas",
              NotificationPolicy.nextAllowed(p, false, now),
              null,
              null,
              "digest");
        }
      }
      cursor = page.getLast();
      if (page.size() < 100) break;
    } while (true);
  }

  private void plan(
      String id,
      String user,
      String title,
      String body,
      String link,
      Instant available,
      String article,
      String category,
      String type) {
    store.transaction(
        tx -> {
          var ref = store.doc("outbox", id);
          var existingJob = await(tx.get(ref));
          var alertRef = store.doc("users", user).collection("alerts").document(id);
          var existingAlert = await(tx.get(alertRef));
          if (existingJob.exists() || existingAlert.exists()) return null;
          tx.create(
              ref,
              map(
                  "kind",
                  "push",
                  "articleId",
                  article,
                  "type",
                  type,
                  "userId",
                  user,
                  "title",
                  title,
                  "body",
                  body,
                  "deepLink",
                  link,
                  "state",
                  "pending",
                  "attempts",
                  0,
                  "availableAt",
                  time(available),
                  "expiresAt",
                  time(available.plus(Duration.ofDays(1)))));
          tx.create(
              store.doc("users", user).collection("alerts").document(id),
              map(
                  "type",
                  type,
                  "category",
                  category,
                  "title",
                  title,
                  "subtitle",
                  body,
                  "articleId",
                  article,
                  "at",
                  time(Instant.now()),
                  "read",
                  false));
          return null;
        });
  }
}
