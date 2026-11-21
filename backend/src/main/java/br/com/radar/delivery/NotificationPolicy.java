package br.com.radar.delivery;

import br.com.radar.content.ContentModels.Article;
import br.com.radar.content.ContentService;
import br.com.radar.user.UserModels.Prefs;
import java.time.*;

public final class NotificationPolicy {
  private NotificationPolicy() {}

  public static boolean matches(Prefs prefs, Article article) {
    if (!article.confirmed() && !prefs.showRumors()) return false;
    boolean urgent = article.urgency().equals("urgent");
    if (urgent && !prefs.urgentAlerts()) return false;
    if (prefs.alertLevel().equals("urgent") && !urgent) return false;
    if (prefs.alertLevel().equals("balanced")
        && article.urgency().equals("normal")
        && !article.firstInBrazil()) return false;
    return prefs.topics().isEmpty() && prefs.followedEntities().isEmpty()
        || prefs.topics().contains(article.category())
        || article.entities().stream().anyMatch(e -> prefs.followedEntities().contains(e.id()));
  }

  public static Instant nextAllowed(Prefs prefs, boolean urgent, Instant now) {
    if (urgent || prefs.quietHours() == null) return now;
    var local = now.atZone(ContentService.ZONE);
    LocalTime from = LocalTime.parse(prefs.quietHours().from()),
        to = LocalTime.parse(prefs.quietHours().to());
    var time = local.toLocalTime();
    boolean overnight = from.isAfter(to),
        quiet =
            overnight
                ? time.compareTo(from) >= 0 || time.isBefore(to)
                : time.compareTo(from) >= 0 && time.isBefore(to);
    if (!quiet || from.equals(to)) return now;
    var day = local.toLocalDate();
    if (overnight && !time.isBefore(from)) day = day.plusDays(1);
    return day.atTime(to).atZone(ContentService.ZONE).toInstant();
  }
}
