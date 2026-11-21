import '../../l10n/app_copy.dart';
import 'package:material_ui/material_ui.dart';

import '../../routes.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../widgets/primitives.dart';
import 'preview_common.dart';

/// 15 · Dynamic Island: compacta, mínima e expandida (urgente e ao vivo).
/// Prévia em Flutter. A versão real é feita em ActivityKit (Swift).
class DynamicIslandPreview extends StatelessWidget {
  const DynamicIslandPreview({super.key});

  @override
  Widget build(BuildContext context) {
    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(top: 22, bottom: 10),
          child: Text(t, style: RText.footnote.withColor(RColors.textSecondary)),
        );

    return PreviewScaffold(
      showClock: false,
      label: '15 · Dynamic Island',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          Center(child: label('Compacta')),
          Center(
            child: Container(
              width: 250,
              height: 37,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(RRadius.pill)),
              child: Row(
                children: [
                  const AppIcon(size: 22),
                  const Spacer(),
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: RColors.urgent, shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text(context.tr('Ao vivo'), style: RText.footnoteEmph.withColor(RColors.urgent)),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
          Center(child: label('Mínima (com outra atividade)')),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 126,
                height: 37,
                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(RRadius.pill)),
              ),
              const SizedBox(width: 6),
              Container(
                width: 37,
                height: 37,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                child: const AppIcon(size: 22),
              ),
            ],
          ),
          Center(child: label('Expandida · notícia urgente')),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(44)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    AppIcon(size: 28),
                    Spacer(),
                    TintPill('Urgente', icon: Icons.notification_important_outlined, color: RColors.urgent),
                  ],
                ),
                const SizedBox(height: 10),
                Text('Ataque hacker atinge banco digital', style: RText.title3),
                const SizedBox(height: 4),
                Text(
                  '2 milhões de clientes afetados · 4 fontes confirmam',
                  style: RText.footnote.withColor(RColors.textSecondary),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: RButton(
                        'Ler agora',
                        height: 44,
                        onPressed: () => Routes.openArticle('banco-ataque', source: 'live'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RButton(
                        'Salvar',
                        height: 44,
                        kind: RButtonKind.secondary,
                        onPressed: () {
                          final state = AppScope.read(context);
                          if (!state.isSaved('banco-ataque')) state.toggleSave('banco-ataque');
                          state.showToast('Salvo pra ler depois');
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Center(child: label('Expandida · evento ao vivo')),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(44)),
            child: Row(
              children: [
                const AppIcon(size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Keynote Nvidia · 23 min', style: RText.caption1Emph.withColor(RColors.urgent)),
                      const SizedBox(height: 2),
                      Text('Huang revela a GPU Rubin Ultra', style: RText.headline),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
