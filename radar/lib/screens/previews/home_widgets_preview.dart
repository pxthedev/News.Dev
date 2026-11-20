import 'package:material_ui/material_ui.dart';

import '../../routes.dart';
import '../../theme/tokens.dart';
import '../../widgets/primitives.dart';
import 'preview_common.dart';

/// 16 · Widgets da tela inicial (pequeno, médio e grande).
/// Prévia em Flutter. Os widgets reais são feitos em WidgetKit (Swift).
class HomeWidgetsPreview extends StatelessWidget {
  const HomeWidgetsPreview({super.key});

  @override
  Widget build(BuildContext context) {
    const dark = RColors.onRadar;
    const lines = [
      (RColors.urgent, '9:52', 'Ataque hacker atinge banco digital', 'banco-ataque'),
      (RColors.radar, '9:37', 'Nvidia anuncia fábrica na Ásia', 'nvidia-fabrica'),
      (RColors.textTertiary, '9:10', 'Rust chega ao kernel do Windows', 'rust-windows'),
    ];

    return PreviewScaffold(
      showClock: false,
      label: '16 · Widgets',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          // Médio
          _WidgetFrame(
            color: RColors.bgCard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const AppIcon(size: 16),
                    const SizedBox(width: 6),
                    Text('news.dev', style: RText.subheadlineEmph.withColor(RColors.radar)),
                    const Spacer(),
                    Text('14 furos hoje', style: RText.caption1.withColor(RColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 10),
                for (final l in lines)
                  GestureDetector(
                    onTap: () => Routes.openArticle(l.$4, source: 'widget'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 3,
                            height: 18,
                            decoration: BoxDecoration(color: l.$1, borderRadius: BorderRadius.circular(2)),
                          ),
                          const SizedBox(width: 8),
                          Text(l.$2, style: RText.caption1.withColor(RColors.textSecondary)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(l.$3, style: RText.subheadlineEmph, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          // Pequeno + ícones
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: GestureDetector(
                    onTap: () => Routes.openArticle('nvidia-fabrica', source: 'widget'),
                    child: _WidgetFrame(
                      color: RColors.radar,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const AppIcon(size: 18),
                              const Spacer(),
                              Text('há 4 min', style: RText.caption1Emph.withColor(dark)),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            'Nvidia anuncia fábrica de US\$ 12 bi',
                            style: RText.headline.withColor(dark),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: GridView.count(
                    crossAxisCount: 2,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.78,
                    children: const [
                      _FakeApp(label: 'news.dev', radar: true),
                      _FakeApp(label: 'Notas', color: Color(0xFF6B5A16)),
                      _FakeApp(label: 'Música', color: Color(0xFF7A2E22)),
                      _FakeApp(label: 'Fotos', color: Color(0xFF16466E)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Grande
          _WidgetFrame(
            color: RColors.bgCard,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => Routes.openArticle('nvidia-fabrica', source: 'widget'),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(colors: [RColors.radar, Color(0xFFA9D12A)]),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PRIMEIRO NO BRASIL · 4 MIN', style: RText.caption2.withColor(dark)),
                        const SizedBox(height: 4),
                        Text('Jensen Huang confirma nova fábrica da Nvidia na Ásia', style: RText.headline.withColor(dark)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const _WidgetItem(kicker: 'SEGURANÇA', title: 'Ataque hacker expõe dados de banco', id: 'banco-ataque'),
                const SizedBox(height: 12),
                const _WidgetItem(kicker: 'STARTUPS', title: 'Startup paulista capta R\$ 80 mi', id: 'startup-paulista'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WidgetFrame extends StatelessWidget {
  const _WidgetFrame({required this.child, required this.color, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final Color color;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(RRadius.card)),
        child: child,
      );
}

class _WidgetItem extends StatelessWidget {
  const _WidgetItem({required this.kicker, required this.title, required this.id});
  final String kicker;
  final String title;
  final String id;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => Routes.openArticle(id, source: 'widget'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(kicker, style: RText.caption2.withColor(RColors.textSecondary)),
            const SizedBox(height: 2),
            Text(title, style: RText.subheadlineEmph),
          ],
        ),
      );
}

class _FakeApp extends StatelessWidget {
  const _FakeApp({required this.label, this.color = RColors.bgElevated, this.radar = false});
  final String label;
  final Color color;
  final bool radar;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Column(
          children: [
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: radar
                    ? const FittedBox(child: AppIcon(size: 60))
                    : Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14))),
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: RText.caption1, maxLines: 1),
          ],
        ),
      );
}
