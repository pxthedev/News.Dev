import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../l10n/app_copy.dart';

import '../theme/tokens.dart';
import '../theme/brand.dart';

/// Base de toque: escala levemente ao pressionar (spring iOS) e expõe semântica de botão.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.97,
    this.semanticLabel,
    this.haptic = false,
    this.selected,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final String? semanticLabel;
  final bool haptic;
  final bool? selected;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      selected: widget.selected,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        onTapCancel: enabled ? () => _set(false) : null,
        onTap: enabled
            ? () {
                if (widget.haptic) HapticFeedback.lightImpact();
                widget.onTap!();
              }
            : null,
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: _down ? widget.pressedScale : 1,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}

enum RButtonKind { primary, secondary, text }

/// Botão pílula de largura total (altura 54).
class RButton extends StatelessWidget {
  const RButton(
    this.label, {
    super.key,
    this.onPressed,
    this.kind = RButtonKind.primary,
    this.icon,
    this.expand = true,
    this.height = RSize.button,
  });

  final String label;
  final VoidCallback? onPressed;
  final RButtonKind kind;
  final IconData? icon;
  final bool expand;
  final double height;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (kind) {
      RButtonKind.primary => (RColors.radar, RColors.onRadar),
      RButtonKind.secondary => (RColors.bgElevated, RColors.textPrimary),
      RButtonKind.text => (Colors.transparent, RColors.textSecondary),
    };
    final style =
        (kind == RButtonKind.text ? RText.body : RText.headline).withColor(fg);
    return Opacity(
      opacity: onPressed == null ? 0.4 : 1,
      child: Pressable(
        onTap: onPressed,
        child: Container(
          height: height,
          width: expand ? double.infinity : null,
          padding: EdgeInsets.symmetric(horizontal: expand ? 24 : 18),
          decoration: BoxDecoration(
              color: bg, borderRadius: BorderRadius.circular(RRadius.pill)),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: fg),
                const SizedBox(width: 6)
              ],
              Flexible(
                  child: Text(context.tr(label),
                      style: style,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chip pílula. Ativo = índigo com texto escuro; inativo = bg/card.
/// Com [icon] e [bordered] vira o chip de tópico do onboarding.
class RChip extends StatelessWidget {
  const RChip(
    this.label, {
    super.key,
    this.active = false,
    this.onTap,
    this.icon,
    this.showCheck = false,
    this.bordered = false,
    this.large = false,
  });

  final String label;
  final bool active;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool showCheck;
  final bool bordered;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final fg = active ? RColors.onRadar : RColors.textPrimary;
    return Pressable(
      onTap: onTap,
      selected: active,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
            horizontal: large ? 16 : 14, vertical: large ? 12 : 8),
        decoration: BoxDecoration(
          color: active ? RColors.radar : RColors.bgCard,
          borderRadius: BorderRadius.circular(RRadius.pill),
          border: bordered
              ? Border.all(color: active ? RColors.radar : RColors.separator)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 8)
            ],
            Text(context.tr(label), style: RText.subheadlineEmph.withColor(fg)),
            if (showCheck && active) ...[
              const SizedBox(width: 6),
              Icon(Icons.check, size: 16, color: fg)
            ],
          ],
        ),
      ),
    );
  }
}

/// Segmented control em pílula.
class SegmentedPill extends StatelessWidget {
  const SegmentedPill(
      {super.key,
      required this.segments,
      required this.index,
      required this.onChanged});

