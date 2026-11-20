import '../json.dart';
import '../local_store.dart';
import '../models.dart';
import '../repository.dart';
import 'api_client.dart';

/// Implementação real, falando com a API em Java/Spring Boot. Endpoints e formatos em docs/API.md.
///
/// Offline: a primeira página do feed "Pra você" fica em cache (50 matérias). Sem conexão,
/// o feed devolve esse cache com `offline: true` e a matéria é buscada no cache dos salvos.
class HttpRepository extends RadarRepository {
  HttpRepository(this.api, this.store);

  final ApiClient api;
  final LocalStore store;

  void _checkOnline() {
    if (simulateOffline) {
      throw const RepoException(
          'Sem conexão. Mostrando as últimas notícias salvas.',
          offline: true);
    }
  }

  Future<Json> _get(String path,
      [Map<String, Object?> query = const {}]) async {
    _checkOnline();
    return await api.get(path, query: query) as Json;
  }

  @override
  Future<HomeSummary> home({bool showRumors = false}) async => remember(
      HomeSummary.fromJson(await _get('/v1/home', {'rumors': showRumors})));

  @override
  Future<FeedPage> feed({
    String? cursor,
    FeedFilter filter = FeedFilter.forYou,
    Set<NewsCategory> topics = const {},
    bool showRumors = false,
  }) async {
    try {
      final page = remember(FeedPage.fromJson(await _get('/v1/feed', {
        'filter': filter.slug,
        'cursor': cursor,
        'limit': 20,
        'rumors': showRumors,
      })));
      if (cursor == null && filter == FeedFilter.forYou) {
        await store.cacheFeed(page.items);
      }
      return page;
    } on RepoException catch (e) {
      if (!e.offline || cursor != null) rethrow;
      final cached =
          store.cachedFeed().where((a) => showRumors || a.confirmed).toList();
      return remember(FeedPage(items: cached, offline: true));
    }
  }

  @override
  Future<int> newCount({
    required DateTime since,
    FeedFilter filter = FeedFilter.forYou,
    Set<NewsCategory> topics = const {},
    bool showRumors = false,
  }) async {
    final j = await _get('/v1/feed/new-count',
        {'since': since, 'filter': filter.slug, 'rumors': showRumors});
    return j.integer('count');
  }

  @override
  Future<Article?> article(String id) async {
    final cached = byId(id);
    if (cached != null) return cached;
    try {
      return remember<Article>(
          Article.fromJson(await _get('/v1/articles/$id')));
    } on RepoException catch (e) {
      if (e.statusCode == 404) return null;
      if (e.offline) {
        for (final a in [...store.savedArticles(), ...store.cachedFeed()]) {
          if (a.id == id) return remember<Article>(a);
        }
      }
      rethrow;
    }
  }

  @override
  Future<List<Article>> articles(List<String> ids) async {
    final missing = ids.where((id) => byId(id) == null).toList();
    if (missing.isNotEmpty) {
      try {
        for (var offset = 0; offset < missing.length; offset += 100) {
          final batch = missing.sublist(offset,
              (offset + 100 < missing.length ? offset + 100 : missing.length));
          final j = await _get('/v1/articles', {'ids': batch.join(',')});
          remember(j.objects('items').map(Article.fromJson).toList());
        }
      } on RepoException catch (e) {
        if (!e.offline) rethrow;
        remember(store
            .savedArticles()
            .where((a) => missing.contains(a.id))
            .toList());
      }
    }
    return ids.map(byId).whereType<Article>().toList();
  }

  @override
  Future<TopicPage> topic(NewsCategory c,
          {String? company, String? cursor, bool showRumors = false}) async =>
      remember(TopicPage.fromJson(await _get('/v1/topics/${c.slug}',
          {'company': company, 'cursor': cursor, 'rumors': showRumors})));

  @override
  Future<ExploreData> explore() async =>
      ExploreData.fromJson(await _get('/v1/explore'));

  @override
  Future<SearchResult> search(String query, {bool showRumors = false}) async {
    if (query.trim().isEmpty) return SearchResult.empty;
    return remember(SearchResult.fromJson(
        await _get('/v1/search', {'q': query.trim(), 'rumors': showRumors})));
  }

  @override
  Future<LiveEvent?> liveEvent(String id) async {
    try {
      return LiveEvent.fromJson(await _get('/v1/live/$id'));
    } on RepoException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  // ---- Usuário

  @override
  Future<UserProfile> me() async => UserProfile.fromJson(await _get('/v1/me'));

  @override
  Future<WeeklyStats> weeklyStats() async =>
      WeeklyStats.fromJson(await _get('/v1/me/stats/weekly'));

  @override
  Future<UserPrefs?> prefs() async {
    try {
      return UserPrefs.fromJson(await _get('/v1/me/prefs'));
    } on RepoException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<void> savePrefs(UserPrefs prefs) =>
      api.put('/v1/me/prefs', body: prefs.toJson());

  @override
  Future<List<AlertItem>> alerts() async => (await _get('/v1/me/alerts'))
      .objects('items')
      .map(AlertItem.fromJson)
      .toList();

  @override
  Future<void> markAlertsRead(List<String> ids) =>
      api.post('/v1/me/alerts/read', body: {'ids': ids});

  @override
  Future<List<SavedEntry>> saved() async => (await _get('/v1/me/saved'))
      .objects('items')
      .map(SavedEntry.fromJson)
      .toList();

  @override
  Future<void> setSaved(String articleId,
          {required bool saved, double? progress, bool? archived}) =>
      saved
          ? api.put('/v1/me/saved/$articleId', body: {
              if (progress != null) 'progress': progress,
              if (archived != null) 'archived': archived,
            })
          : api.delete('/v1/me/saved/$articleId');

  @override
  Future<void> setFollowing(String entityId, {required bool following}) =>
      following
          ? api.put('/v1/me/following/$entityId')
          : api.delete('/v1/me/following/$entityId');

  @override
  Future<void> joinWaitlist() => api.post('/v1/waitlist/community');

  @override
  Future<void> recordRead(String articleId) =>
      api.post('/v1/me/reads/$articleId');

  @override
  Future<void> registerPushToken(String token,
          {required String platform, String kind = 'token'}) =>
      api.post('/v1/me/push-tokens',
          body: {'token': token, 'platform': platform, 'kind': kind});
}
