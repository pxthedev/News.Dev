import '../l10n/app_copy.dart';

import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import '../services/analytics.dart';
import '../services/platform_services.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/primitives.dart';
import '../widgets/system.dart';

/// 18 · Compartilhar furo
Future<void> showShareSheet(BuildContext context, Article article) =>
    showRSheet<void>(context, builder: (_) => ShareSheet(article: article));

class ShareSheet extends StatefulWidget {
  const ShareSheet({super.key, required this.article});
  final Article article;

  @override
  State<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<ShareSheet> {
  final _cardKey = GlobalKey();
  bool _busy = false;

  Future<void> _shareImage() async {
    final state = AppScope.read(context);
    final nav = Navigator.of(context);
    setState(() => _busy = true);
    final png = await exportStoryPng(_cardKey);
    await PlatformServices.instance.shareImage(png, text: widget.article.shareUrl);
    Analytics.log('article_shared', {'id': widget.article.id, 'channel': 'image'});
    if (!mounted) return;
    nav.pop();
    state.showToast('Imagem pronta pros Stories');
  }

  Future<void> _shareTo(String channel) async {
    final state = AppScope.read(context);
    final nav = Navigator.of(context);
    if (channel == 'copy') {
      await Clipboard.setData(ClipboardData(text: widget.article.shareUrl));
      state.showToast('Link copiado');
    } else {
      await PlatformServices.instance.shareTo(channel, widget.article.shareUrl);
    }
    Analytics.log('article_shared', {'id': widget.article.id, 'channel': channel});
    if (mounted) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(context.tr('Compartilhar furo'), style: RText.headline),
        const SizedBox(height: 16),
        RepaintBoundary(key: _cardKey, child: ShareCard(article: widget.article)),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _Shortcut(
              label: 'WhatsApp',
              color: const Color(0xFF25D366),
              icon: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 24),
              onTap: () => _shareTo('whatsapp'),
            ),
            _Shortcut(
              label: 'Stories',
              color: const Color(0xFFE1306C),
              icon: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 24),
              onTap: () => _shareTo('stories'),
            ),
            _Shortcut(
              label: 'X',
              color: RColors.bgElevated,
              icon: Text('X', style: RText.title3),
              onTap: () => _shareTo('x'),
            ),
            _Shortcut(
              label: 'LinkedIn',
              color: const Color(0xFF0A66C2),
              icon: Text('in', style: RText.title3),
              onTap: () => _shareTo('linkedin'),
            ),
            _Shortcut(
              label: 'Copiar',
              color: RColors.bgElevated,
              icon: const Icon(Icons.link, color: Colors.white, size: 24),
              onTap: () => _shareTo('copy'),
            ),
          ],
        ),
        const SizedBox(height: 22),
        RButton(_busy ? 'Gerando imagem…' : 'Compartilhar imagem', onPressed: _busy ? null : _shareImage),
      ],
    );
  }
}

/// Card exportado como imagem.
class ShareCard extends StatelessWidget {
  const ShareCard({super.key, required this.article});
  final Article article;

  @override
  Widget build(BuildContext context) {
    const dark = RColors.onRadar;
    final lead = article.leadMinutes;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(RRadius.card),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [RColors.radar, Color(0xFFA9D12A)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIcon(size: 20),
              const SizedBox(width: 6),
              Text('news.dev', style: RText.headline.withColor(dark)),
              const Spacer(),
              if (article.firstInBrazil) const FirstBadge(),
            ],
          ),
          const SizedBox(height: 14),
          Text(article.title, style: RText.title2.withColor(dark)),
          const SizedBox(height: 14),
          Text(
            lead != null
                ? 'Soube $lead min antes da imprensa brasileira'
                : 'Confirmado por ${article.sourceCount} fontes',
            style: RText.footnoteEmph.withColor(dark),
          ),
        ],
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({required this.label, required this.color, required this.icon, required this.onTap});
  final String label;
  final Color color;
  final Widget icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: 'Compartilhar no $label',
      child: ExcludeSemantics(
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: icon,
            ),
            const SizedBox(height: 6),
            Text(label, style: RText.caption1.withColor(RColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

/// Renderiza o card num PNG 1080×1920 (formato Stories) com fundo preto e brilho índigo.
Future<Uint8List?> exportStoryPng(GlobalKey boundaryKey) async {
  final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return null;
  const w = 1080.0;
  const h = 1920.0;
  const margin = 72.0;
  final ratio = (w - margin * 2) / boundary.size.width;
  final card = await boundary.toImage(pixelRatio: ratio);

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, w, h));
  canvas.drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()..color = RColors.bgBase);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, w, h),
    Paint()
      ..shader = ui.Gradient.radial(
        const Offset(w / 2, h * 0.32),
        w * 0.95,
        [RColors.radar.withValues(alpha: 0.32), RColors.radar.withValues(alpha: 0)],
      ),
  );
  canvas.drawImage(card, Offset(margin, (h - card.height) / 2), Paint());

  final image = await recorder.endRecording().toImage(w.toInt(), h.toInt());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data?.buffer.asUint8List();
}
