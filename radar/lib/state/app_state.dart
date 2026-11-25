import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../data/json.dart';
import '../data/api/http_repository.dart';
import '../data/local_store.dart';
import '../data/mock_data.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../services/analytics.dart';
import '../l10n/app_copy.dart';
import '../utils/format.dart';

class ToastData {
  const ToastData(this.id, this.message, {this.actionLabel, this.onAction});
  final int id;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
}

/// Estado global do app (preferências, salvos, alertas, overlays).
/// ChangeNotifier puro pra não amarrar a equipe a uma lib.
///
/// Persistência: toda mudança é salva no aparelho ([LocalStore]) com debounce.
/// Sincronização: ações do usuário (salvar, seguir, preferências…) também vão pro
/// backend via [RadarRepository], sem travar a interface. Se falhar, o estado local vale.
class AppState extends ChangeNotifier {
  AppState({this.onboarded = false, RadarRepository? repo, this.store})
      : repo = repo ?? Repo.instance;

  final RadarRepository repo;
  final LocalStore? store;

  bool onboarded;
  String? pendingSharedArticle;
  late final _language =
      ValueNotifier(AppLanguage.fromCode(store?.appLanguage));
  ValueListenable<AppLanguage> get languageListenable => _language;
  AppLanguage get language => _language.value;

  void setLanguage(AppLanguage language) {
    if (_language.value == language) return;
    _language.value = language;
    unawaited(store?.writeAppLanguage(language.code));
    notifyListeners();
  }

  // Usuário
  String userName = 'Leitor';
  String userBio = '';
  Uint8List? userAvatar;
  int _profileRevision = 0;
  String? userEmail;
  bool get isAccount =>
      repo is HttpRepository && (repo as HttpRepository).api.store.isAccount;
  DateTime? memberSince;
  String get firstName => userName.split(' ').first;
  String get initials {
    final parts = userName.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return (parts.length == 1
            ? parts.first[0]
            : '${parts.first[0]}${parts.last[0]}')
        .toUpperCase();
  }

  String get readerSince => monthYear(memberSince ?? DateTime.now());
  WeeklyStats week = const WeeklyStats(
      scoops: 0,
      streakDays: 0,
      avgLeadMinutes: 0,
      perDay: [0, 0, 0, 0, 0, 0, 0]);

  // Preferências (UserPrefs)
  final Set<NewsCategory> topics = {
    NewsCategory.ia,
    NewsCategory.seguranca,
    NewsCategory.programacao
  };
  AlertLevel alertLevel = AlertLevel.balanced;
  bool quietHours = true;
  bool urgentAlerts = true;
  bool digest = true;
  bool showRumors = false; // rumores vêm desligados por padrão
  bool pushGranted = false;
  final Set<String> followedEntities = {};

  // Salvos
  final List<String> savedIds = [];
  final Set<String> archivedIds = {};
  final Map<String, double> readProgress = {};

  // Alertas e busca
  final List<AlertItem> alerts = [];
  final List<RecentSearch> recentSearches = [...mockRecentSearches];

  // Pop-ups
  bool communityJoined = false;
  DateTime? communityTeaserShownAt;
  int articlesOpened = 0;
  bool ratingAsked = false;
  bool demoBannerShown = false;

  // Overlays globais (toast e banner urgente)
  final toast = ValueNotifier<ToastData?>(null);
  final banner = ValueNotifier<Article?>(null);
  Timer? _toastTimer;
  Timer? _bannerTimer;
  Timer? _persistTimer;
  Timer? _prefsTimer;
  int _toastSeq = 0;
  bool _disposed = false;

  void _applyProfile(UserProfile profile) {
    userName = profile.name;
    userEmail = profile.email;
    memberSince = profile.createdAt;
    userBio = profile.bio;
    userAvatar = profile.avatar;
  }

  Future<void> updateProfile(
      {required String name,
      required String bio,
      Uint8List? avatar,
      bool removeAvatar = false}) async {
    final repository = repo;
    if (repository is! HttpRepository || !isAccount) {
      throw const RepoException('Entre na conta para editar o perfil.');
    }
    final revision = ++_profileRevision;
    final result = await repository.updateProfile(
        name: name, bio: bio, avatar: avatar, removeAvatar: removeAvatar);
    if (_disposed || revision != _profileRevision) return;
    _applyProfile(result);
    _schedulePersist();
    notifyListeners();
  }

  int get unreadAlerts => alerts.where((a) => a.unread).length;

