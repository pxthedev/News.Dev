import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/models.dart';
import '../../services/analytics.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../widgets/primitives.dart';
import 'alert_level_screen.dart';
import 'onboarding_common.dart';
import '../account_screen.dart';

/// 02 · Escolha de tópicos. Com [editing] vira a tela "Tópicos seguidos" do perfil.
class TopicsScreen extends StatelessWidget {
  const TopicsScreen({super.key, this.editing = false});
  final bool editing;

  static (int daily, int scoops) estimate(Set<NewsCategory> topics) {
    var daily = 0;
    var scoops = 0;
    for (final t in topics) {
      daily += t.dailyAvg;
      scoops += t.scoopsAvg;
    }
    return (daily, scoops);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (!state.isAccount) return const AccountScreen();
    final n = state.topics.length;
    final (daily, scoops) = estimate(state.topics);
    final enough = n >= 3;

    return OnboardingScaffold(
      progress: editing ? null : 0.33,
      progressFrom: 0,
      showBack: editing,
      title: editing ? 'Tópicos seguidos' : 'O que te interessa?',
      subtitle: 'Escolha 3 ou mais. Seu feed se ajusta ao que você lê.',
      bottom: RButton(
        editing
            ? 'Salvar tópicos'
            : 'Continuar · ${n == 1 ? '1 escolhido' : '$n escolhidos'}',
        onPressed: enough
            ? () {
                Analytics.log('onboarding_topics_selected',
                    {'topics': state.topics.map((t) => t.slug).toList()});
                if (editing) {
                  Navigator.of(context).pop();
                  state.showToast('Tópicos atualizados');
                } else {
                  Navigator.of(context).push(CupertinoPageRoute<void>(
                      builder: (_) => const AlertLevelScreen()));
                }
              }
            : null,
      ),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 10,
          children: [
            for (final c in NewsCategory.values)
              RChip(
                c.label,
                icon: c.chipIcon,
                active: state.topics.contains(c),
                showCheck: true,
                bordered: true,
                large: true,
                onTap: () => state.toggleTopic(c),
              ),
          ],
        ),
        const SizedBox(height: 24),
        RCard(
          radius: 18,
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, color: RColors.radar, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    n == 0
                        ? 'Escolha seus tópicos pra ver quantas notícias você receberia por dia.'
                        : 'Com esses tópicos você receberia cerca de $daily notícias por dia, com $scoops furos em média.',
                    key: ValueKey('$daily-$scoops'),
                    style: RText.footnote.withColor(RColors.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
