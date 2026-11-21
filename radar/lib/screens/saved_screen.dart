import '../widgets/news.dart';

import '../l10n/app_copy.dart';
import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../data/repository.dart';
import '../routes.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/charts.dart';
import '../widgets/primitives.dart';

/// 10 · Salvos
class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  bool _showRead = false;
  final Set<String> _requested = {};

  /// Salvos vindos do servidor (ou de outro aparelho) podem não estar em memória ainda.
  void _fetchMissing(List<String> ids) {
    final missing = ids
        .where(
            (id) => Repo.instance.byId(id) == null && !_requested.contains(id))
        .toList();
    if (missing.isEmpty) return;
    _requested.addAll(missing);
    Repo.instance.articles(missing).then((_) {
      if (mounted) setState(() {});
    }, onError: (Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final top = MediaQuery.paddingOf(context).top;
    _fetchMissing(state.savedIds);
    final all =
        state.savedIds.map(Repo.instance.byId).whereType<Article>().toList();
    final archived = state.archivedIds;
    final list = all
        .where((article) => archived.contains(article.id) == _showRead)
        .toList();
    final readMin =
        list.fold<int>(0, (sum, article) => sum + article.readingMinutes);

    return ListView(
      padding:
          EdgeInsets.fromLTRB(20, top + 8, 20, RSize.tabClearance(context)),
      children: [
        Semantics(
            header: true,
            child: Text(context.tr('Salvos'), style: RText.largeTitle)),
        const SizedBox(height: 14),
        Row(
          children: [
            RChip('Ler depois',
                active: !_showRead,
                onTap: () => setState(() => _showRead = false)),
            const SizedBox(width: 8),
            RChip('Lidos',
                active: _showRead,
                onTap: () => setState(() => _showRead = true)),
          ],
        ),
        const SizedBox(height: 16),
        if (list.isEmpty)
          EmptyState(
            icon: _showRead ? Icons.done_all : Icons.bookmark_border,
            title: _showRead
                ? 'O que você terminar de ler fica aqui'
                : 'Salve matérias pra ler depois',
            message: _showRead
                ? 'Arraste uma matéria salva pro lado pra marcar como lida.'
                : 'Toque no marcador de qualquer matéria. Ela fica disponível mesmo sem internet.',
          )
        else ...[
          if (!_showRead) ...[
            _SummaryCard(
              count: list.length,
              readMin: readMin,
            ),
            const SizedBox(height: 16),
          ],
          for (final a in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _showRead
                  ? _SavedCard(article: a, progress: 1)
                  : Dismissible(
                      key: ValueKey('saved-${a.id}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        decoration: BoxDecoration(
                          color: RColors.bgElevated,
                          borderRadius: BorderRadius.circular(RRadius.card),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.archive_outlined,
                                color: RColors.radar),
                            const SizedBox(width: 6),
                            Text(context.tr('Arquivar'),
                                style: const TextStyle(
                                    color: RColors.radar,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      onDismissed: (_) {
                        state.archive(a.id);
                        state.showToast('Movida pra lidos',
                            actionLabel: 'Desfazer',
                            onAction: () => state.unarchive(a.id));
                      },
                      child: _SavedCard(
                          article: a, progress: state.readProgress[a.id] ?? 0),
                    ),
            ),
        ],
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.count, required this.readMin});
  final int count;
  final int readMin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(RRadius.card),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
                RColors.radar.withValues(alpha: 0.2), RColors.bgCard),
            RColors.bgCard
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              context.tr(
                  count == 1 ? '{n} matéria' : '{n} matérias', {'n': count}),
              style: RText.title2),
          const SizedBox(height: 2),
          Text(
            context.tr('{n} min de leitura', {'n': readMin}),
            style: RText.footnote.withColor(RColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _SavedCard extends StatelessWidget {
  const _SavedCard({required this.article, required this.progress});
  final Article article;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final color = article.category.color;
    final remaining = progress >= 1
        ? context.tr('Lida')
        : (progress > 0
            ? context.tr(
                '{n} min restantes', {'n': article.remainingMinutes(progress)})
            : '${article.readingMinutes} min');
    return MergeSemantics(
      child: Pressable(
        pressedScale: 0.98,
        onTap: () => Routes.openArticle(article.id, source: 'feed'),
        child: RCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(article.kickerLabel.toUpperCase(),
                        style: RText.caption1Emph.withColor(color)),
                  ),
                  const Icon(Icons.bookmark,
                      color: RColors.radar, size: 18, semanticLabel: 'Salva'),
                ],
              ),
              const SizedBox(height: 8),
              NewsHeadline(article, style: RText.headline),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: LinearBar(value: progress, color: color)),
                  const SizedBox(width: 12),
                  Text(remaining,
                      style: RText.caption1.withColor(RColors.textSecondary)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
