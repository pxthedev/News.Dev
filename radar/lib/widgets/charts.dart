import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';

/// Gráfico de barras arredondadas (Em alta hoje, Sua semana, widgets).
class MiniBars extends StatelessWidget {
  const MiniBars({
    super.key,
    required this.values,
    required this.highlight,
    this.height = 56,
    this.color = RColors.bgControl,
    this.highlightColor = RColors.radar,
    this.labels,
    this.labelColor = RColors.textSecondary,
    this.gap = 6,
    this.radius = 6,
    this.minFraction = 0.14,
  });

  final List<num> values;
  final int highlight;
  final double height;
  final Color color;
  final Color highlightColor;
  final List<String>? labels;
  final Color labelColor;
  final double gap;
  final double radius;
  final double minFraction;

  @override
  Widget build(BuildContext context) {
    var maxV = values.fold<double>(0, (m, v) => math.max(m, v.toDouble()));
    if (maxV == 0) maxV = 1;
    return ExcludeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: gap / 2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: math.max(minFraction, values[i] / maxV)),
                      duration: Duration(milliseconds: 500 + i * 50),
                      curve: Curves.easeOutCubic,
                      builder: (context, f, _) => Container(
                        height: height * f,
                        decoration: BoxDecoration(
                          color: i == highlight ? highlightColor : color,
                          borderRadius: BorderRadius.circular(radius),
                        ),
                      ),
                    ),
                    if (labels != null) ...[
                      const SizedBox(height: 6),
                      Text(labels![i], style: RText.caption2.withColor(labelColor)),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Anel de progresso (Sua vantagem, widget circular).
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 64,
    this.stroke = 6,
    this.color = RColors.radar,
    this.track = RColors.bgControl,
    this.child,
  });

  final double progress;
  final double size;
  final double stroke;
  final Color color;
  final Color track;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, p, child) => CustomPaint(
          painter: _RingPainter(p, stroke, color, track),
          child: Center(child: child),
        ),
        child: child,
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress, this.stroke, this.color, this.track);
  final double progress;
  final double stroke;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(rect, 0, math.pi * 2, false, base..color = track);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color || old.track != track || old.stroke != stroke;
}

/// Barra de progresso fina (leitura, Live Activity).
class LinearBar extends StatelessWidget {
  const LinearBar({super.key, required this.value, this.color = RColors.radar, this.track = RColors.bgControl, this.height = 3});
  final double value;
  final Color color;
  final Color track;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: track)),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0, 1).toDouble(),
              child: ColoredBox(color: color, child: SizedBox(height: height)),
            ),
          ],
        ),
      ),
    );
  }
}
