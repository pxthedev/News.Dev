import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../data/repository.dart';
import '../l10n/app_copy.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import 'primitives.dart';

class ArticleComments extends StatefulWidget {
  const ArticleComments({super.key, required this.articleId});

  final String articleId;

  @override
  State<ArticleComments> createState() => _ArticleCommentsState();
}

class _ArticleCommentsState extends State<ArticleComments> {
  final _draft = TextEditingController();
  final _comments = <ArticleComment>[];
  String? _cursor;
  String? _error;
  bool _busy = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, String error) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on RepoException {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load() => _run(() async {
        final page = await AppScope.read(context)
            .repo
            .articleComments(widget.articleId, before: _cursor);
        if (!mounted) return;
        _comments.addAll(page.items);
        _cursor = page.nextCursor;
        _loaded = true;
      }, 'Não foi possível carregar os comentários.');

  Future<void> _publish() async {
    final body = _draft.text.trim();
    if (body.isEmpty || body.length > 1000) return;
    await _run(() async {
      final comment = await AppScope.read(context)
          .repo
          .postArticleComment(widget.articleId, body);
      if (!mounted) return;
      _draft.clear();
      FocusScope.of(context).unfocus();
      _comments.insert(0, comment);
    }, 'Não foi possível publicar o comentário.');
  }

  Future<void> _delete(ArticleComment comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(context.tr('Excluir comentário?')),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialog).pop(false),
              child: Text(context.tr('Cancelar'))),
          TextButton(
              onPressed: () => Navigator.of(dialog).pop(true),
              child: Text(context.tr('Excluir'))),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await _run(() async {
      await AppScope.read(context)
          .repo
          .deleteArticleComment(widget.articleId, comment.id);
      if (mounted) _comments.remove(comment);
    }, 'Não foi possível excluir o comentário.');
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final localizations = MaterialLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        Semantics(
          header: true,
          child: Text(context.tr('Comentários'), style: RText.title2),
        ),
        const SizedBox(height: 12),
        if (state.isAccount && _loaded)
          RCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _draft,
                  enabled: !_busy,
                  minLines: 2,
                  maxLines: 5,
                  maxLength: 1000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: context.tr('O que você achou da notícia?'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                ListenableBuilder(
                  listenable: _draft,
                  builder: (context, _) => RButton(
                    'Publicar comentário',
                    icon: Icons.send_outlined,
                    onPressed: _busy ||
                            _draft.text.trim().isEmpty ||
                            _draft.text.trim().length > 1000
                        ? null
                        : _publish,
                  ),
                ),
              ],
            ),
          )
        else if (!state.isAccount)
          Text(context.tr('Entre com uma conta para comentar.'),
              style: RText.callout.withColor(RColors.textSecondary)),
        if (_error case final error?) ...[
          const SizedBox(height: 12),
          Text(context.tr(error), style: RText.callout),
          if (!_loaded)
            RButton('Tentar de novo', kind: RButtonKind.text, onPressed: _load),
        ],
        if (_loaded && _comments.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(context.tr('Ainda não há comentários.'),
                style: RText.callout.withColor(RColors.textSecondary)),
          ),
        for (final comment in _comments)
          Padding(
            key: ValueKey(comment.id),
            padding: const EdgeInsets.only(top: 12),
            child: RCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                comment.author.isEmpty
                                    ? context.tr('Leitor')
                                    : comment.author,
                                style: RText.headline),
                            Text(
                                localizations
                                    .formatMediumDate(comment.createdAt),
                                style: RText.caption1
                                    .withColor(RColors.textSecondary)),
                          ],
                        ),
                      ),
                      if (comment.mine && state.isAccount)
                        CircleButton(
                          icon: Icons.delete_outline,
                          label: 'Excluir comentário',
                          onTap: () {
                            if (!_busy) _delete(comment);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(comment.body, style: RText.body),
                ],
              ),
            ),
          ),
        if (_cursor != null && !_busy)
          RButton('Ver mais comentários',
              kind: RButtonKind.text, onPressed: _load),
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }
}
