import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../routes.dart';
import '../theme/tokens.dart';
import '../utils/format.dart';
import 'primitives.dart';

/// "SEGURANÇA · há 12 min" na cor da categoria.
class CategoryMeta extends StatelessWidget {
  const CategoryMeta({super.key, required this.article, this.showTime = true});
  final Article article;
  final bool showTime;

  @override
  Widget build(BuildContext context) {
    final label = article.kickerLabel.toUpperCase();
    final text = showTime ? '$label · ${relativeTime(article.publishedAt)}' : label;
    return Text(text, style: RText.caption1Emph.withColor(article.category.color), maxLines: 1);
  }
}

/// Miniatura: imagem real quando houver, senão gradiente da cor da categoria.
class Thumbnail extends StatelessWidget {
  const Thumbnail({
    super.key,
    required this.category,
    this.imageUrl,
    this.width = RSize.thumb,
    this.height = RSize.thumb,
    this.radius = RRadius.thumb,
    this.showIcon = false,
  });

  final NewsCategory category;
  final String? imageUrl;
  final double width;
  final double height;
  final double radius;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    final gradient = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [category.color, category.deep],
        ),
      ),
    );
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(
          width: width,
          height: height,
          child: imageUrl == null
              ? gradient
              : Image.network(imageUrl!, fit: BoxFit.cover, errorBuilder: (context, error, stack) => gradient),
        ),
      ),
    );
  }
}

/// Linha de notícia: categoria + tempo, título, fontes e miniatura 72×72.
class NewsRow extends StatelessWidget {
  const NewsRow({super.key, required this.article, this.showDivider = true, this.source = 'feed'});
  final Article article;
  final bool showDivider;
  final String source;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Pressable(
        pressedScale: 0.99,
        onTap: () => Routes.openArticle(article.id, source: source),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: showDivider ? const Border(bottom: BorderSide(color: RColors.separator, width: 0.5)) : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(child: CategoryMeta(article: article)),
                      if (!article.confirmed) ...[
                        const SizedBox(width: 6),
                        const TintPill('não confirmado', color: RColors.orange),
                      ],
                    ]),
                    const SizedBox(height: 4),
                    Text(article.title, style: RText.headline, maxLines: 3, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(article.sourcesLabel, style: RText.footnote.withColor(RColors.textSecondary), maxLines: 1),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Thumbnail(category: article.category, imageUrl: article.imageUrl),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton do feed com shimmer escuro (bg/card → bg/elevated).
class FeedSkeleton extends StatefulWidget {
  const FeedSkeleton({super.key, this.count = 4});
  final int count;

  @override
  State<FeedSkeleton> createState() => _FeedSkeletonState();
}

class _FeedSkeletonState extends State<FeedSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Carregando notícias',
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final color = Color.lerp(RColors.bgCard, RColors.bgElevated, _c.value)!;
          Widget box(double w, double h) => Container(
                width: w,
                height: h,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
              );
          return Column(
            children: [
              for (var i = 0; i < widget.count; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            box(110, 12),
                            const SizedBox(height: 8),
                            box(double.infinity, 16),
                            const SizedBox(height: 6),
                            box(180, 16),
                            const SizedBox(height: 8),
                            box(120, 12),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Container(
                        width: RSize.thumb,
                        height: RSize.thumb,
                        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(RRadius.thumb)),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
