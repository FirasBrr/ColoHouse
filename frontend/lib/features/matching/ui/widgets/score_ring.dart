import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Circular 0-100 compatibility score that fills up when it appears.
class ScoreRing extends StatelessWidget {
  final int score;
  final double size;
  final double strokeWidth;
  final bool showCaption; // "match" under the number (big ring on the detail screen)

  const ScoreRing({
    super.key,
    required this.score,
    this.size = 56,
    this.strokeWidth = 6,
    this.showCaption = false,
  });

  /// >= 75 green, >= 50 amber, below red (same colors everywhere in matching).
  static Color colorFor(BuildContext context, int score) {
    if (score >= 75) return context.colors.primary;
    if (score >= 50) return context.colors.tertiary;
    return context.colors.error;
  }

  static String labelFor(int score) {
    if (score >= 75) return 'Great match';
    if (score >= 50) return 'Good match';
    return 'Low match';
  }

  @override
  Widget build(BuildContext context) {
    final target = score.clamp(0, 100).toDouble();
    final color = colorFor(context, score);
    final numberSize = size * (showCaption ? 0.28 : 0.3);

    return Semantics(
      label: 'Compatibility $score out of 100',
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: target),
        duration: Duration(milliseconds: showCaption ? 1200 : 900),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _RingPainter(
              progress: value / 100,
              color: color,
              trackColor: color.withValues(alpha: 0.15),
              strokeWidth: strokeWidth,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text.rich(
                    TextSpan(
                      text: '${value.round()}',
                      children: [
                        TextSpan(text: '%', style: TextStyle(fontSize: numberSize * 0.5)),
                      ],
                    ),
                    style: TextStyle(
                      fontSize: numberSize,
                      fontWeight: FontWeight.w800,
                      color: color,
                      height: 1,
                    ),
                  ),
                  if (showCaption) ...[
                    const SizedBox(height: 4),
                    Text(
                      'match',
                      style: TextStyle(
                        fontSize: size * 0.09,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress; // 0..1
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final inset = strokeWidth / 2;
    final rect = Rect.fromLTWH(inset, inset, size.width - strokeWidth, size.height - strokeWidth);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawArc(rect, 0, 2 * math.pi, false, track);
    if (progress <= 0) return;

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;
    // Starts at 12 o'clock
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}
