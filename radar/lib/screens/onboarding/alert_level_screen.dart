import '../../l10n/app_copy.dart';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/models.dart';
import '../../services/analytics.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../widgets/primitives.dart';
import 'onboarding_common.dart';
import 'push_permission_screen.dart';

/// 03 · Intensidade de alertas
class AlertLevelScreen extends StatelessWidget {
  const AlertLevelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    const options = [
      (AlertLevel.urgent, 'Só urgentes', '1 a 2 por dia. Só o que não pode esperar.', Icons.notification_important_outlined, RColors.urgent),
      (AlertLevel.balanced, 'Equilibrado', 'Urgentes + resumos às 8h e às 19h.', Icons.bolt, RColors.radar),
      (AlertLevel.realtime, 'Tempo real', 'Tudo que nossa IA confirmar, na hora.', Icons.wifi_tethering, RColors.link),
    ];

    return OnboardingScaffold(
      progress: 0.66,
      progressFrom: 0.33,
      title: 'Quantos alertas você quer?',
      subtitle: 'Você controla o barulho. Dá pra mudar a qualquer momento.',
      bottom: RButton(
        'Continuar',
        onPressed: () {
          Analytics.log('alert_level_selected', {'level': state.alertLevel.name, 'quietHours': state.quietHours});
          Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => const PushPermissionScreen()));
        },
      ),
      children: [
        for (final o in options) ...[
          _LevelCard(
            title: o.$2,
            description: o.$3,
            icon: o.$4,
            color: o.$5,
            selected: state.alertLevel == o.$1,
            onTap: () => state.setAlertLevel(o.$1),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 8),
        Pressable(
          pressedScale: 0.99,
          onTap: () => state.setQuietHours(!state.quietHours),
          child: RCard(
            radius: 20,
            padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
            child: Row(
              children: [
                const Icon(Icons.schedule, color: RColors.textSecondary, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Silêncio das 23h às 7h, exceto urgentes.',
                    style: RText.footnote.withColor(RColors.textSecondary),
                  ),
                ),
                RToggle(
                  value: state.quietHours,
                  label: 'Silêncio das 23h às 7h',
                  onChanged: state.setQuietHours,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      child: Pressable(
        pressedScale: 0.98,
        haptic: true,
        selected: selected,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: RColors.bgCard,
            borderRadius: BorderRadius.circular(RRadius.cardLg),
            border: Border.all(color: selected ? RColors.radar : RColors.bgElevated, width: 2),
          ),
          child: Row(
            children: [
              IconTile(icon: icon, color: color, size: 44),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr(title), style: RText.headline),
                    const SizedBox(height: 2),
                    Text(context.tr(description), style: RText.footnote.withColor(RColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? RColors.radar : Colors.transparent,
                  border: Border.all(color: selected ? RColors.radar : RColors.bgControl, width: 2),
                ),
                child: selected ? const Icon(Icons.check, size: 15, color: RColors.onRadar) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