  UserPrefs get prefs => UserPrefs(
        topics: topics.toList(),
        alertLevel: alertLevel,
        digestTimes: digest ? const ['08:00', '19:00'] : const [],
        quietHours: quietHours ? (from: '23:00', to: '07:00') : null,
        showRumors: showRumors,
        urgentAlerts: urgentAlerts,
        followedEntities: followedEntities.toList(),
      );

  // ---- Inicialização

  /// Lê o estado salvo no aparelho. Rápido; chame antes do runApp.
  void restore() {
    final j = store?.readState();
    if (j == null) return;
    try {
      _fromJson(j);
      if (!isAccount) onboarded = false;
    } on Object catch (e) {
      debugPrint('[state] estado local inválido, ignorando: $e');
    }
  }

  /// Busca perfil, estatísticas, alertas e (na primeira vez) os salvos no backend.
  /// Não bloqueia a interface: cada parte atualiza a tela quando chega.
  Future<void> refreshRemote() async {
    await Future.wait([
      _try(() async {
        final revision = _profileRevision;
        final me = await repo.me();
        if (revision == _profileRevision) _applyProfile(me);
      }),
      _try(() async => week = await repo.weeklyStats()),
      _try(() async {
        final list = await repo.alerts();
        alerts
          ..clear()
          ..addAll(list);
      }),
      if (savedIds.isEmpty && store?.readState()?['savedIds'] == null)
        _try(() async {
          final entries = await repo.saved()
            ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
          savedIds
            ..clear()
            ..addAll(entries.map((e) => e.articleId));
          archivedIds
              .addAll(entries.where((e) => e.archived).map((e) => e.articleId));
          readProgress
              .addAll({for (final e in entries) e.articleId: e.progress});
        }),
    ]);
    if (!_disposed) notifyListeners();
    // Garante o conteúdo dos salvos no cache offline.
    await _try(() => repo.articles(savedIds));
    await _cacheSavedArticles();
  }

  /// Limpa dados privados antes de carregar outra identidade neste aparelho.
  Future<void> reloadIdentity({bool refresh = true}) async {
    _prefsTimer?.cancel();
    _persistTimer?.cancel();
    onboarded = false;
    _profileRevision++;
    userName = 'Leitor';
    userEmail = null;
    userBio = '';
    userAvatar = null;
    memberSince = null;
    week = const WeeklyStats(
        scoops: 0,
        streakDays: 0,
        avgLeadMinutes: 0,
        perDay: [0, 0, 0, 0, 0, 0, 0]);
    savedIds.clear();
    archivedIds.clear();
    readProgress.clear();
    alerts.clear();
    followedEntities.clear();
    recentSearches.clear();
    topics
      ..clear()
      ..addAll(
          [NewsCategory.ia, NewsCategory.seguranca, NewsCategory.programacao]);
    alertLevel = AlertLevel.balanced;
    digest = true;
    quietHours = true;
    showRumors = false;
    urgentAlerts = true;
    communityJoined = false;
    communityTeaserShownAt = null;
    articlesOpened = 0;
    ratingAsked = false;
    repo.resetCache();
    await store?.clearUserData();
    if (!refresh) {
      notifyListeners();
      return;
    }
    await _try(() async {
      final remotePrefs = await repo.prefs();
      if (remotePrefs != null) {
        topics
          ..clear()
          ..addAll(remotePrefs.topics);
        alertLevel = remotePrefs.alertLevel;
        digest = remotePrefs.digestTimes.isNotEmpty;
        quietHours = remotePrefs.quietHours != null;
        showRumors = remotePrefs.showRumors;
        urgentAlerts = remotePrefs.urgentAlerts;
        followedEntities.addAll(remotePrefs.followedEntities);
      }
    });
    await refreshRemote();
    notifyListeners();
  }

  Future<void> _try(Future<void> Function() f) async {
    try {
      await f();
    } on Object catch (e) {
      debugPrint('[state] falha ao sincronizar: $e');
    }
  }

  /// Dispara a chamada ao backend sem esperar. Erro só vai pro log.
  void _sync(Future<void> Function() f) => unawaited(_try(f));

  @override
  void notifyListeners() {
    super.notifyListeners();
    _schedulePersist();
  }

