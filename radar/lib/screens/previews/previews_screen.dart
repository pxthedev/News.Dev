import 'package:material_ui/material_ui.dart';

import '../../data/repository.dart';
import '../../routes.dart';
import '../../sheets/community_sheet.dart';
import '../../sheets/rating_dialog.dart';
import '../../sheets/share_sheet.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../widgets/primitives.dart';

/// Catálogo pra equipe revisar as telas 13–20 e os estados especiais.
class PreviewsScreen extends StatefulWidget {
  const PreviewsScreen({super.key});

  @override
  State<PreviewsScreen> createState() => _PreviewsScreenState();
}

class _PreviewsScreenState extends State<PreviewsScreen> {
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final repo = Repo.instance;

    Widget row(String title, String subtitle, VoidCallback onTap,
            {Widget? trailing}) =>
        Pressable(
          pressedScale: 0.99,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: RText.body),
                      Text(subtitle,
                          style:
                              RText.caption1.withColor(RColors.textSecondary)),
                    ],
                  ),
                ),
                trailing ??
                    const Icon(Icons.chevron_right,
                        color: RColors.textTertiary),
              ],
            ),
          ),
        );

    Widget group(List<Widget> rows) => RCard(
          padding: EdgeInsets.zero,
          radius: 20,
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                rows[i],
                if (i < rows.length - 1) const HairlineDivider(indent: 16)
              ],
            ],
          ),
        );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: CircleButton(
                  icon: Icons.chevron_left,
                  label: 'Voltar',
                  onTap: () => Navigator.of(context).pop()),
            ),
            const SizedBox(height: 8),
            Semantics(
                header: true, child: Text('Prévias', style: RText.largeTitle)),
            const SizedBox(height: 6),
            Text(
              'As telas 13 a 16 rodam fora do app. Aqui são prévias em Flutter. As versões reais são feitas em Swift, com WidgetKit e ActivityKit.',
              style: RText.footnote.withColor(RColors.textSecondary),
            ),
            const SizedBox(height: 20),
            const GroupLabel('FORA DO APP'),
            group([
              row('13 · Tela bloqueada', 'Widgets e notificações',
                  () => Routes.push(Routes.lockScreen)),
              row('14 · Live Activity', 'Keynote ao vivo',
                  () => Routes.push(Routes.liveActivity)),
              row('15 · Dynamic Island', 'Compacta, mínima e expandida',
                  () => Routes.push(Routes.dynamicIsland)),
              row('16 · Widgets da tela inicial', 'Pequeno, médio e grande',
                  () => Routes.push(Routes.homeWidgets)),
            ]),
            const SizedBox(height: 22),
            const GroupLabel('POP-UPS E SHEETS'),
            group([
              row('17 · Banner urgente', 'Aparece sobre qualquer tela', () {
                final a = repo.byId('banco-ataque');
                if (a != null) state.showBanner(a);
              }),
              row('17 · Toast', 'Salvo pra ler depois · Desfazer', () {
                state.showToast('Salvo pra ler depois',
                    actionLabel: 'Desfazer', onAction: () {});
              }),
              row('18 · Compartilhar furo', 'Card 1080×1920 pros Stories',
                  () async {
                final hero = repo.lastHome?.hero ?? (await repo.home()).hero;
                if (context.mounted && hero != null) {
                  await showShareSheet(context, hero);
                }
              }),
              row('19 · Comunidade', 'Teaser com lista de espera',
                  () => showCommunitySheet(context)),
              row('20 · Pedido de avaliação', 'Depois de um momento positivo',
                  () => showRatingDialog(context)),
            ]),
            const SizedBox(height: 22),
            const GroupLabel('ESTADOS'),
            group([
              row(
                'Simular sem conexão',
                'Feed mostra o cache e o aviso de erro',
                () => setState(
                    () => repo.simulateOffline = !repo.simulateOffline),
                trailing: RToggle(
                  value: repo.simulateOffline,
                  onChanged: (v) => setState(() => repo.simulateOffline = v),
                ),
              ),
              row(
                'Mostrar rumores',
                'Rumores não confirmados no feed',
                () => state.setShowRumors(!state.showRumors),
                trailing: RToggle(
                    value: state.showRumors, onChanged: state.setShowRumors),
              ),
              row(
                  'Deep link: radar://materia/nvidia-fabrica',
                  'Abre direto na matéria',
                  () => Routes.handleDeepLink(
                      Uri.parse('radar://materia/nvidia-fabrica'))),
              row(
                  'Deep link: radar://topico/seguranca',
                  'Abre a página do tópico',
                  () => Routes.handleDeepLink(
                      Uri.parse('radar://topico/seguranca'))),
              row('Deep link: radar://alertas', 'Abre a central de alertas',
                  () => Routes.handleDeepLink(Uri.parse('radar://alertas'))),
            ]),
          ],
        ),
      ),
    );
  }
}
