import 'package:flutter/foundation.dart';

/// Ponto único de analytics. Troque o corpo de [log] pelo SDK escolhido
/// (Amplitude, PostHog…). Eventos usados no app:
/// onboarding_topics_selected, alert_level_selected, push_permission_result,
/// article_opened {source: feed|push|widget|live}, article_listened,
/// article_shared, community_waitlist_joined.
abstract final class Analytics {
  static void log(String event, [Map<String, Object?> params = const {}]) {
    debugPrint('[analytics] $event${params.isEmpty ? '' : ' $params'}');
  }
}