  void _schedulePersist() {
    if (store == null) return;
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 400), persistNow);
  }

  Future<void> persistNow() async {
    _persistTimer?.cancel();
    await store?.writeState(_toJson());
  }

  /// Preferências mudam em rajadas (toggles); manda pro backend 1 s depois da última.
  void _schedulePrefsSync() {
    if (!isAccount) return;
    if (!onboarded) return;
    _prefsTimer?.cancel();
    _prefsTimer = Timer(
        const Duration(seconds: 1), () => _sync(() => repo.savePrefs(prefs)));
  }

  Future<void> _cacheSavedArticles() async {
    final s = store;
    if (s == null) return;
    await s.cacheSavedArticles(
        savedIds.map(repo.byId).whereType<Article>().toList());
  }

  Json _toJson() => {
        'onboarded': onboarded,
        'userName': userName,
        'userBio': userBio,
        'memberSince': memberSince?.toUtc().toIso8601String(),
        'week': week.toJson(),
        'prefs': prefs.toJson(),
        'pushGranted': pushGranted,
        'savedIds': savedIds,
        'archivedIds': archivedIds.toList(),
        'readProgress': readProgress,
        'recentSearches': [for (final r in recentSearches) r.toJson()],
        'communityJoined': communityJoined,
        'communityTeaserShownAt':
            communityTeaserShownAt?.toUtc().toIso8601String(),
        'articlesOpened': articlesOpened,
        'ratingAsked': ratingAsked,
      };

  void _fromJson(Json j) {
    onboarded = j.boolean('onboarded');
    userName = j.strOrNull('userName') ?? userName;
    userBio = j.strOrNull('userBio') ?? '';
    memberSince = j['memberSince'] == null ? null : j.date('memberSince');
    if (j['week'] is Map) week = WeeklyStats.fromJson(j.obj('week'));
    if (j['prefs'] is Map) {
      final p = UserPrefs.fromJson(j.obj('prefs'));
      topics
        ..clear()
        ..addAll(p.topics);
      alertLevel = p.alertLevel;
      digest = p.digestTimes.isNotEmpty;
      quietHours = p.quietHours != null;
      showRumors = p.showRumors;
      urgentAlerts = p.urgentAlerts;
      followedEntities
        ..clear()
        ..addAll(p.followedEntities);
    }
    pushGranted = j.boolean('pushGranted');
    savedIds
      ..clear()
      ..addAll(j.list('savedIds').cast<String>());
    archivedIds
      ..clear()
      ..addAll(j.list('archivedIds').cast<String>());
    readProgress
      ..clear()
      ..addAll({
        for (final e in ((j['readProgress'] as Map?) ?? const {}).entries)
          e.key as String: (e.value as num).toDouble(),
      });
    if (j['recentSearches'] is List) {
      recentSearches
        ..clear()
        ..addAll(j.objects('recentSearches').map(RecentSearch.fromJson));
    }
    communityJoined = j.boolean('communityJoined');
    communityTeaserShownAt = j['communityTeaserShownAt'] == null
        ? null
        : j.date('communityTeaserShownAt');
    articlesOpened = j.integer('articlesOpened', fallback: 0);
    ratingAsked = j.boolean('ratingAsked');
  }

  // ---- Onboarding
  void toggleTopic(NewsCategory c) {
    topics.contains(c) ? topics.remove(c) : topics.add(c);
    HapticFeedback.selectionClick();
    notifyListeners();
    _schedulePrefsSync();
  }

  void setAlertLevel(AlertLevel level) {
    alertLevel = level;
    notifyListeners();
    _schedulePrefsSync();
  }

  void setQuietHours(bool v) {
    quietHours = v;
    notifyListeners();
    _schedulePrefsSync();
  }

  void setPushGranted(bool v) {
    pushGranted = v;
    notifyListeners();
  }

  void completeOnboarding() {
    if (!isAccount) return;
    onboarded = true;
    notifyListeners();
    _sync(() => repo.savePrefs(prefs));
  }

  void resetOnboarding() {
    onboarded = false;
    notifyListeners();
  }

  // ---- Ajustes
  void setUrgentAlerts(bool v) {
    urgentAlerts = v;
    notifyListeners();
    _schedulePrefsSync();
  }

  void setDigest(bool v) {
    digest = v;
    notifyListeners();
    _schedulePrefsSync();
  }

  void setShowRumors(bool v) {
    showRumors = v;
    notifyListeners();
    _schedulePrefsSync();
  }

  // ---- Salvos
  bool isSaved(String id) => savedIds.contains(id);

  /// Retorna true se a matéria ficou salva.
  bool toggleSave(String id) {
    final saved = !savedIds.contains(id);
    if (saved) {
      savedIds.insert(0, id);
    } else {
      savedIds.remove(id);
      readProgress.remove(id);
    }
    archivedIds.remove(id);
    HapticFeedback.lightImpact();
    notifyListeners();
    _sync(() => repo.setSaved(id, saved: saved));
    unawaited(_cacheSavedArticles());
    return saved;
  }

  void archive(String id) {
    archivedIds.add(id);
    notifyListeners();
    _sync(() => repo.setSaved(id, saved: true, archived: true));
  }

  void unarchive(String id) {
    archivedIds.remove(id);
    notifyListeners();
    _sync(() => repo.setSaved(id, saved: true, archived: false));
  }

  /// Progresso de leitura (0 a 1) de uma matéria salva. Só sobe, nunca desce.
  void setReadProgress(String id, double progress) {
    if (!isSaved(id)) return;
    final p = progress.clamp(0.0, 1.0);
    final old = readProgress[id] ?? 0;
    if (p - old < 0.05 && p < 1) return;
    readProgress[id] = p;
    notifyListeners();
    _sync(() => repo.setSaved(id, saved: true, progress: p));
  }

  // ---- Seguir
  bool isFollowingEntity(String id) => followedEntities.contains(id);

  void toggleFollowEntity(String id) {
    final following = !followedEntities.contains(id);
    following ? followedEntities.add(id) : followedEntities.remove(id);
    HapticFeedback.lightImpact();
    notifyListeners();
    _sync(() => repo.setFollowing(id, following: following));
  }

  void toggleFollowTopic(NewsCategory c) {
    topics.contains(c) ? topics.remove(c) : topics.add(c);
    HapticFeedback.lightImpact();
    notifyListeners();
    _schedulePrefsSync();
  }

  // ---- Alertas
  void markAlertRead(String id) {
    for (final a in alerts) {
      if (a.id == id) a.unread = false;
    }
    notifyListeners();
    _sync(() => repo.markAlertsRead([id]));
  }

  void markAllAlertsRead() {
    final ids = [
      for (final a in alerts)
        if (a.unread) a.id
    ];
    for (final a in alerts) {
      a.unread = false;
    }
    HapticFeedback.lightImpact();
    notifyListeners();
    if (ids.isNotEmpty) _sync(() => repo.markAlertsRead(ids));
  }

  // ---- Busca
  void addRecentSearch(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    recentSearches.removeWhere((r) => r.text == t);
    recentSearches.insert(0, RecentSearch(t));
    if (recentSearches.length > 8) recentSearches.removeLast();
    notifyListeners();
  }

  void clearRecentSearches() {
    recentSearches.clear();
    notifyListeners();
  }

  // ---- Avaliação e comunidade
  void registerArticleOpened() {
    articlesOpened++;
    _schedulePersist();
  }

  /// Pede avaliação depois de um momento positivo: terminar de ler a 3ª matéria.
  bool get shouldAskRating => !ratingAsked && articlesOpened >= 3;

  void markRatingAsked() {
    ratingAsked = true;
    _schedulePersist();
  }

  /// Teaser da comunidade: no máximo uma vez a cada 14 dias.
  bool get canShowCommunityTeaser =>
      !communityJoined &&
      (communityTeaserShownAt == null ||
          DateTime.now().difference(communityTeaserShownAt!).inDays >= 14);

  void markCommunityTeaserShown() {
    communityTeaserShownAt = DateTime.now();
    _schedulePersist();
  }

  void joinCommunity() {
    communityJoined = true;
    Analytics.log('community_waitlist_joined');
    HapticFeedback.mediumImpact();
    notifyListeners();
    _sync(repo.joinWaitlist);
  }

  // ---- Overlays
  void showToast(String message,
      {String? actionLabel, VoidCallback? onAction}) {
    _toastTimer?.cancel();
    toast.value = ToastData(++_toastSeq, message,
        actionLabel: actionLabel, onAction: onAction);
    _toastTimer = Timer(const Duration(seconds: 3), hideToast);
  }

  void hideToast() {
    _toastTimer?.cancel();
    toast.value = null;
  }

  void showBanner(Article article) {
    _bannerTimer?.cancel();
    banner.value = article;
    HapticFeedback.mediumImpact();
    _bannerTimer = Timer(const Duration(seconds: 6), dismissBanner);
  }

  void dismissBanner() {
    _bannerTimer?.cancel();
    banner.value = null;
  }

  @override
  void dispose() {
    _language.dispose();
    _disposed = true;
    _toastTimer?.cancel();
    _bannerTimer?.cancel();
    _persistTimer?.cancel();
    _prefsTimer?.cancel();
    toast.dispose();
    banner.dispose();
    super.dispose();
  }
}

/// Dá acesso ao [AppState] pela árvore de widgets.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  /// Lê e reconstrói quando o estado muda.
  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Lê sem se inscrever (use em callbacks e initState).
  static AppState read(BuildContext context) =>
      (context.getElementForInheritedWidgetOfExactType<AppScope>()!.widget
              as AppScope)
          .notifier!;
}
