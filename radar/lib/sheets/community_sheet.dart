import '../l10n/app_copy.dart';

import 'package:material_ui/material_ui.dart';

import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/primitives.dart';
import '../widgets/system.dart';

/// 19 · Teaser da comunidade. A regra de 14 dias fica em [AppState.canShowCommunityTeaser].
Future<void> showCommunitySheet(BuildContext context) {
  AppScope.read(context).markCommunityTeaserShown();
  return showRSheet<void>(context, builder: (_) => const CommunitySheet());
}

class CommunitySheet extends StatelessWidget {
  const CommunitySheet({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    const benefits = [
      (Icons.group_outlined, 'Discussões por tópico, com especialistas'),
      (Icons.star_border_rounded, 'Selo de fundador pros primeiros 1.000'),
      (Icons.notifications_none, 'Aviso quando abrir pra você'),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 4),
        const AvatarStack(
          items: [('MA', RColors.link), ('RL', RColors.purple), ('JG', RColors.radar), ('TS', RColors.orange)],
          size: 48,
          overlap: 0.22,
          borderColor: RColors.bgCard,
          showPlus: true,
        ),
        const SizedBox(height: 16),
        const TintPill('Em breve', icon: Icons.auto_awesome),
        const SizedBox(height: 12),
        Semantics(header: true, child: Text(context.tr('Comunidade news.dev'), style: RText.title2, textAlign: TextAlign.center)),
        const SizedBox(height: 8),
        Text(
          'Debata os furos com quem vive de tecnologia. Entre na lista e ganhe acesso antecipado.',
          textAlign: TextAlign.center,
          style: RText.subheadline.withColor(RColors.textSecondary),
        ),
        const SizedBox(height: 18),
        RCard(
          color: RColors.bgElevated,
          radius: 18,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(
            children: [
              for (final b in benefits)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(b.$1, size: 20, color: RColors.radar),
                      const SizedBox(width: 10),
                      Expanded(child: Text(b.$2, style: RText.subheadline)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        RButton(
          state.communityJoined ? 'Você já está na lista' : 'Entrar na lista',
          onPressed: state.communityJoined
              ? null
              : () {
                  state.joinCommunity();
                  Navigator.of(context).pop();
                  state.showToast('Você está na lista. A gente avisa quando abrir.');
                },
        ),
        const SizedBox(height: 4),
        RButton('Agora não', kind: RButtonKind.text, onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}
