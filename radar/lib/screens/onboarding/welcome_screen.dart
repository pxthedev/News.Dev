import '../../l10n/app_copy.dart';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../../theme/tokens.dart';
import '../../routes.dart';
import '../../widgets/primitives.dart';
import '../../widgets/system.dart';
import '../account_screen.dart';
import '../../state/app_state.dart';
import 'topics_screen.dart';

/// 01 · Boas-vindas
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
              child: RadialGlow(
                  alignment: Alignment(0, -0.45), opacity: 0.22, radius: 1.0)),
          SafeArea(
            child: FillScrollView(
              padding: const EdgeInsets.symmetric(horizontal: RSpace.screen),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 48),
                  const _NotificationStack(),
                  const Spacer(),
                  const SizedBox(height: 32),
                  const BrandLockup(size: 64, showCategory: true),
                  const SizedBox(height: 18),
                  Semantics(
                      header: true,
                      child: Text(context.tr('Tecnologia, antes de todo mundo.'),
                          style: RText.display)),
                  const SizedBox(height: 12),
                  Text(
                    'Nossa IA vasculha mais de 2.000 fontes, 24 horas por dia, e traduz o que importa pro português.',
                    style: RText.body.withColor(RColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  RButton(
                    'Começar',
                    onPressed: () => Navigator.of(context).push(
                      CupertinoPageRoute<void>(
                          builder: (_) => AppScope.read(context).isAccount
                              ? const TopicsScreen()
                              : const AccountScreen(register: true)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  RButton('Já tenho conta',
                      kind: RButtonKind.text,
                      onPressed: () => Routes.push(Routes.account)),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pilha de 3 notificações: as de trás mais estreitas e transparentes.
class _NotificationStack extends StatelessWidget {
  const _NotificationStack();

  @override
  Widget build(BuildContext context) {
    return const ExcludeSemantics(
      child: SizedBox(
        height: 186,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: 0,
              left: 28,
              right: 28,
              child: Opacity(
                opacity: 0.45,
                child: NotificationCard(
                  title: 'Nvidia anuncia fábrica de US\$ 12 bi',
                  body: 'Jensen Huang confirmou em Taipé.',
                  time: '',
                  maxBodyLines: 1,
                ),
              ),
            ),
            Positioned(
              top: 48,
              left: 14,
              right: 14,
              child: Opacity(
                opacity: 0.72,
                child: NotificationCard(
                  title: 'OpenAI lança novo modelo de raciocínio',
                  body: 'Disponível hoje na API e no app.',
                  time: '9:12',
                  maxBodyLines: 1,
                ),
              ),
            ),
            Positioned(
              top: 96,
              left: 0,
              right: 0,
              child: NotificationCard(
                title: 'Urgente · Ataque hacker atinge banco',
                body:
                    'Dados de 2 milhões de clientes expostos. Primeiro no Brasil.',
                time: 'agora',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
