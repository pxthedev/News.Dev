import '../utils/format.dart';
import 'mock_data.dart';
import 'models.dart';
import 'repository.dart';

/// Repositório com dados mockados. Padrão quando não há `RADAR_API_URL`.
/// Simula latência, paginação, chegada de notícias novas e falta de conexão.
class MockRepository extends RadarRepository {
  MockRepository({this.latency = true}) {
    for (final a in buildMockArticles()) {
      _base.add(remember(a));
    }
  }

  /// false nos testes.
  final bool latency;

  final List<Article> _base = [];
  final DateTime _startedAt = DateTime.now();
  final List<Article> _arrived = [];
  final _alerts = buildMockAlerts();
  final _comments = <String, List<ArticleComment>>{};
  final _replies = <String, List<ArticleComment>>{};
  int _commentSequence = 0;

  @override
  Future<ArticleCommentsPage> articleComments(String id,
          {String? before, String? parentId}) async =>
      (
        items: List<ArticleComment>.of(
            (parentId == null ? _comments[id] : _replies[parentId]) ??
                const []),
        nextCursor: null
      );

  @override
  Future<ArticleComment> postArticleComment(String id, String body,
      {String? parentId}) async {
    final profile = await me();
    final comment = ArticleComment(
        '${++_commentSequence}', profile.name, body, DateTime.now(), true);
    final roots = _comments.putIfAbsent(id, () => []);
    if (parentId == null) {
      roots.insert(0, comment);
    } else {
      final index = roots.indexWhere((item) => item.id == parentId);
      if (index < 0) throw const RepoException('Comentário indisponível.');
      (_replies[parentId] ??= []).insert(0, comment);
      roots[index] =
          roots[index].copyWith(replyCount: _replies[parentId]!.length);
    }
    return comment;
  }

  @override
  Future<void> deleteArticleComment(String id, String commentId) async {
    final roots = _comments[id];
    if (roots == null) return;
    roots.removeWhere((comment) => comment.id == commentId);
    _replies.remove(commentId);
    for (var i = 0; i < roots.length; i++) {
      final replies = _replies[roots[i].id];
      if (replies == null) continue;
      replies.removeWhere((reply) => reply.id == commentId);
      roots[i] = roots[i].copyWith(replyCount: replies.length);
    }
  }

  @override
  Future<int> setArticleCommentLike(
      String id, String commentId, bool liked) async {
    final roots = _comments[id] ?? const <ArticleComment>[];
    for (final list in [
      roots,
      for (final root in roots)
        if (_replies[root.id] case final replies?) replies,
    ]) {
      final index = list.indexWhere((comment) => comment.id == commentId);
      if (index < 0) continue;
      list[index] =
          list[index].copyWith(liked: liked, likeCount: liked ? 1 : 0);
      return list[index].likeCount;
    }
    throw const RepoException('Comentário indisponível.');
  }

  final Map<String, SavedEntry> _saved = {
    for (final (i, id) in mockSavedIds.indexed)
      id: SavedEntry(
        articleId: id,
        savedAt: DateTime.now().subtract(Duration(hours: i * 5)),
        progress: mockReadProgress[id] ?? 0,
      ),
  };
  UserPrefs? _prefs;

  static const heroId = 'nvidia-fabrica';
  static const maxPages = 4;

  Future<void> _wait(int ms) => latency
      ? Future<void>.delayed(Duration(milliseconds: ms))
      : Future.value();

  void _checkOnline() {
    if (simulateOffline) {
      throw const RepoException('Sem conexão.', offline: true);
    }
  }

  List<Article> _visible({required bool showRumors}) {
    final list = [..._arrived, ..._base]
        .where((a) => a.id != heroId && (showRumors || a.confirmed))
        .toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return list;
  }

  List<Article> _filtered(
      FeedFilter filter, Set<NewsCategory> topics, bool showRumors) {
    final list = _visible(showRumors: showRumors);
    return switch (filter) {
      FeedFilter.forYou => list,
      FeedFilter.urgent =>
        list.where((a) => a.urgency != Urgency.normal).toList(),
      FeedFilter.following =>
        list.where((a) => topics.contains(a.category)).toList(),
    };
  }

  @override
  Future<HomeSummary> home({bool showRumors = false}) async {
    await _wait(300);
    return remember(HomeSummary(
      hero: byId(heroId)!,
      scoopsSinceLastNight: 14,
      trending: const TrendingTag(
          tag: 'ransomware', count: 231, perDay: [3, 4, 2, 6, 5, 7, 10]),
    ));
  }

  @override
  Future<FeedPage> feed({
    String? cursor,
    FeedFilter filter = FeedFilter.forYou,
    Set<NewsCategory> topics = const {},
    bool showRumors = false,
  }) async {
    final page = int.tryParse(cursor ?? '') ?? 0;
    await _wait(page == 0 ? 700 : 500);
    final list = _filtered(filter, topics, showRumors);
    if (simulateOffline) {
      // Igual ao HttpRepository: cache das últimas matérias + aviso.
      return FeedPage(
          items: page == 0 ? list.take(6).toList() : const [], offline: true);
    }
    if (page == 0) {
      return FeedPage(items: list, nextCursor: list.isEmpty ? null : '1');
    }
    final older = [for (final a in list) _olderCopy(a, page)];
    return remember(FeedPage(
        items: older, nextCursor: page < maxPages ? '${page + 1}' : null));
  }

