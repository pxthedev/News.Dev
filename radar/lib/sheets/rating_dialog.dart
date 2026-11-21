import '../l10n/app_copy.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../services/platform_services.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/primitives.dart';

/// 20 · Pedido de avaliação. "Avaliar" chama o SKStoreReviewController (via in_app_review).
Future<void> showRatingDialog(BuildContext context) {
  final state = AppScope.read(context);
  state.markRatingAsked();
  return showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: 'Fechar',
    barrierColor: Colors.black.withValues(alpha: 0.6),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (ctx, a, b) => RatingDialog(scoops: state.week.scoops),
    transitionBuilder: (ctx, anim, _, child) => FadeTransition(
      opacity: anim,
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.08, end: 1).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ),
  );
}

class RatingDialog extends StatefulWidget {
  const RatingDialog({super.key, required this.scoops});
  final int scoops;

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  int _stars = 0;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          width: 300,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(color: RColors.bgElevated, borderRadius: BorderRadius.circular(RRadius.cardLg)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
                child: Column(
                  children: [
                    const AppIcon(size: 64),
                    const SizedBox(height: 14),
                    Semantics(header: true, child: Text(context.tr('Curtindo o news.dev?'), style: RText.headline)),
                    const SizedBox(height: 6),
                    Text(
                      'Você soube de ${widget.scoops} furos antes de todo mundo esta semana. Conta pra gente na App Store?',
                      textAlign: TextAlign.center,
                      style: RText.footnote.withColor(RColors.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 1; i <= 5; i++)
                          Semantics(
                            button: true,
                            label: '$i ${i == 1 ? 'estrela' : 'estrelas'}',
                            selected: i <= _stars,
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _stars = i);
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  i <= _stars ? Icons.star_rounded : Icons.star_border_rounded,
                                  color: RColors.radar,
                                  size: 32,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const HairlineDivider(),
              _DialogAction(
                label: 'Avaliar',
                style: RText.headline.withColor(RColors.radar),
                onTap: () {
                  Navigator.of(context).pop();
                  PlatformServices.instance.requestReview();
                },
              ),
              const HairlineDivider(),
              _DialogAction(
                label: 'Agora não',
                style: RText.body.withColor(RColors.textSecondary),
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogAction extends StatelessWidget {
  const _DialogAction({required this.label, required this.style, required this.onTap});
  final String label;
  final TextStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      pressedScale: 0.98,
      child: SizedBox(height: 50, width: double.infinity, child: Center(child: Text(label, style: style))),
    );
  }
}
