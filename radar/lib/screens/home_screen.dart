import '../l10n/app_copy.dart';
import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../data/mock_repository.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../routes.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/charts.dart';
import '../widgets/news.dart';
import '../widgets/primitives.dart';

/// 05 · Agora (home)
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scroll = ScrollController();
  int _segment = 0;
  final List<Article> _items = [];
  HomeSummary? _home;
  String? _cursor;
  String? _error;
  DateTime _loadedAt = DateTime.now();
  bool _loading = true;
  bool _loadingMore = false;
  bool _offline = false;
  int _pendingNew = 0;
  Timer? _pollTimer;
  Timer? _bannerTimer;

  RadarRepository get _repo => Repo.instance;
  bool get _hasMore => _cursor != null;

  FeedFilter get _filter => FeedFilter.values[_segment];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
    // Confere notícias novas com o app aberto (pílula "↑ 3 novas").
    _pollTimer =
        Timer.periodic(const Duration(seconds: 15), (_) => _checkNew());
    // Demonstração do banner urgente (só no mock, uma vez por sessão).
    final state = AppScope.read(context);
    if (_repo is MockRepository && !state.demoBannerShown) {
      state.demoBannerShown = true;
      _bannerTimer = Timer(const Duration(seconds: 5), () {
        final a = _repo.byId('banco-ataque');
        if (a != null) state.showBanner(a);
      });
    }
  }

  Future<void> _checkNew() async {
    if (!mounted || _loading || _offline) return;
    final state = AppScope.read(context);
    try {
      final n = await _repo.newCount(
        since: _loadedAt,
        filter: _filter,
        topics: state.topics,
        showRumors: state.showRumors,
      );
      if (mounted && n != _pendingNew) setState(() => _pendingNew = n);
    } on RepoException {
      // Silencioso: a próxima tentativa resolve.
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _bannerTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final state = AppScope.read(context);
    final startedAt = DateTime.now();
    final homeFuture = _loadHome(state.showRumors);
    try {
      final res = await _repo.feed(
          filter: _filter, topics: state.topics, showRumors: state.showRumors);
      final home = await homeFuture;
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(res.items);
        _home = home;
        _cursor = res.nextCursor;
        _offline = res.offline;
        _error = null;
        _loading = false;
        _loadedAt = startedAt;
      });
    } on RepoException catch (e) {
      final home = await homeFuture;
      if (!mounted) return;
      setState(() {
        _home = home;
        _error = e.message;
        _loading = false;
      });
    }
  }

  /// Sem conexão, mantém o topo que já estava na tela.
  Future<HomeSummary?> _loadHome(bool showRumors) async {
    try {
      return await _repo.home(showRumors: showRumors);
    } on RepoException {
      return _home;
    }
  }

  Future<void> _refresh() async {
    setState(() => _pendingNew = 0);
    await _load();
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 600 &&
        !_loading &&
        !_loadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    final state = AppScope.read(context);
    setState(() => _loadingMore = true);
    try {
      final res = await _repo.feed(
        cursor: _cursor,
        filter: _filter,
        topics: state.topics,
        showRumors: state.showRumors,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(res.items);
        _cursor = res.nextCursor;
        _loadingMore = false;
      });
    } on RepoException {
      // Mantém o cursor; rolar de novo tenta outra vez.
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _showNew() async {
    setState(() => _pendingNew = 0);
    unawaited(_scroll.animateTo(0,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic));
    await _load();
  }

  void _setSegment(int i) {
    setState(() {
      _segment = i;
      _loading = true;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final top = MediaQuery.paddingOf(context).top;
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final home = _home;
    final hero = home?.hero;
    final insights = home == null
        ? null
        : IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                    child: _AdvantageCard(minutes: state.week.avgLeadMinutes)),
                const SizedBox(width: 12),
                Expanded(child: _TrendingCard(trending: home.trending)),
              ],
            ),
          );

    return Stack(
      children: [
        SafeArea(
          bottom: false,
          child: CustomScrollView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            slivers: [
              CupertinoSliverRefreshControl(onRefresh: _refresh),
              const SliverToBoxAdapter(child: SizedBox(height: 6)),
              SliverPadding(
                padding: RSize.screenPadding,
                sliver: SliverToBoxAdapter(
                  child: _Header(
                    initials: state.initials,
                    segment: _segment,
                    onSegment: _setSegment,
                    unread: state.unreadAlerts,
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(20, wide ? 28 : 18, 20, 0),
                sliver: SliverList.list(
                  children: [
                    Semantics(
                        header: true,
                        child: Text(context.newsGreeting(state.firstName),
                            style: wide
                                ? RText.title1.copyWith(fontSize: 44)
                                : RText.title1)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.bolt, size: 16, color: RColors.radar),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _home == null
                                ? context.tr('Atualizando…')
                                : context.tr(
                                    _home!.scoopsSinceLastNight == 1
                                        ? '{n} furo desde ontem à noite'
                                        : '{n} furos desde ontem à noite',
                                    {'n': _home!.scoopsSinceLastNight}),
                            style: RText.subheadline
                                .withColor(RColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                    if (_offline) ...[
                      const SizedBox(height: 16),
                      const _OfflineNotice()
                    ],
                    if (insights != null) ...[
                      const SizedBox(height: 20),
                      if (wide && hero != null)
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(flex: 3, child: HeroCard(article: hero)),
                              const SizedBox(width: 16),
                              Expanded(flex: 2, child: insights),
                            ],
                          ),
                        )
                      else ...[
                        if (hero != null) ...[
                          HeroCard(article: hero),
                          const SizedBox(height: 14),
                        ],
                        insights,
                      ],
                    ],
                    const SizedBox(height: 24),
                    SectionHeader(
                      'Últimas',
                      action: 'Ver tudo',
                      onAction: () =>
                          Routes.openList('Últimas', List.of(_items)),
                    ),
                  ],
                ),
              ),
              if (_loading)
                const SliverPadding(
                    padding: RSize.screenPadding,
                    sliver: SliverToBoxAdapter(child: FeedSkeleton()))
              else if (_error != null && _items.isEmpty)
                SliverToBoxAdapter(
                  child: EmptyState(
                    icon: Icons.wifi_off,
                    title: _error!,
                    message: 'Puxe pra tentar de novo.',
                    actionLabel: 'Tentar de novo',
                    onAction: () {
                      setState(() => _loading = true);
                      _load();
                    },
                  ),
                )
              else if (_items.isEmpty)
                SliverToBoxAdapter(
                  child: EmptyState(
                    icon: Icons.bolt,
                    title: _segment == 2
                        ? 'Siga tópicos pra montar este feed'
                        : 'Nada novo por aqui',
                    message: _segment == 2
                        ? 'Escolha o que te interessa e a gente avisa primeiro.'
                        : 'Puxe pra atualizar. A IA segue vasculhando as fontes.',
                    actionLabel: _segment == 2 ? 'Escolher tópicos' : null,
                    onAction: _segment == 2
                        ? () => Routes.push(Routes.editTopics)
                        : null,
                  ),
                )
              else
                SliverPadding(
                  padding: RSize.screenPadding,
                  sliver: SliverList.builder(
                    itemCount: _items.length + 1,
                    itemBuilder: (context, i) {
                      if (i == _items.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: _loadingMore
                              ? const CupertinoActivityIndicator()
                              : (_hasMore
                                  ? const SizedBox.shrink()
                                  : Text(
                                      'Você está em dia.',
                                      textAlign: TextAlign.center,
                                      style: RText.footnote
                                          .withColor(RColors.textTertiary),
                                    )),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: RColors.bgElevated,
                            borderRadius: BorderRadius.circular(RRadius.card),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child:
                                NewsRow(article: _items[i], showDivider: false),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              SliverToBoxAdapter(
                  child: SizedBox(height: RSize.tabClearance(context))),
            ],
          ),
        ),
        Positioned(
          top: top + 58,
          left: 0,
          right: 0,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: ScaleTransition(scale: anim, child: child),
              ),
              child: _pendingNew > 0
                  ? _NewItemsPill(
                      key: const ValueKey('pill'),
                      count: _pendingNew,
                      onTap: _showNew)
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(
      {required this.initials,
      required this.segment,
      required this.onSegment,
      required this.unread});
  final String initials;
  final int segment;
  final ValueChanged<int> onSegment;
  final int unread;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Semantics(
            label: 'Seu perfil', child: InitialsAvatar(initials, size: 36)),
        Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SegmentedPill(
                segments: const ['Pra você', 'Urgente', 'Seguindo'],
                index: segment,
                onChanged: onSegment,
              ),
            ),
          ),
        ),
        CircleButton(
          icon: Icons.notifications_none,
          label: 'Alertas',
          badge: unread > 0,
          onTap: Routes.openAlerts,
        ),
      ],
    );
  }
}

