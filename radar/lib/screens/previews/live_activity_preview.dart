import 'package:material_ui/material_ui.dart';

import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../../routes.dart';
import '../../theme/tokens.dart';
import '../../utils/format.dart';
import '../../widgets/charts.dart';
import '../../widgets/primitives.dart';
import 'preview_common.dart';

/// 14 · Live Activity (keynotes e eventos ao vivo).
/// Prévia em Flutter. A versão real é feita em ActivityKit (Swift).
class LiveActivityPreview extends StatelessWidget {
  const LiveActivityPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final event = buildMockLiveEvent();
    return PreviewScaffold(
      label: '14 · Live Activity',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            const Spacer(),
            GestureDetector(
              onTap: () => Routes.openArticle('nvidia-fabrica', source: 'live'),
              child: LiveActivityCard(event: event, elapsedLabel: '23 min', progress: 0.52),
            ),
            const SizedBox(height: 8),
            for (final u in event.updates) ...[
              GlassBox(
                radius: 16,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                child: Row(
                  children: [
                    Text(hhmm(u.at), style: RText.caption1Emph.withColor(RColors.radar)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(u.text, style: RText.footnote, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}

class LiveActivityCard extends StatelessWidget {
  const LiveActivityCard({super.key, required this.event, required this.elapsedLabel, required this.progress});
  final LiveEvent event;
  final String elapsedLabel;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xE6101010),
        borderRadius: BorderRadius.circular(RRadius.cardLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIcon(size: 22),
              const SizedBox(width: 8),
              Expanded(child: Text('Ao vivo · ${event.title}', style: RText.footnoteEmph)),
              LivePill(elapsedLabel),
            ],
          ),
          const SizedBox(height: 10),
          Text(event.headline, style: RText.title3),
          const SizedBox(height: 4),
          Text(
            '${plural(event.updates.length + 1, 'anúncio', 'anúncios')} até agora · tradução em tempo real',
            style: RText.footnote.withColor(RColors.textSecondary),
          ),
          const SizedBox(height: 14),
          LinearBar(value: progress, height: 5, track: Colors.white.withValues(alpha: 0.15)),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('Início ${hhmm(event.startsAt)}', style: RText.caption1.withColor(RColors.textSecondary)),
              const Spacer(),
              Text('Fim ~${hhmm(event.endsAt)}', style: RText.caption1.withColor(RColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}
