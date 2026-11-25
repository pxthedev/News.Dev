import 'package:flutter/foundation.dart';

import '../utils/format.dart';
import 'mock_repository.dart';
import 'models.dart';

/// Filtro do feed da home. No query string: `for-you` | `urgent` | `following`.
enum FeedFilter {
  forYou('for-you'),
  urgent('urgent'),
  following('following');

  const FeedFilter(this.slug);
  final String slug;
}

/// Falha de rede ou de servidor. [message] já vem pronta pra mostrar ao usuário.
class RepoException implements Exception {
  const RepoException(this.message, {this.offline = false, this.statusCode});
  final String message;
  final bool offline;
  final int? statusCode;
  @override
  String toString() => 'RepoException($statusCode): $message';
}

/// Tudo que as telas pedem ao backend. Duas implementações:
/// - [MockRepository]: dados mockados em pt-BR (padrão, roda sem servidor).
/// - `HttpRepository`: fala com a API em Java/Spring Boot (ver docs/API.md).
///
/// Toda matéria que passa por aqui fica num cache em memória, pra [byId] responder na hora
/// (ex.: abrir a matéria a partir do feed sem nova chamada).
abstract class RadarRepository {
  final Map<String, Article> _cache = {};

  /// Liga pela tela de prévias pra testar o estado sem conexão.
  bool simulateOffline = false;

  /// Último resumo da home recebido (usado pelas prévias).
  HomeSummary? lastHome;

  Article? byId(String id) => _cache[id];
  void resetCache() {
    _cache.clear();
    lastHome = null;
  }

  Future<void> recordRead(String articleId) async {}

  @protected
  T remember<T>(T value) {
    switch (value) {
      case Article a:
        _cache[a.id] = a;
      case FeedPage p:
        p.items.forEach(remember);
      case HomeSummary h:
        remember(h.hero);
        lastHome = h;
      case TopicPage t:
        remember(t.feed);
      case SearchResult s:
        s.articles.forEach(remember);
      case List<Article> l:
        l.forEach(remember);
    }
    return value;
  }

  // ---- Leitura
  Future<HomeSummary> home({bool showRumors = false});

  /// [cursor] null = primeira página. [topics] só é usado pelo mock;
  /// na API o filtro "following" usa os tópicos salvos nas preferências.
  Future<FeedPage> feed({
    String? cursor,
    FeedFilter filter = FeedFilter.forYou,
    Set<NewsCategory> topics = const {},
    bool showRumors = false,
  });

  /// Quantas matérias novas desde [since] (pílula "↑ 3 novas").
  Future<int> newCount({
    required DateTime since,
    FeedFilter filter = FeedFilter.forYou,
    Set<NewsCategory> topics = const {},
    bool showRumors = false,
  });

  /// Cache primeiro; se não tiver, busca. null = matéria não existe (404).
  Future<Article?> article(String id);

  Future<ArticleCommentsPage> articleComments(String id, {String? before});
  Future<ArticleComment> postArticleComment(String id, String body);
  Future<void> deleteArticleComment(String id, String commentId);

  Future<ArticleTranslation> translateArticle(
          String id, String language) async =>
      throw const RepoException('Tradução indisponível.');

  /// Várias matérias de uma vez (salvos, ranking). Ids inexistentes são ignorados.
  Future<List<Article>> articles(List<String> ids);

  Future<TopicPage> topic(NewsCategory c,
      {String? company, String? cursor, bool showRumors = false});
  Future<ExploreData> explore();
  Future<SearchResult> search(String query, {bool showRumors = false});
  Future<LiveEvent?> liveEvent(String id);

  /// Tópicos vêm de uma lista fixa, então a busca deles é local.
  List<NewsCategory> findTopics(String query) {
    final q = fold(query.trim());
    if (q.length < 2) return const [];
    return NewsCategory.values
        .where((c) => fold(c.label).contains(q) || fold(c.fullName).contains(q))
        .toList();
  }

  // ---- Usuário
  Future<UserProfile> me();
  Future<WeeklyStats> weeklyStats();
  Future<UserPrefs?> prefs();
  Future<void> savePrefs(UserPrefs prefs);
  Future<List<AlertItem>> alerts();
  Future<void> markAlertsRead(List<String> ids);
  Future<List<SavedEntry>> saved();
  Future<void> setSaved(String articleId,
      {required bool saved, double? progress, bool? archived});
  Future<void> setFollowing(String entityId, {required bool following});
  Future<void> joinWaitlist();

  /// Token do APNs/FCM. Chamar depois que o usuário aceitar as notificações.
  Future<void> registerPushToken(String token,
      {required String platform, String kind = 'token'});
}

/// Ponto único de acesso. Trocado em `main.dart` conforme `--dart-define=RADAR_API_URL`.
abstract final class Repo {
  static RadarRepository instance = MockRepository();
}
