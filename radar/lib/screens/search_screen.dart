import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../data/repository.dart';
import '../routes.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../utils/format.dart';
import '../widgets/news.dart';
import '../widgets/primitives.dart';

/// 09 · Busca
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.initialQuery = ''});
  final String initialQuery;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final _controller = TextEditingController(text: widget.initialQuery);
  final _focus = FocusNode();
  int _scope = 0; // Tudo / Matérias / Tópicos / Pessoas
  Timer? _debounce;
  SearchResult _result = SearchResult.empty;
  String _resultFor = '';
  bool _searching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery.trim().isNotEmpty) _run();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _setQuery(String q) {
    _controller.text = q;
    _controller.selection = TextSelection.collapsed(offset: q.length);
    _onChanged();
  }

  void _onChanged() {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _run);
  }

  Future<void> _run() async {
    final q = _controller.text.trim();
    if (q.isEmpty) {
      setState(() {
        _result = SearchResult.empty;
        _resultFor = '';
        _error = null;
      });
      return;
    }
    setState(() => _searching = true);
    try {
      final r = await Repo.instance.search(q, showRumors: AppScope.read(context).showRumors);
      if (!mounted || _controller.text.trim() != q) return;
      setState(() {
        _result = r;
        _resultFor = q;
        _error = null;
      });
    } on RepoException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final q = _controller.text.trim();
    final hasQuery = q.isNotEmpty;
    final articles = hasQuery ? _result.articles : const <Article>[];
    final entity = hasQuery ? _result.entity : null;
    final topics = hasQuery ? Repo.instance.findTopics(q) : const <NewsCategory>[];
    final people = hasQuery ? _result.people : const <Person>[];
    final settled = !_searching && _resultFor == q;

    final showEntity = entity != null && (_scope == 0 || (_scope == 3 && entity.kind == 'Pessoa'));
    final showTopics = topics.isNotEmpty && (_scope == 0 || _scope == 2);
    final showPeople = people.isNotEmpty && (_scope == 0 || _scope == 3) && entity?.kind != 'Pessoa';
    final showArticles = _scope == 0 || _scope == 1;
    final nothing =
        settled && !showEntity && !showTopics && !showPeople && (!showArticles || articles.isEmpty);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  Expanded(child: _activeField(state)),
                  const SizedBox(width: 12),
                  Pressable(
                    onTap: () => Navigator.of(context).pop(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text('Cancelar', style: RText.body.withColor(RColors.radar)),
                    ),
                  ),
                ],
              ),
            ),
            if (hasQuery)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Row(
                  children: [
                    for (final (i, label) in const ['Tudo', 'Matérias', 'Tópicos', 'Pessoas'].indexed)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: RChip(label, active: _scope == i, onTap: () => setState(() => _scope = i)),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: ListView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                children: [
                  if (hasQuery) ...[
                    if (_error != null)
                      EmptyState(icon: Icons.wifi_off, title: _error!, message: 'Confira a conexão e tente de novo.')
                    else if (_searching && _resultFor != q)
                      const Padding(padding: EdgeInsets.all(24), child: CupertinoActivityIndicator()),
                    if (showEntity) ...[_EntityCard(entity: entity), const SizedBox(height: 20)],
                    if (showTopics) ...[
                      const SectionHeader('Tópicos'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final t in topics)
                            RChip(t.label, icon: t.icon, onTap: () => Routes.openTopic(t)),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (showPeople) ...[
                      const SectionHeader('Pessoas'),
                      const SizedBox(height: 8),
                      for (final p in people)
                        Pressable(
                          onTap: () => _setQuery(p.fullName),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                InitialsAvatar(p.initials, size: 40, color: p.color),
                                const SizedBox(width: 12),
                                Text(p.fullName, style: RText.headline),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                    ],
                    if (showArticles && articles.isNotEmpty) ...[
                      Row(
                        children: [
                          Expanded(child: Semantics(header: true, child: Text('Matérias', style: RText.title3))),
                          Text(
                            plural(articles.length, 'resultado', 'resultados'),
                            style: RText.footnote.withColor(RColors.textSecondary),
                          ),
                        ],
                      ),
                      for (var i = 0; i < articles.length; i++)
                        NewsRow(article: articles[i], showDivider: i < articles.length - 1),
                      const SizedBox(height: 24),
                    ],
                    if (nothing && _error == null)
                      EmptyState(
                        icon: Icons.search,
                        title: 'Nada encontrado pra “$q”',
                        message: 'Tente o nome de uma empresa, pessoa ou tópico.',
                      ),
                  ],
                  Row(
                    children: [
                      Expanded(child: Semantics(header: true, child: Text('Buscas recentes', style: RText.title3))),
                      if (state.recentSearches.isNotEmpty)
                        Pressable(
                          onTap: state.clearRecentSearches,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text('Limpar', style: RText.subheadline.withColor(RColors.textSecondary)),
                          ),
                        ),
                    ],
                  ),
                  if (state.recentSearches.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Suas buscas aparecem aqui.',
                        style: RText.subheadline.withColor(RColors.textTertiary),
                      ),
                    ),
                  for (final r in state.recentSearches)
                    Pressable(
                      pressedScale: 0.99,
                      onTap: () => _setQuery(r.text),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: RColors.separator, width: 0.5)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              r.trending ? Icons.trending_up : Icons.history,
                              size: 20,
                              color: r.trending ? RColors.radar : RColors.textSecondary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(r.text, style: RText.body)),
                            const Icon(Icons.north_east, size: 16, color: RColors.textTertiary),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _activeField(AppState state) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: RColors.bgCard,
        borderRadius: BorderRadius.circular(RRadius.field),
        border: Border.all(color: RColors.radar, width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: RColors.textSecondary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              autofocus: true,
              cursorColor: RColors.radar,
              style: RText.body,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration.collapsed(
                hintText: 'Empresas, pessoas e tópicos',
                hintStyle: RText.body.withColor(RColors.textSecondary),
              ),
              onChanged: (_) => _onChanged(),
              onSubmitted: state.addRecentSearch,
            ),
          ),
          if (_controller.text.isNotEmpty)
            Semantics(
              button: true,
              label: 'Limpar busca',
              child: GestureDetector(
                onTap: () => _setQuery(''),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.cancel, size: 18, color: RColors.textTertiary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EntityCard extends StatelessWidget {
  const _EntityCard({required this.entity});
  final EntityInfo entity;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final following = state.isFollowingEntity(entity.id);
    final scoops = entity.scoopsToday == 0
        ? 'nenhum furo hoje'
        : '${plural(entity.scoopsToday, 'furo', 'furos')} hoje';
    return RCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: entity.color, borderRadius: BorderRadius.circular(RRadius.sm)),
            child: Text(entity.name.substring(0, 1), style: RText.title3),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entity.name, style: RText.headline),
                Text(
                  '${entity.kind} · ${entity.articleCount} matérias · $scoops',
                  style: RText.footnote.withColor(RColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Pressable(
            onTap: () => state.toggleFollowEntity(entity.id),
            semanticLabel: following ? 'Deixar de seguir ${entity.name}' : 'Seguir ${entity.name}',
            child: SizedBox(
              width: RSize.minTap,
              height: RSize.minTap,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: following ? RColors.bgElevated : RColors.radar,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    following ? Icons.check : Icons.add,
                    color: following ? RColors.radar : RColors.onRadar,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
