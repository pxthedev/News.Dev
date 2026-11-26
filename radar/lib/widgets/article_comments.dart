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
  final _replyDraft = TextEditingController();
  final _comments = <ArticleComment>[];
  final _replies = <String, List<ArticleComment>>{};
  final _replyCursors = <String, String?>{};
  final _expanded = <String>{};
  String? _replyTo;
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
    _replyDraft.dispose();
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

  Future<void> _publish({ArticleComment? parent}) async {
    final draft = parent == null ? _draft : _replyDraft;
    final body = draft.text.trim();
    if (body.isEmpty || body.length > 1000) return;
    await _run(() async {
      final comment = await AppScope.read(context)
          .repo
          .postArticleComment(widget.articleId, body, parentId: parent?.id);
      if (!mounted) return;
      draft.clear();
      FocusScope.of(context).unfocus();
      if (parent == null) {
        _comments.insert(0, comment);
      } else {
        _replies[parent.id]!.insert(0, comment);
        _replace(_comments, parent.copyWith(replyCount: parent.replyCount + 1));
        _replyTo = null;
      }
    }, 'Não foi possível publicar o comentário.');
  }

  void _replace(List<ArticleComment> list, ArticleComment comment) {
    final index = list.indexWhere((item) => item.id == comment.id);
    if (index >= 0) list[index] = comment;
  }

  Future<void> _loadReplies(ArticleComment parent, {bool compose = false}) =>
      _run(() async {
        if (!_replies.containsKey(parent.id) ||
            (!compose && _expanded.contains(parent.id))) {
          final page = await AppScope.read(context).repo.articleComments(
              widget.articleId,
              parentId: parent.id,
              before: _replyCursors[parent.id]);
          if (!mounted) return;
          (_replies[parent.id] ??= []).addAll(page.items);
          _replyCursors[parent.id] = page.nextCursor;
        }
        _expanded.add(parent.id);
        if (compose && _replyTo != parent.id) {
          _replyDraft.clear();
          _replyTo = parent.id;
        }
      }, 'Não foi possível carregar as respostas.');

  Future<void> _like(ArticleComment comment, ArticleComment? parent) =>
      _run(() async {
        final liked = !comment.liked;
        final count = await AppScope.read(context)
            .repo
            .setArticleCommentLike(widget.articleId, comment.id, liked);
        if (!mounted) return;
        _replace(parent == null ? _comments : _replies[parent.id]!,
            comment.copyWith(likeCount: count, liked: liked));
      }, 'Não foi possível atualizar a curtida.');

  Future<void> _delete(ArticleComment comment, {ArticleComment? parent}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(context.tr('Excluir comentário?')),
        content: comment.replyCount > 0
            ? Text(context.tr('As respostas também serão excluídas.'))
            : null,
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
      if (!mounted) return;
      if (parent == null) {
        _comments.remove(comment);
        _replies.remove(comment.id);
        _replyCursors.remove(comment.id);
        _expanded.remove(comment.id);
        if (_replyTo == comment.id) {
          _replyTo = null;
          _replyDraft.clear();
        }
      } else {
        _replies[parent.id]?.remove(comment);
        _replace(_comments, parent.copyWith(replyCount: parent.replyCount - 1));
      }
    }, 'Não foi possível excluir o comentário.');
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
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
        for (final comment in _comments) _card(context, comment),
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

  Widget _card(BuildContext context, ArticleComment comment,
      {ArticleComment? parent}) {
    final account = AppScope.of(context).isAccount;
    final expanded = _expanded.contains(comment.id);
    return Padding(
      key: ValueKey(comment.id),
      padding: EdgeInsets.only(top: 12, left: parent == null ? 0 : 16),
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
                          MaterialLocalizations.of(context)
                              .formatMediumDate(comment.createdAt),
                          style:
                              RText.caption1.withColor(RColors.textSecondary)),
                    ],
                  ),
                ),
                if (comment.mine && account)
                  CircleButton(
                    icon: Icons.delete_outline,
                    label: 'Excluir comentário',
                    onTap: () {
                      if (!_busy) _delete(comment, parent: parent);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(comment.body, style: RText.body),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              children: [
                TextButton.icon(
                  onPressed:
                      account && !_busy ? () => _like(comment, parent) : null,
                  icon: Icon(
                      comment.liked ? Icons.favorite : Icons.favorite_border,
                      size: 18),
                  label: Text(
                      '${context.tr(comment.liked ? 'Descurtir' : 'Curtir')} · ${comment.likeCount}'),
                ),
                if (parent == null && account)
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _loadReplies(comment, compose: true),
                    child: Text(context.tr('Responder')),
                  ),
                if (parent == null && (comment.replyCount > 0 || expanded))
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () {
                            if (expanded) {
                              setState(() {
                                _expanded.remove(comment.id);
                                if (_replyTo == comment.id) _replyTo = null;
                              });
                            } else {
                              _loadReplies(comment);
                            }
                          },
                    child: Text(expanded
                        ? context.tr('Ocultar respostas')
                        : context.tr(
                            'Ver respostas ({n})', {'n': comment.replyCount})),
                  ),
              ],
            ),
            if (parent == null && expanded) ...[
              if (_replyTo == comment.id) ...[
                TextField(
                  controller: _replyDraft,
                  maxLength: 1000,
                  minLines: 1,
                  maxLines: 5,
                  enabled: !_busy,
                  decoration:
                      InputDecoration(labelText: context.tr('Sua resposta')),
                ),
                ListenableBuilder(
                  listenable: _replyDraft,
                  builder: (context, _) => RButton(
                    'Publicar resposta',
                    onPressed: _busy || _replyDraft.text.trim().isEmpty
                        ? null
                        : () => _publish(parent: comment),
                  ),
                ),
              ],
              for (final reply
                  in _replies[comment.id] ?? const <ArticleComment>[])
                _card(context, reply, parent: comment),
              if (_replyCursors[comment.id] != null)
                TextButton(
                  onPressed: _busy ? null : () => _loadReplies(comment),
                  child: Text(context.tr('Ver mais respostas')),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
