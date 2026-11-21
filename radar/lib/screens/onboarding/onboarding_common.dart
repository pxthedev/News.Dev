import '../../l10n/app_copy.dart';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../routes.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../widgets/primitives.dart';
import '../root_shell.dart';

/// Conclui o onboarding: haptic de sucesso e entra no app sem volta.
void finishOnboarding(BuildContext context) {
  final state = AppScope.read(context);
  if (!state.isAccount) return;
  state.completeOnboarding();
  final sharedArticle = state.pendingSharedArticle;
  state.pendingSharedArticle = null;
  HapticFeedback.heavyImpact();
  Navigator.of(context).pushAndRemoveUntil(
    CupertinoPageRoute<void>(builder: (_) => const RootShell()),
    (_) => false,
  );
  if (sharedArticle != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (rootNavigatorKey.currentState != null && state.isAccount) {
        Routes.openArticle(sharedArticle, source: 'share');
      }
    });
  }
}

class OnboardingProgress extends StatelessWidget {
  const OnboardingProgress({super.key, required this.value, this.from = 0});
  final double value;
  final double from;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Progresso do cadastro',
      value: '${(value * 100).round()}%',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: SizedBox(
          width: double.infinity,
          height: 4,
          child: Stack(
            children: [
              const Positioned.fill(
                  child: ColoredBox(color: RColors.bgControl)),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: from, end: value),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: v,
                  child: const ColoredBox(
                      color: RColors.radar, child: SizedBox(height: 4)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Estrutura das telas 02 e 03: progresso, título, conteúdo rolável e botão fixo embaixo.
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    this.progress,
    this.progressFrom = 0,
    required this.title,
    this.subtitle,
    required this.children,
    required this.bottom,
    this.showBack = false,
  });

  final double? progress;
  final double progressFrom;
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget bottom;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (showBack)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 20, 0),
                child: Row(children: [
                  CircleButton(
                      icon: Icons.chevron_left,
                      label: 'Voltar',
                      onTap: () => Navigator.of(context).pop()),
                ]),
              ),
            if (progress != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: OnboardingProgress(value: progress!, from: progressFrom),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                children: [
                  Semantics(
                      header: true, child: Text(context.tr(title), style: RText.title1)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 8),
                    Text(context.tr(subtitle!),
                        style: RText.callout.withColor(RColors.textSecondary)),
                  ],
                  const SizedBox(height: 22),
                  ...children,
                ],
              ),
            ),
            Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: bottom),
          ],
        ),
      ),
    );
  }
}