  final List<String> segments;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: RColors.bgCard,
          borderRadius: BorderRadius.circular(RRadius.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < segments.length; i++)
            Pressable(
              pressedScale: 0.95,
              selected: i == index,
              onTap: () {
                if (i != index) {
                  HapticFeedback.selectionClick();
                  onChanged(i);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                decoration: BoxDecoration(
                  color: i == index
                      ? RColors.bgControl
                      : RColors.bgControl.withValues(alpha: 0),
                  borderRadius: BorderRadius.circular(RRadius.pill),
                ),
                child: Text(
                  context.tr(segments[i]),
                  style: i == index
                      ? RText.footnoteEmph
                      : RText.footnote.withColor(RColors.textSecondary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Toggle iOS 51×31. Ligado = trilho índigo com bolinha escura.
class RToggle extends StatelessWidget {
  const RToggle(
      {super.key, required this.value, required this.onChanged, this.label});

  final bool value;
  final ValueChanged<bool> onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      label: label == null ? null : context.tr(label!),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onChanged(!value);
        },
        child: SizedBox(
          height: RSize.minTap,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 51,
              height: 31,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: value ? RColors.radar : RColors.bgControl,
                borderRadius: BorderRadius.circular(RRadius.pill),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 27,
                  height: 27,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: value ? RColors.onRadar : Colors.white,
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 4,
                          offset: Offset(0, 2))
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botão circular 40×40 (área de toque de 44).
class CircleButton extends StatelessWidget {
  const CircleButton({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.badge = false,
    this.color = RColors.bgCard,
    this.iconColor = RColors.textPrimary,
    this.size = RSize.circleButton,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool badge;
  final Color color;
  final Color iconColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      pressedScale: 0.9,
      semanticLabel: badge ? '$label, há itens não lidos' : label,
      child: SizedBox(
        width: RSize.minTap,
        height: RSize.minTap,
        child: Center(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, size: 20, color: iconColor),
                if (badge)
                  Positioned(
                    top: size * 0.22,
                    right: size * 0.24,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: RColors.urgent,
                        shape: BoxShape.circle,
                        border: Border.all(color: color, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tile de ícone: raio de 30% do tamanho, fundo com tint e ícone na cor cheia.
class IconTile extends StatelessWidget {
  const IconTile(
      {super.key,
      required this.icon,
      required this.color,
      this.size = 36,
      this.solid = false});

  final IconData icon;
  final Color color;
  final double size;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: solid ? color : RColors.tint(color),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child:
          Icon(icon, size: size * 0.55, color: solid ? RColors.onRadar : color),
    );
  }
}

/// Marca news.dev.
class AppIcon extends StatelessWidget {
  const AppIcon({super.key, this.size = 38});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppBrand.name,
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.24),
        child: Image.asset(AppBrand.iconAsset,
            width: size,
            height: size,
            fit: BoxFit.contain,
            excludeFromSemantics: true),
      ),
    );
  }
}

class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.size = 56, this.showCategory = false});
  final double size;
  final bool showCategory;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(child: AppIcon(size: size)),
          const SizedBox(width: 14),
          Flexible(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppBrand.name,
                  style: RText.title1.copyWith(
                      fontWeight: FontWeight.w700, letterSpacing: -0.8)),
              if (showCategory) ...[
                const SizedBox(height: 4),
                Text(context.tr(AppBrand.category),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RText.caption2
                        .withColor(RColors.textSecondary)
                        .copyWith(fontSize: 10, letterSpacing: 1.1)),
              ],
            ],
          )),
        ],
      );
}

/// Selo "Primeiro no Brasil".
class FirstBadge extends StatelessWidget {
  const FirstBadge({super.key, this.label = 'Primeiro no Brasil'});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: RColors.onRadar,
          borderRadius: BorderRadius.circular(RRadius.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                  color: RColors.radar, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(context.tr(label),
              style: RText.caption1Emph.withColor(RColors.radar)),
        ],
      ),
    );
  }
}

/// Pílula pequena com tint índigo ("Em breve", "Último passo").
class TintPill extends StatelessWidget {
  const TintPill(this.label,
      {super.key, this.icon, this.color = RColors.radar});
  final String label;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
          color: RColors.tint(color),
          borderRadius: BorderRadius.circular(RRadius.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4)
          ],
          Text(context.tr(label), style: RText.caption1Emph.withColor(color)),
        ],
      ),
    );
  }
}

/// Pílula vermelha "● 23 min" / "● Ao vivo".
class LivePill extends StatelessWidget {
  const LivePill(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: RColors.tint(RColors.urgent, 0.2),
          borderRadius: BorderRadius.circular(RRadius.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                  color: RColors.urgent, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(context.tr(label),
              style: RText.caption1Emph.withColor(RColors.urgent)),
        ],
      ),
    );
  }
}

class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar(this.initials,
      {super.key,
      this.size = 36,
      this.color = RColors.radar,
      this.borderColor,
      this.photo});

  final String initials;
  final double size;
  final Color color;
  final Color? borderColor;
  final Uint8List? photo;

  @override
  Widget build(BuildContext context) {
    final textColor = color == RColors.radar ? RColors.onRadar : Colors.white;
    final image = photo;
    if (image != null) {
      return ClipOval(
        child: Image.memory(image,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => InitialsAvatar(initials,
                size: size, color: color, borderColor: borderColor)),
      );
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: borderColor == null
            ? null
            : Border.all(color: borderColor!, width: 2),
      ),
      child: Text(
        initials,
        style: TextStyle(
            fontSize: size * 0.36,
            fontWeight: FontWeight.w600,
            color: textColor,
            height: 1),
      ),
    );
  }
}

