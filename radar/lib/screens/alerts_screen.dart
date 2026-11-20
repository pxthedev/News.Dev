import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../routes.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../utils/format.dart';
import '../widgets/primitives.dart';

/// 11 · Central de alertas
class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final now = DateTime.now();
    final today = state.alerts.where((a) => isSameDay(a.at, now)).toList();
    final earlier = state.alerts.where((a) => !isSameDay(a.at, now)).toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
          children: [
            Row(
              children: [
                Transform.translate(
                  offset: const Offset(-2, 0),
                  child: CircleButton(icon: Icons.chevron_left, label: 'Voltar', onTap: () => Navigator.of(context).pop()),
                ),
                const Spacer(),
                if (state.unreadAlerts > 0)
                  Pressable(
                    onTap: state.markAllAlertsRead,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text('Marcar como lidos', style: RText.subheadline.withColor(RColors.radar)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Semantics(header: true, child: Text('Alertas', style: RText.largeTitle)),
            const SizedBox(height: 16),
            if (state.alerts.isEmpty)
              const EmptyState(
                icon: Icons.notifications_none,
                title: 'Tudo em dia',
                message: 'Quando nossa IA confirmar um furo dos seus tópicos, ele aparece aqui.',
              ),
            if (today.isNotEmpty) ...[
              const GroupLabel('HOJE'),
              _AlertGroup(alerts: today),
              const SizedBox(height: 22),
            ],
            if (earlier.isNotEmpty) ...[
              const GroupLabel('ONTEM'),
              _AlertGroup(alerts: earlier),
            ],
          ],
        ),
      ),
    );
  }
}

class _AlertGroup extends StatelessWidget {
  const _AlertGroup({required this.alerts});
  final List<AlertItem> alerts;

  @override
  Widget build(BuildContext context) {
    return RCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < alerts.length; i++) ...[
            _AlertRow(alert: alerts[i]),
            if (i < alerts.length - 1) const HairlineDivider(indent: 62),
          ],
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.alert});
  final AlertItem alert;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.read(context);
    final unread = alert.unread;
    return MergeSemantics(
      child: Pressable(
        pressedScale: 0.99,
        semanticLabel: unread ? 'Não lido' : null,
        onTap: () {
          state.markAlertRead(alert.id);
          final id = alert.articleId;
          if (id != null) Routes.openArticle(id, source: 'push');
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconTile(icon: alert.icon, color: alert.color, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.title,
                      style: unread ? RText.subheadlineEmph : RText.subheadline.withColor(RColors.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(alert.subtitle, style: RText.caption1.withColor(RColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(hhmm(alert.at), style: RText.caption1.withColor(RColors.textTertiary)),
                  const SizedBox(height: 10),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: unread ? 1 : 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: alert.color, shape: BoxShape.circle),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
