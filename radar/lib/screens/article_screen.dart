import 'dart:math' as math;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../data/repository.dart';
import '../services/platform_services.dart';
import '../sheets/community_sheet.dart';
import '../sheets/rating_dialog.dart';
import '../sheets/share_sheet.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../utils/format.dart';
import '../widgets/primitives.dart';
import '../widgets/system.dart';

/// 06 · Matéria
class ArticleScreen extends StatefulWidget {
  const ArticleScreen({super.key, required this.articleId});
  final String articleId;

  @override
  State<ArticleScreen> createState() => _ArticleScreenState();
}

class _ArticleScreenState extends State<ArticleScreen> {
  final _scroll = ScrollController();
  bool _reachedEnd = false;
  bool _showFullArticle = false;
  Article? _article;
  bool _fetching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    AppScope.read(context).registerArticleOpened();
    _scroll.addListener(_onScroll);
    _article = Repo.instance.byId(widget.articleId);
    if (_article == null) _fetch();
  }

  /// Abriu por deep link, push ou widget: a matéria ainda não está em memória.
  Future<void> _fetch() async {
    setState(() {
      _fetching = true;
      _error = null;
    });
    try {
      final a = await Repo.instance.article(widget.articleId);
      if (mounted) setState(() => _article = a);
    } on RepoException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Momento positivo: terminou de ler. Pede avaliação ou mostra o teaser da comunidade.
  void _onScroll() {
    if (!_showFullArticle) return;
    final pos = _scroll.position;
    if (pos.maxScrollExtent > 0 && _article != null) {
      AppScope.read(context)
          .setReadProgress(_article!.id, pos.pixels / pos.maxScrollExtent);
    }
    if (_reachedEnd || pos.extentAfter > 40) return;
    _reachedEnd = true;
    Repo.instance.recordRead(widget.articleId).catchError((Object _) {});
    final state = AppScope.read(context);
    if (state.shouldAskRating) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) showRatingDialog(context);
      });
    } else if (state.articlesOpened >= 5 && state.canShowCommunityTeaser) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) showCommunitySheet(context);
      });
    }
  }

  void _toggleSave(Article a) {
    final state = AppScope.read(context);
    final saved = state.toggleSave(a.id);
    if (saved) {
      state.showToast('Salvo pra ler depois',
          actionLabel: 'Desfazer', onAction: () => state.toggleSave(a.id));
    } else {
      state.showToast('Removido dos salvos',
          actionLabel: 'Desfazer', onAction: () => state.toggleSave(a.id));
    }
  }

  Future<void> _openReadingLink(Uri url) async {
    try {
      if (await PlatformServices.instance.openUrl(url.toString())) return;
    } on Exception {
      // O navegador do dispositivo pode estar indisponível.
    }
    if (mounted) {
      AppScope.read(context).showToast('Não foi possível abrir a página.');
    }
  }

  Future<void> _chooseTranslation(Uri source) async {
    final language = await showRSheet<String>(
      context,
      builder: (sheet) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Traduzir notícia', style: RText.title2),
          const SizedBox(height: 8),
          Text(
              'Escolha o idioma para abrir a publicação traduzida pelo Google.',
              style: RText.subheadline.withColor(RColors.textSecondary)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (code, label) in const [
                ('pt', 'Português'),
                ('en', 'Inglês'),
                ('es', 'Espanhol'),
                ('fr', 'Francês'),
                ('de', 'Alemão'),
                ('it', 'Italiano'),
                ('ja', 'Japonês'),
                ('ko', 'Coreano'),
                ('zh-CN', 'Chinês (simplificado)'),
                ('ar', 'Árabe'),
                ('hi', 'Hindi'),
                ('ru', 'Russo'),
              ])
                RChip(label, onTap: () => Navigator.of(sheet).pop(code)),
            ],
          ),
        ],
      ),
    );
    if (!mounted || language == null) return;
    await _openReadingLink(Uri.https('translate.google.com', '/translate', {
      'sl': 'auto',
      'tl': language,
      'u': source.toString(),
    }));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final article = _article;
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;

    if (article == null && _fetching) {
      return const Scaffold(body: Center(child: CupertinoActivityIndicator()));
    }
    if (article == null) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: CircleButton(
                    icon: Icons.chevron_left,
                    label: 'Voltar',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: _error != null
                      ? EmptyState(
                          icon: Icons.wifi_off,
                          title: _error!,
                          message: 'Confira a conexão e tente de novo.',
                          actionLabel: 'Tentar de novo',
                          onAction: _fetch,
                        )
                      : const EmptyState(
                          icon: Icons.article_outlined,
                          title: 'Essa matéria saiu do ar',
                          message:
                              'Volte pro feed pra ver as últimas notícias.',
                        ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final saved = state.isSaved(article.id);
    final paragraphs = article.body
        .split(RegExp(r'\r?\n\s*\r?\n'))
        .map((paragraph) => paragraph.trim())
        .where((paragraph) => paragraph.isNotEmpty)
        .toList();
    final synopsis = _synopsis(article.summary, paragraphs);
    final publisher = article.id.startsWith('rss-') &&
            article.confirmed &&
            article.sources.length == 1 &&
            paragraphs.isEmpty
        ? article.sources.single
        : null;
    final sourceUrl = article.sources
        .map((source) => Uri.tryParse(source.url))
        .whereType<Uri>()
        .where((url) =>
            (url.scheme == 'http' || url.scheme == 'https') &&
            url.host.isNotEmpty &&
            url.userInfo.isEmpty)
        .firstOrNull;
    final gutter = math.max(
      RSpace.screen,
      (MediaQuery.sizeOf(context).width - 744) / 2,
    );

    return Scaffold(
      body: CustomScrollView(
        controller: _scroll,
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: SizedBox(height: top + 2)),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: gutter),
            sliver: SliverList.list(
              children: [
                Row(
                  children: [
                    Transform.translate(
                      offset: const Offset(-2, 0),
                      child: CircleButton(
                        icon: Icons.chevron_left,
                        label: 'Voltar',
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const Spacer(),
                    CircleButton(
                      icon: saved ? Icons.bookmark : Icons.bookmark_border,
                      iconColor: saved ? RColors.radar : RColors.textPrimary,
                      label: saved ? 'Remover dos salvos' : 'Salvar',
                      onTap: () => _toggleSave(article),
                    ),
                    CircleButton(
                      icon: Icons.ios_share,
                      label: 'Compartilhar',
                      onTap: () => showShareSheet(context, article),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _HeroImage(article: article),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: RColors.bgElevated,
                        borderRadius: BorderRadius.circular(RRadius.pill),
                      ),
                      child:
                          Text(article.kickerLabel, style: RText.caption1Emph),
                    ),
                    if (article.firstInBrazil) const FirstBadge(),
                  ],
                ),
                const SizedBox(height: 12),
                Semantics(
                    header: true,
                    child: Text(article.title, style: RText.title1)),
                const SizedBox(height: 12),
                if (publisher != null)
                  _MetaLine(
                    icon: Icons.article_outlined,
                    color: RColors.radar,
                    text: 'Publicado por ${publisher.name}',
                  )
                else if (article.confirmed)
                  _MetaLine(
                    icon: Icons.check_circle,
                    color: RColors.radar,
                    text:
                        'Confirmado por ${article.sourceCount} fontes · detectado às ${hhmm(article.detectedAt)}',
                  )
                else
                  _MetaLine(
                    icon: Icons.warning_amber_rounded,
                    color: RColors.orange,
                    text:
                        'Rumor não confirmado · só ${plural(article.sourceCount, 'fonte', 'fontes')} até agora',
                  ),
                if (article.firstInBrazil && article.leadMinutes != null) ...[
                  const SizedBox(height: 6),
                  _MetaLine(
                    icon: Icons.bolt,
                    color: RColors.radar,
                    text:
                        'Você soube ${article.leadMinutes} min antes da imprensa BR',
                    emphasize: true,
                  ),
                ],
                if (synopsis.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _SynopsisCard(text: synopsis),
                ],
                if (paragraphs.isNotEmpty || sourceUrl != null) ...[
                  const SizedBox(height: 16),
                  RButton(
                    _showFullArticle
                        ? 'Recolher matéria'
                        : 'Ler matéria completa',
                    icon: paragraphs.isEmpty
                        ? Icons.open_in_new
                        : _showFullArticle
                            ? Icons.expand_less
                            : Icons.expand_more,
                    onPressed: paragraphs.isNotEmpty
                        ? () =>
                            setState(() => _showFullArticle = !_showFullArticle)
                        : () => _openReadingLink(sourceUrl!),
                  ),
                ],
                if (sourceUrl != null) ...[
                  const SizedBox(height: 8),
                  RButton(
                    'Traduzir notícia',
                    icon: Icons.translate,
                    kind: RButtonKind.secondary,
                    onPressed: () => _chooseTranslation(sourceUrl),
                  ),
                ],
                if (_showFullArticle && paragraphs.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Semantics(
                    header: true,
                    child: Text('Matéria completa', style: RText.title3),
                  ),
                  const SizedBox(height: 12),
                  for (final paragraph in paragraphs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Text(paragraph,
                          style: RText.body.withColor(RColors.textSecondary)),
                    ),
                ],
                if (publisher == null && article.sources.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Fontes', style: RText.headline),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in article.sources)
                        RChip(s.name,
                            onTap: () =>
                                PlatformServices.instance.openUrl(s.url)),
                      if (article.sourceCount > article.sources.length)
                        RChip(
                            '+${article.sourceCount - article.sources.length}'),
                    ],
                  ),
                ],
                SizedBox(height: 32 + bottom),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _synopsis(List<String> summary, List<String> paragraphs) {
  final points = summary
      .map((point) => point.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((point) => point.isNotEmpty)
      .toSet();
  if (points.isNotEmpty) {
    return points.map((point) {
      return RegExp(r'[.!?…]["”’)]*$').hasMatch(point) ? point : '$point.';
    }).join(' ');
  }
  if (paragraphs.isEmpty) return '';
  final words = paragraphs.first.split(RegExp(r'\s+'));
  if (words.length <= 48) return words.join(' ');
  return '${words.take(48).join(' ')}…';
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.article});
  final Article article;

  @override
  Widget build(BuildContext context) {
    final c = article.category;
    return Semantics(
      image: true,
      label: 'Ilustração de ${c.label}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(RRadius.hero),
        child: SizedBox(
          height: 190,
          width: double.infinity,
          child: article.imageUrl != null
              ? Image.network(article.imageUrl!, fit: BoxFit.cover)
              : DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.alphaBlend(
                            c.color.withValues(alpha: 0.28), c.deep),
                        RColors.bgBase
                      ],
                    ),
                  ),
                  child: Center(child: Icon(c.icon, size: 72, color: c.color)),
                ),
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine(
      {required this.icon,
      required this.color,
      required this.text,
      this.emphasize = false});
  final IconData icon;
  final Color color;
  final String text;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 16, color: color)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: emphasize
                ? RText.footnoteEmph.withColor(color)
                : RText.footnote.withColor(RColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _SynopsisCard extends StatelessWidget {
  const _SynopsisCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.subject, size: 20, color: RColors.radar),
              const SizedBox(width: 8),
              Semantics(
                header: true,
                child: Text('Sinopse', style: RText.headline),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(text, style: RText.body.copyWith(height: 1.5)),
        ],
      ),
    );
  }
}