/// Avatares sobrepostos.
class AvatarStack extends StatelessWidget {
  const AvatarStack({
    super.key,
    required this.items,
    this.size = 22,
    this.overlap = 0.3,
    this.borderColor = RColors.radar,
    this.showPlus = false,
  });

  final List<(String, Color)> items;
  final double size;
  final double overlap;
  final Color borderColor;
  final bool showPlus;

  @override
  Widget build(BuildContext context) {
    final step = size * (1 - overlap);
    final count = items.length + (showPlus ? 1 : 0);
    return ExcludeSemantics(
      child: SizedBox(
        width: step * (count - 1) + size,
        height: size,
        child: Stack(
          children: [
            for (var i = 0; i < items.length; i++)
              Positioned(
                left: i * step,
                child: InitialsAvatar(items[i].$1,
                    size: size, color: items[i].$2, borderColor: borderColor),
              ),
            if (showPlus)
              Positioned(
                left: items.length * step,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: RColors.bgElevated,
                    shape: BoxShape.circle,
                    border: Border.all(color: borderColor, width: 2),
                  ),
                  child: Icon(Icons.add,
                      size: size * 0.45, color: RColors.textPrimary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: Semantics(
                header: true,
                child: Text(context.tr(title), style: RText.title3))),
        if (action != null)
          Pressable(
            onTap: onAction,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(context.tr(action!),
                  style: RText.subheadline.withColor(RColors.textSecondary)),
            ),
          ),
      ],
    );
  }
}

/// Rótulo de grupo ("HOJE", "NOTIFICAÇÕES").
class GroupLabel extends StatelessWidget {
  const GroupLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 8),
        child: Semantics(
          header: true,
          child: Text(context.tr(text),
              style: RText.footnoteEmph
                  .copyWith(color: RColors.textSecondary, letterSpacing: 0.3)),
        ),
      );
}

class Grabber extends StatelessWidget {
  const Grabber({super.key});

  @override
  Widget build(BuildContext context) => Container(
        width: 36,
        height: 5,
        decoration: BoxDecoration(
            color: RColors.bgControl, borderRadius: BorderRadius.circular(3)),
      );
}

/// Brilho radial suave (fundo das telas de boas-vindas e tela bloqueada).
class RadialGlow extends StatelessWidget {
  const RadialGlow({
    super.key,
    this.alignment = const Alignment(0, -0.6),
    this.color = RColors.radar,
    this.opacity = 0.2,
    this.radius = 0.9,
  });

  final Alignment alignment;
  final Color color;
  final double opacity;
  final double radius;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: alignment,
              radius: radius,
              colors: [
                color.withValues(alpha: opacity),
                color.withValues(alpha: 0)
              ],
            ),
          ),
        ),
      );
}

/// Coluna que ocupa a tela inteira mas rola quando o texto cresce (Dynamic Type).
class FillScrollView extends StatelessWidget {
  const FillScrollView(
      {super.key, required this.child, this.padding = EdgeInsets.zero});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        padding: padding,
        child: ConstrainedBox(
          constraints:
              BoxConstraints(minHeight: c.maxHeight - padding.vertical),
          child: IntrinsicHeight(child: child),
        ),
      ),
    );
  }
}

/// Estado vazio: convite, não pedido de desculpas.
class EmptyState extends StatelessWidget {
  const EmptyState(
      {super.key,
      required this.icon,
      required this.title,
      this.message,
      this.actionLabel,
      this.onAction});

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconTile(icon: icon, color: RColors.radar, size: 56),
          const SizedBox(height: 16),
          Text(context.tr(title),
              style: RText.headline, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(context.tr(message!),
                style: RText.subheadline.withColor(RColors.textSecondary),
                textAlign: TextAlign.center),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: 18),
            RButton(actionLabel!,
                onPressed: onAction, expand: false, height: 44),
          ],
        ],
      ),
    );
  }
}

/// Card padrão (bg/card, raio 22).
class RCard extends StatelessWidget {
  const RCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(16),
      this.radius = RRadius.card,
      this.color = RColors.bgCard});
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(radius)),
        child: child,
      );
}

class HairlineDivider extends StatelessWidget {
  const HairlineDivider({super.key, this.indent = 0});
  final double indent;

  @override
  Widget build(BuildContext context) => Container(
        height: 0.5,
        margin: EdgeInsets.only(left: indent),
        color: RColors.separator,
      );
}
