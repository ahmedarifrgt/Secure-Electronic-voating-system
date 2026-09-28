import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/palette.dart';

/// A circular gauge that visualizes the face-match confidence (0–100%).
///
/// Used on the face verification screen to show how closely the live webcam
/// frame matches the registered photo.
class AccuracyGauge extends StatelessWidget {
  const AccuracyGauge({
    super.key,
    required this.percent,
    this.size = 140,
    this.label,
    this.subtitle,
  });

  /// Confidence percentage 0–100.
  final int percent;
  final double size;
  final String? label;
  final String? subtitle;

  Color get _color {
    if (percent >= 80) return Palette.success;
    if (percent >= 50) return Palette.warning;
    return Palette.error;
  }

  @override
  Widget build(BuildContext context) {
    final clamped = percent.clamp(0, 100);
    final angle = (clamped / 100.0) * 2 * math.pi;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _GaugePainter(
              angle: angle,
              color: _color,
              trackColor: Palette.hairline,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$clamped%',
                    style: TextStyle(
                      fontSize: size * 0.22,
                      fontWeight: FontWeight.w800,
                      color: Palette.navy,
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (label != null)
                    Text(
                      label!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Palette.inkMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: const TextStyle(
              fontSize: 13,
              color: Palette.inkMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.angle,
    required this.color,
    required this.trackColor,
  });

  final double angle;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    const startAngle = -math.pi / 2; // 12 o'clock
    const strokeWidth = 12.0;
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    // Track
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, trackPaint);

    // Value arc
    if (angle <= 0) return;
    final valuePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, startAngle, angle, false, valuePaint);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.angle != angle ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor;
  }
}

