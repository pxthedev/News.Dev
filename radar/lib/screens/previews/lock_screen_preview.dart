import 'package:material_ui/material_ui.dart';

import '../../routes.dart';
import '../../theme/tokens.dart';
import '../../widgets/charts.dart';
import '../../widgets/system.dart';
import '../../widgets/primitives.dart';
import 'preview_common.dart';

/// 13 · Tela bloqueada: widgets circular e retangular + notificações.
/// Prévia em Flutter. O widget real é feito em WidgetKit (Swift).
class LockScreenPreview extends StatelessWidget {
  const LockScreenPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return PreviewScaffold(
      label: '13 · Tela bloqueada',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ProgressRing(
                  progress: 0.72,
                  size: 66,
                  stroke: 5,
                  track: Colors.white.withValues(alpha: 0.15),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('14', style: RText.headline.copyWith(height: 1)),
                      Text('furos', style: RText.caption2.withColor(RColors.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => Routes.openArticle('nvidia-acoes', source: 'widget'),
                  child: SizedBox(
                    width: 168,
                    child: GlassBox(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const AppIcon(size: 14),
                              const SizedBox(width: 4),
                              Text('news.dev · 4 min', style: RText.caption2),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Nvidia sobe 4% após anúncio de fábrica',
                            style: RText.footnoteEmph,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            NotificationCard(
              title: 'Urgente · Ataque hacker atinge banco',
              body: 'Dados de 2 milhões de clientes expostos. Primeiro no Brasil, 41 min antes da imprensa.',
              onTap: () => Routes.openArticle('banco-ataque', source: 'push'),
            ),
            const SizedBox(height: 8),
            NotificationCard(
              title: 'Nvidia anuncia fábrica de US\$ 12 bi',
              body: 'Jensen Huang confirmou em Taipé. Toque pra ler o resumo.',
              time: '9:37',
              onTap: () => Routes.openArticle('nvidia-fabrica', source: 'push'),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: GlassBox(
                radius: 20,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: Text('+ 6 notificações do news.dev', style: RText.footnote.withColor(RColors.textSecondary)),
              ),
            ),
            const SizedBox(height: 28),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [_LockButton(Icons.flashlight_on_outlined), _LockButton(Icons.camera_alt_outlined)],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _LockButton extends StatelessWidget {
  const _LockButton(this.icon);
  final IconData icon;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Container(
          width: 50,
          height: 50,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(icon, size: 22),
        ),
      );
}
