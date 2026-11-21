package br.com.radar;

import static org.assertj.core.api.Assertions.*;

import br.com.radar.content.ContentModels.*;
import br.com.radar.delivery.NotificationPolicy;
import br.com.radar.user.UserModels.*;
import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.Test;

class NotificationPolicyTest {
  Prefs prefs(boolean rumors, boolean urgent, String level) {
    return new Prefs(
        List.of("chips"),
        level,
        List.of("08:00"),
        new QuietHours("23:00", "07:00"),
        rumors,
        urgent,
        List.of());
  }

  Article article(boolean confirmed, String urgency) {
    Instant now = Instant.parse("2026-11-14T12:00:00Z");
    return new Article(
        "test",
        "Título",
        List.of("a", "b", "c"),
        "texto",
        "chips",
        null,
        null,
        now,
        now,
        List.of(new Source("Fonte", "https://example.com", null, null)),
        1,
        false,
        null,
        urgency,
        confirmed,
        1,
        null,
        null,
        List.of(),
        null);
  }

  @Test
  void appliesRumorsUrgencyAndTopicPreferences() {
    assertThat(NotificationPolicy.matches(prefs(false, true, "realtime"), article(false, "urgent")))
        .isFalse();
    assertThat(NotificationPolicy.matches(prefs(true, true, "realtime"), article(false, "urgent")))
        .isTrue();
    assertThat(NotificationPolicy.matches(prefs(true, false, "realtime"), article(true, "urgent")))
        .isFalse();
    assertThat(NotificationPolicy.matches(prefs(false, true, "urgent"), article(true, "important")))
        .isFalse();
    assertThat(NotificationPolicy.matches(prefs(false, true, "balanced"), article(true, "normal")))
        .isFalse();
  }

  @Test
  void overnightQuietHoursDelayNormalButNeverUrgent() {
    Instant night = Instant.parse("2026-11-15T03:00:00Z"),
        morning = Instant.parse("2026-11-15T10:00:00Z");
    assertThat(NotificationPolicy.nextAllowed(prefs(false, true, "realtime"), false, night))
        .isEqualTo(morning);
    assertThat(NotificationPolicy.nextAllowed(prefs(false, true, "realtime"), true, night))
        .isEqualTo(night);
    assertThat(NotificationPolicy.nextAllowed(prefs(false, true, "realtime"), false, morning))
        .isEqualTo(morning);
  }
}
