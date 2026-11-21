package br.com.radar.delivery;

import static br.com.radar.common.PostgresStore.*;

import br.com.radar.common.PostgresStore;
import br.com.radar.common.PostgresStore.*;
import java.time.*;
import java.util.*;
import org.springframework.stereotype.Component;

@Component
public class DeliveryQueue {
  private final PostgresStore store;

  public DeliveryQueue(PostgresStore store) {
    this.store = store;
  }

  public void email(Transaction tx, String id, String to, String subject, String body) {
    tx.create(
        store.doc("outbox", id),
        map(
            "kind",
            "email",
            "to",
            to,
            "subject",
            subject,
            "body",
            body,
            "state",
            "pending",
            "attempts",
            0,
            "availableAt",
            time(Instant.now()),
            "expiresAt",
            time(Instant.now().plus(Duration.ofDays(1)))));
  }

  public void push(String id, String user, String title, String body, String link) {
    store.transaction(
        tx -> {
          var ref = store.doc("outbox", id);
          if (await(tx.get(ref)).exists()) return null;
          tx.create(
              ref,
              map(
                  "kind",
                  "push",
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
                  time(Instant.now()),
                  "expiresAt",
                  time(Instant.now().plus(Duration.ofDays(1)))));
          return null;
        });
  }

  public boolean claim(DocumentReference ref) {
    return store.transaction(
        tx -> {
          var doc = await(tx.get(ref));
          if (!doc.exists()
              || !List.of("pending", "sending").contains(doc.getString("state"))
              || instant(doc.getInstant("availableAt")).isAfter(Instant.now())) return false;
          tx.update(
              ref,
              map(
                  "state",
                  "sending",
                  "availableAt",
                  time(Instant.now().plusSeconds(120)),
                  "attempts",
                  FieldValue.increment(1)));
          return true;
        });
  }
}
