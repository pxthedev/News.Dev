import 'package:material_ui/material_ui.dart';

import '../routes.dart';
import '../theme/tokens.dart';
import '../widgets/news.dart';
import '../widgets/primitives.dart';

/// Lista simples de matérias ("Ver tudo", "Ver ranking").
class ArticleListScreen extends StatelessWidget {
  const ArticleListScreen({super.key, required this.args});
  final ListArgs args;

  @override
  Widget build(BuildContext context) {
    final items = args.articles;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Transform.translate(
                offset: const Offset(-2, 0),
                child: CircleButton(icon: Icons.chevron_left, label: 'Voltar', onTap: () => Navigator.of(context).pop()),
              ),
            ),
            const SizedBox(height: 8),
            Semantics(header: true, child: Text(args.title, style: RText.largeTitle)),
            const SizedBox(height: 8),
            if (items.isEmpty)
              const EmptyState(icon: Icons.bolt, title: 'Nada por aqui ainda', message: 'Puxe o feed pra atualizar.')
            else
              for (var i = 0; i < items.length; i++) NewsRow(article: items[i], showDivider: i < items.length - 1),
          ],
        ),
      ),
    );
  }
}
