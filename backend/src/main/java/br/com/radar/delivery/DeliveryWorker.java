package br.com.radar.delivery;

import static br.com.radar.common.PostgresStore.*;

import br.com.radar.common.*;
import br.com.radar.common.PostgresStore.*;
import java.time.*;
import java.util.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
@ConditionalOnProperty(name = "radar.delivery.enabled", havingValue = "true")
public class DeliveryWorker {
  private final PostgresStore store;
  private final DeliveryQueue queue;
  private final JavaMailSender mail;
  private final PushSender push;
  private final String from;
  private final JsonStore json;

  public DeliveryWorker(
      PostgresStore store,
      DeliveryQueue queue,
      JavaMailSender mail,
      PushSender push,
      JsonStore json,
      @Value("${radar.mail.from}") String from) {
    this.store = store;
    this.queue = queue;
    this.mail = mail;
    this.push = push;
    this.from = from;
    this.json = json;
  }

  @Scheduled(fixedDelayString = "${radar.delivery.delay-ms:15000}")
  public void run() {
    for (String state : List.of("pending", "sending"))
      for (var doc :
          store.query(
              store
                  .collection("outbox")
                  .whereEqualTo("state", state)
                  .whereLessThanOrEqualTo("availableAt", time(Instant.now()))
                  .limit(30))) {
        if ("push".equals(doc.getString("kind")) && !push.available()) continue;
        if (!queue.claim(doc.getReference())) continue;
        var current = store.get(doc.getReference());
        try {
          if (instant(current.getInstant("expiresAt")).isBefore(Instant.now())) {
            await(doc.getReference().update(map("state", "expired", "body", FieldValue.delete())));
            continue;
          }
          if ("email".equals(current.getString("kind"))) {
            var message = new SimpleMailMessage();
            message.setFrom(from);
            message.setTo(current.getString("to"));
            message.setSubject(current.getString("subject"));
            message.setText(current.getString("body"));
            mail.send(message);
          } else {
            Instant due = checkPolicy(current);
            if (due == null) {
              await(
                  doc.getReference()
                      .update(map("state", "cancelled", "body", FieldValue.delete())));
              continue;
            }
            if (due.isAfter(Instant.now())) {
              await(doc.getReference().update(map("state", "pending", "availableAt", time(due))));
              continue;
            }
            sendPush(current);
          }
          await(
              doc.getReference()
                  .update(
                      map(
                          "state",
                          "sent",
                          "body",
                          FieldValue.delete(),
                          "sentAt",
                          time(Instant.now()))));
        } catch (Exception e) {
          long attempts = current.getLong("attempts");
          await(
              doc.getReference()
                  .update(
                      map(
                          "state",
                          attempts >= 6 ? "failed" : "pending",
                          "availableAt",
                          time(
                              Instant.now()
                                  .plusSeconds(
                                      Math.min(3600, 30L * (1L << Math.min(attempts, 6))))),
                          "lastError",
                          e.getClass().getSimpleName())));
        }
      }
  }

  private void sendPush(DocumentSnapshot job) {
    var devices =
        store
            .query(store.collection("pushTokens").whereEqualTo("userId", job.getString("userId")))
            .stream()
            .map(DocumentSnapshot::getData)
            .toList();
    push.send(job.getId(), job.getData(), devices);
  }

  private Instant checkPolicy(DocumentSnapshot job) {
    var user = store.get(store.doc("users", job.getString("userId")));
    if (!user.exists() || user.getString("prefs") == null) return null;
    var prefs = json.read(user.getString("prefs"), br.com.radar.user.UserModels.Prefs.class);
    Object following = user.get("following");
    if (following instanceof List<?> list)
      prefs =
          new br.com.radar.user.UserModels.Prefs(
              prefs.topics(),
              prefs.alertLevel(),
              prefs.digestTimes(),
              prefs.quietHours(),
              prefs.showRumors(),
              prefs.urgentAlerts(),
              list.stream().map(Object::toString).toList());
    if (job.getString("articleId") != null) {
      var doc = store.get(store.doc("articles", job.getString("articleId")));
      if (!doc.exists()) return null;
      try {
        var article =
            json.read(doc.getString("payload"), br.com.radar.content.ContentModels.Article.class);
        if (!NotificationPolicy.matches(prefs, article)) return null;
        return NotificationPolicy.nextAllowed(
            prefs, article.urgency().equals("urgent"), Instant.now());
      } catch (Exception e) {
        throw new IllegalStateException(e);
      }
    }
    if (prefs.digestTimes().isEmpty()) return null;
    return NotificationPolicy.nextAllowed(prefs, false, Instant.now());
  }
}
