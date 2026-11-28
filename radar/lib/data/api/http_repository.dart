import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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

  final _headlineCache = <(String, String, String), Future<String?>>{};
  final _headlineQueue = <String, Map<String, Completer<String?>>>{};
  Timer? _headlineTimer;

  Future<String?> translatedHeadline(Article article, String language) {
    final key = (language, article.id, article.title);
    if (_headlineCache.length >= 400) {
      _headlineCache.remove(_headlineCache.keys.first);
    }
    return _headlineCache.putIfAbsent(key, () {
      final pending = _headlineQueue.putIfAbsent(language, () => {});
      final result = pending.putIfAbsent(article.id, Completer<String?>.new);
      _headlineTimer ??=
          Timer(const Duration(milliseconds: 35), _flushHeadlines);
      return result.future.then((translation) {
        if (translation == null) _headlineCache.remove(key);
        return translation;
      });
    });
  }

  Future<void> _flushHeadlines() async {
    _headlineTimer = null;
    final batches = Map.of(_headlineQueue);
    _headlineQueue.clear();
    for (final group in batches.entries) {
      final entries = group.value.entries.toList();
      for (var offset = 0; offset < entries.length; offset += 15) {
        final batch = entries.skip(offset).take(15).toList();
        Json? response;
        try {
          response = await _get('/v1/articles/headline-translations', {
            'ids': batch.map((entry) => entry.key).join(','),
            'language': group.key,
          });
        } on RepoException {
          // A notícia permanece legível no idioma original.
        } on TypeError {
          // Respostas inesperadas também preservam o título original.
        }
        for (final entry in batch) {
          final title = response?[entry.key];
          entry.value
              .complete(title is String && title.isNotEmpty ? title : null);
        }
      }
    }
  }

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
  Future<HomeSummary> home(
          {bool showRumors = false,
          Set<NewsCategory> topics = const {}}) async =>
      remember(HomeSummary.fromJson(await _get(
          '/v1/home', {'rumors': showRumors, 'topics': _topics(topics)})));

  /// Tópicos seguidos no formato do servidor (vazio = todos os tópicos).
  static String _topics(Set<NewsCategory> topics) =>
      (topics.map((t) => t.slug).toList()..sort()).join(',');

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
        'topics': _topics(topics),
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
        {
          'since': since,
          'filter': filter.slug,
          'rumors': showRumors,
          'topics': _topics(topics),
        });
    return j.integer('count');
  }

  @override
  Future<Article?> article(String id) async {
    final cached = byId(id);
    if (cached != null && cached.body.trim().isNotEmpty) return cached;
    try {
      return remember<Article>(
          Article.fromJson(await _get('/v1/articles/$id')));
    } on RepoException catch (e) {
      if (e.statusCode == 404) return null;
      if (e.offline) {
        if (cached != null) return cached;
        for (final a in [...store.savedArticles(), ...store.cachedFeed()]) {
          if (a.id == id) return remember<Article>(a);
        }
      }
      rethrow;
    }
  }

  @override
  Future<ArticleCommentsPage> articleComments(String id,
      {String? before, String? parentId}) async {
    final result = await _get(
        '/v1/articles/${Uri.encodeComponent(id)}/comments',
        {'before': before, 'parentId': parentId});
    return (
      items: result.objects('items').map(ArticleComment.fromJson).toList(),
      nextCursor: result['nextCursor'] as String?,
    );
  }

  @override
  Future<ArticleComment> postArticleComment(String id, String body,
      {String? parentId}) async {
    _checkOnline();
    return ArticleComment.fromJson(await api.post(
            '/v1/articles/${Uri.encodeComponent(id)}/comments',
            body: {'body': body, if (parentId != null) 'parentId': parentId})
        as Json);
  }

  @override
  Future<int> setArticleCommentLike(
      String id, String commentId, bool liked) async {
    _checkOnline();
    final path =
        '/v1/articles/${Uri.encodeComponent(id)}/comments/${Uri.encodeComponent(commentId)}/like';
    final result =
        (liked ? await api.put(path) : await api.delete(path)) as Json;
    return result.integer('likeCount');
  }

  @override
  Future<void> deleteArticleComment(String id, String commentId) async {
    _checkOnline();
    await api.delete(
        '/v1/articles/${Uri.encodeComponent(id)}/comments/${Uri.encodeComponent(commentId)}');
  }

  @override
  Future<ArticleTranslation> translateArticle(
          String id, String language) async =>
      ArticleTranslation.fromJson(await _get(
        '/v1/articles/${Uri.encodeComponent(id)}/translation',
        {'language': language},
      ));

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

  Future<UserProfile> updateProfile(
      {required String name,
      required String bio,
      Uint8List? avatar,
      bool removeAvatar = false}) async {
    _checkOnline();
    return UserProfile.fromJson(await api.put('/v1/me', body: {
      'name': name,
      'bio': bio,
      if (avatar != null) 'avatarBase64': base64Encode(avatar),
      if (removeAvatar) 'removeAvatar': true,
    }) as Json);
  }

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
