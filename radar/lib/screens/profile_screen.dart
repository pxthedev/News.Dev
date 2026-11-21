import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../routes.dart';
import '../l10n/app_copy.dart';
import '../sheets/community_sheet.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/charts.dart';
import '../widgets/primitives.dart';
import '../widgets/system.dart';
import '../widgets/sign_out_button.dart';
import 'onboarding/welcome_screen.dart';

/// 12 · Perfil e ajustes
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _more(BuildContext context, AppState state) {
    showRSheet<void>(
      context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(state.userName, style: RText.headline),
          const SizedBox(height: 16),
          RButton(
            'Refazer onboarding',
            kind: RButtonKind.secondary,
            onPressed: () {
              Navigator.of(ctx).pop();
              state.resetOnboarding();
              Navigator.of(context).pushAndRemoveUntil(
                CupertinoPageRoute<void>(builder: (_) => const WelcomeScreen()),
                (_) => false,
              );
            },
          ),
          const SizedBox(height: 8),
          RButton('Fechar',
              kind: RButtonKind.text, onPressed: () => Navigator.of(ctx).pop()),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final top = MediaQuery.paddingOf(context).top;

    return ListView(
      padding:
          EdgeInsets.fromLTRB(20, top + 8, 20, RSize.tabClearance(context)),
      children: [
        Row(
          children: [
            InitialsAvatar(state.initials, size: 60),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                      header: true,
                      child: Text(state.userName, style: RText.title3)),
                  const SizedBox(height: 2),
                  Text('Leitor desde ${state.readerSince}',
                      style: RText.footnote.withColor(RColors.textSecondary)),
                ],
              ),
            ),
            CircleButton(
                icon: Icons.more_horiz,
                label: 'Mais opções',
                onTap: () => _more(context, state)),
          ],
        ),
        const SizedBox(height: 18),
        _WeekCard(state: state),
        const SizedBox(height: 24),
        const GroupLabel('NOTIFICAÇÕES'),
        _SettingsGroup(
          children: [
            _SettingRow(
              icon: Icons.notification_important_outlined,
              color: RColors.urgent,
              label: 'Urgentes',
              onTap: () => state.setUrgentAlerts(!state.urgentAlerts),
              trailing: RToggle(
                  value: state.urgentAlerts,
                  label: 'Urgentes',
                  onChanged: state.setUrgentAlerts),
            ),
            _SettingRow(
              icon: Icons.schedule,
              color: RColors.link,
              label: 'Resumo 8h e 19h',
              onTap: () => state.setDigest(!state.digest),
              trailing: RToggle(
                  value: state.digest,
                  label: 'Resumo 8h e 19h',
                  onChanged: state.setDigest),
            ),
            _SettingRow(
              icon: Icons.campaign_outlined,
              color: RColors.orange,
              label: 'Rumores não confirmados',
              onTap: () => state.setShowRumors(!state.showRumors),
              trailing: RToggle(
                value: state.showRumors,
                label: 'Rumores não confirmados',
                onChanged: state.setShowRumors,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(
            state.showRumors
                ? 'Rumores aparecem no feed com o aviso “não confirmado”.'
                : 'A velocidade não pode custar credibilidade. Rumores ficam escondidos.',
            style: RText.caption1.withColor(RColors.textTertiary),
          ),
        ),
        const SizedBox(height: 24),
        _SettingsGroup(
          children: [
            _SettingRow(
              icon: Icons.language,
              color: RColors.radar,
              label: 'Idioma',
              onTap: () async {
                final language = await showRSheet<AppLanguage>(
                  context,
                  builder: (sheet) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(sheet.tr('Idioma do app'), style: RText.title2),
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final language in AppLanguage.values)
                          RChip(language.label,
                              active: state.language == language,
                              onTap: () => Navigator.of(sheet).pop(language)),
                      ]),
                    ],
                  ),
                );
                if (language != null && context.mounted) {
                  state.setLanguage(language);
                }
              },
              trailing: Text(state.language.label,
                  style: RText.subheadline.withColor(RColors.textSecondary)),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const GroupLabel('CONTA'),
        _SettingsGroup(
          children: [
            _SettingRow(
              icon: Icons.person_outline,
              color: RColors.link,
              label:
                  state.isAccount ? 'Gerenciar conta' : 'Entrar ou criar conta',
              onTap: () => Routes.push(Routes.account),
              trailing:
                  const Icon(Icons.chevron_right, color: RColors.textTertiary),
            ),
            _SettingRow(
              icon: Icons.auto_awesome,
              color: RColors.radar,
              label: 'Tópicos seguidos',
              onTap: () => Routes.push(Routes.editTopics),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${state.topics.length}',
                      style: RText.body.withColor(RColors.textSecondary)),
                  const Icon(Icons.chevron_right, color: RColors.textTertiary),
                ],
              ),
            ),
            _SettingRow(
              icon: Icons.group_outlined,
              color: RColors.purple,
              label: 'Comunidade',
              onTap: () => showCommunitySheet(context),
              trailing: const TintPill('Em breve'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (state.isAccount) ...[
          const SignOutButton(),
          const SizedBox(height: 24),
        ],
        const GroupLabel('PRÉVIAS (DEV)'),
        _SettingsGroup(
          children: [
            _SettingRow(
              icon: Icons.dashboard_outlined,
              color: RColors.link,
              label: 'Telas fora do app e pop-ups',
              onTap: () => Routes.push(Routes.previews),
              trailing:
                  const Icon(Icons.chevron_right, color: RColors.textTertiary),
            ),
          ],
        ),
      ],
    );
  }
}

/// Card da semana (índigo): furos, sequência e barras S T Q Q S S D.
class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    const dark = RColors.onRadar;
    final w = state.week;
    final today = DateTime.now().weekday - 1;
    return Semantics(
      label:
          'Sua semana: ${w.scoops} furos antes de todo mundo. Sequência de ${w.streakDays} dias.',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: RColors.radar,
              borderRadius: BorderRadius.circular(RRadius.cardLg)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(context.tr('Sua semana'),
                      style: RText.footnoteEmph.withColor(dark)),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: dark,
                        borderRadius: BorderRadius.circular(RRadius.pill)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_fire_department_outlined,
                            size: 14, color: RColors.radar),
                        const SizedBox(width: 4),
                        Text('${w.streakDays} dias',
                            style: RText.caption1Emph.withColor(RColors.radar)),
                      ],
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text('${w.scoops}', style: RText.display.withColor(dark)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text('furos antes de todo mundo',
                          style: RText.subheadline.withColor(dark))),
                ],
              ),
              const SizedBox(height: 10),
              MiniBars(
                values: w.perDay,
                highlight: today,
                height: 56,
                color: dark.withValues(alpha: 0.16),
                highlightColor: dark,
                labels: const ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'],
                labelColor: dark,
                gap: 10,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return RCard(
      radius: 20,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) const HairlineDivider(indent: 56),
          ],
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      pressedScale: 0.99,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(
            children: [
              IconTile(icon: icon, color: color, size: 30),
              const SizedBox(width: 12),
              Expanded(child: Text(context.tr(label), style: RText.body)),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}
