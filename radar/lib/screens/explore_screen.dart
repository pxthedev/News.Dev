import '../l10n/app_copy.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../data/repository.dart';
import '../routes.dart';
import '../theme/tokens.dart';
import '../widgets/primitives.dart';

/// 07 · Explorar
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  ExploreData? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final d = await Repo.instance.explore();
      if (mounted) setState(() => _data = d);
    } on RepoException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _openRanking(List<TrendingItem> trending) async {
    final articles = await Repo.instance.articles([for (final t in trending) t.articleId]);
    await Routes.openList('Em alta agora', articles);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final data = _data;
    final header = [
      Semantics(header: true, child: Text(context.tr('Explorar'), style: RText.largeTitle)),
      const SizedBox(height: 14),
      const _SearchFieldButton(),
      const SizedBox(height: 16),
    ];
    if (data == null) {
      return ListView(
        padding: EdgeInsets.fromLTRB(20, top + 8, 20, RSize.tabClearance(context)),
        children: [
          ...header,
          if (_error != null)
            EmptyState(
              icon: Icons.wifi_off,
              title: _error!,
              message: 'Confira a conexão e tente de novo.',
              actionLabel: 'Tentar de novo',
              onAction: _load,
            )
          else
            const Padding(padding: EdgeInsets.all(24), child: CupertinoActivityIndicator()),
        ],
      );
    }
    final stats = data.topics;
    final trending = data.trending;
    return ListView(
      padding: EdgeInsets.fromLTRB(20, top + 8, 20, RSize.tabClearance(context)),
      children: [
        ...header,
        for (var r = 0; r < stats.length; r += 2) ...[
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _TopicCard(stat: stats[r])),
                const SizedBox(width: 12),
                Expanded(child: r + 1 < stats.length ? _TopicCard(stat: stats[r + 1]) : const SizedBox()),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 8),
        SectionHeader(
          'Em alta agora',
          action: 'Ver ranking',
          onAction: () => _openRanking(trending),
        ),
        const SizedBox(height: 4),
        RCard(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              for (var i = 0; i < trending.length; i++) ...[
                _TrendingRow(rank: i + 1, item: trending[i]),
                if (i < trending.length - 1) const HairlineDivider(indent: 36),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        const SectionHeader('Pessoas em destaque'),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final p in data.people)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Pressable(
                    onTap: () => Routes.openSearch(p.fullName),
                    semanticLabel: p.fullName,
                    child: ExcludeSemantics(
                      child: Column(
                        children: [
                          InitialsAvatar(p.initials, size: 56, color: p.color),
                          const SizedBox(height: 6),
                          Text(p.shortName, style: RText.caption1.withColor(RColors.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SearchFieldButton extends StatelessWidget {
  const _SearchFieldButton();

  @override
  Widget build(BuildContext context) {
    return Pressable(
      pressedScale: 0.99,
      semanticLabel: 'Buscar empresas, pessoas e tópicos',
      onTap: Routes.openSearch,
      child: ExcludeSemantics(
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: RColors.bgCard, borderRadius: BorderRadius.circular(RRadius.field)),
          child: Row(
            children: [
              const Icon(Icons.search, color: RColors.textSecondary, size: 20),
              const SizedBox(width: 8),
              Text('Empresas, pessoas e tópicos', style: RText.body.withColor(RColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({required this.stat});
  final TopicStat stat;

  @override
  Widget build(BuildContext context) {
    final c = stat.category;
    return Pressable(
      pressedScale: 0.97,
      onTap: () => Routes.openTopic(c),
      semanticLabel: '${c.label}, ${stat.today} hoje, ${stat.delta}',
      child: ExcludeSemantics(
        child: RCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconTile(icon: c.icon, color: c.color, size: 36),
                  const Spacer(),
                  Text(stat.delta, style: RText.caption1Emph.withColor(c.color)),
                ],
              ),
              const SizedBox(height: 22),
              Text(c.label, style: RText.headline),
              const SizedBox(height: 2),
              Text('${stat.today} hoje', style: RText.footnote.withColor(RColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendingRow extends StatelessWidget {
  const _TrendingRow({required this.rank, required this.item});
  final int rank;
  final TrendingItem item;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Pressable(
        pressedScale: 0.99,
        onTap: () => Routes.openArticle(item.articleId, source: 'feed'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '$rank',
                  style: RText.title2.withColor(rank == 1 ? RColors.radar : RColors.textTertiary),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: RText.subheadlineEmph, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(item.readers, style: RText.caption1.withColor(RColors.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: RColors.textTertiary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
