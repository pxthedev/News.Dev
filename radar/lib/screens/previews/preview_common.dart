import 'package:material_ui/material_ui.dart';

import '../../theme/tokens.dart';
import '../../utils/format.dart';
import '../../widgets/primitives.dart';

/// Papel de parede escuro com brilhos índigo e azul (tela bloqueada).
class LockWallpaper extends StatelessWidget {
  const LockWallpaper({super.key});

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: Color(0xFF050805))),
        Positioned.fill(child: RadialGlow(alignment: Alignment(-0.2, -0.55), opacity: 0.32, radius: 1.1)),
        Positioned.fill(
          child: RadialGlow(alignment: Alignment(0.7, 1.0), color: RColors.link, opacity: 0.22, radius: 0.9),
        ),
      ],
    );
  }
}

/// Estrutura das prévias: papel de parede, botão de fechar e conteúdo.
class PreviewScaffold extends StatelessWidget {
  const PreviewScaffold({super.key, required this.child, this.showClock = true, this.label});
  final Widget child;
  final bool showClock;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: LockWallpaper()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 20, 0),
                  child: Row(
                    children: [
                      CircleButton(
                        icon: Icons.close,
                        label: 'Fechar prévia',
                        color: const Color(0x33FFFFFF),
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                      if (label != null) Text(label!, style: RText.footnoteEmph.withColor(RColors.textSecondary)),
                    ],
                  ),
                ),
                if (showClock) ...[
                  Text(longDate(now), style: RText.title3.copyWith(fontWeight: FontWeight.w500)),
                  Text(
                    hhmm(now),
                    style: const TextStyle(
                      fontSize: 86,
                      height: 1.05,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -2,
                      color: RColors.textPrimary,
                    ),
                  ),
                ],
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Vidro claro usado nos widgets da tela bloqueada.
class GlassBox extends StatelessWidget {
  const GlassBox({super.key, required this.child, this.radius = 18, this.padding = const EdgeInsets.all(12)});
  final Widget child;
  final double radius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: child,
      );
}
