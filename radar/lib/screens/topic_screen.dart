import '../l10n/app_copy.dart';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../data/repository.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/news.dart';
import '../widgets/primitives.dart';
import '../widgets/system.dart';

/// 08 · Página de tópico
class TopicScreen extends StatefulWidget {
  const TopicScreen({super.key, required this.category});
  final NewsCategory category;

  @override
  State<TopicScreen> createState() => _TopicScreenState();
}

class _TopicScreenState extends State<TopicScreen> {
  int _filter = 0;
  TopicPage? _page;
  List<String> _companies = const [];
  bool _loading = true;
  String? _error;
  bool? _loadedWithRumors;

  String? get _company => _filter == 0 ? null : _companies[_filter - 1];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final rumors = AppScope.of(context).showRumors;
    if (_loadedWithRumors != rumors) {
      _loadedWithRumors = rumors;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await Repo.instance.topic(
        widget.category,
        company: _company,
        showRumors: AppScope.read(context).showRumors,
      );
      if (!mounted) return;
      setState(() {
        _page = page;
        // Os chips vêm da primeira carga ("Tudo") pra não sumirem ao filtrar.
        if (_filter == 0) _companies = page.companies;
      });
    } on RepoException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setFilter(int i) {
    if (i == _filter) return;
    setState(() => _filter = i);
    _load();
  }

  void _toggleFollow(AppState state) {
    final c = widget.category;
    final wasFollowing = state.topics.contains(c);
    state.toggleFollowTopic(c);
    state.showToast(
      wasFollowing ? 'Você deixou de seguir ${c.label}' : 'Seguindo ${c.label}',
      actionLabel: 'Desfazer',
      onAction: () => state.toggleFollowTopic(c),
    );
  }

  void _showMore(AppState state) {
    showRSheet<void>(
      context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.tr(widget.category.fullName), style: RText.headline),
          const SizedBox(height: 16),
          RButton(
            'Silenciar alertas deste tópico',
            kind: RButtonKind.secondary,
            onPressed: () {
              Navigator.of(ctx).pop();
              state.showToast('Alertas de ${widget.category.label} silenciados');
            },
          ),
          const SizedBox(height: 8),
          RButton('Fechar', kind: RButtonKind.text, onPressed: () => Navigator.of(ctx).pop()),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final c = widget.category;
    final companies = ['Tudo', ..._companies];
    final company = _company;
    final articles = _page?.feed.items ?? const <Article>[];
    final following = state.topics.contains(c);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    CircleButton(icon: Icons.chevron_left, label: 'Voltar', onTap: () => Navigator.of(context).pop()),
                    const Spacer(),
                    CircleButton(icon: Icons.more_horiz, label: 'Mais opções', onTap: () => _showMore(state)),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              sliver: SliverToBoxAdapter(
                child: _TopicHeader(
                  category: c,
                  page: _page,
                  following: following,
                  onToggle: () => _toggleFollow(state),
                ),
              ),
            ),
            if (companies.length > 1)
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: RSize.screenPadding,
                  child: Row(
                    children: [
                      for (var i = 0; i < companies.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: RChip(
                            companies[i],
                            active: i == _filter,
                            onTap: () => _setFilter(i),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
              sliver: _loading && articles.isEmpty
                  ? const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(24), child: CupertinoActivityIndicator()))
                  : _error != null
                  ? SliverToBoxAdapter(
                      child: EmptyState(
                        icon: Icons.wifi_off,
                        title: _error!,
                        message: 'Confira a conexão e tente de novo.',
                        actionLabel: 'Tentar de novo',
                        onAction: _load,
                      ),
                    )
                  : articles.isEmpty
                  ? SliverToBoxAdapter(
                      child: EmptyState(
                        icon: c.icon,
                        title: company == null ? 'Nada novo aqui ainda' : 'Nada de $company por aqui hoje',
                        message: 'A IA avisa assim que surgir algo confirmado.',
                      ),
                    )
                  : SliverList.builder(
                      itemCount: articles.length,
                      itemBuilder: (context, i) => NewsRow(article: articles[i], showDivider: i < articles.length - 1),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicHeader extends StatelessWidget {
  const _TopicHeader({required this.category, required this.page, required this.following, required this.onToggle});
  final NewsCategory category;
  final TopicPage? page;
  final bool following;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final c = category;
    String n(int? v) => v == null ? '–' : '$v';
    final (today, week, scoops) = (n(page?.today), n(page?.week), n(page?.scoops));
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(RRadius.hero),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.alphaBlend(c.color.withValues(alpha: 0.26), const Color(0xFF101410)), const Color(0xFF0D0F0C)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconTile(icon: c.icon, color: c.color, size: 52, solid: true),
              const Spacer(),
              Pressable(
                onTap: onToggle,
                haptic: true,
                semanticLabel: following ? 'Seguindo ${c.label}. Toque pra deixar de seguir.' : 'Seguir ${c.label}',
                child: ExcludeSemantics(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: following ? Colors.white.withValues(alpha: 0.12) : RColors.radar,
                      borderRadius: BorderRadius.circular(RRadius.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(following ? Icons.check : Icons.add,
                            size: 16, color: following ? RColors.textPrimary : RColors.onRadar),
                        const SizedBox(width: 6),
                        Text(
                          following ? 'Seguindo' : 'Seguir',
                          style: RText.subheadlineEmph.withColor(following ? RColors.textPrimary : RColors.onRadar),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Semantics(header: true, child: Text(context.tr(c.fullName), style: RText.title1)),
          const SizedBox(height: 4),
          Text(context.tr(c.description), style: RText.subheadline.withColor(RColors.textSecondary)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _MiniStat(value: today, label: 'hoje')),
              const SizedBox(width: 8),
              Expanded(child: _MiniStat(value: week, label: 'na semana')),
              const SizedBox(width: 8),
              Expanded(child: _MiniStat(value: scoops, label: 'furos')),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(RRadius.field),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: RText.title3),
            Text(context.tr(label), style: RText.caption1.withColor(RColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
