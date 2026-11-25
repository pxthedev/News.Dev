import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../l10n/app_copy.dart';
import '../services/platform_services.dart';
import '../sheets/community_sheet.dart';
import '../sheets/rating_dialog.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';

class FullArticleScreen extends StatefulWidget {
  const FullArticleScreen({
    super.key,
    required this.articleId,
    required this.title,
    required this.paragraphs,
    this.openSource,
    this.translated = false,
  });

  final String articleId;
  final String title;
  final List<String> paragraphs;
  final Source? openSource;
  final bool translated;

  @override
  State<FullArticleScreen> createState() => _FullArticleScreenState();
}

class _FullArticleScreenState extends State<FullArticleScreen> {
  final _scroll = ScrollController();
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_trackReading);
    WidgetsBinding.instance.addPostFrameCallback((_) => _trackReading());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _trackReading() {
    if (!mounted || !_scroll.hasClients) return;
    final position = _scroll.position;
    final extent = position.maxScrollExtent;
    final progress =
        extent <= 0 ? 1.0 : (position.pixels / extent).clamp(0.0, 1.0);
    final state = AppScope.read(context);
    final id = widget.articleId;
    if (progress > (state.readProgress[id] ?? 0)) {
      state.setReadProgress(id, progress);
    }
    if (_finished || position.extentAfter > 40) return;
    _finished = true;
    state.repo.recordRead(id).catchError((Object _) {});
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      if (state.shouldAskRating) {
        showRatingDialog(context);
      } else if (state.articlesOpened >= 5 && state.canShowCommunityTeaser) {
        showCommunitySheet(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final gutter =
        math.max(RSpace.screen, (MediaQuery.sizeOf(context).width - 704) / 2);
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Matéria completa'))),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          controller: _scroll,
          padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 40),
          child: SelectionArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(widget.title, style: RText.largeTitle),
                ),
                const SizedBox(height: 24),
                for (final paragraph in widget.paragraphs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(paragraph,
                        style: RText.body.copyWith(height: 1.65)),
                  ),
                if (widget.openSource case final source?)
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () =>
                            PlatformServices.instance.openUrl(source.url),
                        child: Text(source.name),
                      ),
                      TextButton(
                        onPressed: () => PlatformServices.instance.openUrl(
                            'https://creativecommons.org/licenses/by-sa/4.0/'),
                        child: const Text('CC BY-SA 4.0'),
                      ),
                      Text(
                          context.tr(widget.translated
                              ? 'Texto adaptado e traduzido.'
                              : 'Texto adaptado para leitura.'),
                          style: RText.caption1),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
