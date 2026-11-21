package br.com.radar.common;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/** Replaces Firestore TTL for expiring credentials and delivery payloads. */
@Component
public class RetentionWorker {
  private final JdbcTemplate jdbc;

  public RetentionWorker(JdbcTemplate jdbc) {
    this.jdbc = jdbc;
  }

  @Scheduled(
      fixedDelayString = "${radar.maintenance.delay-ms:3600000}",
      initialDelayString = "${radar.maintenance.delay-ms:3600000}")
  public void clean() {
    for (String table : java.util.List.of("sessions", "password_resets", "outbox"))
      jdbc.update(
          "delete from fionova."
              + table
              + " where (owner_id,id) in (select owner_id,id from fionova."
              + table
              + " where (data->>'expiresAt')::timestamptz < now() limit 500)");
    jdbc.update(
        "delete from fionova.refresh_tokens r where not exists(select 1 from fionova.sessions s where s.id=r.data->>'sessionId')");
  }
}
