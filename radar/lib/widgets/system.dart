import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../l10n/app_copy.dart';
import '../routes.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import 'primitives.dart';

// ---------------------------------------------------------------------------
// Tab bar flutuante

class TabItem {
  const TabItem(this.icon, this.label);
  final IconData icon;
  final String label;
}

const radarTabs = [
  TabItem(Icons.bolt, 'Agora'),
  TabItem(Icons.explore_outlined, 'Explorar'),
  TabItem(Icons.bookmark_border, 'Salvos'),
  TabItem(Icons.person_outline, 'Perfil'),
];

/// Pílula 353×64. A aba ativa vira pílula índigo com ícone e rótulo.
class FloatingTabBar extends StatelessWidget {
  const FloatingTabBar({super.key, required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: RSize.tabBar,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: RColors.bgCard,
        borderRadius: BorderRadius.circular(RRadius.pill),
        border: Border.all(color: RColors.separator, width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var i = 0; i < radarTabs.length; i++)
            _TabButton(item: radarTabs[i], active: i == index, onTap: () => onTap(i)),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.item, required this.active, required this.onTap});
  final TabItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const curve = Curves.easeOutCubic;
    const duration = Duration(milliseconds: 320);
    return Semantics(
      button: true,
      selected: active,
      label: context.tr(item.label),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ExcludeSemantics(
          child: AnimatedContainer(
            duration: duration,
            curve: curve,
            height: 48,
            padding: EdgeInsets.symmetric(horizontal: active ? 18 : 14),
            decoration: BoxDecoration(
              color: active ? RColors.radar : RColors.radar.withValues(alpha: 0),
              borderRadius: BorderRadius.circular(RRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.icon, size: 22, color: active ? RColors.onRadar : RColors.textSecondary),
                AnimatedSize(
                  duration: duration,
                  curve: curve,
                  child: active
                      ? Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Text(context.tr(item.label), style: RText.headline.withColor(RColors.onRadar), maxLines: 1),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Gradiente de transparente pra preto atrás da tab bar (o conteúdo some por baixo).
class BottomFade extends StatelessWidget {
  const BottomFade({super.key, this.height = RSize.tabFade});
  final double height;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          height: height,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x00000000), Color(0xD9000000), Color(0xFF000000)],
              stops: [0, 0.55, 1],
            ),
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Notificação iOS (vidro escuro)

class NotificationCard extends StatelessWidget {
  const NotificationCard({
    super.key,
    required this.title,
    required this.body,
    this.time = 'agora',
    this.maxBodyLines = 3,
    this.onTap,
  });

  final String title;
  final String body;
  final String time;
  final int maxBodyLines;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.all(12),
          color: RColors.bgElevated.withValues(alpha: 0.85),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppIcon(size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(title, style: RText.footnoteEmph, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        if (time.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(time, style: RText.caption1.withColor(RColors.textSecondary)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(body, style: RText.footnote, maxLines: maxBodyLines, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (onTap == null) return card;
    return Pressable(onTap: onTap, pressedScale: 0.98, child: card);
  }
}

// ---------------------------------------------------------------------------
// Toast e banner urgente

class RToast extends StatelessWidget {
  const RToast({super.key, required this.data, required this.onAction});
  final ToastData data;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 16, 8),
        constraints: const BoxConstraints(minHeight: 44),
        decoration: BoxDecoration(
          color: RColors.bgElevated,
          borderRadius: BorderRadius.circular(RRadius.pill),
          boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 20, offset: Offset(0, 8))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(color: RColors.radar, shape: BoxShape.circle),
              child: const Icon(Icons.check, size: 15, color: RColors.onRadar),
            ),
            const SizedBox(width: 8),
            Flexible(child: Text(data.message, style: RText.subheadlineEmph)),
            if (data.actionLabel != null) ...[
              const SizedBox(width: 10),
              Pressable(
                onTap: onAction,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(data.actionLabel!, style: RText.subheadline.withColor(RColors.radar)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class UrgentBanner extends StatelessWidget {
  const UrgentBanner({super.key, required this.article, required this.onOpen, required this.onDismiss});
  final Article article;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      button: true,
      label: 'Urgente agora: ${article.title}',
      child: GestureDetector(
        onTap: onOpen,
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) < -50) onDismiss();
        },
        child: ExcludeSemantics(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: RColors.bgElevated,
              borderRadius: BorderRadius.circular(RRadius.cardLg),
              border: Border.all(color: RColors.urgent.withValues(alpha: 0.6)),
              boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 24, offset: Offset(0, 10))],
            ),
            child: Row(
              children: [
                const IconTile(icon: Icons.notification_important_outlined, color: RColors.urgent, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr('URGENTE · AGORA'), style: RText.caption2.withColor(RColors.urgent)),
                      const SizedBox(height: 2),
                      Text(article.title, style: RText.subheadlineEmph, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: RColors.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Camada acima do Navigator: banner urgente (topo) e toast (acima da tab bar)
/// aparecem sobre qualquer tela.
class OverlayHost extends StatelessWidget {
  const OverlayHost({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.read(context);
    final pad = MediaQuery.paddingOf(context);
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          child,
          Positioned(
            left: 20,
            right: 20,
            bottom: math.max(pad.bottom - 6, 12) + RSize.tabBar + 14,
            child: ValueListenableBuilder<ToastData?>(
              valueListenable: state.toast,
              builder: (context, data, _) => AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(anim),
                    child: child,
                  ),
                ),
                child: data == null
                    ? const SizedBox.shrink(key: ValueKey('no-toast'))
                    : Center(
                        key: ValueKey(data.id),
                        child: RToast(
                          data: data,
                          onAction: () {
                            data.onAction?.call();
                            state.hideToast();
                          },
                        ),
                      ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            top: pad.top + 6,
            child: ValueListenableBuilder<Article?>(
              valueListenable: state.banner,
              builder: (context, article, _) => AnimatedSwitcher(
                duration: const Duration(milliseconds: 380),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, anim) => SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, -1.6), end: Offset.zero).animate(anim),
                  child: child,
                ),
                child: article == null
                    ? const SizedBox.shrink(key: ValueKey('no-banner'))
                    : UrgentBanner(
                        key: ValueKey(article.id),
                        article: article,
                        onDismiss: state.dismissBanner,
                        onOpen: () {
                          state.dismissBanner();
                          Routes.openArticle(article.id, source: 'push');
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sheet

/// Sheet padrão: bg/card, cantos de 34, grabber, overlay preto de 60%.
Future<T?> showRSheet<T>(BuildContext context, {required WidgetBuilder builder}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    elevation: 0,
    builder: (ctx) => Container(
      decoration: const BoxDecoration(
        color: RColors.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(RRadius.sheet)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 44),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [const Grabber(), const SizedBox(height: 16), builder(ctx)],
        ),
      ),
    ),
  );
}