/// Card de destaque índigo (raio 28). Escala 0,98 ao tocar.
class HeroCard extends StatelessWidget {
  const HeroCard({super.key, required this.article});
  final Article article;

  @override
  Widget build(BuildContext context) {
    final dark = RColors.onRadar;
    return Pressable(
      pressedScale: 0.98,
      onTap: () => Routes.openArticle(article.id),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: RColors.radar,
            borderRadius: BorderRadius.circular(RRadius.hero)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    article.category.label,
                    style: RText.footnoteEmph.withColor(dark),
                  ),
                ),
                const SizedBox(width: 8),
                Text(context.newsTime(article.publishedAt),
                    style: RText.footnoteEmph.withColor(dark)),
              ],
            ),
            const SizedBox(height: 14),
            if (article.firstInBrazil) ...[
              const FirstBadge(),
              const SizedBox(height: 8),
            ],
            NewsHeadline(article, style: RText.title2.withColor(dark)),
            const SizedBox(height: 18),
            Row(
              children: [
                AvatarStack(
                  items: [
                    for (final s in article.sources
                        .where((s) => s.name.isNotEmpty)
                        .take(3))
                      (s.name.substring(0, 1), s.color)
                  ],
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr('{n} fontes · {min} min', {
                      'n': article.sourceCount,
                      'min': article.readingMinutes
                    }),
                    style: RText.footnoteEmph.withColor(dark),
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration:
                      BoxDecoration(color: dark, shape: BoxShape.circle),
                  child: const Icon(Icons.north_east,
                      color: RColors.radar, size: 22),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AdvantageCard extends StatelessWidget {
  const _AdvantageCard({required this.minutes});
  final int minutes;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Sua vantagem: $minutes minutos à frente da imprensa brasileira, em média',
      child: ExcludeSemantics(
        child: RCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('Sua vantagem'),
                  style: RText.footnote.withColor(RColors.textSecondary)),
              const SizedBox(height: 12),
              const ProgressRing(
                  progress: 0.78,
                  size: 60,
                  child: Icon(Icons.bolt, color: RColors.radar, size: 26)),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('$minutes', style: RText.bigNumber),
                  const SizedBox(width: 4),
                  Text('min',
                      style: RText.callout.withColor(RColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 4),
              Text(context.tr('à frente da imprensa BR, em média'),
                  style: RText.caption1.withColor(RColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendingCard extends StatelessWidget {
  const _TrendingCard({required this.trending});
  final TrendingTag trending;

  @override
  Widget build(BuildContext context) {
    final t = trending;
    return Pressable(
      pressedScale: 0.98,
      semanticLabel: 'Em alta hoje: ${t.tag}, ${t.count} matérias',
      onTap: () => Routes.openSearch(t.tag),
      child: RCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('Em alta hoje'),
                style: RText.footnote.withColor(RColors.textSecondary)),
            const SizedBox(height: 8),
            Text('#${t.tag}',
                style: RText.headline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const Spacer(),
            const SizedBox(height: 12),
            MiniBars(
                values: t.perDay, highlight: t.perDay.length - 1, height: 62),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.trending_up, size: 14, color: RColors.radar),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '${t.count} matérias',
                    style: RText.caption1Emph.withColor(RColors.radar),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NewItemsPill extends StatelessWidget {
  const _NewItemsPill({super.key, required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      haptic: true,
      semanticLabel: '$count notícias novas. Toque pra ver.',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: RColors.radar,
          borderRadius: BorderRadius.circular(RRadius.pill),
          boxShadow: const [
            BoxShadow(
                color: Color(0x66000000), blurRadius: 16, offset: Offset(0, 6))
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.arrow_upward, size: 16, color: RColors.onRadar),
            const SizedBox(width: 4),
            Text(context.tr('{n} novas', {'n': count}),
                style: RText.footnoteEmph.withColor(RColors.onRadar)),
          ],
        ),
      ),
    );
  }
}

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice();

  @override
  Widget build(BuildContext context) {
    return RCard(
      color: RColors.bgElevated,
      radius: 16,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, color: RColors.textSecondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
                context
                    .tr('Sem conexão. Mostrando as últimas notícias salvas.'),
                style: RText.footnote),
          ),
        ],
      ),
    );
  }
}
