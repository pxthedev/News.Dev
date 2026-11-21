import '../../l10n/app_copy.dart';

import 'package:material_ui/material_ui.dart';

import '../../services/analytics.dart';
import '../../services/platform_services.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../utils/format.dart';
import '../../widgets/primitives.dart';
import '../../widgets/system.dart';
import 'onboarding_common.dart';

/// 04 · Pré-permissão de notificações. O prompt nativo só aparece ao tocar em "Ativar notificações".
class PushPermissionScreen extends StatelessWidget {
  const PushPermissionScreen({super.key});

  Future<void> _activate(BuildContext context) async {
    final state = AppScope.read(context);
    final granted = await PlatformServices.instance.requestPushPermission();
    state.setPushGranted(granted);
    Analytics.log('push_permission_result', {'granted': granted});
    if (context.mounted) finishOnboarding(context);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: RadialGlow(alignment: Alignment(0, -0.75), opacity: 0.2, radius: 0.9)),
          SafeArea(
            child: FillScrollView(
              padding: const EdgeInsets.symmetric(horizontal: RSpace.screen),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  ExcludeSemantics(
                    child: Column(
                      children: [
                        Center(
                          child: Text(longDate(now), style: RText.subheadlineEmph.withColor(const Color(0xCCFFFFFF))),
                        ),
                        Center(
                          child: Text(
                            hhmm(now),
                            style: const TextStyle(
                              fontSize: 86,
                              height: 1.05,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -2,
                              color: RColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        const NotificationCard(
                          title: 'Urgente · OpenAI anuncia novo modelo',
                          body: 'Você soube 38 min antes da imprensa brasileira.',
                        ),
                        const SizedBox(height: 8),
                        const NotificationCard(
                          title: 'Resumo da manhã',
                          body: '8 notícias que você precisa saber hoje.',
                          time: '8:00',
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(height: 32),
                  const TintPill('Último passo', icon: Icons.bolt),
                  const SizedBox(height: 12),
                  Semantics(header: true, child: Text(context.tr('Seja o primeiro a saber'), style: RText.title1)),
                  const SizedBox(height: 8),
                  Text(
                    'Ative as notificações pra receber os furos assim que nossa IA confirmar a notícia em mais de uma fonte.',
                    style: RText.callout.withColor(RColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  RButton('Ativar notificações', onPressed: () => _activate(context)),
                  const SizedBox(height: 4),
                  RButton(
                    'Agora não',
                    kind: RButtonKind.text,
                    onPressed: () {
                      Analytics.log('push_permission_result', {'granted': false, 'deferred': true});
                      finishOnboarding(context);
                    },
                  ),
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