  Article _olderCopy(Article a, int page) {
    final shift = Duration(hours: 10 * page);
    return a.copyWith(
      id: '${a.id}~$page',
      publishedAt: a.publishedAt.subtract(shift),
      detectedAt: a.detectedAt.subtract(shift),
    );
  }

  /// Depois de 12 s com o app aberto, "chegam" 3 notícias.
  @override
  Future<int> newCount({
    required DateTime since,
    FeedFilter filter = FeedFilter.forYou,
    Set<NewsCategory> topics = const {},
    bool showRumors = false,
  }) async {
    if (DateTime.now().difference(_startedAt).inSeconds < 12) return 0;
    if (_arrived.isEmpty) {
      final now = DateTime.now();
      for (final a in buildNewArrivals(1)) {
        _arrived.add(remember(a.copyWith(publishedAt: now, detectedAt: now)));
      }
    }
    return _arrived.where((a) => a.publishedAt.isAfter(since)).length;
  }

  @override
  Future<Article?> article(String id) async {
    final cached = byId(id);
    if (cached != null) return cached;
    await _wait(300);
    _checkOnline();
    return null;
  }

  @override
  Future<List<Article>> articles(List<String> ids) async =>
      ids.map(byId).whereType<Article>().toList();

  @override
  Future<TopicPage> topic(NewsCategory c,
      {String? company, String? cursor, bool showRumors = false}) async {
    await _wait(250);
    _checkOnline();
    final items = _visible(showRumors: showRumors).where((a) {
      if (a.category != c &&
          !(c == NewsCategory.ia && a.title.contains('IA'))) {
        return false;
      }
      if (company == null) return true;
      return a.entities.any((e) => e.name == company) ||
          a.title.contains(company);
    }).toList();
    final (today, week, scoops) = _statsFor(c);
    return remember(TopicPage(
      today: today,
      week: week,
      scoops: scoops,
      companies: companiesByCategory[c] ?? const [],
      feed: FeedPage(items: items),
    ));
  }

  (int, int, int) _statsFor(NewsCategory c) {
    if (c == NewsCategory.ia) return (48, 312, 6);
    final today = c.dailyAvg * 2 + 4;
    return (today, today * 6 + 7, c.scoopsAvg * 2);
  }

  @override
  Future<ExploreData> explore() async {
    await _wait(250);
    _checkOnline();
    return const ExploreData(
        topics: mockTopicStats, trending: mockTrending, people: mockPeople);
  }

  @override
  Future<SearchResult> search(String query, {bool showRumors = false}) async {
    final q = fold(query.trim());
    if (q.isEmpty) return SearchResult.empty;
    await _wait(150);
    _checkOnline();
    final all = [byId(heroId)!, ..._visible(showRumors: showRumors)];
    final words = q.split(' ').where((w) => w.isNotEmpty);
    final articles = all.where((a) {
      final hay = fold(
          '${a.title} ${a.kickerLabel} ${a.entities.map((e) => e.name).join(' ')}');
      return words.every(hay.contains);
    }).toList();
    EntityInfo? entity;
    if (q.length >= 2) {
      for (final e in mockEntities) {
        final name = fold(e.name);
        if (name.startsWith(q) || q.startsWith(name)) {
          entity = e;
          break;
        }
      }
    }
    final people = mockPeople
        .where((p) =>
            fold(p.fullName).contains(q) || fold(p.shortName).contains(q))
        .toList();
    return SearchResult(articles: articles, entity: entity, people: people);
  }

  @override
  Future<LiveEvent?> liveEvent(String id) async => buildMockLiveEvent();

  @override
  Future<UserProfile> me() async => UserProfile(
      id: 'mock-user',
      name: 'João Guilherme',
      createdAt: DateTime(2026, 10, 3));

  @override
  Future<WeeklyStats> weeklyStats() async => mockWeek;

  @override
  Future<UserPrefs?> prefs() async => _prefs;

  @override
  Future<void> savePrefs(UserPrefs prefs) async => _prefs = prefs;

  @override
  Future<List<AlertItem>> alerts() async => _alerts;

  @override
  Future<void> markAlertsRead(List<String> ids) async {
    for (final a in _alerts) {
      if (ids.contains(a.id)) a.unread = false;
    }
  }

  @override
  Future<List<SavedEntry>> saved() async => _saved.values.toList();

  @override
  Future<void> setSaved(String articleId,
      {required bool saved, double? progress, bool? archived}) async {
    if (!saved) {
      _saved.remove(articleId);
      return;
    }
    final old = _saved[articleId];
    _saved[articleId] = SavedEntry(
      articleId: articleId,
      savedAt: old?.savedAt ?? DateTime.now(),
      progress: progress ?? old?.progress ?? 0,
      archived: archived ?? old?.archived ?? false,
    );
  }

  @override
  Future<void> setFollowing(String entityId, {required bool following}) async {}

  @override
  Future<void> joinWaitlist() async {}

  @override
  Future<void> registerPushToken(String token,
      {required String platform, String kind = 'token'}) async {}
}
